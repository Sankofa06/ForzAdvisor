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
    func testLegacyNumericValuesAreWithheldFromRenderedSettings() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-ui-test-legacy-settings"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Legacy Result Test"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Stored fixture lines: 1"].exists)
        XCTAssertTrue(app.staticTexts["Legacy settings withheld"].exists)
        XCTAssertFalse(app.staticTexts["Available settings"].exists)
        XCTAssertFalse(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "37.125")).firstMatch.exists)
        XCTAssertFalse(app.buttons["Expand all"].exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Legacy numeric settings withheld"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testResultCaptureButtonDispatchesFromRenderedEvidenceSection() {
        let app = launchCaptureActionHarness()
        let capture = app.buttons["verifyTirePressureCaptureButton"]
        XCTAssertTrue(capture.waitForExistence(timeout: 5))
        for _ in 0..<8 where !capture.isHittable { app.swipeUp() }
        XCTAssertTrue(capture.isHittable)

        capture.tap()

        XCTAssertTrue(
            app.staticTexts["Result: Verify Tire Pressures"]
                .waitForExistence(timeout: 5)
        )
    }

    @MainActor
    func testEvidenceHubCaptureButtonDispatchesFromRenderedHubView() {
        let app = launchCaptureActionHarness()
        let openEvidenceHub = app.buttons["openTuneEvidenceHubButton"]
        XCTAssertTrue(openEvidenceHub.waitForExistence(timeout: 5))
        openEvidenceHub.tap()

        XCTAssertTrue(app.navigationBars["Evidence Hub"].waitForExistence(timeout: 5))
        let capture = app.buttons["hubVerifyTirePressureCaptureButton"]
        XCTAssertTrue(capture.waitForExistence(timeout: 5))
        for _ in 0..<8 where !capture.isHittable { app.swipeUp() }
        XCTAssertTrue(capture.isHittable)
        capture.tap()

        XCTAssertTrue(
            app.staticTexts["Hub: Verify Tire Pressures"]
                .waitForExistence(timeout: 5)
        )
    }

    @MainActor
    private func launchCaptureActionHarness() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-ui-test-capture-actions"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))
        return app
    }

    @MainActor
    private func openCompletedManualResult(in app: XCUIApplication) {
        let garage = app.descendants(matching: .any)["garageHome"].firstMatch
        XCTAssertTrue(garage.waitForExistence(timeout: 15))
        garage.descendants(matching: .button)["newTuneButton"].tap()
        app.buttons["manualEntryButton"].tap()

        app.textFields["manualEntryYearField"].enterText("1997", in: app)
        dismissKeyboard(in: app)
        app.textFields["manualEntryMakeField"].enterText("Mazda", in: app)
        dismissKeyboard(in: app)
        app.textFields["manualEntryModelField"].enterText("Miata", in: app)
        dismissKeyboard(in: app)
        app.textFields["manualEntryWeightField"].enterText("2345", in: app)
        dismissKeyboard(in: app)
        app.textFields["manualEntryFrontWeightField"].enterText("55", in: app)
        dismissKeyboard(in: app)
        app.textFields["manualEntryPerformanceIndexField"].enterText("750", in: app)
        dismissKeyboard(in: app)
        let performanceClass = app.buttons["manualEntryClass-S1"]
        performanceClass.scrollToInteractionViewport(in: app)
        performanceClass.tap()
        let drivetrain = app.buttons["manualEntryDrivetrain-RWD"]
        drivetrain.scrollToInteractionViewport(in: app)
        drivetrain.tap()

        let next = app.buttons["manualEntryNextButton"]
        XCTAssertTrue(next.waitUntilEnabled(timeout: 5))
        next.tap()
        XCTAssertTrue(app.navigationBars["Choose Discipline"].waitForExistence(timeout: 5))
        let road = app.buttons["disciplineButton-road"]
        road.scrollToInteractionViewport(in: app)
        road.tap()
        let start = app.buttons["startTuneGenerationButton"]
        // The lazy list creates the generation control only after scrolling.
        for _ in 0..<8 where !start.exists { app.swipeUp() }
        start.scrollToInteractionViewport(in: app)
        start.tap()
        XCTAssertTrue(app.navigationBars["Tune"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["saveTuneButton"].waitForExistence(timeout: 15))
    }

    @MainActor
    private func dismissKeyboard(in app: XCUIApplication) {
        let done = app.buttons["manualEntryKeyboardDoneButton"]
        if done.waitForExistence(timeout: 2) { done.tap() }
    }
}
