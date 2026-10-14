import XCTest

final class InputFlowAccessibilityUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testManualNextRevealsMissingClassAndDrivetrain() {
        let app = launchManualEntry()
        for (identifier, value) in [
            ("manualEntryYearField", "1997"),
            ("manualEntryMakeField", "Mazda"),
            ("manualEntryWeightField", "2345"),
            ("manualEntryFrontWeightField", "55"),
            ("manualEntryPerformanceIndexField", "789")
        ] {
            app.textFields[identifier].enterText(value, in: app)
            app.buttons["manualEntryKeyboardDoneButton"].tap()
        }
        // Submit from the far end of the form: the missing selection must be revealed.
        app.swipeUp()
        app.swipeUp()
        app.buttons["manualEntryNextButton"].tap()
        let performanceClass = app.buttons["manualEntryClass-S1"]
        assertHittable(performanceClass)
        performanceClass.tap()
        app.swipeDown()
        app.swipeDown()
        app.buttons["manualEntryNextButton"].tap()
        assertHittable(app.buttons["manualEntryDrivetrain-RWD"])
        XCTAssertTrue(app.navigationBars["Manual Entry"].exists)
    }

    @MainActor
    func testManualKeyboardDoneDismissesKeyboard() {
        let app = launchManualEntry()
        app.textFields["manualEntryYearField"].enterText("1997", in: app)
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        app.buttons["manualEntryKeyboardDoneButton"].tap()
        assertKeyboardDismissed(app)
    }

    @MainActor
    func testOCRKeyboardDoneDismissesKeyboard() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-ui-test-ocr-manual-values"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Confirm Inputs"].waitForExistence(timeout: 15))
        let year = app.textFields["ocrConfirmationYearField"]
        year.scrollToInteractionViewport(in: app)
        year.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        app.buttons["ocrConfirmationKeyboardDoneButton"].tap()
        assertKeyboardDismissed(app)
    }

    @MainActor
    private func launchManualEntry() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        let garage = app.descendants(matching: .any)["garageHome"].firstMatch
        XCTAssertTrue(garage.waitForExistence(timeout: 15))
        garage.descendants(matching: .button)["newTuneButton"].tap()
        let manualEntry = app.buttons["manualEntryButton"]
        manualEntry.scrollToInteractionViewport(in: app)
        manualEntry.tap()
        XCTAssertTrue(app.navigationBars["Manual Entry"].waitForExistence(timeout: 5))
        return app
    }

    private func assertHittable(_ element: XCUIElement) {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND isHittable == true"), object: element
        )
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed)
    }

    @MainActor
    private func assertKeyboardDismissed(_ app: XCUIApplication) {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: app.keyboards.firstMatch
        )
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 3), .completed)
    }
}
