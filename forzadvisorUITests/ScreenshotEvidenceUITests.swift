import XCTest

final class ScreenshotEvidenceUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSupportedManualFlowScreenshotEvidence() {
        let app = launchApp()

        assertEmptyGarage(in: app)
        capture("01-empty-garage-light", in: app)

        openNewTune(in: app)
        capture("02-new-tune-source-light", in: app)

        openValidationReadyManualEntry(in: app)
        capture("03-manual-entry-validation-ready-light", in: app)

        openDisciplinePreflight(in: app)
        capture("04-discipline-provider-preflight-light", in: app)

        openResult(in: app)
        capture("05-result-top-light", in: app)

        let availableSettings = app.descendants(matching: .any)[
            "availableSettingsSection"
        ].firstMatch
        scrollToHittable(availableSettings, in: app)
        let availableSettingsRenderDelay = expectation(
            description: "Available settings finishes rendering"
        )
        availableSettingsRenderDelay.isInverted = true
        XCTAssertEqual(
            XCTWaiter().wait(for: [availableSettingsRenderDelay], timeout: 0.5),
            .completed
        )
        XCTAssertTrue(
            app.staticTexts[
                "Availability means these values can be entered in game. It is not an accuracy or validation score."
            ].exists
        )
        capture("06-result-available-settings-light", in: app)

        let evidenceSummary = app.staticTexts.matching(
            NSPredicate(
                format: "label == %@",
                "Optional Validation & Research"
            )
        ).firstMatch
        scrollToHittable(evidenceSummary, in: app)
        let evidenceExplanation = app.staticTexts.matching(
            NSPredicate(
                format: "label == %@",
                "Use Evidence Hub later if you want to record on-device observations, choose future reuse, or review shared evidence. It never changes available settings automatically."
            )
        ).firstMatch
        scrollToHittable(evidenceExplanation, in: app)
        capture("07-result-evidence-summary-light", in: app)

        saveResult(in: app)
        let openEvidenceHub = app.buttons["openTuneEvidenceHubButton"]
        scrollToHittable(openEvidenceHub, in: app)
        openEvidenceHub.tap()

        let evidenceHub = app.descendants(matching: .any)["tuneEvidenceHub"]
            .firstMatch
        XCTAssertTrue(evidenceHub.waitForExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["Evidence Hub"].exists)
        capture("08-evidence-hub-light", in: app)
    }

    @MainActor
    func testSettingsAndStepGuideScreenshotEvidence() {
        let app = launchApp()
        assertEmptyGarage(in: app)

        let settings = app.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.descendants(matching: .any)["providerPreference-offlineFormula"]
                .firstMatch.waitForExistence(timeout: 5)
        )
        capture("09-settings-provider-card-light", in: app)

        app.navigationBars["Settings"].buttons["Done"].tap()
        let stepGuide = app.buttons["garageStepGuideButton"]
        XCTAssertTrue(stepGuide.waitForExistence(timeout: 5))
        stepGuide.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["copilotSheet"]
                .firstMatch.waitForExistence(timeout: 5)
        )
        XCTAssertTrue(app.staticTexts[
            "Local deterministic guidance. No model, network, or transcript."
        ].exists)
        for label in [
            "Next step",
            "What can I trust?",
            "What is missing?",
            "Privacy"
        ] {
            XCTAssertTrue(app.buttons[label].exists)
        }
        capture("10-step-guide-choices-light", in: app)
    }

    @MainActor
    func testDarkModeGarageNewTuneAndResultScreenshotEvidence() {
        let app = launchApp(arguments: ["-AppleInterfaceStyle", "Dark"])

        assertEmptyGarage(in: app)
        capture("11-empty-garage-dark", in: app)
        openNewTune(in: app)
        capture("12-new-tune-source-dark", in: app)
        openValidationReadyManualEntry(in: app)
        openDisciplinePreflight(in: app)
        openResult(in: app)
        capture("13-result-top-dark", in: app)
    }

    @MainActor
    func testAccessibilityXXXLGarageNewTuneAndResultScreenshotEvidence() {
        let app = launchApp(arguments: [
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
        ])

        assertEmptyGarage(in: app)
        capture("14-empty-garage-accessibility-xxxl", in: app)
        openNewTune(in: app)
        capture("15-new-tune-source-accessibility-xxxl", in: app)
        openValidationReadyManualEntry(in: app)
        openDisciplinePreflight(in: app)
        openResult(in: app)
        capture("16-result-top-accessibility-xxxl", in: app)
    }

    @MainActor
    private func launchApp(arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"] + arguments
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))
        return app
    }

    @MainActor
    private func assertEmptyGarage(in app: XCUIApplication) {
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
    private func openNewTune(in app: XCUIApplication) {
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
    private func openValidationReadyManualEntry(in app: XCUIApplication) {
        app.buttons["manualEntryButton"].tap()
        XCTAssertTrue(app.navigationBars["Manual Entry"].waitForExistence(timeout: 5))

        app.textFields["manualEntryYearField"].enterText("1997")
        app.textFields["manualEntryMakeField"].enterText("Mazda")
        app.textFields["manualEntryModelField"].enterText("Miata")
        dismissKeyboard(in: app)
        let weight = app.textFields["manualEntryWeightField"]
        scrollToHittable(weight, in: app)
        weight.enterText("2345")
        dismissKeyboard(in: app)
        let frontWeight = app.textFields["manualEntryFrontWeightField"]
        scrollToHittable(frontWeight, in: app)
        frontWeight.enterText("55")
        dismissKeyboard(in: app)
        let performanceIndex = app.textFields["manualEntryPerformanceIndexField"]
        scrollToHittable(performanceIndex, in: app)
        performanceIndex.enterText("750")
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
    private func openDisciplinePreflight(in app: XCUIApplication) {
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
    private func openResult(in app: XCUIApplication) {
        let start = app.buttons["startTuneGenerationButton"]
        XCTAssertTrue(start.isHittable)
        start.tap()
        XCTAssertTrue(app.navigationBars["Tune"].waitForExistence(timeout: 15))
        XCTAssertTrue(
            app.descendants(matching: .any)["tuneResultStatus"]
                .firstMatch.exists
        )
        let save = app.buttons["saveTuneButton"]
        scrollToHittable(save, in: app)
    }

    @MainActor
    private func saveResult(in app: XCUIApplication) {
        let save = app.buttons["saveTuneButton"]
        scrollBackwardToHittable(save, in: app)
        save.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["savedTuneStatus"]
                .firstMatch.waitForExistence(timeout: 5)
        )
    }

    @MainActor
    private func dismissKeyboard(in app: XCUIApplication) {
        let done = app.buttons["manualEntryKeyboardDoneButton"]
        if done.waitForExistence(timeout: 2) { done.tap() }
    }

    @MainActor
    private func scrollToHittable(
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
    private func scrollBackwardToHittable(
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
    private func centerInInteractionViewport(
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
    private func capture(_ name: String, in app: XCUIApplication) {
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
