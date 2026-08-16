import SwiftData
import XCTest
@testable import forzadvisor

extension CopilotWorkflowActionRouterTests {
    @MainActor
    func testPersistedFH5ResearchRoutePreservesPayloadAndFailsClosed()
        throws {
        let tune = try eligibleTune(for: .upgrade, game: .fh5)
        let freshThumbnail = Data("fresh-fh5-thumbnail".utf8)
        let freshNotes = "Fresh persisted FH5 notes"
        let directory = FileManager.default.temporaryDirectory
            .appending(
                path:
                    "forzadvisor-copilot-fh5-\(UUID().uuidString)",
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
        writer.insert(try SavedTune(
            tune: tune,
            playerNotes: freshNotes,
            thumbnailData: freshThumbnail
        ))
        try writer.save()
        let reader = ModelContext(container)
        let persisted = try XCTUnwrap(
            reader.fetch(FetchDescriptor<SavedTune>()).first
        )
        XCTAssertEqual(persisted.id, tune.id)
        XCTAssertEqual(persisted.tuneResult, tune)
        let authoritative = try XCTUnwrap(
            CopilotPersistedActionSnapshotResolver().resolve(
                displayedTune: tune,
                savedTuneID: tune.id,
                in: reader
            )
        )
        XCTAssertNotNil(
            UpgradePartCaptureEligibility().snapshot(
                for: authoritative.result.tune
            )
        )
        XCTAssertTrue(authoritative.fh5ResearchLabEligible)
        XCTAssertEqual(
            authoritative.matchingFH5ResearchObservationCount,
            0
        )
        XCTAssertEqual(tune.purpose, .fh5BuildPlan)
        XCTAssertEqual(tune.request.car.game, .fh5)
        XCTAssertEqual(tune.id, savedTuneID)
        XCTAssertTrue(
            TuneResultBoundarySanitizer()
                .isSafeFH5BuildPlan(tune)
        )
        XCTAssertEqual(tune.projectionReport?.readyCount, 0)
        let destination = try XCTUnwrap(router.destination(
            for: .openFH5ResearchLab,
            from: resultStep(tune),
            authoritativeSnapshot: authoritative
        ))
        assertDestination(
            destination,
            route: .research,
            expectedTune: tune,
            expectedThumbnailData: freshThumbnail,
            expectedPlayerNotes: freshNotes
        )

        let unsaved = WorkflowStep.result(
            tune,
            savedTuneID: nil,
            adjustmentChanges: [],
            thumbnailData: thumbnailData,
            playerNotes: playerNotes
        )
        XCTAssertNil(router.destination(
            for: .openFH5ResearchLab,
            from: unsaved,
            authoritativeSnapshot: authoritative
        ))

        var stale = tune
        stale.generatedAt.addTimeInterval(1)
        XCTAssertNil(router.destination(
            for: .openFH5ResearchLab,
            from: resultStep(stale),
            authoritativeSnapshot: authoritative
        ))

        var ineligible = tune
        ineligible.projectionReport?.fields = [
            readyField(.frontCamber)
        ]
        XCTAssertNil(router.destination(
            for: .openFH5ResearchLab,
            from: resultStep(ineligible),
            authoritativeSnapshot: actionSnapshot(
                ineligible,
                fh5ResearchLabEligible: true
            )
        ))
        XCTAssertNil(router.destination(
            for: .openTireLab,
            from: resultStep(tune),
            authoritativeSnapshot: authoritative
        ))
        XCTAssertNil(router.destination(
            for: .openUpgradeLab,
            from: resultStep(tune),
            authoritativeSnapshot: authoritative
        ))

        let upgradeFallback = try XCTUnwrap(router.destination(
            for: .openUpgradeLab,
            from: resultStep(tune),
            authoritativeSnapshot: actionSnapshot(tune)
        ))
        assertDestination(
            upgradeFallback,
            route: .upgrade,
            expectedTune: tune,
            expectedThumbnailData: thumbnailData,
            expectedPlayerNotes: playerNotes
        )

        let record = try FH5ResearchObservationFactory().make(
            tune: tune,
            savedTune: tune,
            isStreaming: false,
            capture: validFH5ResearchCapture(for: tune),
            capturedAt:
                Date(timeIntervalSinceReferenceDate: 920)
        )
        try persisted.appendFH5ResearchObservationRecord(record)
        try reader.save()
        let afterObservation = try XCTUnwrap(
            CopilotPersistedActionSnapshotResolver().resolve(
                displayedTune: tune,
                savedTuneID: tune.id,
                in: ModelContext(container)
            )
        )
        XCTAssertEqual(
            afterObservation.matchingFH5ResearchObservationCount,
            1
        )
        for action in [
            CopilotAction.openFH5ResearchLab,
            .openUpgradeLab
        ] {
            XCTAssertNil(router.destination(
                for: action,
                from: resultStep(tune),
                authoritativeSnapshot: afterObservation
            ))
        }

        persisted.replaceFH5ResearchObservationRecordsDataForTesting(
            Data("corrupt".utf8)
        )
        try reader.save()
        XCTAssertThrowsError(
            try CopilotPersistedActionSnapshotResolver().resolve(
                displayedTune: tune,
                savedTuneID: tune.id,
                in: ModelContext(container)
            )
        )

        var readyForgery = tune
        readyForgery.projectionReport?.fields[0] =
            readyField(.frontCamber)
        assertFH5ActionsRejected(readyForgery)

        var numericSections = tune
        numericSections.sections = [TuneSection(
            title: "Forged numeric output",
            symbolName: "exclamationmark.triangle",
            lines: [TuneLine(
                label: "Front camber",
                value: "-1.5",
                unit: "degrees",
                fieldID: .frontCamber
            )]
        )]
        assertFH5ActionsRejected(numericSections)

        var providerTagged = tune
        providerTagged.providerInfo = .direct(.anthropicAPI)
        assertFH5ActionsRejected(providerTagged)

        var rulesetTagged = tune
        rulesetTagged.rulesetReference = try XCTUnwrap(
            TuneRulesetReference(descriptor: TuneRulesetDescriptor(
                id: "forged.fh5.copilot",
                game: .fh5,
                schemaVersion: 1,
                algorithmVersion: "forged",
                knowledgeRevision: "forged",
                validationStatus: .validated,
                provenanceIDs: ["forged"]
            ))
        )
        assertFH5ActionsRejected(rulesetTagged)

        var invalidProjection = tune
        invalidProjection.projectionReport?.schemaVersion =
            TuneProjectionReport.currentSchemaVersion + 1
        assertFH5ActionsRejected(invalidProjection)

        var staleProjection = tune
        staleProjection.projectionReport?.snapshotID = UUID()
        assertFH5ActionsRejected(staleProjection)
    }

}
