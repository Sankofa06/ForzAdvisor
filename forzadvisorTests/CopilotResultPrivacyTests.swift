import XCTest
@testable import forzadvisor

extension CopilotTests {
    func testResultAndPartialContextNeverSerializeOrRepeatRawTuneValues() throws {
        let selection = try catalogSelection()
        let tune = projectedTune(car: selection.carInput, rawSentinel: "31.375-secret")
        let result = CopilotContextFactory().make(
            step: .result(tune, savedTuneID: nil, adjustmentChanges: [], thumbnailData: nil, playerNotes: ""),
            savedTuneCount: 0,
            catalogCarCount: 0
        )
        let partial = CopilotContextFactory().make(
            step: .loading(
                tune.request,
                thumbnailData: Data("secret-image".utf8),
                savedTuneID: nil,
                playerNotes: "secret-note",
                partialTune: tune
            ),
            savedTuneCount: 0,
            catalogCarCount: 0
        )

        for context in [result, partial] {
            let encoded = try XCTUnwrap(String(data: JSONEncoder().encode(context), encoding: .utf8))
            XCTAssertFalse(encoded.contains("31.375-secret"))
            XCTAssertFalse(encoded.contains("secret-image"))
            XCTAssertFalse(encoded.contains("secret-note"))
            for intent in CopilotIntent.allCases {
                XCTAssertFalse(
                    CopilotEngine().response(to: intent, in: context).message.contains("31.375-secret")
                )
            }
        }
        XCTAssertEqual(partial.projection?.readyCount, tune.projectionReport?.readyCount)
        XCTAssertTrue(partial.projection?.isStreaming == true)
        XCTAssertNil(partial.projection?.tuneMenuLabEligible)
        XCTAssertNil(partial.projection?.tireLabEligible)
        XCTAssertNil(partial.projection?.upgradeLabEligible)
        XCTAssertNil(partial.projection?.exactUpgradePathCount)
        XCTAssertNil(partial.projection?.isSaved)
        XCTAssertFalse(partial.facts.contains { $0.label == "Tire Lab" })
        XCTAssertFalse(partial.facts.contains { $0.label == "FH6 Tune Menu Lab" })
        XCTAssertFalse(partial.facts.contains { $0.label == "Upgrade Lab" })
        XCTAssertFalse(partial.facts.contains { $0.label == "Exact upgrade paths" })
    }

    func testResultEligibilityAndPathCountsMatchExistingServices() throws {
        let tireTune = try tireEligibleTune()
        let context = CopilotContextFactory().make(
            step: .result(tireTune, savedTuneID: nil, adjustmentChanges: [], thumbnailData: nil, playerNotes: ""),
            savedTuneCount: 0,
            catalogCarCount: 0
        )

        XCTAssertEqual(
            context.projection?.tuneMenuLabEligible,
            FH6TuneMenuCaptureEligibility().snapshot(for: tireTune) != nil
        )
        XCTAssertEqual(
            context.projection?.tireLabEligible,
            TirePressureCaptureEligibility().snapshot(for: tireTune) != nil
        )
        XCTAssertEqual(
            context.projection?.upgradeLabEligible,
            UpgradePartCaptureEligibility().snapshot(for: tireTune) != nil
        )
        XCTAssertEqual(
            context.projection?.exactUpgradePathCount,
            TuneControlUpgradePlanner().paths(for: tireTune).count
        )
        XCTAssertTrue(CopilotEngine().response(to: .nextStep, in: context).message.contains("Tune Menu Lab"))
    }

    func testResultWithoutProjectionMakesNoReadyClaim() throws {
        let selection = try catalogSelection()
        var tune = projectedTune(car: selection.carInput)
        tune.projectionReport = nil
        let context = CopilotContextFactory().make(
            step: .result(tune, savedTuneID: nil, adjustmentChanges: [], thumbnailData: nil, playerNotes: ""),
            savedTuneCount: 0,
            catalogCarCount: 0
        )

        XCTAssertNil(context.projection)
        XCTAssertTrue(CopilotEngine().response(to: .trust, in: context).message.contains("no verified projection report"))
        XCTAssertTrue(CopilotEngine().response(to: .missing, in: context).message.contains("projection report is missing"))
    }

    func testUnsupportedQuestionReturnsStableNoActionResponse() {
        let context = syntheticContext(for: .result)
        let response = CopilotEngine().response(to: "set my tires to 28.5", in: context)

        XCTAssertEqual(response, .unsupported)
        XCTAssertNil(response.intent)
        XCTAssertNil(response.action)
    }

    func testResultPriorityCoversStreamingWithheldUnsavedAndSavedStates() {
        let engine = CopilotEngine()
        var facts = projectionFacts(readyCount: 2, isSaved: false, isStreaming: true)
        var response = engine.response(
            to: .nextStep,
            in: resultContext(facts)
        )
        XCTAssertTrue(response.message.contains("Wait"))
        XCTAssertNil(response.action)

        facts = projectionFacts(readyCount: 0, isSaved: false, isStreaming: false)
        response = engine.response(to: .nextStep, in: resultContext(facts))
        XCTAssertTrue(response.message.contains("withheld"))
        XCTAssertNil(response.action)

        facts = projectionFacts(readyCount: 2, isSaved: false, isStreaming: false)
        response = engine.response(to: .nextStep, in: resultContext(facts))
        XCTAssertTrue(response.message.contains("Save"))
        XCTAssertNil(response.action)

        facts = projectionFacts(readyCount: 2, isSaved: true, isStreaming: false)
        response = engine.response(to: .nextStep, in: resultContext(facts))
        XCTAssertTrue(response.message.contains("guided feedback"))
        XCTAssertNil(response.action)
    }

}
