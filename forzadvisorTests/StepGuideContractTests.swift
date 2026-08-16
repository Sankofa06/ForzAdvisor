import XCTest
@testable import forzadvisor

final class StepGuideContractTests: XCTestCase {
    func testContractExposesExactlyFourDeterministicIntents() {
        XCTAssertEqual(StepGuideContract.title, "Step Guide")
        XCTAssertEqual(StepGuideContract.intents.count, 4)
        XCTAssertEqual(
            StepGuideContract.intents,
            [.nextStep, .trust, .missing, .privacy]
        )
        XCTAssertEqual(
            Set(StepGuideContract.intents.map(\.rawValue)).count,
            4
        )
        XCTAssertEqual(StepGuideIntent.allCases.count, 4)
    }

    func testStepGuideEngineUsesStepGuideUserFacingVocabulary() {
        let context = StepGuideContext(
            phase: .home,
            carDisplayName: nil,
            gameTitle: nil,
            disciplineTitle: nil,
            savedTuneCount: 0,
            catalogCarCount: nil,
            projection: nil,
            cannotSeeUnsavedEdits: false
        )

        for intent in StepGuideContract.intents {
            let response = StepGuideEngine().response(
                to: intent,
                in: context
            )
            XCTAssertEqual(response.intent, intent)
            XCTAssertFalse(response.message.contains("Copilot"))
        }
    }

    func testRejectedActionKeepsGuideOpenWithTypedReason() {
        let rejection = StepGuideActionRejection(
            reason: .staleContext,
            message: "That action is no longer available."
        )
        let result = StepGuideActionResult.rejected(rejection)

        XCTAssertFalse(result.shouldDismiss)
        XCTAssertEqual(result.rejection, rejection)
        XCTAssertTrue(StepGuideActionResult.accepted.shouldDismiss)
        XCTAssertNil(StepGuideActionResult.accepted.rejection)
    }

    func testCompatibilityAliasesPreserveActionRawValues() {
        let internalAction = CopilotAction.openRecordTestDrive
        let guideAction: StepGuideAction = internalAction

        XCTAssertEqual(
            guideAction.rawValue,
            "openRecordTestDrive"
        )
    }
}
