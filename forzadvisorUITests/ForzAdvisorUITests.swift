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
        app.launch()

        let newTuneButton = app.buttons["newTuneButton"]
        XCTAssertTrue(newTuneButton.waitForExistence(timeout: 5))
        newTuneButton.tap()

        let manualEntryButton = app.buttons["manualEntryButton"]
        XCTAssertTrue(manualEntryButton.waitForExistence(timeout: 5))
        manualEntryButton.tap()

        XCTAssertTrue(app.navigationBars["Manual Entry"].waitForExistence(timeout: 5))

        let nextButton = app.buttons["manualEntryNextButton"]
        XCTAssertTrue(nextButton.waitForExistence(timeout: 5))
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
        XCTAssertTrue(app.staticTexts["2019 Toyota Supra"].waitForExistence(timeout: 5))
    }
}
