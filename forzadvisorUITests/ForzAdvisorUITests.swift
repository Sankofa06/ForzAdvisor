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
        let keyboardDoneButton = app.buttons["manualEntryKeyboardDoneButton"]
        XCTAssertTrue(nextButton.waitForExistence(timeout: 5))
        XCTAssertFalse(nextButton.isEnabled)

        app.textFields["manualEntryYearField"].enterText("1997")
        app.textFields["manualEntryMakeField"].enterText("Mazda")
        app.textFields["manualEntryModelField"].enterText("Miata")
        XCTAssertTrue(keyboardDoneButton.waitForExistence(timeout: 2))
        keyboardDoneButton.tap()
        app.swipeUp()
        app.textFields["manualEntryWeightField"].enterText("2345")
        XCTAssertTrue(keyboardDoneButton.waitForExistence(timeout: 2))
        keyboardDoneButton.tap()
        app.swipeUp()
        app.textFields["manualEntryFrontWeightField"].enterText("55")
        XCTAssertTrue(keyboardDoneButton.waitForExistence(timeout: 2))
        keyboardDoneButton.tap()
        app.swipeUp()
        app.textFields["manualEntryPerformanceIndexField"].enterText("689")
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
        XCTAssertTrue(
            app.descendants(matching: .any)["tuneCoverage"].firstMatch.waitForExistence(timeout: 5)
        )
        XCTAssertFalse(app.buttons["feedbackButton-pushesWide"].exists)
    }

    @MainActor
    func testManualGameSelectionSurvivesDisciplineRoundTrip() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))

        let garageHome = app.descendants(matching: .any)["garageHome"].firstMatch
        XCTAssertTrue(garageHome.waitForExistence(timeout: 15))
        garageHome.descendants(matching: .button)["newTuneButton"].tap()
        app.buttons["manualEntryButton"].tap()

        let fh5Button = app.buttons["manualEntryGame-fh5"]
        XCTAssertTrue(fh5Button.waitForExistence(timeout: 5))
        fh5Button.tap()
        XCTAssertEqual(fh5Button.value as? String, "Selected")

        let keyboardDoneButton = app.buttons["manualEntryKeyboardDoneButton"]
        app.textFields["manualEntryYearField"].enterText("1997")
        app.textFields["manualEntryMakeField"].enterText("Mazda")
        app.textFields["manualEntryModelField"].enterText("Miata")
        XCTAssertTrue(keyboardDoneButton.waitForExistence(timeout: 2))
        keyboardDoneButton.tap()
        app.swipeUp()
        app.textFields["manualEntryWeightField"].enterText("2345")
        XCTAssertTrue(keyboardDoneButton.waitForExistence(timeout: 2))
        keyboardDoneButton.tap()
        app.swipeUp()
        app.textFields["manualEntryFrontWeightField"].enterText("55")
        XCTAssertTrue(keyboardDoneButton.waitForExistence(timeout: 2))
        keyboardDoneButton.tap()
        app.swipeUp()
        app.textFields["manualEntryPerformanceIndexField"].enterText("789")
        if keyboardDoneButton.waitForExistence(timeout: 2) {
            keyboardDoneButton.tap()
        }
        app.buttons["manualEntryClass-A"].tap()
        app.buttons["manualEntryDrivetrain-RWD"].tap()

        let nextButton = app.buttons["manualEntryNextButton"]
        XCTAssertTrue(nextButton.waitUntilEnabled(timeout: 3))
        nextButton.tap()

        XCTAssertTrue(app.buttons["disciplineButton-road"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["FH5"].waitForExistence(timeout: 5))
        app.navigationBars["Pick Tune Type"].buttons["Back"].tap()

        XCTAssertTrue(fh5Button.waitForExistence(timeout: 5))
        XCTAssertEqual(fh5Button.value as? String, "Selected")
    }

    @MainActor
    func testCatalogTuneCanBeSavedAndReopened() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))

        let garageHome = app.descendants(matching: .any)["garageHome"].firstMatch
        XCTAssertTrue(garageHome.waitForExistence(timeout: 15))
        garageHome.descendants(matching: .button)["newTuneButton"].tap()

        let catalogButton = app.buttons["catalogEntryButton"]
        XCTAssertTrue(catalogButton.waitForExistence(timeout: 5))
        catalogButton.tap()

        XCTAssertTrue(app.descendants(matching: .any)["catalogPicker"].firstMatch.waitForExistence(timeout: 5))
        let searchField = app.textFields["catalogSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.enterText("Supra")

        let supraRow = app.buttons["catalogCarRow-fh6-2020-toyota-gr-supra"]
        XCTAssertTrue(supraRow.waitForExistence(timeout: 5))
        supraRow.tap()

        XCTAssertTrue(app.descendants(matching: .any)["catalogVerificationBadge"].firstMatch.waitForExistence(timeout: 5))
        let editValuesButton = app.buttons["catalogEditValuesButton"]
        XCTAssertTrue(app.waitForVisibleElement(editValuesButton, timeout: 8))
        editValuesButton.tap()
        XCTAssertTrue(app.navigationBars["Manual Entry"].waitForExistence(timeout: 5))
        app.navigationBars["Manual Entry"].buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Review Car"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["catalogVerificationBadge"].firstMatch.waitForExistence(timeout: 5))

        let provenance = app.descendants(matching: .any)["catalogProvenance"].firstMatch
        XCTAssertTrue(app.waitForVisibleElement(provenance, timeout: 8))
        let useCarButton = app.buttons["catalogUseCarButton"]
        XCTAssertTrue(app.waitForVisibleElement(useCarButton, timeout: 8))
        useCarButton.tap()

        let roadButton = app.buttons["disciplineButton-road"]
        XCTAssertTrue(roadButton.waitForExistence(timeout: 5))
        roadButton.tap()

        let tuneIdentity = app.descendants(matching: .any)["tuneCatalogIdentity"].firstMatch
        XCTAssertTrue(app.waitForVisibleElement(tuneIdentity, timeout: 10))

        let verifyUpgradesButton = app.buttons["verifyUpgradePartsButton"]
        XCTAssertTrue(app.waitForVisibleElement(verifyUpgradesButton, timeout: 8))
        verifyUpgradesButton.tap()
        XCTAssertTrue(app.navigationBars["Verify Upgrades"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["upgradeCaptureBuildVersion"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.descendants(matching: .any)["upgradeCaptureStatus-sportTransmission"]
                .firstMatch.waitForExistence(timeout: 5)
        )
        let submitUpgradeButton = app.buttons["submitUpgradeCaptureButton"]
        XCTAssertTrue(app.waitForVisibleElement(submitUpgradeButton, timeout: 8))
        submitUpgradeButton.tap()
        XCTAssertTrue(app.staticTexts["Check This Observation"].waitForExistence(timeout: 5))
        app.navigationBars["Verify Upgrades"].buttons["Back"].tap()
        XCTAssertTrue(app.navigationBars["Tune"].waitForExistence(timeout: 5))

        let verifyTiresButton = app.buttons["verifyTirePressuresButton"]
        XCTAssertTrue(app.waitForVisibleElement(verifyTiresButton, timeout: 8))
        verifyTiresButton.tap()
        XCTAssertTrue(app.navigationBars["Verify Tires"].waitForExistence(timeout: 5))

        let submitCaptureButton = app.buttons["submitTireCaptureButton"]
        XCTAssertTrue(app.waitForVisibleElement(submitCaptureButton, timeout: 8))
        submitCaptureButton.tap()
        XCTAssertTrue(app.staticTexts["Check These Values"].waitForExistence(timeout: 5))
        app.navigationBars["Verify Tires"].buttons["Back"].tap()
        XCTAssertTrue(app.navigationBars["Tune"].waitForExistence(timeout: 5))

        app.buttons["saveTuneButton"].tap()
        app.buttons["doneTuneButton"].tap()

        let savedTuneRow = app.buttons["savedTuneRow"].firstMatch
        XCTAssertTrue(savedTuneRow.waitForExistence(timeout: 5))
        savedTuneRow.tap()
        XCTAssertTrue(app.waitForVisibleElement(tuneIdentity, timeout: 10))
    }

    @MainActor
    func testUpgradeLabCompletesCopiesPersistsAndKeepsTireLabEligible() throws {
        let app = XCUIApplication()
        launchCatalogSupraTune(in: app)
        let buildVersion = "ui-upgrade-first-1"

        let verifyUpgrades = app.buttons["verifyUpgradePartsButton"]
        XCTAssertTrue(app.scrollToHittable(verifyUpgrades, timeout: 10))
        verifyUpgrades.tap()
        XCTAssertTrue(app.navigationBars["Verify Upgrades"].waitForExistence(timeout: 5))

        completeUpgradeCapture(in: app, buildVersion: buildVersion)
        XCTAssertTrue(app.navigationBars["Tune"].waitForExistence(timeout: 15))
        assertThreeUpgradePaths(in: app)

        let copyBuildPlan = app.buttons["copyBuildPlanButton"]
        XCTAssertTrue(app.scrollToHittable(copyBuildPlan, timeout: 8))
        copyBuildPlan.tap()
        let copiedPredicate = NSPredicate(format: "label == %@", "Copied build plan")
        let copiedExpectation = XCTNSPredicateExpectation(predicate: copiedPredicate, object: copyBuildPlan)
        XCTAssertEqual(XCTWaiter.wait(for: [copiedExpectation], timeout: 5), .completed)

        let verifyTires = app.buttons["verifyTirePressuresButton"]
        XCTAssertTrue(app.scrollToHittable(verifyTires, timeout: 10))
        verifyTires.tap()
        XCTAssertTrue(app.navigationBars["Verify Tires"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["tireCaptureBuildVersion"].value as? String, buildVersion)
        app.navigationBars["Verify Tires"].buttons["Back"].tap()
        XCTAssertTrue(app.navigationBars["Tune"].waitForExistence(timeout: 5))

        app.buttons["saveTuneButton"].tap()
        app.buttons["doneTuneButton"].tap()
        let savedTuneRow = app.buttons["savedTuneRow"].firstMatch
        XCTAssertTrue(savedTuneRow.waitForExistence(timeout: 5))
        savedTuneRow.tap()
        XCTAssertTrue(app.navigationBars["Tune"].waitForExistence(timeout: 5))
        assertThreeUpgradePaths(in: app)
    }

    @MainActor
    func testTireLabThenUpgradeLabPreservesVerifiedTireRows() throws {
        let app = XCUIApplication()
        launchCatalogSupraTune(in: app)
        let buildVersion = "ui-tire-first-1"

        let verifyTires = app.buttons["verifyTirePressuresButton"]
        XCTAssertTrue(app.scrollToHittable(verifyTires, timeout: 10))
        verifyTires.tap()
        XCTAssertTrue(app.navigationBars["Verify Tires"].waitForExistence(timeout: 5))
        completeTireCapture(in: app, buildVersion: buildVersion)
        XCTAssertTrue(app.navigationBars["Tune"].waitForExistence(timeout: 15))
        assertVerifiedTireRows(in: app)

        let verifyUpgrades = app.buttons["verifyUpgradePartsButton"]
        XCTAssertTrue(app.scrollToHittable(verifyUpgrades, timeout: 10))
        verifyUpgrades.tap()
        XCTAssertTrue(app.navigationBars["Verify Upgrades"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["upgradeCaptureBuildVersion"].value as? String, buildVersion)
        completeUpgradeCapture(in: app, buildVersion: buildVersion, entersBuildVersion: false)

        XCTAssertTrue(app.navigationBars["Tune"].waitForExistence(timeout: 15))
        assertVerifiedTireRows(in: app)
        assertThreeUpgradePaths(in: app)
    }

    @MainActor
    private func launchCatalogSupraTune(in app: XCUIApplication) {
        app.launchArguments = ["-ui-testing"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))

        let garageHome = app.descendants(matching: .any)["garageHome"].firstMatch
        XCTAssertTrue(garageHome.waitForExistence(timeout: 15))
        garageHome.descendants(matching: .button)["newTuneButton"].tap()
        app.buttons["catalogEntryButton"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["catalogPicker"].firstMatch.waitForExistence(timeout: 5))

        let searchField = app.textFields["catalogSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.enterText("Supra")
        let supraRow = app.buttons["catalogCarRow-fh6-2020-toyota-gr-supra"]
        XCTAssertTrue(supraRow.waitForExistence(timeout: 5))
        supraRow.tap()

        let useCar = app.buttons["catalogUseCarButton"]
        XCTAssertTrue(app.scrollToHittable(useCar, timeout: 8))
        useCar.tap()
        let road = app.buttons["disciplineButton-road"]
        XCTAssertTrue(road.waitForExistence(timeout: 5))
        road.tap()
        XCTAssertTrue(app.navigationBars["Tune"].waitForExistence(timeout: 15))
    }

    @MainActor
    private func completeUpgradeCapture(
        in app: XCUIApplication,
        buildVersion: String,
        entersBuildVersion: Bool = true
    ) {
        if entersBuildVersion {
            let buildField = app.textFields["upgradeCaptureBuildVersion"]
            XCTAssertTrue(buildField.waitForExistence(timeout: 5))
            buildField.enterText(buildVersion)
            app.dismissTextKeyboardIfPresent()
        }

        for partID in Self.tunePartIDs {
            let control = app.segmentedControls["upgradeCaptureStatus-\(partID)"]
            XCTAssertTrue(app.waitForVisibleElement(control, timeout: 8), "Missing status control for \(partID)")
            let offered = control.buttons["Offered"]
            XCTAssertTrue(offered.exists, "Offered segment was missing for \(partID)")
            offered.tap()
        }

        setToggle("upgradeCaptureStockConfirmation", in: app)
        setToggle("upgradeCaptureLocalPermission", in: app)
        let submit = app.buttons["submitUpgradeCaptureButton"]
        XCTAssertTrue(app.scrollToHittable(submit, timeout: 8))
        submit.tap()
    }

    @MainActor
    private func completeTireCapture(in app: XCUIApplication, buildVersion: String) {
        let values = [
            ("tireCaptureBuildVersion", buildVersion),
            ("tireCaptureCompound", "Stock"),
            ("frontTireMinimum", "15"),
            ("frontTireMaximum", "40"),
            ("frontTireStep", "0.5"),
            ("frontTireCurrent", "30"),
            ("rearTireMinimum", "15"),
            ("rearTireMaximum", "40"),
            ("rearTireStep", "0.5"),
            ("rearTireCurrent", "30")
        ]
        for (identifier, value) in values {
            let field = app.textFields[identifier]
            XCTAssertTrue(app.waitForVisibleElement(field, timeout: 8), "Missing field \(identifier)")
            field.enterText(value)
        }

        setToggle("tireCaptureStockConfirmation", in: app)
        setToggle("tireCaptureLocalPermission", in: app)
        let submit = app.buttons["submitTireCaptureButton"]
        XCTAssertTrue(app.scrollToHittable(submit, timeout: 8))
        submit.tap()
    }

    @MainActor
    private func setToggle(_ identifier: String, in app: XCUIApplication) {
        let toggle = app.switches[identifier]
        XCTAssertTrue(app.scrollToHittable(toggle, timeout: 8), "Missing toggle \(identifier)")
        if toggle.value as? String != "1" {
            toggle.tap()
        }
        XCTAssertEqual(toggle.value as? String, "1")
    }

    @MainActor
    private func assertThreeUpgradePaths(in app: XCUIApplication) {
        let paths = app.descendants(matching: .any)["tuningControlUpgradePaths"].firstMatch
        XCTAssertTrue(app.scrollToHittable(paths, timeout: 10))
        for index in 1...3 {
            let path = app.descendants(matching: .any)["tuningControlUpgradePath-\(index)"].firstMatch
            XCTAssertTrue(path.waitForExistence(timeout: 3), "Missing upgrade path \(index)")
        }
    }

    @MainActor
    private func assertVerifiedTireRows(in app: XCUIApplication) {
        let front = app.descendants(matching: .any)["tuneField-frontTirePressure"].firstMatch
        let rear = app.descendants(matching: .any)["tuneField-rearTirePressure"].firstMatch
        XCTAssertTrue(app.scrollToHittable(front, timeout: 10))
        XCTAssertTrue(rear.waitForExistence(timeout: 3))
        XCTAssertFalse((front.value as? String ?? "").isEmpty)
        XCTAssertFalse((rear.value as? String ?? "").isEmpty)
    }

    private static let tunePartIDs = [
        "sportTransmission", "raceTransmission", "driftTransmission",
        "raceSuspension", "rallySuspension", "offroadSuspension", "driftSuspension",
        "raceFrontAntirollBar", "raceRearAntirollBar", "raceFrontBumper", "raceRearWing",
        "raceBrakes", "sportDifferential", "raceDifferential", "rallyDifferential",
        "offroadDifferential", "driftDifferential"
    ]
}

private extension XCUIElement {
    func enterText(_ text: String, focusTimeout: TimeInterval = 2) {
        tap()

        if !waitForKeyboardFocus(timeout: 0.4) {
            coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.2)).tap()
        }

        guard waitForKeyboardFocus(timeout: focusTimeout) else {
            XCTFail("\(identifier) did not receive keyboard focus before typing.")
            return
        }

        typeText(text)
    }

    private func waitForKeyboardFocus(timeout: TimeInterval) -> Bool {
        let focusPredicate = NSPredicate(format: "hasKeyboardFocus == true")
        let focusExpectation = XCTNSPredicateExpectation(predicate: focusPredicate, object: self)
        return XCTWaiter.wait(for: [focusExpectation], timeout: timeout) == .completed
    }

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

    func scrollToHittable(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.waitForExistence(timeout: 0.5), element.isHittable {
                return true
            }
            swipeUp()
        }
        return element.exists && element.isHittable
    }

    func dismissTextKeyboardIfPresent() {
        let returnButton = keyboards.buttons["return"]
        if returnButton.waitForExistence(timeout: 1) {
            returnButton.tap()
        }
    }
}
