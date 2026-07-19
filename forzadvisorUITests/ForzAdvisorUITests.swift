//
//  ForzAdvisorUITests.swift
//  forzadvisorUITests
//
//  Manual-entry smoke coverage for the core tune, save, and reopen flow.
//

import XCTest

final class ForzAdvisorUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

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
        XCTAssertTrue(nextButton.waitForExistence(timeout: 5))
        XCTAssertFalse(nextButton.isEnabled)

        app.textFields["manualEntryYearField"].tap()
        app.textFields["manualEntryYearField"].typeText("1997")
        app.textFields["manualEntryMakeField"].tap()
        app.textFields["manualEntryMakeField"].typeText("Mazda")
        app.textFields["manualEntryModelField"].tap()
        app.textFields["manualEntryModelField"].typeText("Miata")
        app.textFields["manualEntryWeightField"].tap()
        app.textFields["manualEntryWeightField"].typeText("2345")
        app.textFields["manualEntryFrontWeightField"].tap()
        app.textFields["manualEntryFrontWeightField"].typeText("55")
        app.textFields["manualEntryPerformanceIndexField"].tap()
        app.textFields["manualEntryPerformanceIndexField"].typeText("789")
        let keyboardDoneButton = app.buttons["manualEntryKeyboardDoneButton"]
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
        XCTAssertTrue(roadButton.waitForExistence(timeout: 5))
        roadButton.tap()

        XCTAssertTrue(app.navigationBars["Tune"].waitForExistence(timeout: 5))

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

        let feedbackButton = app.buttons["feedbackButton-pushesWide"]
        XCTAssertTrue(feedbackButton.waitForExistence(timeout: 5))
        feedbackButton.tap()

        let adjustmentChangeRow = app.descendants(matching: .any)["adjustmentChangeRow"].firstMatch
        XCTAssertTrue(app.waitForVisibleElement(adjustmentChangeRow, timeout: 15))
    }
}

private extension XCUIElement {
    func waitUntilEnabled(timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "isEnabled == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
}

private extension XCUIApplication {
    func waitForVisibleElement(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.waitForExistence(timeout: 1) {
                return true
            }
            swipeUp()
        }
        return element.exists
    }
}
