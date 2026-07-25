//
//  CopilotWorkflowActionRouterTests.swift
//  forzadvisorTests
//

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
            let destination = try XCTUnwrap(
                router.destination(for: action, from: current)
            )

            assertDestination(
                destination,
                route: route,
                expectedTune: tune
            )
        }
    }

    func testTuneMenuPrioritySuppressesTireAndUpgradeActions() throws {
        let tune = try eligibleTune(for: .tuneMenu)
        let current = resultStep(tune)

        XCTAssertNotNil(
            router.destination(
                for: .openFH6TuneMenuLab,
                from: current
            )
        )
        XCTAssertNil(
            router.destination(for: .openTireLab, from: current)
        )
        XCTAssertNil(
            router.destination(for: .openUpgradeLab, from: current)
        )
    }

    func testRouterRejectsStaleWrongNonResultAndIneligibleActions() throws {
        let tune = try eligibleTune(for: .tuneMenu)

        XCTAssertNil(
            router.destination(for: .openFH6TuneMenuLab, from: .home)
        )
        XCTAssertNil(
            router.destination(
                for: .openTireLab,
                from: resultStep(tune)
            )
        )

        var noProjection = tune
        noProjection.projectionReport = nil
        XCTAssertNil(
            router.destination(
                for: .openFH6TuneMenuLab,
                from: resultStep(noProjection)
            )
        )

        var noReadyValues = tune
        noReadyValues.projectionReport?.fields.removeAll {
            $0.status == .ready
        }
        XCTAssertNil(
            router.destination(
                for: .openFH6TuneMenuLab,
                from: resultStep(noReadyValues)
            )
        )

        var edited = tune
        edited.request.car.weightPounds += 1
        XCTAssertNil(
            router.destination(
                for: .openFH6TuneMenuLab,
                from: resultStep(edited)
            )
        )
    }

    func testRouterKeepsFH5UpgradeAdviceNonActionable() throws {
        let tune = try eligibleTune(for: .upgrade, game: .fh5)
        XCTAssertNotNil(
            UpgradePartCaptureEligibility().snapshot(for: tune),
            "The existing FH5 message can still recommend Upgrade Lab."
        )

        XCTAssertNil(
            router.destination(
                for: .openUpgradeLab,
                from: resultStep(tune)
            )
        )
    }

    func testCommunityActionRequiresLiveExactSavedTuneAndZeroTrials()
        async throws {
        let tune = try await eligibleCommunityTune()
        var oldTune = tune
        oldTune.id = UUID()
        let oldStep = resultStep(oldTune)
        let freshThumbnail = Data("fresh-thumbnail".utf8)
        let freshNotes = "Fresh persisted notes"
        let freshResult = CopilotPersistedResultPayload(
            tune: tune,
            thumbnailData: freshThumbnail,
            playerNotes: freshNotes
        )
        let destination = try XCTUnwrap(
            router.destination(
                for: .openFH6CommunityReferenceTrial,
                from: oldStep,
                persistedResult: freshResult,
                matchingCommunityTrialCount: 0
            )
        )
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
        XCTAssertNotEqual(routedTune.id, oldTune.id)
        XCTAssertNotEqual(routedThumbnail, thumbnailData)
        XCTAssertNotEqual(routedNotes, playerNotes)

        XCTAssertNil(router.destination(
            for: .openFH6CommunityReferenceTrial,
            from: oldStep,
            persistedResult: freshResult,
            matchingCommunityTrialCount: 1
        ))
        XCTAssertNil(router.destination(
            for: .openFH6CommunityReferenceTrial,
            from: oldStep,
            persistedResult: nil,
            matchingCommunityTrialCount: 0
        ))
        let higherPriorityTune = try eligibleTune(for: .tuneMenu)
        XCTAssertNil(router.destination(
            for: .openFH6CommunityReferenceTrial,
            from: oldStep,
            persistedResult: CopilotPersistedResultPayload(
                tune: higherPriorityTune,
                thumbnailData: freshThumbnail,
                playerNotes: freshNotes
            ),
            matchingCommunityTrialCount: 0
        ))
    }

    private func eligibleTune(
        for route: Route,
        game: ForzaGame = .fh6
    ) throws -> TuneResult {
        let catalog = try BundledCarCatalog.load().get()
        let entry = try XCTUnwrap(
            catalog.entries.first { $0.game == game }
        )
        let selection = catalog.selection(for: entry)
        let snapshot = selection.capabilityOnlyBuildSnapshot(
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
        case .upgrade:
            fields = [
                readyField(.frontCamber),
                partConfirmationField(.finalDrive),
                readyField(.caster),
                readyField(.caster)
            ]
            confirmations = [finalDriveConfirmation]
        }

        return TuneResult(
            id: UUID(),
            request: TuneRequest(
                car: selection.carInput,
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
    }

    private func eligibleCommunityTune() async throws -> TuneResult {
        let catalog = try BundledCarCatalog.load().get()
        let entry = try XCTUnwrap(
            catalog.entries.first { $0.game == .fh6 }
        )
        let selection = catalog.selection(for: entry)
        let capturedAt = Date(timeIntervalSinceReferenceDate: 909)
        let capability = selection.capabilityOnlyBuildSnapshot(
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
        return try await CapabilityProjectingTuneProvider(
            base: LocalSampleTuneProvider()
        ).generateTune(for: TuneRequest(
            car: exact.car,
            discipline: .road,
            buildSnapshot: exact
        ))
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

    private func assertDestination(
        _ destination: WorkflowStep,
        route: Route,
        expectedTune: TuneResult,
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
            thumbnailData,
            file: file,
            line: line
        )
        XCTAssertEqual(
            payload.playerNotes,
            playerNotes,
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

    private enum Route {
        case tuneMenu
        case tire
        case upgrade
    }
}
