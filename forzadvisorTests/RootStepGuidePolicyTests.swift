import XCTest
@testable import forzadvisor

final class RootStepGuidePolicyTests: XCTestCase {
    func testFirstSaveHandoffSuppressesCompactToolbarEntry() {
        let policy = RootStepGuideEntryPolicy()
        let step = WorkflowStep.newTune

        XCTAssertEqual(policy.presentation(for: step), .compactToolbar)
        XCTAssertEqual(
            policy.presentation(
                for: step,
                firstSaveHandoffPresented: true
            ),
            .firstSaveHandoff
        )
    }
}
