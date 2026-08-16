import SwiftData
import XCTest
@testable import forzadvisor

extension CopilotWorkflowActionRouterTests {
    func testExactSequenceRequiresValidationBeforeCommunityAndZeroTrials()
        async throws {
        let tune = try await eligibleCommunityTune()
        var oldTune = tune
        oldTune.id = UUID()
        let currentStep = resultStep(tune)
        let freshThumbnail = Data("fresh-thumbnail".utf8)
        let freshNotes = "Fresh persisted notes"
        let unvalidated = actionSnapshot(
            tune,
            validationCount: 0,
            thumbnailData: freshThumbnail,
            playerNotes: freshNotes
        )
        XCTAssertNotNil(
            router.destination(
                for: .openRecordTestDrive,
                from: currentStep,
                authoritativeSnapshot: unvalidated
            )
        )
        XCTAssertNil(router.destination(
            for: .openFH6CommunityReferenceTrial,
            from: currentStep,
            authoritativeSnapshot: unvalidated
        ))

        let validated = actionSnapshot(
            tune,
            validationCount: 1,
            thumbnailData: freshThumbnail,
            playerNotes: freshNotes
        )
        let destination = try XCTUnwrap(router.destination(
            for: .openFH6CommunityReferenceTrial,
            from: currentStep,
            authoritativeSnapshot: validated
        ))
        guard case .fh6CommunityReferenceTrialCapture(
            let routedTune,
            let routedSavedTuneID,
            let routedThumbnail,
            let routedNotes
        ) = destination else {
            return XCTFail("Expected community comparison capture")
        }
        XCTAssertEqual(routedTune, tune)
        XCTAssertEqual(routedSavedTuneID, savedTuneID)
        XCTAssertEqual(routedThumbnail, freshThumbnail)
        XCTAssertEqual(routedNotes, freshNotes)
        XCTAssertNotEqual(routedThumbnail, thumbnailData)
        XCTAssertNotEqual(routedNotes, playerNotes)

        XCTAssertNil(router.destination(
            for: .openFH6CommunityReferenceTrial,
            from: currentStep,
            authoritativeSnapshot: actionSnapshot(
                tune,
                validationCount: 1,
                communityCount: 1
            )
        ))
        XCTAssertNil(router.destination(
            for: .openRecordTestDrive,
            from: resultStep(oldTune),
            authoritativeSnapshot: unvalidated
        ))
        let higherPriorityTune = try eligibleTune(for: .tuneMenu)
        XCTAssertNil(router.destination(
            for: .openFH6CommunityReferenceTrial,
            from: resultStep(higherPriorityTune),
            authoritativeSnapshot: actionSnapshot(
                higherPriorityTune,
                validationCount: 1
            )
        ))
    }

    @MainActor
    func testRootSnapshotFetchesFreshPayloadCountsAndFailsClosed()
        async throws {
        let tune = try await eligibleCommunityTune()
        let directory = FileManager.default.temporaryDirectory
            .appending(
                path:
                    "forzadvisor-copilot-root-\(UUID().uuidString)",
                directoryHint: .isDirectory
            )
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }
        let container = try ModelContainer(
            for: SavedTune.self,
            configurations: ModelConfiguration(
                url: directory.appending(path: "store.sqlite")
            )
        )
        let writer = ModelContext(container)
        let saved = try SavedTune(
            tune: tune,
            playerNotes: "Fresh root notes",
            thumbnailData: Data("fresh-root-thumbnail".utf8)
        )
        writer.insert(saved)
        try writer.save()

        let reader = ModelContext(container)
        let first = try XCTUnwrap(
            CopilotPersistedActionSnapshotResolver()
                .resolve(
                    displayedTune: tune,
                    savedTuneID: savedTuneID,
                    in: reader
                )
        )
        XCTAssertEqual(first.result.tune, tune)
        XCTAssertEqual(
            first.result.playerNotes,
            "Fresh root notes"
        )
        XCTAssertEqual(
            first.result.thumbnailData,
            Data("fresh-root-thumbnail".utf8)
        )
        XCTAssertEqual(first.matchingValidationRecordCount, 0)
        XCTAssertEqual(first.matchingCommunityTrialCount, 0)

        let validation =
            try FirstPartyValidationRecordFactory().make(
                tune: tune,
                savedTune: tune,
                isStreaming: false,
                capture: validValidationCapture()
            )
        try saved.appendValidationRecord(validation)
        try writer.save()
        let afterValidation = try XCTUnwrap(
            CopilotPersistedActionSnapshotResolver()
                .resolve(
                    displayedTune: tune,
                    savedTuneID: savedTuneID,
                    in: ModelContext(container)
                )
        )
        XCTAssertEqual(
            afterValidation.matchingValidationRecordCount,
            1
        )

        var staleDisplayedTune = tune
        staleDisplayedTune.generatedAt.addTimeInterval(1)
        XCTAssertNil(
            try CopilotPersistedActionSnapshotResolver()
                .resolve(
                    displayedTune: staleDisplayedTune,
                    savedTuneID: savedTuneID,
                    in: ModelContext(container)
                )
        )

        saved.replaceValidationRecordsDataForTesting(
            Data("corrupt".utf8)
        )
        try writer.save()
        XCTAssertThrowsError(
            try CopilotPersistedActionSnapshotResolver()
                .resolve(
                    displayedTune: tune,
                    savedTuneID: savedTuneID,
                    in: ModelContext(container)
                )
        )
    }

}
