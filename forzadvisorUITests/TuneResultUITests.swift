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
        // A partially exposed row can be hittable underneath the navigation
        // chrome after the full-screen swipe. Match the passing screenshot
        // journey by centering Save before its single, consequential tap.
        centerSaveForInteraction(save, in: app)
        XCTAssertTrue(save.isHittable)
        XCTAssertTrue(save.isEnabled)

        captureSaveDiagnostic("result-regression-before-save", in: app)
        save.tap()
        captureSaveDiagnostic("result-regression-after-save", in: app)
        // Edit is independent of lazy list materialization and proves the
        // app entered its saved state before searching for its status row.
        let edit = app.buttons["editSavedTuneButton"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5),
                      "Save did not expose Edit after one tap. Save exists=\(save.exists), frame=\(save.exists ? save.frame : .zero); inline error=\(app.descendants(matching: .any)["saveTuneInlineError"].firstMatch.exists).")
        let savedStatus = app.staticTexts["savedTuneStatus"]
        revealSavedStatus(savedStatus, in: app)
        XCTAssertTrue(savedStatus.waitForExistence(timeout: 5))
        XCTAssertEqual(savedStatus.label, "Saved setup")
        XCTAssertTrue(savedStatus.isHittable)
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
    private func centerSaveForInteraction(_ save: XCUIElement, in app: XCUIApplication) {
        let list = app.collectionViews.firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        let safeArea = CGRect(
            x: app.frame.minX + 8, y: app.frame.minY + app.frame.height * 0.22,
            width: app.frame.width - 16, height: app.frame.height * 0.43
        )
        for _ in 0..<12 {
            if save.exists && save.isHittable && safeArea.contains(save.frame) { return }
            let above = save.exists && save.frame.midY < safeArea.midY
            let start = list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: above ? 0.32 : 0.68))
            let end = list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: above ? 0.52 : 0.48))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTAssertTrue(save.exists && save.isHittable && safeArea.contains(save.frame),
                      "Save must be fully visible in the content viewport before tapping.")
    }

    @MainActor
    private func revealSavedStatus(_ status: XCUIElement, in app: XCUIApplication) {
        // Shared bounded search handles a missing lazy row, either side of
        // the viewport, and navigation chrome after the saved-state transition.
        status.scrollToInteractionViewport(in: app)
        XCTAssertTrue(status.exists && status.isHittable,
                      "Saved status not revealed. exists=\(status.exists), hittable=\(status.isHittable), frame=\(status.exists ? status.frame : .zero), app=\(app.frame).")
    }

    @MainActor
    private func captureSaveDiagnostic(_ name: String, in app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
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
