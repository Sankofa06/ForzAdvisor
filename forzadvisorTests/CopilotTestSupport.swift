import XCTest
@testable import forzadvisor

extension CopilotTests {
    func syntheticContext(for phase: CopilotPhase) -> CopilotContext {
        CopilotContext(
            phase: phase,
            carDisplayName: phase == .result ? "Test Car" : nil,
            gameTitle: phase == .result ? "FH6" : nil,
            disciplineTitle: phase == .result ? "Road" : nil,
            savedTuneCount: phase == .home ? 3 : nil,
            catalogCarCount: phase == .catalogPicker ? 6 : nil,
            projection: phase == .result ? projectionFacts(readyCount: 2, isSaved: true) : nil,
            cannotSeeUnsavedEdits: [
                .catalogEdit, .ocrReview, .manualEntry,
                .rosterIdentityStockEntry, .fh6TuneMenuCapture,
                .tirePressureCapture,
                .upgradePartCapture, .fh5ResearchCapture,
                .fh5ControlledExperimentCapture, .recordTestDrive,
                .editSavedTune, .settings, .fh6ValidationReview,
                .fh6CommunityOutcomeReview, .fh5ResearchReview,
                .fh5CandidateOutcomeReview
            ].contains(phase)
        )
    }

    func rosterIdentity(
        game: ForzaGame,
        sentinel: String
    ) -> OfficialRosterCarIdentity {
        OfficialRosterCarIdentity(
            id: "\(sentinel)-id",
            game: game,
            year: game == .fh5 ? 1986 : 2554,
            make: game == .fh5 ? "" : "\(sentinel)-make",
            model: "\(sentinel)-model",
            officialDesignation:
                "\(sentinel)-official-designation",
            performanceIndex: game == .fh5 ? nil : 987,
            performanceClass: game == .fh5 ? nil : .s2
        )
    }

    func resultContext(_ projection: CopilotProjectionFacts) -> CopilotContext {
        CopilotContext(
            phase: .result,
            carDisplayName: "Test Car",
            gameTitle: "FH6",
            disciplineTitle: "Road",
            savedTuneCount: nil,
            catalogCarCount: nil,
            projection: projection,
            cannotSeeUnsavedEdits: false
        )
    }

    func projectionFacts(
        readyCount: Int,
        isSaved: Bool,
        isStreaming: Bool = false
    ) -> CopilotProjectionFacts {
        CopilotProjectionFacts(
            readyCount: readyCount,
            blockedByStatus: [],
            blockedByReason: [],
            tireLabEligible: false,
            upgradeLabEligible: false,
            exactUpgradePathCount: 0,
            isSaved: isSaved,
            isStreaming: isStreaming
        )
    }

    func projectedTune(car: CarInput, rawSentinel: String = "31.375-secret") -> TuneResult {
        TuneResult(
            request: TuneRequest(car: car, discipline: .road),
            sections: [TuneSection(
                title: "Raw settings",
                symbolName: "slider.horizontal.3",
                lines: [TuneLine(label: "Front", value: rawSentinel, unit: "PSI")]
            )],
            notes: emptyNotes,
            projectionReport: TuneProjectionReport(
                schemaVersion: TuneProjectionReport.currentSchemaVersion,
                snapshotID: nil,
                contextStatus: .missingSnapshot,
                capabilityResolution: nil,
                fields: [TuneFieldProjection(
                    field: .frontTirePressure,
                    status: .needsConstraint,
                    requiredPurchaseIDs: [],
                    unresolvedPartIDs: [],
                    reason: .missingProductionConstraint
                )],
                purchasePlan: [],
                confirmations: [],
                diagnostics: []
            )
        )
    }

    func tireEligibleTune() throws -> TuneResult {
        let selection = try catalogSelection(game: .fh6)
        let snapshot = selection.capabilityOnlyBuildSnapshot(
            capturedAt: Date(timeIntervalSinceReferenceDate: 42)
        )
        return TuneResult(
            request: TuneRequest(
                car: selection.carInput,
                discipline: .road,
                buildSnapshot: snapshot
            ),
            sections: [],
            notes: emptyNotes,
            projectionReport: TuneProjectionReport(
                schemaVersion: TuneProjectionReport.currentSchemaVersion,
                snapshotID: snapshot.id,
                contextStatus: .capabilityOnly,
                capabilityResolution: nil,
                fields: [
                    TuneFieldProjection(
                        field: .frontTirePressure,
                        status: .needsConstraint,
                        requiredPurchaseIDs: [],
                        unresolvedPartIDs: [],
                        reason: .missingProductionConstraint
                    ),
                    TuneFieldProjection(
                        field: .rearTirePressure,
                        status: .needsConstraint,
                        requiredPurchaseIDs: [],
                        unresolvedPartIDs: [],
                        reason: .missingProductionConstraint
                    )
                ],
                purchasePlan: [],
                confirmations: [],
                diagnostics: []
            )
        )
    }

    func catalogSelection(game: ForzaGame? = nil) throws -> CatalogCarSelection {
        SyntheticLegacyTuneFixtureFactory.selection(
            game: game ?? .fh6,
            reviewedAt: Date(timeIntervalSinceReferenceDate: 42)
        )
    }

    private var emptyNotes: TuneNotes {
        TuneNotes(bias: "", ifPushesWide: "", ifSnapsOnLift: "", retuneTrigger: "")
    }
}
