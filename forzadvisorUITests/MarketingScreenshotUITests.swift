import XCTest

final class MarketingScreenshotUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testMarketingScreenshotsLight() {
        captureJourney(appearance: "light")
    }

    @MainActor
    func testMarketingScreenshotsDark() {
        captureJourney(appearance: "dark")
    }

    @MainActor
    private func captureJourney(appearance: String) {
        let app = marketingLaunch(appearance: appearance)
        assertSeededGarage(in: app)
        marketingCapture("01-garage", appearance: appearance, in: app)

        marketingTap(app.buttons["newTuneButton"].firstMatch, in: app)
        XCTAssertTrue(app.navigationBars["Tune Source"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["takePhotoPrimaryButton"].exists)
        marketingCapture("02-source", appearance: appearance, in: app)

        marketingTap(app.buttons["manualEntryButton"], in: app)
        XCTAssertTrue(app.navigationBars["Manual Entry"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["manualEntryMakeField"].value as? String, "Mazda")
        XCTAssertEqual(app.textFields["manualEntryModelField"].value as? String, "MX-5 Miata")
        marketingReveal(app.textFields["manualEntryWeightField"], in: app)
        marketingCapture("03-manual", appearance: appearance, in: app)

        marketingTap(app.buttons["manualEntryNextButton"], in: app)
        XCTAssertTrue(app.navigationBars["Choose Discipline"].waitForExistence(timeout: 5))
        marketingTap(app.buttons["disciplineButton-road"], in: app)
        marketingReveal(app.buttons["startTuneGenerationButton"], in: app)
        XCTAssertTrue(app.buttons["startTuneGenerationButton"].isEnabled)
        let disclosure = app.staticTexts["Preferred method"].firstMatch
        marketingReveal(disclosure, in: app)
        XCTAssertTrue(marketingIsVisible(disclosure, in: app))
        let readiness = app.staticTexts["Readiness"].firstMatch
        XCTAssertTrue(marketingIsVisible(readiness, in: app))
        let route = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS %@", "Expected route")
        ).firstMatch
        XCTAssertTrue(marketingIsVisible(route, in: app))

        // Verify the generation disclosure, then compose the capture around
        // the player's car and selected discipline at the top of the screen.
        let progress = app.descendants(matching: .any)["tuneWorkflowProgress-3"].firstMatch
        marketingReveal(progress, in: app)
        let road = app.buttons["disciplineButton-road"]
        XCTAssertTrue(marketingIsVisible(progress, in: app))
        XCTAssertTrue(marketingIsVisible(road, in: app))
        XCTAssertEqual(road.value as? String, "Selected")
        marketingCapture("04-discipline", appearance: appearance, in: app)

        // Open the real saved plan through Garage instead of generating a
        // replacement or calling a provider during marketing capture.
        app.terminate()
        let savedApp = marketingLaunch(appearance: appearance)
        assertSeededGarage(in: savedApp)
        marketingTap(savedApp.buttons["savedTuneRow"].firstMatch, in: savedApp)
        XCTAssertTrue(savedApp.navigationBars["Tune"].waitForExistence(timeout: 5))
        XCTAssertTrue(savedApp.descendants(matching: .any)["tuneResultStatus"]
            .firstMatch.waitForExistence(timeout: 5))
        let withheld = savedApp.staticTexts["withheldSettingsTitle"]
        marketingReveal(withheld, in: savedApp)
        XCTAssertEqual(withheld.label, "Settings withheld — more game evidence needed")
        marketingCapture("05-saved-plan", appearance: appearance, in: savedApp)

        savedApp.terminate()
        let guideApp = marketingLaunch(appearance: appearance)
        assertSeededGarage(in: guideApp)
        marketingTap(guideApp.buttons["garageStepGuideButton"], in: guideApp)
        XCTAssertTrue(guideApp.descendants(matching: .any)["copilotSheet"]
            .firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(guideApp.staticTexts[
            "Local deterministic guidance. No model, network, or transcript."
        ].exists)
        XCTAssertTrue(guideApp.buttons["Next step"].exists)
        marketingCapture("06-step-guide", appearance: appearance, in: guideApp)
    }
}
