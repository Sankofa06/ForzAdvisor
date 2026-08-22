import XCTest
@testable import forzadvisor

final class ValidationDraftCleanupCoordinatorTests: XCTestCase {
    private enum InjectedFailure: Error { case expected }

    func testCommittedDraftCleanupFailureRemainsPendingThenRetries() throws {
        final class State {
            var shouldFail = true
            var calls = 0
        }
        let state = State()
        let pendingURL = temporaryURL()
        let coordinator = ValidationDraftCleanupCoordinator(
            pendingURL: pendingURL,
            deleteDraft: { _, _ in
                state.calls += 1
                if state.shouldFail { throw InjectedFailure.expected }
            }
        )
        let task = ValidationDraftCleanupTask(
            kind: .fh6TuneMenuCapture,
            savedTuneID: UUID()
        )

        XCTAssertThrowsError(try coordinator.scheduleAndRun(task))
        XCTAssertEqual(state.calls, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: pendingURL.path))

        state.shouldFail = false
        try coordinator.retryPending()
        XCTAssertEqual(state.calls, 2)
        XCTAssertFalse(FileManager.default.fileExists(atPath: pendingURL.path))
    }

    func testCorruptQueueIsQuarantinedBeforeCurrentTaskIsScheduled() throws {
        let pendingURL = temporaryURL()
        try FileManager.default.createDirectory(
            at: pendingURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("not-json".utf8).write(to: pendingURL)
        var deleted: [ValidationDraftCleanupTask] = []
        let coordinator = ValidationDraftCleanupCoordinator(
            pendingURL: pendingURL,
            deleteDraft: { kind, savedTuneID in
                deleted.append(.init(kind: kind, savedTuneID: savedTuneID))
            }
        )
        let task = ValidationDraftCleanupTask(
            kind: .fh5ResearchObservation,
            savedTuneID: UUID()
        )

        try coordinator.scheduleAndRun(task)

        XCTAssertEqual(deleted, [task])
        XCTAssertFalse(FileManager.default.fileExists(atPath: pendingURL.path))
        let quarantined = try FileManager.default.contentsOfDirectory(
            at: pendingURL.deletingLastPathComponent(),
            includingPropertiesForKeys: nil
        ).filter { $0.lastPathComponent.contains("corrupt-") }
        XCTAssertEqual(quarantined.count, 1)
    }

    func testConfirmedGenerationCommitUsesCoordinatorAndCleanupFailureIsOnlyAWarning() throws {
        let pendingURL = temporaryURL()
        var shouldFail = true
        var cleanupCalls: [ValidationDraftCleanupTask] = []
        let coordinator = ValidationDraftCleanupCoordinator(
            pendingURL: pendingURL,
            deleteDraft: { kind, savedTuneID in
                cleanupCalls.append(.init(
                    kind: kind,
                    savedTuneID: savedTuneID
                ))
                if shouldFail { throw InjectedFailure.expected }
            }
        )
        let task = ValidationDraftCleanupTask(
            kind: .fh6TuneMenuCapture,
            savedTuneID: UUID()
        )
        let outcome = coordinator.runAfterConfirmedGenerationCommit(task)

        guard case .pendingWarning(let warning) = outcome else {
            return XCTFail("Cleanup failure must become a postcommit warning.")
        }
        XCTAssertEqual(cleanupCalls, [task])
        XCTAssertTrue(warning.hasPrefix("Tune saved."))
        XCTAssertTrue(warning.contains("will retry next launch"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: pendingURL.path))

        shouldFail = false
        XCTAssertEqual(
            coordinator.runAfterConfirmedGenerationCommit(task),
            .completed
        )
        XCTAssertEqual(cleanupCalls, [task, task])
        XCTAssertFalse(FileManager.default.fileExists(atPath: pendingURL.path))
    }

    func testGenerationSuccessWiresPostcommitCleanupWithoutFailureRouting() throws {
        let source = try bundledSourceContract(
            named: "ContentView+GenerationWorkflow"
        )
        let successStart = try XCTUnwrap(source.range(
            of: "onSuccess: { tune in"
        ))
        let failureStart = try XCTUnwrap(source.range(
            of: "onFailure: { failedSession, error in",
            range: successStart.upperBound..<source.endIndex
        ))
        let success = String(
            source[successStart.lowerBound..<failureStart.lowerBound]
        )
        let failureAndFollowingWorkflow = String(source[failureStart.lowerBound...])

        XCTAssertTrue(success.contains("ValidationDraftCleanupCoordinator"))
        XCTAssertTrue(success.contains(
            "runAfterConfirmedGenerationCommit"
        ))
        XCTAssertTrue(success.contains(
            "if case .pendingWarning(let message) = cleanupOutcome"
        ))
        XCTAssertTrue(success.contains("errorMessage = message"))
        XCTAssertTrue(success.contains("step = .result"))
        XCTAssertFalse(success.contains("step = .generationFailed"))
        XCTAssertFalse(failureAndFollowingWorkflow.contains(
            "runAfterConfirmedGenerationCommit"
        ))
    }

    private func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("pending.json")
    }

    private func bundledSourceContract(named name: String) throws -> String {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(
            forResource: name,
            withExtension: "swift",
            subdirectory: "SourceContracts"
        ))
        return try String(contentsOf: url, encoding: .utf8)
    }
}
