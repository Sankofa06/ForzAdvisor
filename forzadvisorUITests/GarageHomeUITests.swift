import XCTest

final class GarageHomeUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testEmptyGaragePrioritizesSupportedFirstTunePaths() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()

        let garage = app.descendants(matching: .any)["garageHome"].firstMatch
        XCTAssertTrue(garage.waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["newTuneButton"].exists)
        XCTAssertTrue(app.staticTexts["Create your first tune"].exists)
        XCTAssertTrue(app.staticTexts["Optional Testing & Research"].exists)
        XCTAssertFalse(app.searchFields.firstMatch.exists)
        XCTAssertFalse(app.descendants(matching: .any)["garageDisciplineFilter"].exists)
    }

    @MainActor
    func testEmptyGarageHasOneLabeledStepGuideEntry() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()

        let stepGuide = app.buttons["garageStepGuideButton"]
        XCTAssertTrue(stepGuide.waitForExistence(timeout: 15))
        XCTAssertEqual(app.buttons.matching(identifier: "garageStepGuideButton").count, 1)
        XCTAssertFalse(app.buttons["garageCopilotButton"].exists)
    }
}
