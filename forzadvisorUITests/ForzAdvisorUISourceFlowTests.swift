import XCTest

extension ForzAdvisorUITests {
    @MainActor
    func testTuneSourceOffersOnlySupportedEntries() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))

        let garageHome = app.descendants(matching: .any)["garageHome"].firstMatch
        XCTAssertTrue(garageHome.waitForExistence(timeout: 15))
        garageHome.descendants(matching: .button)["newTuneButton"].tap()

        XCTAssertTrue(app.buttons["takePhotoPrimaryButton"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["importScreenshotButton"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["manualEntryButton"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["catalogEntryButton"].exists)
    }

    @MainActor
    func testManualGameSelectionSurvivesDisciplineRoundTrip() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))

        let garageHome = app.descendants(matching: .any)["garageHome"].firstMatch
        XCTAssertTrue(garageHome.waitForExistence(timeout: 15))
        garageHome.descendants(matching: .button)["newTuneButton"].tap()
        app.buttons["manualEntryButton"].tap()

        let fh5Button = app.buttons["manualEntryGame-fh5"]
        XCTAssertTrue(fh5Button.waitForExistence(timeout: 5))
        fh5Button.tap()
        XCTAssertEqual(fh5Button.value as? String, "Selected")

        let keyboardDoneButton = app.buttons["manualEntryKeyboardDoneButton"]
        app.textFields["manualEntryYearField"].enterText("1997")
        app.textFields["manualEntryMakeField"].enterText("Mazda")
        app.textFields["manualEntryModelField"].enterText("Miata")
        XCTAssertTrue(keyboardDoneButton.waitForExistence(timeout: 2))
        keyboardDoneButton.tap()
        app.swipeUp()
        app.textFields["manualEntryWeightField"].enterText("2345")
        XCTAssertTrue(keyboardDoneButton.waitForExistence(timeout: 2))
        keyboardDoneButton.tap()
        app.swipeUp()
        app.textFields["manualEntryFrontWeightField"].enterText("55")
        XCTAssertTrue(keyboardDoneButton.waitForExistence(timeout: 2))
        keyboardDoneButton.tap()
        app.swipeUp()
        app.textFields["manualEntryPerformanceIndexField"].enterText("789")
        if keyboardDoneButton.waitForExistence(timeout: 2) {
            keyboardDoneButton.tap()
        }
        app.buttons["manualEntryClass-A"].tap()
        app.buttons["manualEntryDrivetrain-RWD"].tap()

        let nextButton = app.buttons["manualEntryNextButton"]
        XCTAssertTrue(nextButton.waitUntilEnabled(timeout: 3))
        nextButton.tap()

        XCTAssertTrue(app.buttons["disciplineButton-road"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["FH5"].waitForExistence(timeout: 5))
        app.navigationBars["Choose Discipline"].buttons["Back"].tap()

        XCTAssertTrue(fh5Button.waitForExistence(timeout: 5))
        XCTAssertEqual(fh5Button.value as? String, "Selected")
    }
}
