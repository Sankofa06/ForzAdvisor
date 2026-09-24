import XCTest

final class ScreenshotEvidenceUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSupportedManualFlowScreenshotEvidence() {
        let app = launchApp()

        assertEmptyGarage(in: app)
        capture("01-empty-garage-light", in: app)

        openNewTune(in: app)
        capture("02-new-tune-source-light", in: app)

        openValidationReadyManualEntry(in: app)
        capture("03-manual-entry-validation-ready-light", in: app)

        openDisciplinePreflight(in: app)
        capture("04-discipline-provider-preflight-light", in: app)

        openResult(in: app)
        capture("05-result-top-light", in: app)

        let availableSettings = app.descendants(matching: .any)[
            "availableSettingsSection"
        ].firstMatch
        scrollToHittable(availableSettings, in: app)
        let availableSettingsRenderDelay = expectation(
            description: "Available settings finishes rendering"
        )
        availableSettingsRenderDelay.isInverted = true
        XCTAssertEqual(
            XCTWaiter().wait(for: [availableSettingsRenderDelay], timeout: 0.5),
            .completed
        )
        XCTAssertTrue(
            app.staticTexts[
                "No numeric values are being presented yet. This plan keeps the next in-game step explicit."
            ].exists
        )
        capture("06-result-available-settings-light", in: app)

        let evidenceSummary = app.staticTexts.matching(
            NSPredicate(
                format: "label == %@",
                "Optional Validation & Research"
            )
        ).firstMatch
        scrollToHittable(evidenceSummary, in: app)
        let evidenceExplanation = app.staticTexts.matching(
            NSPredicate(
                format: "label == %@",
                "Use Evidence Hub later if you want to record on-device observations, choose future reuse, or review shared evidence. It never changes available settings automatically."
            )
        ).firstMatch
        scrollToHittable(evidenceExplanation, in: app)
        capture("07-result-evidence-summary-light", in: app)

        saveResult(in: app)
        let openEvidenceHub = app.buttons["openTuneEvidenceHubButton"]
        scrollToHittable(openEvidenceHub, in: app)
        openEvidenceHub.tap()

        let evidenceHub = app.descendants(matching: .any)["tuneEvidenceHub"]
            .firstMatch
        XCTAssertTrue(evidenceHub.waitForExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["Evidence Hub"].exists)
        capture("08-evidence-hub-light", in: app)
    }

    @MainActor
    func testSettingsAndStepGuideScreenshotEvidence() {
        let app = launchApp()
        assertEmptyGarage(in: app)

        let settings = app.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.descendants(matching: .any)["providerPreference-offlineFormula"]
                .firstMatch.waitForExistence(timeout: 5)
        )
        capture("09-settings-provider-card-light", in: app)

        app.navigationBars["Settings"].buttons["Done"].tap()
        let stepGuide = app.buttons["garageStepGuideButton"]
        XCTAssertTrue(stepGuide.waitForExistence(timeout: 5))
        stepGuide.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["copilotSheet"]
                .firstMatch.waitForExistence(timeout: 5)
        )
        XCTAssertTrue(app.staticTexts[
            "Local deterministic guidance. No model, network, or transcript."
        ].exists)
        for label in [
            "Next step",
            "What can I trust?",
            "What is missing?",
            "Privacy"
        ] {
            XCTAssertTrue(app.buttons[label].exists)
        }
        capture("10-step-guide-choices-light", in: app)
    }

    @MainActor
    func testDarkModeGarageNewTuneAndResultScreenshotEvidence() {
        let app = launchApp(arguments: ["-AppleInterfaceStyle", "Dark"])

        assertEmptyGarage(in: app)
        capture("11-empty-garage-dark", in: app)
        openNewTune(in: app)
        capture("12-new-tune-source-dark", in: app)
        openValidationReadyManualEntry(in: app)
        openDisciplinePreflight(in: app)
        openResult(in: app)
        capture("13-result-top-dark", in: app)
    }

    @MainActor
    func testAccessibilityXXXLGarageNewTuneAndResultScreenshotEvidence() {
        let app = launchApp(arguments: [
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
        ])

        assertEmptyGarage(in: app)
        capture("14-empty-garage-accessibility-xxxl", in: app)
        openNewTune(in: app)
        capture("15-new-tune-source-accessibility-xxxl", in: app)
        openValidationReadyManualEntry(in: app)
        openDisciplinePreflight(in: app)
        openResult(in: app)
        capture("16-result-top-accessibility-xxxl", in: app)
    }

}
