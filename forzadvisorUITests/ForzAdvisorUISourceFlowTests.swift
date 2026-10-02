import XCTest

extension ForzAdvisorUITests {
    @MainActor
    func testManualDraftSurvivesGarageAndNewTune() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        let garage = app.descendants(matching: .any)["garageHome"].firstMatch
        XCTAssertTrue(garage.waitForExistence(timeout: 15))
        garage.descendants(matching: .button)["newTuneButton"].tap()
        app.buttons["manualEntryButton"].tap()
        let make = app.textFields["manualEntryMakeField"]
        make.enterText("Mazda", in: app)
        app.buttons["manualEntryKeyboardDoneButton"].tap()
        app.navigationBars["Manual Entry"].buttons["Cancel"].tap()
        app.buttons["Close"].tap()
        XCTAssertTrue(garage.waitForExistence(timeout: 5))
        garage.descendants(matching: .button)["newTuneButton"].tap()
        let resume = app.buttons["resumeNewTuneButton"]
        XCTAssertTrue(resume.waitForExistence(timeout: 5))
        resume.tap()
        XCTAssertTrue(make.waitForExistence(timeout: 5))
        XCTAssertEqual(make.value as? String, "Mazda")
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "restored-manual-draft"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testTuneSourceOffersOnlySupportedEntries() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))

        let garageHome = app.descendants(matching: .any)["garageHome"].firstMatch
        XCTAssertTrue(garageHome.waitForExistence(timeout: 15))
        garageHome.descendants(matching: .button)["newTuneButton"].tap()

        for (identifier, title) in [
            ("takePhotoPrimaryButton", "Take Photo"),
            ("importScreenshotButton", "Import Screenshot"),
            ("manualEntryButton", "Enter Manually")
        ] {
            let button = app.buttons[identifier]
            XCTAssertTrue(button.waitForExistence(timeout: 5), identifier)
            XCTAssertTrue(button.label.contains(title), title)
        }
        XCTAssertFalse(app.buttons["catalogEntryButton"].exists)
        for unsupportedClaim in [
            "Browse Full Official", "official FH5", "official FH6", "roster-only"
        ] {
            let claim = NSPredicate(format: "label CONTAINS[c] %@", unsupportedClaim)
            XCTAssertFalse(
                app.descendants(matching: .any).matching(claim).firstMatch.exists,
                unsupportedClaim
            )
        }
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
        let weightField = app.textFields["manualEntryWeightField"]
        weightField.scrollToInteractionViewport(in: app)
        weightField.enterText("2345")
        XCTAssertTrue(keyboardDoneButton.waitForExistence(timeout: 2))
        keyboardDoneButton.tap()
        app.swipeUp()
        let frontWeightField = app.textFields["manualEntryFrontWeightField"]
        frontWeightField.scrollToInteractionViewport(in: app)
        frontWeightField.enterText("55")
        XCTAssertTrue(keyboardDoneButton.waitForExistence(timeout: 2))
        keyboardDoneButton.tap()
        app.swipeUp()
        let performanceIndexField = app.textFields[
            "manualEntryPerformanceIndexField"
        ]
        performanceIndexField.scrollToInteractionViewport(in: app)
        performanceIndexField.enterText("789")
        if keyboardDoneButton.waitForExistence(timeout: 2) {
            keyboardDoneButton.tap()
        }
        let performanceClass = app.buttons["manualEntryClass-A"]
        performanceClass.scrollToInteractionViewport(in: app)
        performanceClass.tap()
        let drivetrain = app.buttons["manualEntryDrivetrain-RWD"]
        drivetrain.scrollToInteractionViewport(in: app)
        drivetrain.tap()

        let nextButton = app.buttons["manualEntryNextButton"]
        XCTAssertTrue(nextButton.waitUntilEnabled(timeout: 3))
        nextButton.tap()

        XCTAssertTrue(app.buttons["disciplineButton-road"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["FH5"].waitForExistence(timeout: 5))
        app.buttons["disciplineButton-road"].tap()
        let localMethod = app.staticTexts["Local FH5 build planner"]
        for _ in 0..<8 where !localMethod.exists { app.swipeUp() }
        XCTAssertTrue(localMethod.waitForExistence(timeout: 5))
        app.navigationBars["Choose Discipline"].buttons["Back"].tap()

        XCTAssertTrue(fh5Button.waitForExistence(timeout: 5))
        XCTAssertEqual(fh5Button.value as? String, "Selected")
    }
}
