import XCTest
@testable import forzadvisor

final class TuneResultPresentationTests: XCTestCase {
    func testStreamingResultIsExplicitlyIncompleteAndCannotCopyOrSave() {
        let presentation = TuneResultPresentation(
            tune: makeTune(hasProjection: true),
            isSaved: false,
            isStreaming: true
        )

        XCTAssertEqual(presentation.completion, .incomplete)
        XCTAssertFalse(presentation.allowsCopyOrSave)
        XCTAssertEqual(presentation.statusTitle, "Incomplete result")
        XCTAssertTrue(presentation.statusDetail.contains("Copy and Save remain unavailable"))
    }

    func testCompletedProjectedResultAllowsActionsWithoutAccuracyClaim() {
        let presentation = TuneResultPresentation(
            tune: makeTune(hasProjection: true),
            isSaved: false,
            isStreaming: false
        )

        XCTAssertEqual(presentation.completion, .available)
        XCTAssertTrue(presentation.allowsCopyOrSave)
        XCTAssertTrue(presentation.statusDetail.contains("does not mean accuracy"))
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
