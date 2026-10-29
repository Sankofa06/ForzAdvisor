import XCTest

extension XCUIElement {
    @MainActor
    func scrollToInteractionViewport(
        in app: XCUIApplication,
        timeout: TimeInterval = 5
    ) {
        let scrollView = app.collectionViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: timeout))
        // Missing lazy rows have no meaningful frame. Return toward the top
        // before searching down, rather than assuming every target is below us.
        if !exists {
            for _ in 0..<8 {
                scrollView.swipeDown(velocity: .fast)
                if exists { break }
            }
        }
        for _ in 0..<24 {
            let viewport = interactionViewport(in: app)
            if exists && isHittable && viewport.contains(frame) { return }
            let above = exists && frame.height > 0 && frame.midY < viewport.midY
            // Start gestures in visible content, never on the keyboard. Form
            // scrolling dismisses it interactively; recompute bounds each time.
            let start = CGPoint(x: viewport.midX,
                                y: viewport.minY + viewport.height * (above ? 0.30 : 0.75))
            let end = CGPoint(x: start.x,
                              y: viewport.minY + viewport.height * (above ? 0.65 : 0.35))
            app.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: start.x - app.frame.minX, dy: start.y - app.frame.minY))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: .zero)
                    .withOffset(CGVector(dx: end.x - app.frame.minX, dy: end.y - app.frame.minY)))
        }
        XCTAssertTrue(waitUntilInteractionReady(timeout: timeout))
        XCTAssertTrue(interactionViewport(in: app).contains(frame),
                      "\(identifier) must be above the keyboard and below navigation before interaction.")
    }

    @MainActor
    private func interactionViewport(in app: XCUIApplication) -> CGRect {
        let navigation = app.navigationBars.firstMatch
        let top = navigation.exists ? navigation.frame.maxY + 8 : app.frame.minY + 60
        let keyboard = app.keyboards.firstMatch
        let bottom = keyboard.exists ? keyboard.frame.minY - 52 : app.frame.maxY - 40
        return CGRect(x: app.frame.minX + 8, y: top,
                      width: app.frame.width - 16, height: max(44, bottom - top))
    }

    @MainActor
    func enterText(_ text: String, focusTimeout: TimeInterval = 2) {
        // The target application is already running; this creates only its
        // XCTest proxy and gives legacy callers the same keyboard-aware reveal.
        enterText(text, in: XCUIApplication(), focusTimeout: focusTimeout)
    }

    @MainActor
    func enterText(
        _ text: String,
        in app: XCUIApplication,
        focusTimeout: TimeInterval = 2
    ) {
        for _ in 0..<3 {
            scrollToInteractionViewport(in: app)
            if focusForTyping(timeout: focusTimeout) {
                typeTextAndVerifyValue(text)
                return
            }
            // The keyboard can appear or change height during a focus attempt.
            // Recompute the reveal instead of dragging through stale geometry.
            // The next attempt recomputes the viewport before another tap.
        }

        XCTFail("\(identifier) did not receive keyboard focus before typing.")
    }

    private func typeTextAndVerifyValue(_ text: String) {
        let initialValue = value as? String ?? ""
        var expectedValue = initialValue == placeholderValue ? "" : initialValue

        // A whole-string burst can outrun SwiftUI form updates in Simulator.
        // Observe every character; never retry or silently repair a mismatch.
        for character in text {
            typeText(String(character))
            expectedValue.append(character)
            let expectation = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "value == %@", expectedValue),
                object: self
            )
            // Simulator snapshots may lag the actual SwiftUI value. Keep the
            // exact predicate and a bounded wait; never type the character twice.
            guard XCTWaiter.wait(for: [expectation], timeout: 10) == .completed else {
                XCTFail("\(identifier) expected \(expectedValue), received \(value ?? "nil").")
                return
            }
        }
    }

    private func focusForTyping(timeout: TimeInterval) -> Bool {
        if waitForKeyboardFocus(timeout: 0.1) { return true }

        for offset in [
            CGVector(dx: 0.5, dy: 0.5),
            CGVector(dx: 0.8, dy: 0.5),
            CGVector(dx: 0.95, dy: 0.5),
            CGVector(dx: 0.8, dy: 0.75),
            CGVector(dx: 0.95, dy: 0.75)
        ] {
            coordinate(withNormalizedOffset: offset).press(forDuration: 0.12)
            if waitForKeyboardFocus(timeout: timeout) { return true }
        }

        return false
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

    private func waitUntilInteractionReady(timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == true AND isHittable == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
}
