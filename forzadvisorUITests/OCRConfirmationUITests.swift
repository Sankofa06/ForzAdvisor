import XCTest

final class OCRConfirmationUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testManualOptionalValuesSurviveOCRConfirmationAndFallback() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-ui-test-ocr-manual-values"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Confirm Inputs"].waitForExistence(timeout: 15))
        let horsepower = app.textFields["Horsepower · Optional"]
        for _ in 0..<8 where !horsepower.exists { app.swipeUp() }
        horsepower.enterText("400", in: app)
        let torque = app.textFields["Torque · Optional"]
        torque.enterText("350", in: app)
        app.buttons["ocrConfirmationNextButton"].tap()
        XCTAssertTrue(app.staticTexts[
            "Input: 400 hp, 350 lb-ft; fallback: 400 hp, 350 lb-ft"
        ].waitForExistence(timeout: 5))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "ocr-manual-optional-values"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
