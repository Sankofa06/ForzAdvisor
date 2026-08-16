import XCTest
@testable import forzadvisor

final class GarageRemovalStateTests: XCTestCase {
    func testStagingDoesNotBeginPersistence() {
        var state = GarageRemovalState()
        let id = UUID()
        XCTAssertNil(state.stage(id: id, carName: "Car A"))
        XCTAssertEqual(state.pending, GaragePendingRemoval(id: id, carName: "Car A"))
        XCTAssertTrue(state.committingTuneIDs.isEmpty)
        XCTAssertEqual(state.hiddenTuneIDs, [id])
    }

    func testUndoRestoresPendingTuneWithoutCommit() {
        var state = GarageRemovalState()
        let id = UUID()
        state.stage(id: id, carName: "Car A")
        XCTAssertEqual(state.undo()?.id, id)
        XCTAssertNil(state.pending)
        XCTAssertTrue(state.hiddenTuneIDs.isEmpty)
        XCTAssertNil(state.beginPendingCommit())
    }

    func testExpiryAdvancesExactlyOnePendingTuneToCommit() {
        var state = GarageRemovalState()
        let id = UUID()
        state.stage(id: id, carName: "Car A")
        XCTAssertEqual(state.beginPendingCommit(matching: id), id)
        XCTAssertNil(state.beginPendingCommit(matching: id))
        XCTAssertEqual(state.committingTuneIDs, [id])
    }

    func testNextRemovalCommitsPriorAndStagesReplacement() {
        var state = GarageRemovalState()
        let firstID = UUID()
        let secondID = UUID()
        state.stage(id: firstID, carName: "Car A")
        XCTAssertEqual(state.stage(id: secondID, carName: "Car B"), firstID)
        XCTAssertEqual(state.pending?.id, secondID)
        XCTAssertEqual(state.committingTuneIDs, [firstID])
        XCTAssertEqual(state.hiddenTuneIDs, [firstID, secondID])
    }

    func testRollbackRevealsOnlyMatchingTuneAndRetainsFailure() {
        var state = GarageRemovalState()
        let firstID = UUID()
        let secondID = UUID()
        state.stage(id: firstID, carName: "Car A")
        _ = state.stage(id: secondID, carName: "Car B")
        XCTAssertTrue(state.resolve(.rolledBack(savedTuneID: firstID, message: "Save failed")))
        XCTAssertEqual(state.failureMessage, "Save failed")
        XCTAssertEqual(state.hiddenTuneIDs, [secondID])
        XCTAssertFalse(state.resolve(.committed(savedTuneID: firstID)))
    }

    func testCommitResolutionUsesCallbackID() {
        var state = GarageRemovalState()
        let id = UUID()
        state.stage(id: id, carName: "Car A")
        _ = state.beginPendingCommit()
        XCTAssertTrue(state.resolve(.committed(savedTuneID: id)))
        XCTAssertTrue(state.hiddenTuneIDs.isEmpty)
        XCTAssertNil(state.failureMessage)
    }
}
