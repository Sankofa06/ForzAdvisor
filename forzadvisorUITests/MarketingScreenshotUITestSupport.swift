import XCTest

extension MarketingScreenshotUITests {
    @MainActor
    func marketingLaunch(appearance: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-marketing-screenshots-seed"]
        if appearance == "dark" {
            app.launchArguments.append("-ui-test-dark-appearance")
        } else {
            // Explicitly override the simulator's ambient appearance.
            app.launchArguments += ["-AppleInterfaceStyle", "Light"]
        }
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))
        return app
    }

    @MainActor
    func assertSeededGarage(in app: XCUIApplication) {
        XCTAssertTrue(app.descendants(matching: .any)["garageHome"]
            .firstMatch.waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["savedTuneRow"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Create your first tune"].exists)
    }

    @MainActor
    func marketingReveal(_ element: XCUIElement, in app: XCUIApplication) {
        let list = app.collectionViews.firstMatch
        for _ in 0..<16 where !element.exists || !element.isHittable {
            list.swipeUp(velocity: .slow)
        }
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        element.scrollToInteractionViewport(in: app)
        XCTAssertTrue(element.isHittable)
    }

    @MainActor
    func marketingTap(_ element: XCUIElement, in app: XCUIApplication) {
        marketingReveal(element, in: app)
        XCTAssertTrue(element.isEnabled)
        element.tap()
    }

    @MainActor
    func marketingCapture(
        _ screen: String, appearance: String, in app: XCUIApplication
    ) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "marketing-\(screen)-\(appearance)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
