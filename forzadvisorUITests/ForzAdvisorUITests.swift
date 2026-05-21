//
//  ForzAdvisorUITests.swift
//  forzadvisorUITests
//
//  Minimal launch and manual-entry smoke coverage for the main tune flow.
//

import XCTest

final class ForzAdvisorUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchCanOpenManualTuneFlow() throws {
        let app = XCUIApplication()
        app.launch()

        let newTuneButton = app.buttons["newTuneButton"]
        XCTAssertTrue(newTuneButton.waitForExistence(timeout: 5))
        newTuneButton.tap()

        let manualEntryButton = app.buttons["manualEntryButton"]
        XCTAssertTrue(manualEntryButton.waitForExistence(timeout: 5))
        manualEntryButton.tap()

        XCTAssertTrue(app.navigationBars["Manual Entry"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["manualEntryNextButton"].exists)
    }
}
