//
//  StockCatalogContributionContinuationTests.swift
//  forzadvisorTests
//
//  Pure and static contracts for the explicit post-save continuation.
//

import XCTest
@testable import forzadvisor

final class StockCatalogContributionContinuationTests: XCTestCase {
    private struct DraftMutation {
        let name: String
        let apply: (inout StockCatalogContributionDraft) -> Void
    }

    func testDefaultStateHasNoContinuationAuthority() {
        var state = StockCatalogContributionContinuationState()
        let draft = completePostSaveDraft()
        let snapshot = snapshot(recordID: persistedID)
        let exactState = state
        let exactSnapshot = snapshot
        XCTAssertFalse(state.hasToken)
        XCTAssertFalse(
            state.isEligible(
                currentDraft: draft,
                snapshot: snapshot
            )
        )
        XCTAssertNil(
            state.consumeIfEligible(
                currentDraft: draft,
                snapshot: snapshot
            )
        )
        XCTAssertEqual(state, exactState)
        XCTAssertEqual(snapshot, exactSnapshot)
    }

    func testSuccessfulConsumeIsOneShotSameGameAndPreservesSnapshotBytes() throws {
        let draft = completePostSaveDraft(game: .fh5)
        var state = successfulState(draft: draft)
        let snapshot = snapshot(recordID: persistedID, game: .fh5)
        let exactSnapshot = snapshot
        let exactCapturedBytes = try snapshot.captured.map {
            try StockCatalogContributionExporter().canonicalJSON(for: $0)
        }
        XCTAssertEqual(state.token?.persistedRecordID, persistedID)
        XCTAssertEqual(state.token?.exactPostSaveDraft, draft)
        XCTAssertTrue(
            state.isEligible(
                currentDraft: draft,
                snapshot: snapshot
            )
        )
        let next = try XCTUnwrap(
            state.consumeIfEligible(
                currentDraft: draft,
                snapshot: snapshot
            )
        )
        XCTAssertEqual(
            next,
            StockCatalogContributionDraft(game: .fh5)
        )
        XCTAssertFalse(state.hasToken)
        XCTAssertNil(
            state.consumeIfEligible(
                currentDraft: next,
                snapshot: snapshot
            )
        )
        XCTAssertEqual(snapshot, exactSnapshot)
        XCTAssertEqual(snapshot.captured.count, 1)
        XCTAssertEqual(
            try snapshot.captured.map {
                try StockCatalogContributionExporter()
                    .canonicalJSON(for: $0)
            },
            exactCapturedBytes
        )
    }

    func testOfficialRosterDraftConsumesToUnlockedEmptySameGameDraft() throws {
        let identity = try XCTUnwrap(
            try BundledFH5OfficialRoster.load().get()
                .entries.first?.identity
        )
        var draft = StockCatalogContributionDraft(
            officialRosterIdentity: identity
        )
        completeFields(in: &draft)
        var state = successfulState(draft: draft)
        let snapshot = snapshot(recordID: persistedID, game: .fh5)
        XCTAssertEqual(
            state.token?.exactPostSaveDraft.provenance,
            .officialRosterIdentity(id: identity.id, game: .fh5)
        )
        XCTAssertTrue(state.isEligible(
            currentDraft: draft,
            snapshot: snapshot
        ))
        let next = try XCTUnwrap(
            state.consumeIfEligible(
                currentDraft: draft,
                snapshot: snapshot
            )
        )
        XCTAssertEqual(next, StockCatalogContributionDraft(game: .fh5))
        XCTAssertFalse(next.isGameSelectionLocked)
        XCTAssertTrue(next.isPristineGameOnly)
    }

    func testEveryPostSaveDraftEditRejectsAndPreservesEverything() throws {
        let exactDraft = completePostSaveDraft()
        let snapshot = snapshot(recordID: persistedID)
        var mutations: [DraftMutation] = [
            .init(name: "game") { $0.game = .fh5 },
            .init(name: "gameVersion") { $0.gameVersion += "-edited" },
            .init(name: "platform") { $0.platform = .windowsPC },
            .init(name: "year") { $0.year = "2025" },
            .init(name: "make") { $0.make += " Edited" },
            .init(name: "model") { $0.model += " Edited" },
            .init(name: "performanceIndex") { $0.performanceIndex = "701" },
            .init(name: "performanceClass") { $0.performanceClass = .b },
            .init(name: "drivetrain") { $0.drivetrain = .rwd },
            .init(name: "weightPounds") { $0.weightPounds = "3201" },
            .init(name: "frontWeightPercent") {
                $0.frontWeightPercent = "53"
            },
            .init(name: "peakHorsepower") { $0.peakHorsepower = "501" },
            .init(name: "peakTorque") { $0.peakTorque = "451" },
            .init(name: "exactStockConfirmed") {
                $0.captureConfirmations.exactStockConfirmed = true
            },
            .init(name: "personallyReadConfirmed") {
                $0.captureConfirmations.personallyReadConfirmed = true
            },
            .init(name: "englishUnitsConfirmed") {
                $0.captureConfirmations.englishUnitsConfirmed = true
            },
            .init(name: "authorshipConfirmed") {
                $0.captureConfirmations.authorshipConfirmed = true
            },
            .init(name: "localStorageConfirmed") {
                $0.captureConfirmations.localStorageConfirmed = true
            },
            .init(name: "testerFactsRight") {
                $0.captureConfirmations.testerFactsRight = true
            },
            .init(name: "reuseRight") {
                $0.captureConfirmations.reuseRight = true
            },
            .init(name: "curationRight") {
                $0.captureConfirmations.curationRight = true
            },
            .init(name: "redistributionRight") {
                $0.captureConfirmations.redistributionRight = true
            }
        ]
        for field in CatalogDataField.allCases {
            mutations.append(.init(name: "screen.\(field.rawValue)") {
                $0.observationScreens[field] = .telemetry
            })
        }
        mutations.append(.init(name: "provenance") {
            $0 = StockCatalogContributionDraft(
                officialRosterIdentity: OfficialRosterCarIdentity(
                    id: "fh6-test-roster-identity",
                    game: .fh6,
                    year: 2024,
                    make: "Test",
                    model: "Stock Car",
                    officialDesignation: "2024 Test Stock Car",
                    performanceIndex: 700,
                    performanceClass: .a
                )
            )
        })
        for mutation in mutations {
            var changedDraft = exactDraft
            mutation.apply(&changedDraft)
            let exactChangedDraft = changedDraft
            var state = successfulState(draft: exactDraft)
            let exactState = state
            let exactSnapshot = snapshot

            XCTAssertFalse(
                state.isEligible(
                    currentDraft: changedDraft,
                    snapshot: snapshot
                ),
                mutation.name
            )
            XCTAssertNil(
                state.consumeIfEligible(
                    currentDraft: changedDraft,
                    snapshot: snapshot
                ),
                mutation.name
            )
            XCTAssertEqual(state, exactState, mutation.name)
            XCTAssertEqual(changedDraft, exactChangedDraft, mutation.name)
            XCTAssertEqual(snapshot, exactSnapshot, mutation.name)
        }
    }

    func testMissingOrWrongRecordRejectsWithoutConsumingToken() {
        let draft = completePostSaveDraft()
        let wrongSnapshot = snapshot(recordID: UUID())
        var state = successfulState(draft: draft)
        let exactState = state
        let exactSnapshot = wrongSnapshot
        XCTAssertFalse(
            state.isEligible(
                currentDraft: draft,
                snapshot: wrongSnapshot
            )
        )
        XCTAssertNil(
            state.consumeIfEligible(
                currentDraft: draft,
                snapshot: wrongSnapshot
            )
        )
        XCTAssertEqual(state, exactState)
        XCTAssertEqual(wrongSnapshot, exactSnapshot)

        let deleted = StockCatalogContributionStoreSnapshot.empty
        XCTAssertFalse(
            state.isEligible(
                currentDraft: draft,
                snapshot: deleted
            )
        )
        XCTAssertEqual(state, exactState)
    }

    func testStartingAnySaveAttemptClearsPreviousAuthority() {
        let draft = completePostSaveDraft()
        var state = successfulState(draft: draft)

        state.clearForSaveAttempt()

        XCTAssertFalse(state.hasToken)
        XCTAssertFalse(
            state.isEligible(
                currentDraft: draft,
                snapshot: snapshot(recordID: persistedID)
            )
        )
    }

    private var persistedID: UUID {
        UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
    }

    private func successfulState(draft: StockCatalogContributionDraft)
        -> StockCatalogContributionContinuationState {
        var state = StockCatalogContributionContinuationState()
        state.recordSuccessfulSave(
            recordID: persistedID,
            exactPostSaveDraft: draft
        )
        return state
    }

    private func completePostSaveDraft(game: ForzaGame = .fh6)
        -> StockCatalogContributionDraft {
        var draft = StockCatalogContributionDraft(game: game)
        completeFields(in: &draft)
        return draft
    }

    private func completeFields(in draft: inout StockCatalogContributionDraft) {
        draft.gameVersion = "1.0.100.0"
        draft.platform = .xboxSeries
        draft.year = "2024"
        draft.make = "Test"
        draft.model = "Stock Car"
        draft.performanceIndex = "710"
        draft.performanceClass = .a
        draft.drivetrain = .awd
        draft.weightPounds = "3200"
        draft.frontWeightPercent = "52"
        draft.peakHorsepower = "500"
        draft.peakTorque = "450"
        for field in CatalogDataField.allCases {
            draft.observationScreens[field] = .garage
        }
    }

    private func snapshot(recordID: UUID, game: ForzaGame = .fh6)
        -> StockCatalogContributionStoreSnapshot {
        .init(
            captured: [record(id: recordID, game: game)],
            reviewed: [],
            recoveredFromMalformedData: false
        )
    }

    private func record(id: UUID, game: ForzaGame)
        -> StockCatalogContributionRecord {
        let observed = Date(timeIntervalSince1970: 1_800_000_000)
        let fields = StockCatalogContributionValidator.expectedFields
        return StockCatalogContributionRecord(
            id: id,
            capturedAt: observed,
            game: game,
            gameVersion: "1.0.100.0",
            platform: .xboxSeries,
            vehicle: .init(
                year: 2024,
                make: "Test",
                model: "Stock Car",
                stock: .init(
                    performanceIndex: 710,
                    performanceClass: .a,
                    drivetrain: .awd,
                    weightPounds: 3_200,
                    frontWeightPercent: 52,
                    peakHorsepower: 500,
                    peakTorqueFootPounds: 450
                )
            ),
            reviewedFields: fields,
            fieldAttestations: fields.map {
                StockCatalogFieldAttestation(
                    field: $0,
                    observationScreen: .garage,
                    directlyReadInGame: true,
                    untouchedStockConfirmed: true,
                    englishUnitsConfirmedWhenRelevant: true,
                    observedAt: observed
                )
            },
            exactUntouchedStockConfirmed: true,
            personallyReadFromGameConfirmed: true,
            firstPartyAuthorshipConfirmed: true,
            localStoragePermissionConfirmed: true,
            rights: .init(
                testerAuthoredStructuredFacts: true,
                deidentifiedStructuredReuse: true,
                catalogCurationUse: true,
                futureBundledRedistribution: true
            )
        )
    }

}
