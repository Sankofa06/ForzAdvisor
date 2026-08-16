import XCTest
@testable import forzadvisor

@MainActor
final class TuneRefinementProposalStoreTests: XCTestCase {
    func testProviderCompletionStoresProposalWithoutPersistence() {
        let fixture = makeProposal()
        let store = TuneRefinementProposalStore()

        store.store(fixture)

        XCTAssertEqual(store.proposal, fixture)
        XCTAssertNil(store.applied)
    }

    func testApplyRejectsStaleBaselineAndLeavesProposal() {
        let fixture = makeProposal()
        let store = TuneRefinementProposalStore()
        store.store(fixture)
        var stale = fixture.baseline
        stale.generatedAt.addTimeInterval(1)

        XCTAssertThrowsError(try store.apply(
            currentPersistedTune: stale,
            persist: { _ in XCTFail("Must not persist a stale proposal") }
        )) { error in
            XCTAssertEqual(error as? TuneRefinementProposalError, .staleBaseline)
        }
        XCTAssertEqual(store.proposal, fixture)
    }

    func testApplyThenUndoBeforeSixSecondsPersistsExactValues() throws {
        let fixture = makeProposal()
        let store = TuneRefinementProposalStore()
        let start = Date(timeIntervalSince1970: 100)
        var persisted: [TuneResult] = []
        store.store(fixture)

        let applied = try store.apply(
            currentPersistedTune: fixture.baseline,
            now: start,
            persist: { persisted.append($0) }
        )
        XCTAssertEqual(applied.undoDeadline, start.addingTimeInterval(6))
        XCTAssertEqual(persisted, [fixture.candidate])

        let restored = try store.undo(
            currentPersistedTune: fixture.candidate,
            now: start.addingTimeInterval(5.999),
            persist: { persisted.append($0) }
        )
        XCTAssertEqual(restored, fixture.baseline)
        XCTAssertEqual(persisted, [fixture.candidate, fixture.baseline])
        XCTAssertNil(store.applied)
    }

    func testUndoAtDeadlineDoesNotPersist() throws {
        let fixture = makeProposal()
        let store = TuneRefinementProposalStore()
        let start = Date(timeIntervalSince1970: 100)
        store.store(fixture)
        _ = try store.apply(
            currentPersistedTune: fixture.baseline,
            now: start,
            persist: { _ in }
        )

        XCTAssertThrowsError(try store.undo(
            currentPersistedTune: fixture.candidate,
            now: start.addingTimeInterval(6),
            persist: { _ in XCTFail("Expired undo must not persist") }
        )) { error in
            XCTAssertEqual(error as? TuneRefinementProposalError, .undoExpired)
        }
    }

    func testApplySchedulesAutomaticExpirationAtSixSeconds() throws {
        let fixture = makeProposal()
        let start = Date(timeIntervalSince1970: 100)
        var scheduledDelay: TimeInterval?
        var scheduledAction: (@MainActor () -> Void)?
        let store = TuneRefinementProposalStore { delay, action in
            scheduledDelay = delay
            scheduledAction = action
        }
        store.store(fixture)

        _ = try store.apply(
            currentPersistedTune: fixture.baseline,
            now: start,
            persist: { _ in }
        )

        XCTAssertEqual(scheduledDelay, 6)
        XCTAssertTrue(store.canUndo(
            savedTuneID: fixture.savedTuneID,
            now: start.addingTimeInterval(5.999)
        ))
        XCTAssertFalse(store.canUndo(
            savedTuneID: fixture.savedTuneID,
            now: start.addingTimeInterval(6)
        ))
        XCTAssertNotNil(store.applied)

        scheduledAction?()

        XCTAssertNil(store.applied)
    }

    private func makeProposal() -> TuneRefinementProposal {
        let request = TuneRequest(
            car: SampleTuningData.starterCar,
            discipline: .road
        )
        let baseline = TuneResult(
            request: request,
            sections: [],
            notes: TuneNotes(
                bias: "Baseline",
                ifPushesWide: "",
                ifSnapsOnLift: "",
                retuneTrigger: ""
            )
        )
        var candidate = baseline
        candidate.notes.bias = "More rotation"
        return TuneRefinementProposal(
            savedTuneID: baseline.id,
            baseline: baseline,
            result: TuneAdjustmentResult(tune: candidate, changes: []),
            feedback: .pushesWide
        )
    }
}
