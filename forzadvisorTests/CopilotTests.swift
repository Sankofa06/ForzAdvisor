import XCTest
@testable import forzadvisor

final class CopilotTests: XCTestCase {
    func testFirstSavedSetupHandoffRequiresSuccessfulSaveFromEmptyGarage() {
        let savedTuneID = UUID()
        var state = FirstSavedSetupCopilotHandoffState()

        state.recordSaveResult(
            savedTuneID: nil,
            wasGarageEmpty: true
        )
        XCTAssertFalse(state.isPresented(for: savedTuneID))

        state.recordSaveResult(
            savedTuneID: savedTuneID,
            wasGarageEmpty: false
        )
        XCTAssertFalse(state.isPresented(for: savedTuneID))

        state.recordSaveResult(
            savedTuneID: savedTuneID,
            wasGarageEmpty: true
        )
        XCTAssertTrue(state.isPresented(for: savedTuneID))
    }

    func testFirstSavedSetupHandoffIsExactResultBoundAndConsumable() {
        let savedTuneID = UUID()
        var state = FirstSavedSetupCopilotHandoffState()
        state.recordSaveResult(
            savedTuneID: savedTuneID,
            wasGarageEmpty: true
        )

        XCTAssertTrue(state.isPresented(for: savedTuneID))
        XCTAssertFalse(state.isPresented(for: UUID()))
        XCTAssertFalse(state.isPresented(for: nil))

        state.consume()
        state.consume()

        XCTAssertFalse(state.isPresented(for: savedTuneID))
        XCTAssertNil(state.savedTuneID)
    }

    func testPreparingCopilotPresentationConsumesPendingHandoff() {
        let savedTuneID = UUID()
        var state = FirstSavedSetupCopilotHandoffState()
        state.recordSaveResult(
            savedTuneID: savedTuneID,
            wasGarageEmpty: true
        )

        state.prepareForCopilotPresentation()

        XCTAssertFalse(state.isPresented(for: savedTuneID))
        XCTAssertNil(state.savedTuneID)
    }

    func testParserAcceptsOnlyClosedPhrasesAndExplicitSynonyms() {
        let accepted: [(String, CopilotIntent)] = [
            (" Next step ", .nextStep),
            ("WHAT SHOULD I DO NEXT", .nextStep),
            ("what do i do next", .nextStep),
            ("What can I trust?", .trust),
            ("what is verified", .trust),
            ("what's verified", .trust),
            ("What is missing?", .missing),
            ("what's missing", .missing),
            ("what still needs verification", .missing),
            ("Privacy", .privacy),
            ("is this private", .privacy),
            ("how is my data used", .privacy)
        ]
        for (question, intent) in accepted {
            XCTAssertEqual(CopilotIntent.parse(question), intent, question)
        }

        let rejected = [
            "",
            "next step and what can I trust",
            "what can I trust and what is missing",
            "blorp glorp",
            "give me 31.5 PSI",
            "set final drive to 3.80",
            "what PI should I use",
            "what will this cost",
            "how much performance will I gain",
            "which parts are available",
            "search the web",
            "compare Reddit tunes",
            "find a YouTube source",
            "give me general tuning advice",
            "what can i trust please"
        ]
        for question in rejected {
            XCTAssertNil(CopilotIntent.parse(question), question)
        }
    }

    func testEveryWorkflowPhaseAnswersEverySupportedIntent() {
        let engine = CopilotEngine()
        XCTAssertEqual(CopilotPhase.allCases.count, 26)

        for phase in CopilotPhase.allCases {
            let context = syntheticContext(for: phase)
            for intent in CopilotIntent.allCases {
                let response = engine.response(to: intent, in: context)
                XCTAssertEqual(response.intent, intent, "\(phase.rawValue) / \(intent.rawValue)")
                XCTAssertFalse(response.title.isEmpty, "\(phase.rawValue) / \(intent.rawValue)")
                XCTAssertFalse(response.message.isEmpty, "\(phase.rawValue) / \(intent.rawValue)")
                if intent != .nextStep || phase != .result {
                    XCTAssertNil(response.action, "\(phase.rawValue) / \(intent.rawValue)")
                }
            }
        }
    }

}
