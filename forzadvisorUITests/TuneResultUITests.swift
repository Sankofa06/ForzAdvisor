import XCTest

final class TuneResultUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testResultHierarchySaveStatusAndMetadataEditAction() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))

        openCompletedManualResult(in: app)

        XCTAssertTrue(app.descendants(matching: .any)["tuneResultStatus"].waitForExistence(timeout: 5))
        let save = app.buttons["saveTuneButton"]
        XCTAssertTrue(save.exists)
        XCTAssertTrue(app.descendants(matching: .any)["availableSettingsSection"].exists)
        let evidenceHeading = app.staticTexts["Optional Validation & Research"]
        for _ in 0..<8 where !evidenceHeading.exists { app.swipeUp() }
        XCTAssertTrue(evidenceHeading.waitForExistence(timeout: 5))

        for _ in 0..<8 where !save.isHittable { app.swipeDown() }
        XCTAssertTrue(save.isHittable)

        save.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["savedTuneStatus"]
                .waitForExistence(timeout: 5)
        )
        XCTAssertFalse(app.buttons["Saved"].exists)

        app.buttons["editSavedTuneButton"].tap()
        XCTAssertTrue(app.navigationBars["Edit Tune"].waitForExistence(timeout: 5))
        let notes = app.textViews["savedTuneNotesField"]
        XCTAssertTrue(notes.waitForExistence(timeout: 5))
        notes.tap()
        notes.typeText("Metadata only")
        XCTAssertEqual(
            app.buttons["savedTuneEditPrimaryAction"].label,
            "Save Changes"
        )
    }

    @MainActor
    private func openCompletedManualResult(in app: XCUIApplication) {
        let garage = app.descendants(matching: .any)["garageHome"].firstMatch
        XCTAssertTrue(garage.waitForExistence(timeout: 15))
        garage.descendants(matching: .button)["newTuneButton"].tap()
        app.buttons["manualEntryButton"].tap()

        app.textFields["manualEntryYearField"].enterResultText("1997")
        app.textFields["manualEntryMakeField"].enterResultText("Mazda")
        app.textFields["manualEntryModelField"].enterResultText("Miata")
        dismissKeyboardAndScroll(in: app)
        app.textFields["manualEntryWeightField"].enterResultText("2345")
        dismissKeyboardAndScroll(in: app)
        app.textFields["manualEntryFrontWeightField"].enterResultText("55")
        dismissKeyboardAndScroll(in: app)
        app.textFields["manualEntryPerformanceIndexField"].enterResultText("750")
        dismissKeyboard(in: app)
        app.buttons["manualEntryClass-S1"].tap()
        app.buttons["manualEntryDrivetrain-RWD"].tap()

        let next = app.buttons["manualEntryNextButton"]
        XCTAssertTrue(next.waitUntilResultEnabled(timeout: 5))
        next.tap()
        app.buttons["disciplineButton-road"].tap()
        let start = app.buttons["startTuneGenerationButton"]
        for _ in 0..<8 where !start.exists { app.swipeUp() }
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        XCTAssertTrue(start.isHittable)
        start.tap()
        XCTAssertTrue(app.navigationBars["Tune"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["saveTuneButton"].waitForExistence(timeout: 15))
    }

    @MainActor
    private func dismissKeyboardAndScroll(in app: XCUIApplication) {
        dismissKeyboard(in: app)
        app.swipeUp()
    }

    @MainActor
    private func dismissKeyboard(in app: XCUIApplication) {
        let done = app.buttons["manualEntryKeyboardDoneButton"]
        if done.waitForExistence(timeout: 2) { done.tap() }
    }
}

private extension XCUIElement {
    func enterResultText(_ text: String) {
        XCTAssertTrue(waitForExistence(timeout: 5))
        tap()
        typeText(text)
    }

    func waitUntilResultEnabled(timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "isEnabled == true")
        let expectation = XCTNSPredicateExpectation(
            predicate: predicate,
            object: self
        )
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
}
