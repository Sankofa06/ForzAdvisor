import XCTest
@testable import forzadvisor

final class StaleBetaMissionRoutingContractTests: XCTestCase {
    func testDeletedTuneRefreshesMissionBoardAsStale() {
        XCTAssertEqual(
            BetaMissionOpenFailurePolicy().disposition(
                for: ContentWorkflowError.missingSavedTune
            ),
            .refreshAsStale
        )
    }

    func testCommunityOpenerFailuresRefreshMissionBoardAsStale() {
        let policy = BetaMissionOpenFailurePolicy()

        XCTAssertEqual(
            policy.disposition(
                for: ContentWorkflowError.staleCommunityReferenceTrial
            ),
            .refreshAsStale
        )
        XCTAssertEqual(
            policy.disposition(
                for: ContentWorkflowError.missingFirstPartyValidation
            ),
            .refreshAsStale
        )
    }

    func testUnexpectedFailureStillUsesGlobalAlert() {
        struct Unexpected: Error {}
        XCTAssertEqual(
            BetaMissionOpenFailurePolicy().disposition(for: Unexpected()),
            .showGlobalAlert
        )
    }
}
