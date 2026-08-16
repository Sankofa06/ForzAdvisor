import XCTest

extension ForzAdvisorUITests {
    @MainActor
    func testManualTuneCanBeSavedAndReopened() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))

        let garageHome = app.descendants(matching: .any)["garageHome"].firstMatch
        XCTAssertTrue(garageHome.waitForExistence(timeout: 15))

        let newTuneButton = garageHome.descendants(matching: .button)["newTuneButton"]
        XCTAssertTrue(newTuneButton.waitForExistence(timeout: 10))
        newTuneButton.tap()

        let manualEntryButton = app.buttons["manualEntryButton"]
        XCTAssertTrue(manualEntryButton.waitForExistence(timeout: 5))
        manualEntryButton.tap()

        XCTAssertTrue(app.navigationBars["Manual Entry"].waitForExistence(timeout: 5))

        let nextButton = app.buttons["manualEntryNextButton"]
        let keyboardDoneButton = app.buttons["manualEntryKeyboardDoneButton"]
        XCTAssertTrue(nextButton.waitForExistence(timeout: 5))

        app.textFields["manualEntryYearField"].enterText("1997")
        app.textFields["manualEntryMakeField"].enterText("Mazda")
        app.textFields["manualEntryModelField"].enterText("Miata")
        XCTAssertTrue(keyboardDoneButton.waitForExistence(timeout: 2))
        keyboardDoneButton.tap()
        app.swipeUp()
        app.textFields["manualEntryWeightField"].enterText("2345")
        XCTAssertTrue(keyboardDoneButton.waitForExistence(timeout: 2))
        keyboardDoneButton.tap()
        let frontWeightField = app.textFields["manualEntryFrontWeightField"]
        for _ in 0..<5 where !frontWeightField.isHittable { app.swipeUp() }
        XCTAssertTrue(frontWeightField.isHittable)
        frontWeightField.enterText("55")
        XCTAssertTrue(keyboardDoneButton.waitForExistence(timeout: 2))
        keyboardDoneButton.tap()
        app.swipeUp()
        app.textFields["manualEntryPerformanceIndexField"].enterText("689")
        if keyboardDoneButton.waitForExistence(timeout: 2) {
            keyboardDoneButton.tap()
        }
        app.buttons["manualEntryClass-A"].tap()
        app.buttons["manualEntryDrivetrain-RWD"].tap()

        if !nextButton.waitUntilEnabled(timeout: 3) {
            let visibleText = app.staticTexts.allElementsBoundByIndex
                .map(\.label)
                .filter { !$0.isEmpty }
                .joined(separator: " | ")
            XCTFail("Manual entry Next stayed disabled after required input. Visible text: \(visibleText)")
            return
        }
        nextButton.tap()

        let roadButton = app.buttons["disciplineButton-road"]
        XCTAssertTrue(app.navigationBars["Choose Discipline"].waitForExistence(timeout: 5))
        XCTAssertTrue(roadButton.waitForExistence(timeout: 5))
        roadButton.tap()

        XCTAssertTrue(app.navigationBars["Choose Discipline"].exists)
        XCTAssertFalse(app.navigationBars["Tune"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["availableSettingsSection"].exists)

        let startButton = app.buttons["startTuneGenerationButton"]
        let disciplineList = app.collectionViews.firstMatch
        XCTAssertTrue(disciplineList.exists)
        for _ in 0..<8 where !startButton.exists { disciplineList.swipeUp() }
        XCTAssertTrue(startButton.waitForExistence(timeout: 5))
        XCTAssertTrue(startButton.isHittable)
        startButton.tap()

        XCTAssertTrue(app.navigationBars["Tune"].waitForExistence(timeout: 15))

        let saveButton = app.buttons["saveTuneButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        saveButton.tap()

        let doneButton = app.buttons["doneTuneButton"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 5))
        doneButton.tap()

        let savedTuneRow = app.buttons["savedTuneRow"].firstMatch
        XCTAssertTrue(savedTuneRow.waitForExistence(timeout: 5))
        savedTuneRow.tap()

        XCTAssertTrue(app.navigationBars["Tune"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["1997 Mazda Miata"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.descendants(matching: .any)["availableSettingsSection"]
                .firstMatch.waitForExistence(timeout: 5)
        )
        XCTAssertFalse(app.buttons["feedbackButton-pushesWide"].exists)
    }
}
