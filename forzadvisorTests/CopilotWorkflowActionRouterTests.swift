//
//  CopilotWorkflowActionRouterTests.swift
//  forzadvisorTests
//

import SwiftData
import XCTest
@testable import forzadvisor

final class CopilotWorkflowActionRouterTests: XCTestCase {
    private let router = CopilotWorkflowActionRouter()
    private let savedTuneID = UUID(
        uuidString: "D16AFEB1-5E7D-4F15-942F-54377261C977"
    )!
    private let thumbnailData = Data("copilot-thumbnail".utf8)
    private let playerNotes = "Preserve these player notes exactly."

    func testValidRoutesPreserveExactLiveResultPayload() throws {
        for (action, route) in [
            (CopilotAction.openFH6TuneMenuLab, Route.tuneMenu),
            (.openTireLab, .tire),
            (.openUpgradeLab, .upgrade)
        ] {
            let tune = try eligibleTune(for: route)
            let current = resultStep(tune)
            let freshThumbnail =
                Data("fresh-\(route)-thumbnail".utf8)
            let freshNotes = "Fresh \(route) notes"
            let destination = try XCTUnwrap(
                router.destination(
                    for: action,
                    from: current,
                    authoritativeSnapshot:
                        actionSnapshot(
                            tune,
                            thumbnailData: freshThumbnail,
                            playerNotes: freshNotes
                        )
                )
            )

            assertDestination(
                destination,
                route: route,
                expectedTune: tune,
                expectedThumbnailData: freshThumbnail,
                expectedPlayerNotes: freshNotes
            )
        }
    }

    func testTuneMenuPrioritySuppressesTireAndUpgradeActions() throws {
        let tune = try eligibleTune(for: .tuneMenu)
        let current = resultStep(tune)

        XCTAssertNotNil(
            router.destination(
                for: .openFH6TuneMenuLab,
                from: current,
                authoritativeSnapshot: actionSnapshot(tune)
            )
        )
        XCTAssertNil(
            router.destination(
                for: .openTireLab,
                from: current,
                authoritativeSnapshot: actionSnapshot(tune)
            )
        )
        XCTAssertNil(
            router.destination(
                for: .openUpgradeLab,
                from: current,
                authoritativeSnapshot: actionSnapshot(tune)
            )
        )
    }

    func testRouterRejectsStaleWrongNonResultAndIneligibleActions() throws {
        let tune = try eligibleTune(for: .tuneMenu)

        XCTAssertNil(
            router.destination(
                for: .openFH6TuneMenuLab,
                from: .home,
                authoritativeSnapshot: actionSnapshot(tune)
            )
        )
        XCTAssertNil(
            router.destination(
                for: .openTireLab,
                from: resultStep(tune),
                authoritativeSnapshot: actionSnapshot(tune)
            )
        )
        XCTAssertNil(
            router.destination(
                for: .openFH6TuneMenuLab,
                from: resultStep(tune),
                authoritativeSnapshot: nil
            )
        )

        var noProjection = tune
        noProjection.projectionReport = nil
        XCTAssertNil(
            router.destination(
                for: .openFH6TuneMenuLab,
                from: resultStep(noProjection),
                authoritativeSnapshot:
                    actionSnapshot(noProjection)
            )
        )

        var noReadyValues = tune
        noReadyValues.projectionReport?.fields.removeAll {
            $0.status == .ready
        }
        XCTAssertNil(
            router.destination(
                for: .openFH6TuneMenuLab,
                from: resultStep(noReadyValues),
                authoritativeSnapshot:
                    actionSnapshot(noReadyValues)
            )
        )

        var edited = tune
        edited.request.car.weightPounds += 1
        XCTAssertNil(
            router.destination(
                for: .openFH6TuneMenuLab,
                from: resultStep(edited),
                authoritativeSnapshot: actionSnapshot(tune)
            )
        )
    }

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

    private func eligibleTune(
        for route: Route,
        game: ForzaGame = .fh6
    ) throws -> TuneResult {
        let car = CopilotRouterFixtureFactory.car(game: game)
        let snapshot = CopilotRouterFixtureFactory.capabilitySnapshot(
            car: car,
            capturedAt: Date(timeIntervalSinceReferenceDate: 867)
        )

        let fields: [TuneFieldProjection]
        let confirmations: [TuneSettingConfirmation]
        switch route {
        case .tuneMenu:
            fields = [
                readyField(.frontCamber),
                constrainedField(.frontTirePressure),
                constrainedField(.rearTirePressure),
                partConfirmationField(.finalDrive)
            ]
            confirmations = [finalDriveConfirmation]
        case .tire:
            fields = [
                readyField(.frontCamber),
                constrainedField(.frontTirePressure),
                constrainedField(.rearTirePressure),
                readyField(.caster),
                readyField(.caster)
            ]
            confirmations = []
        case .upgrade, .research:
            fields = [
                readyField(.frontCamber),
                partConfirmationField(.finalDrive),
                readyField(.caster),
                readyField(.caster)
            ]
            confirmations = [finalDriveConfirmation]
        }

        let tune = TuneResult(
            id: savedTuneID,
            request: TuneRequest(
                car: car,
                discipline: .road,
                buildSnapshot: snapshot
            ),
            sections: [],
            notes: TuneNotes(
                bias: "",
                ifPushesWide: "",
                ifSnapsOnLift: "",
                retuneTrigger: ""
            ),
            generatedAt:
                Date(timeIntervalSinceReferenceDate: 868),
            purpose: game == .fh5 ? .fh5BuildPlan : .numericTune,
            projectionReport: TuneProjectionReport(
                schemaVersion: TuneProjectionReport.currentSchemaVersion,
                snapshotID: snapshot.id,
                contextStatus: .capabilityOnly,
                capabilityResolution: nil,
                fields: fields,
                purchasePlan: [],
                confirmations: confirmations,
                diagnostics: []
            )
        )
        return game == .fh5
            ? TuneResultBoundarySanitizer().sanitize(tune)
            : tune
    }

    private func eligibleCommunityTune() async throws -> TuneResult {
        let capturedAt = Date(timeIntervalSinceReferenceDate: 909)
        let capability = CopilotRouterFixtureFactory.capabilitySnapshot(
            car: CopilotRouterFixtureFactory.car(game: .fh6),
            capturedAt: capturedAt
        )
        let parts = try UpgradePartCapture(
            gameBuildVersion: "test-build",
            parts: TunePartID.allCases.map {
                UpgradePartCaptureValue(
                    partID: $0,
                    status: .offered
                )
            },
            exactStockBuildConfirmed: true,
            localUsePermitted: true
        ).verifiedSnapshot(
            upgrading: capability,
            capturedAt: capturedAt
        )
        let exact = try TirePressureCapture(
            gameBuildVersion: "test-build",
            tireCompound: "Stock",
            gearCount: 6,
            front: .init(
                minimumPSI: 15,
                maximumPSI: 40,
                stepPSI: 0.5,
                currentPSI: 30
            ),
            rear: .init(
                minimumPSI: 15,
                maximumPSI: 40,
                stepPSI: 0.5,
                currentPSI: 30
            ),
            exactStockBuildConfirmed: true,
            localUsePermitted: true
        ).exactBuildSnapshot(
            upgrading: parts,
            capturedAt: capturedAt,
            evidenceID: "copilot-community"
        )
        var tune = try await CapabilityProjectingTuneProvider(
            base: LocalSampleTuneProvider()
        ).generateTune(for: TuneRequest(
            car: exact.car,
            discipline: .road,
            buildSnapshot: exact
        ))
        tune.id = savedTuneID
        tune.generatedAt =
            Date(timeIntervalSinceReferenceDate: 910)
        return tune
    }

    private func resultStep(_ tune: TuneResult) -> WorkflowStep {
        .result(
            tune,
            savedTuneID: savedTuneID,
            adjustmentChanges: [],
            thumbnailData: thumbnailData,
            playerNotes: playerNotes
        )
    }

    private func actionSnapshot(
        _ tune: TuneResult,
        validationCount: Int = 0,
        communityCount: Int = 0,
        fh5ResearchLabEligible: Bool = false,
        matchingFH5ResearchObservationCount: Int = 0,
        thumbnailData: Data? = nil,
        playerNotes: String? = nil
    ) -> CopilotPersistedActionSnapshot {
        CopilotPersistedActionSnapshot(
            result: CopilotPersistedResultPayload(
                tune: tune,
                thumbnailData:
                    thumbnailData ?? self.thumbnailData,
                playerNotes:
                    playerNotes ?? self.playerNotes
            ),
            accuracyEvidenceChain: .init(
                stage:
                    validationCount == 0
                        ? .needsFirstPartyValidation
                        : communityCount == 0
                            ? .readyForCommunityComparison
                            : .communityComparisonCollected,
                matchingValidationCount:
                    validationCount,
                matchingCommunityComparisonCount:
                    communityCount
            ),
            fh5ResearchLabEligible:
                fh5ResearchLabEligible,
            matchingFH5ResearchObservationCount:
                matchingFH5ResearchObservationCount
        )
    }

    private func assertFH5ActionsRejected(
        _ tune: TuneResult,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertFalse(
            TuneResultBoundarySanitizer()
                .isSafeFH5BuildPlan(tune),
            file: file,
            line: line
        )
        for action in [
            CopilotAction.openFH5ResearchLab,
            .openUpgradeLab
        ] {
            XCTAssertNil(
                router.destination(
                    for: action,
                    from: resultStep(tune),
                    authoritativeSnapshot: actionSnapshot(
                        tune,
                        fh5ResearchLabEligible: true
                    )
                ),
                file: file,
                line: line
            )
        }
    }

    private func assertDestination(
        _ destination: WorkflowStep,
        route: Route,
        expectedTune: TuneResult,
        expectedThumbnailData: Data?,
        expectedPlayerNotes: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let payload: (
            tune: TuneResult,
            savedTuneID: UUID?,
            thumbnailData: Data?,
            playerNotes: String
        )
        switch (route, destination) {
        case let (
            .tuneMenu,
            .fh6TuneMenuCapture(
                tune,
                savedTuneID,
                thumbnailData,
                playerNotes
            )
        ),
        let (
            .tire,
            .tirePressureCapture(
                tune,
                savedTuneID,
                thumbnailData,
                playerNotes
            )
        ),
        let (
            .upgrade,
            .upgradePartCapture(
                tune,
                savedTuneID,
                thumbnailData,
                playerNotes
            )
        ):
            payload = (
                tune,
                savedTuneID,
                thumbnailData,
                playerNotes
            )
        case let (
            .research,
            .fh5ResearchCapture(
                tune,
                savedTuneID,
                thumbnailData,
                playerNotes
            )
        ):
            payload = (
                tune,
                Optional(savedTuneID),
                thumbnailData,
                playerNotes
            )
        default:
            return XCTFail(
                "Unexpected destination for \(route)",
                file: file,
                line: line
            )
        }

        XCTAssertEqual(payload.tune, expectedTune, file: file, line: line)
        XCTAssertEqual(
            payload.savedTuneID,
            savedTuneID,
            file: file,
            line: line
        )
        XCTAssertEqual(
            payload.thumbnailData,
            expectedThumbnailData,
            file: file,
            line: line
        )
        XCTAssertEqual(
            payload.playerNotes,
            expectedPlayerNotes,
            file: file,
            line: line
        )
    }

    private func readyField(_ field: TuneFieldID) -> TuneFieldProjection {
        TuneFieldProjection(
            field: field,
            status: .ready,
            requiredPurchaseIDs: [],
            unresolvedPartIDs: [],
            reason: nil
        )
    }

    private func constrainedField(
        _ field: TuneFieldID
    ) -> TuneFieldProjection {
        TuneFieldProjection(
            field: field,
            status: .needsConstraint,
            requiredPurchaseIDs: [],
            unresolvedPartIDs: [],
            reason: .missingProductionConstraint
        )
    }

    private func partConfirmationField(
        _ field: TuneFieldID
    ) -> TuneFieldProjection {
        TuneFieldProjection(
            field: field,
            status: .needsPartConfirmation,
            requiredPurchaseIDs: [],
            unresolvedPartIDs: [.sportTransmission],
            reason: .partAvailabilityUnknown
        )
    }

    private var finalDriveConfirmation: TuneSettingConfirmation {
        TuneSettingConfirmation(
            setting: .finalDrive,
            candidateParts: [
                TunePartCatalog.definition(for: .sportTransmission)
            ]
        )
    }

    private func validFH5ResearchCapture(
        for tune: TuneResult
    ) -> FH5ResearchCapture {
        let gearCount = 6
        return FH5ResearchCapture(
            platform: .xboxSeries,
            gameVersion: "test-build",
            tireCompoundDisplayName: "Stock",
            forwardGearCount: gearCount,
            controls: TuneFieldID.expectedFields(
                drivetrain: tune.request.car.drivetrain,
                gearCount: gearCount
            ).map {
                FH5TuneFieldObservation(
                    field: $0,
                    availability: .notShown
                )
            },
            exactUntouchedStockConfirmed: true,
            allSlidersRestoredConfirmed: true,
            personallyReadFromGameConfirmed: true,
            firstPartyAuthorshipConfirmed: true,
            localStoragePermitted: true
        )
    }

    private func validValidationCapture()
        -> FirstPartyValidationCapture {
        .init(
            courseType: .testTrack,
            surface: .dry,
            input: .controller,
            runCount: 3,
            verdict: .keep,
            feedback: [],
            exactSetupConfirmed: true,
            allExportedSettingsApplied: true,
            firstPartyAuthorshipConfirmed: true,
            deidentifiedReusePermitted: true
        )
    }

    private enum Route {
        case tuneMenu
        case tire
        case upgrade
        case research
    }
}
