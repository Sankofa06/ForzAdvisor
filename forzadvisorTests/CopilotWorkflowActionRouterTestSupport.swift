import SwiftData
import XCTest
@testable import forzadvisor

extension CopilotWorkflowActionRouterTests {
    func eligibleTune(
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

    func eligibleCommunityTune() async throws -> TuneResult {
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

    func resultStep(_ tune: TuneResult) -> WorkflowStep {
        .result(
            tune,
            savedTuneID: savedTuneID,
            adjustmentChanges: [],
            thumbnailData: thumbnailData,
            playerNotes: playerNotes
        )
    }

    func actionSnapshot(
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

    func assertFH5ActionsRejected(
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

}
