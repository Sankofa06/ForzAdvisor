import XCTest

extension ScreenshotEvidenceUITests {
    @MainActor
    func launchApp(arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"] + arguments
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))
        return app
    }

    @MainActor
    func assertEmptyGarage(in app: XCUIApplication) {
        let garage = app.descendants(matching: .any)["garageHome"].firstMatch
        XCTAssertTrue(garage.waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Create your first tune"].exists)
        let firstTune = app.buttons["newTuneButton"].firstMatch
        XCTAssertTrue(firstTune.waitForExistence(timeout: 5))
        let garageList = app.collectionViews.firstMatch
        for _ in 0..<6 where !firstTune.isHittable { garageList.swipeUp() }
        XCTAssertTrue(firstTune.waitUntilHittable(timeout: 5))
        XCTAssertEqual(firstTune.label, "Start First Tune")
        XCTAssertFalse(app.searchFields.firstMatch.exists)
    }

    @MainActor
    func openNewTune(in app: XCUIApplication) {
        let newTune = app.buttons["newTuneButton"].firstMatch
        XCTAssertTrue(newTune.waitForExistence(timeout: 5))
        XCTAssertEqual(newTune.label, "Start First Tune")
        newTune.tap()
        XCTAssertTrue(app.buttons["takePhotoPrimaryButton"].waitForExistence(timeout: 5))
        let importScreenshot = app.buttons["importScreenshotButton"].firstMatch
        let sourceList = app.collectionViews.firstMatch
        for _ in 0..<6 where !importScreenshot.exists { sourceList.swipeUp() }
        XCTAssertTrue(
            importScreenshot.waitForExistence(timeout: 5)
        )
        XCTAssertEqual(
            importScreenshot.label,
            "Import Screenshot, Run on-device Vision OCR, then confirm every value."
        )
        let manualEntry = app.buttons["manualEntryButton"]
        for _ in 0..<6 where !manualEntry.exists { sourceList.swipeUp() }
        XCTAssertTrue(manualEntry.waitForExistence(timeout: 5))
        scrollToHittable(manualEntry, in: app)
        XCTAssertFalse(app.buttons["catalogEntryButton"].exists)
    }

    @MainActor
    func openValidationReadyManualEntry(in app: XCUIApplication) {
        app.buttons["manualEntryButton"].tap()
        XCTAssertTrue(app.navigationBars["Manual Entry"].waitForExistence(timeout: 5))

        let year = app.textFields["manualEntryYearField"]
        year.enterText("1997", in: app)
        dismissKeyboard(in: app)
        let make = app.textFields["manualEntryMakeField"]
        make.enterText("Mazda", in: app)
        dismissKeyboard(in: app)
        let model = app.textFields["manualEntryModelField"]
        model.enterText("Miata", in: app)
        dismissKeyboard(in: app)
        let weight = app.textFields["manualEntryWeightField"]
        weight.enterText("2345", in: app)
        dismissKeyboard(in: app)
        let frontWeight = app.textFields["manualEntryFrontWeightField"]
        frontWeight.enterText("55", in: app)
        dismissKeyboard(in: app)
        let performanceIndex = app.textFields["manualEntryPerformanceIndexField"]
        performanceIndex.enterText("750", in: app)
        dismissKeyboard(in: app)

        let performanceClass = app.buttons["manualEntryClass-S1"]
        scrollToHittable(performanceClass, in: app)
        performanceClass.tap()
        let drivetrain = app.buttons["manualEntryDrivetrain-RWD"]
        scrollToHittable(drivetrain, in: app)
        drivetrain.tap()

        let next = app.buttons["manualEntryNextButton"]
        XCTAssertTrue(next.waitUntilEnabled(timeout: 5))
        XCTAssertEqual(
            app.textFields["manualEntryFrontWeightField"].value as? String,
            "55"
        )
    }

    @MainActor
    func openDisciplinePreflight(in app: XCUIApplication) {
        app.buttons["manualEntryNextButton"].tap()
        XCTAssertTrue(
            app.navigationBars["Choose Discipline"].waitForExistence(timeout: 5)
        )
        let road = app.buttons["disciplineButton-road"]
        scrollToHittable(road, in: app)
        road.tap()

        let start = app.buttons["startTuneGenerationButton"]
        scrollToHittable(start, in: app)
        XCTAssertTrue(start.isEnabled)
        XCTAssertTrue(app.staticTexts["Preferred method"].exists)
        XCTAssertTrue(app.staticTexts["Readiness"].exists)
    }

    @MainActor
    func openResult(in app: XCUIApplication) {
        let start = app.buttons["startTuneGenerationButton"]
        XCTAssertTrue(start.isHittable)
        start.tap()
        XCTAssertTrue(app.navigationBars["Tune"].waitForExistence(timeout: 15))
        XCTAssertTrue(
            app.descendants(matching: .any)["tuneResultStatus"]
                .firstMatch.exists
        )
        // This manual FH6 result has no confirmed build snapshot, so its
        // eligibility callbacks stay unavailable on the result screen.
        XCTAssertFalse(app.buttons["verifyTuneMenuCaptureButton"].exists)
        XCTAssertFalse(app.buttons["verifyTirePressureCaptureButton"].exists)
        XCTAssertFalse(app.buttons["verifyUpgradePartsCaptureButton"].exists)
        let save = app.buttons["saveTuneButton"]
        scrollToHittable(save, in: app)
    }

    @MainActor
    func saveResult(in app: XCUIApplication) {
        let save = app.buttons["saveTuneButton"]
        scrollBackwardToHittable(save, in: app)
        save.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["savedTuneStatus"]
                .firstMatch.waitForExistence(timeout: 5)
        )
    }

    @MainActor
    func dismissKeyboard(in app: XCUIApplication) {
        let done = app.buttons["manualEntryKeyboardDoneButton"]
        if done.waitForExistence(timeout: 2) { done.tap() }
    }

    @MainActor
    func scrollToHittable(
        _ element: XCUIElement,
        in app: XCUIApplication
    ) {
        let list = app.collectionViews.firstMatch
        for _ in 0..<12 where !element.exists { list.swipeUp(velocity: .slow) }
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        for _ in 0..<12 where !element.isHittable { list.swipeUp(velocity: .slow) }
        centerInInteractionViewport(element, using: list, in: app)
        XCTAssertTrue(element.isHittable)
    }

    @MainActor
    func scrollBackwardToHittable(
        _ element: XCUIElement,
        in app: XCUIApplication
    ) {
        let list = app.collectionViews.firstMatch
        for _ in 0..<12 where !element.exists { list.swipeDown(velocity: .slow) }
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        for _ in 0..<12 where !element.isHittable { list.swipeDown(velocity: .slow) }
        centerInInteractionViewport(element, using: list, in: app)
        XCTAssertTrue(element.isHittable)
    }

    @MainActor
    func centerInInteractionViewport(
        _ element: XCUIElement,
        using scrollView: XCUIElement,
        in app: XCUIApplication
    ) {
        let upperBound = app.frame.minY + app.frame.height * 0.22
        let lowerBound = app.frame.minY + app.frame.height * 0.65
        let upwardStart = scrollView.coordinate(
            withNormalizedOffset: CGVector(dx: 0.5, dy: 0.68)
        )
        let upwardEnd = scrollView.coordinate(
            withNormalizedOffset: CGVector(dx: 0.5, dy: 0.48)
        )
        let downwardStart = scrollView.coordinate(
            withNormalizedOffset: CGVector(dx: 0.5, dy: 0.32)
        )
        let downwardEnd = scrollView.coordinate(
            withNormalizedOffset: CGVector(dx: 0.5, dy: 0.52)
        )

        for _ in 0..<6 {
            let midpoint = element.frame.midY
            if midpoint > lowerBound {
                upwardStart.press(
                    forDuration: 0.05,
                    thenDragTo: upwardEnd
                )
            } else if midpoint < upperBound {
                downwardStart.press(
                    forDuration: 0.05,
                    thenDragTo: downwardEnd
                )
            } else {
                break
            }
        }
    }

    @MainActor
    func capture(_ name: String, in app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

private extension XCUIElement {
    func waitUntilHittable(timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "isHittable == true")
        let expectation = XCTNSPredicateExpectation(
            predicate: predicate,
            object: self
        )
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
}
