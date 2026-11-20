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
        let hittable = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND isHittable == true"),
            object: element
        )
        XCTAssertEqual(XCTWaiter.wait(for: [hittable], timeout: 5), .completed)
        XCTAssertTrue(element.isEnabled)
        element.tap()
    }

    @MainActor
    func marketingCapture(
        _ screen: String, appearance: String, in app: XCUIApplication
    ) {
        let toolbarScreens = ["02-source", "03-manual", "04-discipline", "05-saved-plan"]
        if toolbarScreens.contains(screen) {
            var buttons = [app.buttons["copilotButton"]]
            if screen == "05-saved-plan" {
                buttons.append(app.buttons["editSavedTuneButton"])
            }
            marketingWaitForToolbarRendering(buttons, in: app)
        }
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "marketing-\(screen)-\(appearance)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func marketingWaitForToolbarRendering(
        _ buttons: [XCUIElement], in app: XCUIApplication
    ) {
        var previousFrames: [CGRect] = []
        var stableSince: Date?
        let settled = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                let viewport = app.frame
                var frames: [CGRect] = []
                for button in buttons {
                    guard button.exists && button.isHittable else {
                        stableSince = nil
                        previousFrames = []
                        return false
                    }
                    // Each frame lookup requests a remote accessibility snapshot.
                    let frame = button.frame
                    guard frame.width > 0 && frame.height > 0
                        && viewport.contains(frame) else {
                        stableSince = nil
                        previousFrames = []
                        return false
                    }
                    frames.append(frame)
                }
                if frames != previousFrames {
                    previousFrames = frames
                    stableSince = Date()
                    return false
                }
                // UIKit can expose toolbar accessibility before its symbols
                // finish drawing. Require a full second of stable geometry
                // while XCTest pumps the run loop before requesting pixels.
                guard let stableSince else { return false }
                return Date().timeIntervalSince(stableSince) >= 1
            },
            object: nil
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [settled], timeout: 15), .completed,
            "Toolbar controls must exist, be hittable, remain inside the app, and settle before capture."
        )
    }

}
