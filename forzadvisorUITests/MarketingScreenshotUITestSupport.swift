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
        if marketingIsVisible(element, in: app) { return }
        let list = app.collectionViews.firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        // A lazy row absent from the tree has no useful geometry. Search
        // from the top so a target above the current viewport is not lost.
        if !element.exists {
            for _ in 0..<8 {
                list.swipeDown(velocity: .fast)
                if element.exists { break }
            }
        }
        for _ in 0..<24 {
            if marketingIsVisible(element, in: app) { return }
            let above = element.exists && element.frame.height > 0
                && element.frame.midY < app.frame.midY
            let startY: CGFloat = above ? 0.35 : 0.70
            let endY: CGFloat = above ? 0.55 : 0.50
            list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: startY))
                .press(forDuration: 0.05, thenDragTo: list.coordinate(
                    withNormalizedOffset: CGVector(dx: 0.5, dy: endY)
                ))
        }
        XCTAssertTrue(marketingIsVisible(element, in: app),
                      "Expected visible marketing content: \(element)")
    }

    @MainActor
    func marketingIsVisible(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        guard element.exists, element.frame.width > 0, element.frame.height > 0 else {
            return false
        }
        let navigation = app.navigationBars.firstMatch
        let top = navigation.exists ? navigation.frame.maxY : app.frame.minY + 60
        let viewport = CGRect(x: app.frame.minX, y: top,
                              width: app.frame.width,
                              height: app.frame.maxY - top - 35)
        return viewport.contains(element.frame)
    }

    @MainActor
    func marketingTap(_ element: XCUIElement, in app: XCUIApplication) {
        // Toolbar buttons are outside the list viewport and must not scroll.
        if !element.isHittable { marketingReveal(element, in: app) }
        XCTAssertTrue(element.waitUntilHittable(timeout: 5))
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
