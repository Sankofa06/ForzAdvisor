import XCTest
@testable import forzadvisor

final class TuneResultPresentationTests: XCTestCase {
    func testEligibleResultCaptureCallbacksProduceVisibleActionsAndDispatch() {
        var dispatched = [TuneResultCaptureActionKind]()
        let actions = TuneResultCaptureActions(
            onVerifyTuneMenu: { dispatched.append(.tuneMenu) },
            onVerifyTirePressures: { dispatched.append(.tirePressures) },
            onVerifyUpgradeParts: { dispatched.append(.upgradeParts) }
        )

        XCTAssertEqual(
            actions.availableActions.map(\.kind),
            [.tuneMenu, .tirePressures, .upgradeParts]
        )
        XCTAssertEqual(
            actions.availableActions.map(\.accessibilityIdentifier),
            [
                "verifyTuneMenuCaptureButton",
                "verifyTirePressureCaptureButton",
                "verifyUpgradePartsCaptureButton"
            ]
        )
        actions.availableActions.forEach { $0.perform() }
        XCTAssertEqual(
            dispatched,
            [.tuneMenu, .tirePressures, .upgradeParts]
        )
    }

    func testIneligibleAndStreamingCaptureActionsAreNotAvailable() {
        let ineligibleActions = TuneResultCaptureActions()
        XCTAssertTrue(ineligibleActions.availableActions.isEmpty)

        var dispatchedTireAction = false
        let partiallyEligibleActions = TuneResultCaptureActions(
            onVerifyTirePressures: { dispatchedTireAction = true }
        )
        XCTAssertEqual(
            partiallyEligibleActions.availableActions.map(\.kind),
            [.tirePressures]
        )
        partiallyEligibleActions.availableActions[0].perform()
        XCTAssertTrue(dispatchedTireAction)

        let streamingActions = TuneResultCaptureActions(
            onVerifyTuneMenu: {},
            onVerifyTirePressures: {},
            onVerifyUpgradeParts: {},
            isStreaming: true
        )
        XCTAssertTrue(streamingActions.availableActions.isEmpty)
    }

    func testStreamingResultIsExplicitlyIncompleteAndCannotCopyOrSave() {
        let presentation = TuneResultPresentation(
            tune: makeTune(hasProjection: true),
            isSaved: false,
            isStreaming: true
        )

        XCTAssertEqual(presentation.completion, .incomplete)
        XCTAssertFalse(presentation.allowsCopyOrSave)
        XCTAssertFalse(presentation.allowsSavedConsequentialActions)
        XCTAssertEqual(presentation.statusTitle, "Incomplete result")
        XCTAssertTrue(presentation.statusDetail.contains("Copy and Save remain unavailable"))
    }

    func testStreamingSavedRetuneHidesConsequentialActionsAndProviderClaim() {
        let tune = makeTune(hasProjection: true)
        let presentation = TuneResultPresentation(
            tune: tune,
            isSaved: true,
            isStreaming: true
        )
        let provider = TuneActualProviderPresentation(
            tune: tune,
            isComplete: false
        )

        XCTAssertFalse(presentation.allowsCopyOrSave)
        XCTAssertFalse(presentation.allowsSavedConsequentialActions)
        XCTAssertEqual(
            provider.title,
            "Generation method still in progress"
        )
        XCTAssertTrue(provider.detail.contains("only when generation completes"))
    }

    func testCompletedResultWithNoReadySettingsBecomesEvidenceState() {
        let presentation = TuneResultPresentation(
            tune: makeTune(hasProjection: true),
            isSaved: false,
            isStreaming: false
        )

        XCTAssertEqual(presentation.completion, .needsEvidence)
        XCTAssertFalse(presentation.allowsCopyOrSave)
        XCTAssertTrue(presentation.allowsSave)
        XCTAssertTrue(presentation.statusDetail.contains("No numeric settings passed"))
    }

    func testSavedEvidenceStateAllowsMetadataEditButNotConsequentialActions() {
        let presentation = TuneResultPresentation(
            tune: makeTune(hasProjection: true),
            isSaved: true,
            isStreaming: false
        )

        XCTAssertTrue(presentation.allowsSavedMetadataEdit)
        XCTAssertFalse(presentation.allowsSavedConsequentialActions)
    }

    func testReadyMetadataWithoutUsableNumericOutputStaysEvidenceGated() {
        var tune = makeTune(hasProjection: true)
        tune.projectionReport?.fields = [
            TuneFieldProjection(
                field: .frontTirePressure,
                status: .ready,
                requiredPurchaseIDs: [],
                unresolvedPartIDs: [],
                reason: nil
            )
        ]
        tune.sections = [TuneSection(
            title: "Tires",
            symbolName: "circle.dashed",
            lines: [
                TuneLine(
                    label: "Front pressure",
                    value: "30.0",
                    unit: "PSI",
                    fieldID: .frontTirePressure
                )
            ]
        )]
        let presentation = TuneResultPresentation(
            tune: tune,
            isSaved: false,
            isStreaming: false
        )

        XCTAssertEqual(presentation.completion, .needsEvidence)
        XCTAssertEqual(presentation.availableSettingCount, 0)
        XCTAssertFalse(presentation.allowsCopyOrSave)
        XCTAssertNotEqual(presentation.statusTitle, "Ready to use")
    }

    func testUsableProjectedNumbersAllowNormalTuneActions() async throws {
        let tune = try await SyntheticLegacyTuneFixtureFactory.eligibleValidationTune(
            capturedAt: Date(timeIntervalSinceReferenceDate: 72)
        )
        let presentation = TuneResultPresentation(
            tune: tune,
            isSaved: true,
            isStreaming: false
        )

        XCTAssertEqual(presentation.completion, .available)
        XCTAssertGreaterThan(presentation.availableSettingCount, 0)
        XCTAssertTrue(presentation.allowsCopyOrSave)
        XCTAssertTrue(presentation.allowsSavedConsequentialActions)
        XCTAssertTrue(presentation.statusDetail.contains("does not mean accuracy"))
    }

    func testUsableNumbersWithPendingInGameConfirmationStayPlanOnly() async throws {
        var tune = try await SyntheticLegacyTuneFixtureFactory.eligibleValidationTune(
            capturedAt: Date(timeIntervalSinceReferenceDate: 73)
        )
        tune.projectionReport?.confirmations = [
            TuneSettingConfirmation(setting: .alignment, candidateParts: [])
        ]

        let presentation = TuneResultPresentation(
            tune: tune,
            isSaved: true,
            isStreaming: false
        )

        XCTAssertEqual(presentation.completion, .plan)
        XCTAssertEqual(presentation.availableSettingCount, 0)
        XCTAssertFalse(presentation.allowsCopyOrSave)
        XCTAssertFalse(presentation.allowsSavedConsequentialActions)
    }

    func testFH5NumericPurposeIsPresentedAsPlanOnly() {
        var car = SampleTuningData.starterCar
        car.game = .fh5
        let tune = TuneResult(
            request: TuneRequest(car: car, discipline: .road),
            sections: [],
            notes: TuneNotes(
                bias: "No numeric FH5 guidance",
                ifPushesWide: "Not available",
                ifSnapsOnLift: "Not available",
                retuneTrigger: "Use the build plan"
            ),
            purpose: .numericTune,
            projectionReport: emptyProjection
        )
        let presentation = TuneResultPresentation(
            tune: tune,
            isSaved: false,
            isStreaming: false
        )

        XCTAssertEqual(presentation.completion, .plan)
        XCTAssertFalse(presentation.allowsCopyOrSave)
        XCTAssertTrue(presentation.allowsSave)
        XCTAssertFalse(presentation.allowsSavedConsequentialActions)
        XCTAssertTrue(TuneActualProviderPresentation(tune: tune).title.contains("FH5 build planner"))
    }

    func testLegacyResultRemainsNonCopyable() {
        let presentation = TuneResultPresentation(
            tune: makeTune(hasProjection: false),
            isSaved: true,
            isStreaming: false
        )

        XCTAssertEqual(presentation.completion, .legacyUnavailable)
        XCTAssertFalse(presentation.allowsCopyOrSave)
    }

    func testProviderVocabularyNamesActualAndFallbackRoutes() {
        var direct = makeTune(hasProjection: true)
        direct.providerInfo = .direct(.anthropicAPI)
        XCTAssertEqual(
            TuneActualProviderPresentation(tune: direct).title,
            "Generated with: Anthropic API"
        )

        var fallback = direct
        fallback.providerInfo = .fallback(
            requestedMode: .anthropicAPI,
            reason: .providerError
        )
        XCTAssertEqual(
            TuneActualProviderPresentation(tune: fallback).title,
            "Fallback used: Offline formulas"
        )
    }

    func testIdentityAndNotesUseSaveChanges() {
        let original = makeDraft()
        var identity = original
        identity.car.model = "Supra RZ"
        XCTAssertEqual(
            SavedTuneEditAction.resolve(original: original, current: identity),
            .saveChanges
        )

        var notes = original
        notes.playerNotes = "Try softer rear damping"
        XCTAssertEqual(
            SavedTuneEditAction.resolve(original: original, current: notes),
            .saveChanges
        )
    }

    func testEveryGenerationInputUsesRetuneAndSave() {
        let original = makeDraft()
        var variants = [SavedTuneEditDraft]()

        var weight = original
        weight.car.weightPounds += 1
        variants.append(weight)
        var front = original
        front.car.frontWeightPercent += 0.5
        variants.append(front)
        var pi = original
        pi.car.performanceIndex -= 1
        variants.append(pi)
        var performanceClass = original
        performanceClass.car.performanceClass = .s2
        variants.append(performanceClass)
        var drivetrain = original
        drivetrain.car.drivetrain = .awd
        variants.append(drivetrain)

        for variant in variants {
            XCTAssertEqual(
                SavedTuneEditAction.resolve(
                    original: original,
                    current: variant
                ),
                .retuneAndSave
            )
        }
    }

    private func makeDraft() -> SavedTuneEditDraft {
        SavedTuneEditDraft(tune: makeTune(hasProjection: true), playerNotes: "")
    }

    private func makeTune(hasProjection: Bool) -> TuneResult {
        TuneResult(
            request: TuneRequest(car: SampleTuningData.starterCar, discipline: .road),
            sections: [],
            notes: TuneNotes(
                bias: "Neutral",
                ifPushesWide: "Reduce front roll stiffness",
                ifSnapsOnLift: "Add stability",
                retuneTrigger: "After material changes"
            ),
            projectionReport: hasProjection ? emptyProjection : nil
        )
    }

    private var emptyProjection: TuneProjectionReport {
        TuneProjectionReport(
            schemaVersion: TuneProjectionReport.currentSchemaVersion,
            snapshotID: nil,
            contextStatus: .missingSnapshot,
            capabilityResolution: nil,
            fields: [],
            purchasePlan: [],
            confirmations: [],
            diagnostics: []
        )
    }
}
