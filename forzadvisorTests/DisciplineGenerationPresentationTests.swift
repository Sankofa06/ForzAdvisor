import XCTest
@testable import forzadvisor

final class DisciplineGenerationPresentationTests: XCTestCase {
    private let capabilities = TuneProviderCapabilities(
        onDeviceModel: .ready,
        anthropicAPI: .storedOnDeviceNotTested
    )

    func testSelectionDoesNotCreateAStartIntentUntilTapped() {
        var state = DisciplineSelectionState()

        XCTAssertNil(state.selection)
        XCTAssertNil(state.startIntent)

        state.select(.road)

        XCTAssertEqual(state.selection, .road)
        XCTAssertEqual(state.startIntent, .road)
    }

    func testGameCorrectStartVocabulary() {
        XCTAssertEqual(
            DisciplineGenerationCopy.startButtonTitle(for: .fh5),
            "Create FH5 Build Plan"
        )
        XCTAssertEqual(
            DisciplineGenerationCopy.startButtonTitle(for: .fh6),
            "Generate FH6 Tune"
        )
    }

    func testRemoteRouteNamesFirstAttemptFallbackAndBoundary() {
        let disclosure = TuneProviderDisclosure(
            preferredMode: .anthropicAPI,
            capabilities: capabilities
        )

        XCTAssertEqual(
            DisciplineGenerationCopy.routeSummary(disclosure),
            "Tries Anthropic API first, then Offline formulas if needed."
        )
        XCTAssertTrue(
            DisciplineGenerationCopy.dataBoundary(
                for: .fh6,
                disclosure: disclosure
            ).contains("confirmed car facts and discipline")
        )
    }

    func testFH5BoundaryRemainsLocalEvenWithRemotePreference() {
        let disclosure = TuneProviderDisclosure(
            preferredMode: .anthropicAPI,
            capabilities: capabilities
        )

        XCTAssertEqual(
            DisciplineGenerationCopy.dataBoundary(
                for: .fh5,
                disclosure: disclosure
            ),
            "This FH5 build plan stays on this device. Screenshots and API keys are never included."
        )
    }

    func testTruthfulPhasesContainNoPercentOrETA() {
        let phases: [TuneGenerationPresentationPhase] = [
            .working, .partial, .failed, .canceled, .completed
        ]

        XCTAssertEqual(Set(phases.map(\.title)).count, phases.count)
        for phase in phases {
            XCTAssertFalse(phase.title.contains("%"))
            XCTAssertFalse(phase.detail.contains("%"))
            XCTAssertFalse(phase.title.localizedCaseInsensitiveContains("ETA"))
            XCTAssertFalse(phase.detail.localizedCaseInsensitiveContains("ETA"))
        }
    }

    func testCancelRemainsVisibleThroughFinalTransition() {
        XCTAssertTrue(TuneGenerationPresentationPhase.working.showsCancel)
        XCTAssertTrue(TuneGenerationPresentationPhase.partial.showsCancel)
        XCTAssertTrue(TuneGenerationPresentationPhase.completed.showsCancel)
        XCTAssertFalse(TuneGenerationPresentationPhase.failed.showsCancel)
        XCTAssertTrue(TuneGenerationPresentationPhase.failed.showsRecovery)
    }

    func testFailureUsesExactSafeRecoveryVocabulary() {
        XCTAssertEqual(DisciplineGenerationCopy.retryTitle, "Retry")
        XCTAssertEqual(
            DisciplineGenerationCopy.changeDisciplineTitle,
            "Change Discipline"
        )
        XCTAssertEqual(DisciplineGenerationCopy.backTitle, "Back")
        XCTAssertEqual(
            TuneGenerationPresentationPhase.failed.detail,
            "Your car facts and discipline are still here. Retry or change them before starting again."
        )
    }
}
