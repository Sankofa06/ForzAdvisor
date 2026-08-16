import XCTest

extension XCUIElement {
    func enterText(_ text: String, focusTimeout: TimeInterval = 2) {
        tap()

        if !waitForKeyboardFocus(timeout: 0.4) {
            for offset in [
                CGVector(dx: 0.8, dy: 0.5),
                CGVector(dx: 0.95, dy: 0.5),
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
}
