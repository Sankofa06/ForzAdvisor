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

        XCTAssertThrowsError(try coordinator.scheduleAndRun(task))
        XCTAssertEqual(state.draftCalls, 1)
        XCTAssertEqual(state.localCalls, 1)
        XCTAssertEqual(state.authorizationCalls, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: pendingURL.path))

        state.localFails = false
        try coordinator.retryPending()
        XCTAssertEqual(state.draftCalls, 2)
        XCTAssertEqual(state.localCalls, 2)
        XCTAssertEqual(state.authorizationCalls, 2)
        XCTAssertFalse(FileManager.default.fileExists(atPath: pendingURL.path))
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
