import XCTest

extension XCUIElement {
    @MainActor
    func scrollToInteractionViewport(
        in app: XCUIApplication,
        timeout: TimeInterval = 5
    ) {
        XCTAssertTrue(waitForExistence(timeout: timeout))
        let scrollView = app.collectionViews.firstMatch

        for _ in 0..<12 where !isHittable {
            scrollView.swipeUp(velocity: .slow)
        }

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
            let midpoint = frame.midY
            if midpoint > lowerBound {
                upwardStart.press(forDuration: 0.05, thenDragTo: upwardEnd)
            } else if midpoint < upperBound {
                downwardStart.press(forDuration: 0.05, thenDragTo: downwardEnd)
            } else {
                break
            }
        }

        XCTAssertTrue(waitUntilInteractionReady(timeout: timeout))
    }

    func enterText(_ text: String, focusTimeout: TimeInterval = 2) {
        tap()

        if !waitForKeyboardFocus(timeout: 0.4) {
            for offset in [
                CGVector(dx: 0.8, dy: 0.5),
                CGVector(dx: 0.95, dy: 0.5),
                CGVector(dx: 0.8, dy: 0.75),
                CGVector(dx: 0.95, dy: 0.75),
                CGVector(dx: 0.5, dy: 0.5)
            ] {
                coordinate(withNormalizedOffset: offset).tap()
                if waitForKeyboardFocus(timeout: 0.6) { break }
            }
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

    private func waitUntilInteractionReady(timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == true AND isHittable == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
}
