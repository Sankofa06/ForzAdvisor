import XCTest
@testable import forzadvisor

final class ValidationEvidencePurgeCoordinatorTests: XCTestCase {
    private enum InjectedFailure: Error { case expected }

    @MainActor
    func testPurgeAttemptsEveryStoreAndRetriesOnlyWhilePending() throws {
        final class State {
            var draftCalls = 0
            var localCalls = 0
            var authorizationCalls = 0
            var localFails = true
        }
        let state = State()
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let pendingURL = directory.appendingPathComponent("pending.json")
        let coordinator = ValidationEvidencePurgeCoordinator(
            pendingURL: pendingURL,
            purgeDrafts: { _ in state.draftCalls += 1 },
            purgeLocal: { _ in
                state.localCalls += 1
                if state.localFails { throw InjectedFailure.expected }
            },
            purgeAuthorizations: { _ in state.authorizationCalls += 1 }
        )
        let task = ValidationTunePurgeTask(
            savedTuneID: UUID(),
            authorizationFingerprints: ["fingerprint-a", "fingerprint-b"]
        )

        try coordinator.schedule(task)
        XCTAssertThrowsError(try coordinator.confirmAndRun(
            savedTuneID: task.savedTuneID
        ))
        XCTAssertEqual(state.draftCalls, 1)
        XCTAssertEqual(state.localCalls, 1)
        XCTAssertEqual(state.authorizationCalls, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: pendingURL.path))

        state.localFails = false
        try coordinator.retryPending(tuneExists: { _ in false })
        XCTAssertEqual(state.draftCalls, 2)
        XCTAssertEqual(state.localCalls, 2)
        XCTAssertEqual(state.authorizationCalls, 2)
        XCTAssertFalse(FileManager.default.fileExists(atPath: pendingURL.path))
    }

    @MainActor
    func testCorruptQueueIsQuarantinedBeforeNewTaskIsScheduled() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let pendingURL = directory.appendingPathComponent("pending.json")
        try Data("not-json".utf8).write(to: pendingURL)
        var purgeCalls = 0
        let coordinator = ValidationEvidencePurgeCoordinator(
            pendingURL: pendingURL,
            purgeDrafts: { _ in purgeCalls += 1 },
            purgeLocal: { _ in },
            purgeAuthorizations: { _ in }
        )
        let task = ValidationTunePurgeTask(
            savedTuneID: UUID(),
            authorizationFingerprints: ["target"]
        )

        try coordinator.schedule(task)
        let quarantined = try FileManager.default.contentsOfDirectory(
            atPath: directory.path
        ).filter { $0.hasPrefix("pending.json.corrupt-") }
        XCTAssertEqual(quarantined.count, 1)
        try coordinator.confirmAndRun(savedTuneID: task.savedTuneID)
        XCTAssertEqual(purgeCalls, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: pendingURL.path))
    }

    @MainActor
    func testPreparedTaskIsCancelledAfterCommitFailure() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let pendingURL = directory.appendingPathComponent("pending.json")
        var purgeCalls = 0
        let coordinator = ValidationEvidencePurgeCoordinator(
            pendingURL: pendingURL,
            purgeDrafts: { _ in purgeCalls += 1 },
            purgeLocal: { _ in purgeCalls += 1 },
            purgeAuthorizations: { _ in purgeCalls += 1 }
        )
        let task = ValidationTunePurgeTask(
            savedTuneID: UUID(),
            authorizationFingerprints: ["target"]
        )

        try coordinator.schedule(task)
        try coordinator.retryPending(tuneExists: { id in
            id == task.savedTuneID
        })

        XCTAssertEqual(purgeCalls, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: pendingURL.path))
    }

    @MainActor
    func testDeletionTransactionSchedulesBeforeCommitAndRollsBackSafely() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let pendingURL = directory.appendingPathComponent("pending.json")
        var purgeCalls = 0
        var rollbackCalled = false
        let purge = ValidationEvidencePurgeCoordinator(
            pendingURL: pendingURL,
            purgeDrafts: { _ in purgeCalls += 1 },
            purgeLocal: { _ in purgeCalls += 1 },
            purgeAuthorizations: { _ in purgeCalls += 1 }
        )
        let task = ValidationTunePurgeTask(
            savedTuneID: UUID(),
            authorizationFingerprints: ["target"]
        )

        XCTAssertThrowsError(try ValidationTuneDeletionTransactionCoordinator(
            purgeCoordinator: purge
        ).perform(
            task: task,
            commitDeletion: {
                XCTAssertTrue(FileManager.default.fileExists(
                    atPath: pendingURL.path
                ))
                throw InjectedFailure.expected
            },
            rollbackDeletion: { rollbackCalled = true }
        ))

        XCTAssertTrue(rollbackCalled)
        XCTAssertEqual(purgeCalls, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: pendingURL.path))
    }

    @MainActor
    func testPlannerFailsClosedAndRetainsSharedFingerprints() throws {
        let targetID = UUID()
        let otherID = UUID()
        let planner = ValidationTunePurgePlanner()
        let task = try planner.makeTask(
            deleting: targetID,
            sources: [
                .init(
                    savedTuneID: targetID,
                    legacy: { ["target", "shared"] },
                    local: { ["local-target"] },
                    blocked: { ["blocked-target", "blocked-shared"] }
                ),
                .init(
                    savedTuneID: otherID,
                    legacy: { ["shared"] },
                    local: { ["local-other"] },
                    blocked: { ["blocked-shared"] }
                )
            ]
        )
        XCTAssertEqual(
            task.authorizationFingerprints,
            ["target", "local-target", "blocked-target"]
        )

        XCTAssertThrowsError(try planner.makeTask(
            deleting: targetID,
            sources: [
                .init(
                    savedTuneID: targetID,
                    legacy: { throw InjectedFailure.expected },
                    local: { [] },
                    blocked: { [] }
                )
            ]
        ))
    }

    @MainActor
    func testAuthorizationPurgeRemovesOnlyTargetTuneReceipts() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = ValidationEvidenceAuthorizationStore(
            fileURL: directory.appendingPathComponent("auth.json")
        )
        let first = ValidationEvidenceAuthorizationEnvelope.reusable(
            observationFingerprint: "first",
            authorizationID: UUID(),
            authorizationVersion: "validation-reuse-v1",
            authorizedAt: .now
        )
        let second = ValidationEvidenceAuthorizationEnvelope.reusable(
            observationFingerprint: "second",
            authorizationID: UUID(),
            authorizationVersion: "validation-reuse-v1",
            authorizedAt: .now
        )
        try store.persist(first)
        try store.persist(second)

        XCTAssertEqual(try store.purge(fingerprints: ["first"]), 1)
        XCTAssertNil(try store.authorizationResult(for: "first"))
        let retained = try XCTUnwrap(
            store.authorizationResult(for: "second")
        )
        XCTAssertEqual(retained.observationFingerprint, "second")
        XCTAssertEqual(retained.authorizationID, second.authorizationID)
        XCTAssertTrue(retained.allowsReuse(of: "second"))
    }
}
