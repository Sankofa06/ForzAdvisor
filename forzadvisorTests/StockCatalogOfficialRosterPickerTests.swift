//
//  StockCatalogOfficialRosterPickerTests.swift
//  forzadvisorTests
//
//  Pure safety contracts for official identity selection.
//

import XCTest
@testable import forzadvisor

final class StockCatalogOfficialRosterPickerTests: XCTestCase {
    private struct DraftMutation {
        let name: String
        let apply: (inout StockCatalogContributionDraft) -> Void
    }

    func testPristineMeansFreshGameOnlyDraftForCurrentGame() {
        var draft = StockCatalogContributionDraft(game: .fh5)
        XCTAssertTrue(draft.isPristineGameOnly)

        draft.game = .fh6

        XCTAssertTrue(draft.isPristineGameOnly)
        XCTAssertEqual(
            draft,
            StockCatalogContributionDraft(game: .fh6)
        )
    }

    func testEveryDraftValueBlocksApplyAndPreservesWholeDraft() throws {
        let identity = try fh6Identity()
        var mutations: [DraftMutation] = [
            .init(name: "gameVersion") { $0.gameVersion = "1.2.3" },
            .init(name: "platform") { $0.platform = .windowsPC },
            .init(name: "year") { $0.year = "2024" },
            .init(name: "make") { $0.make = "Tester Make" },
            .init(name: "model") { $0.model = "Tester Model" },
            .init(name: "performanceIndex") { $0.performanceIndex = "700" },
            .init(name: "performanceClass") { $0.performanceClass = .a },
            .init(name: "drivetrain") { $0.drivetrain = .awd },
            .init(name: "weightPounds") { $0.weightPounds = "3000" },
            .init(name: "frontWeightPercent") {
                $0.frontWeightPercent = "52.5"
            },
            .init(name: "peakHorsepower") { $0.peakHorsepower = "400" },
            .init(name: "peakTorque") { $0.peakTorque = "350" },
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
            mutations.append(
                DraftMutation(name: "observationScreens.\(field.rawValue)") {
                    $0.observationScreens[field] = .garage
                }
            )
        }

        for mutation in mutations {
            var draft = StockCatalogContributionDraft(game: .fh5)
            mutation.apply(&draft)
            let exactBeforeApply = draft

            XCTAssertFalse(
                draft.applyOfficialRosterIdentityIfPristine(identity),
                mutation.name
            )
            XCTAssertEqual(draft, exactBeforeApply, mutation.name)
        }
    }

    func testOfficialRosterProvenanceIsNotPristineAndCannotBeReplaced() throws {
        let firstIdentity = try fh5Identity()
        let replacement = try fh6Identity()
        var draft = StockCatalogContributionDraft(
            officialRosterIdentity: firstIdentity
        )
        let exactBeforeApply = draft

        XCTAssertFalse(draft.isPristineGameOnly)
        XCTAssertFalse(
            draft.applyOfficialRosterIdentityIfPristine(replacement)
        )
        XCTAssertEqual(draft, exactBeforeApply)
    }

    func testPristineApplyCanCrossGamesAndWhollyReplacesDraft() throws {
        let fh5 = try fh5Identity()
        let fh6 = try fh6Identity()
        var fh5Draft = StockCatalogContributionDraft(game: .fh5)
        var fh6Draft = StockCatalogContributionDraft(game: .fh6)

        XCTAssertTrue(
            fh5Draft.applyOfficialRosterIdentityIfPristine(fh6)
        )
        XCTAssertTrue(
            fh6Draft.applyOfficialRosterIdentityIfPristine(fh5)
        )
        XCTAssertEqual(
            fh5Draft,
            StockCatalogContributionDraft(
                officialRosterIdentity: fh6
            )
        )
        XCTAssertEqual(
            fh6Draft,
            StockCatalogContributionDraft(
                officialRosterIdentity: fh5
            )
        )
        XCTAssertEqual(fh6Draft.make, "")
        XCTAssertNil(fh5Draft.performanceClass)
        XCTAssertEqual(fh5Draft.performanceIndex, "")
    }

    func testPickerContainsEveryValidatedRosterIdentityAndSearchesNormalizedDesignation()
        throws {
        let snapshot = try pickerSnapshot()

        XCTAssertEqual(
            snapshot.entries(for: .fh5, matching: "").count,
            902
        )
        XCTAssertEqual(
            snapshot.entries(for: .fh6, matching: "").count,
            627
        )
        XCTAssertEqual(
            snapshot.entries(
                for: .fh5,
                matching: "  1986 CITROEN   bx4tc "
            ).map(\.id),
            ["fh5-1986-citroen-bx4tc"]
        )
        XCTAssertTrue(
            snapshot.entries(
                for: .fh5,
                matching: "no official designation matches this"
            ).isEmpty
        )
        XCTAssertEqual(
            snapshot.entries(
                for: .fh5,
                matching: "Citroën BX4TC"
            ).map(\.id),
            ["fh5-1986-citroen-bx4tc"]
        )
        let fh6Designation = try XCTUnwrap(snapshot.fh6.entries.first)
            .displayName
        XCTAssertEqual(
            snapshot.entries(
                for: .fh6,
                matching: fh6Designation.uppercased()
            ).map(\.id),
            [snapshot.fh6.entries[0].id]
        )
    }

    func testEveryReviewedCatalogIDStillAppliesAsIdentityOnly() throws {
        let catalog = try BundledCarCatalog.load().get()
        let picker = try pickerSnapshot()
        XCTAssertEqual(catalog.entries.count, 11)

        for reviewed in catalog.entries {
            let entry = try XCTUnwrap(
                picker.roster(for: reviewed.game).entries.first {
                    $0.id == reviewed.id
                },
                reviewed.id
            )
            var draft = StockCatalogContributionDraft(
                game: reviewed.game == .fh5 ? .fh6 : .fh5
            )

            XCTAssertTrue(
                draft.applyOfficialRosterIdentityIfPristine(
                    entry.identity
                ),
                reviewed.id
            )
            XCTAssertEqual(
                draft,
                StockCatalogContributionDraft(
                    officialRosterIdentity: entry.identity
                ),
                reviewed.id
            )
            assertNoStockOrEvidence(draft, message: reviewed.id)
        }
    }

    func testFH5FailureDoesNotDisableFH6OrUseReviewedFallback() throws {
        let snapshot = StockCatalogOfficialRosterPickerSnapshot(
            fh5Result: .failure(.missingResource("missing")),
            fh6Result: BundledFH6OfficialRoster.load()
        )

        XCTAssertFalse(snapshot.fh5.isAvailable)
        XCTAssertNotNil(snapshot.fh5.localizedIssue)
        XCTAssertTrue(snapshot.fh5.entries.isEmpty)
        XCTAssertTrue(
            snapshot.entries(for: .fh5, matching: "").isEmpty
        )
        XCTAssertTrue(snapshot.fh6.isAvailable)
        XCTAssertEqual(snapshot.fh6.entries.count, 627)
    }

    func testFH6FailureDoesNotDisableFH5OrUseReviewedFallback() throws {
        let snapshot = StockCatalogOfficialRosterPickerSnapshot(
            fh5Result: BundledFH5OfficialRoster.load(),
            fh6Result: .failure(.missingResource("missing"))
        )

        XCTAssertTrue(snapshot.fh5.isAvailable)
        XCTAssertEqual(snapshot.fh5.entries.count, 902)
        XCTAssertFalse(snapshot.fh6.isAvailable)
        XCTAssertNotNil(snapshot.fh6.localizedIssue)
        XCTAssertTrue(snapshot.fh6.entries.isEmpty)
    }

    func testBothFailuresLeaveNoFallbackIdentities() {
        let snapshot = StockCatalogOfficialRosterPickerSnapshot(
            fh5Result: .failure(.missingResource("missing-fh5")),
            fh6Result: .failure(.missingResource("missing-fh6"))
        )

        XCTAssertFalse(snapshot.fh5.isAvailable)
        XCTAssertFalse(snapshot.fh6.isAvailable)
        XCTAssertTrue(snapshot.fh5.entries.isEmpty)
        XCTAssertTrue(snapshot.fh6.entries.isEmpty)
        XCTAssertNotNil(snapshot.fh5.localizedIssue)
        XCTAssertNotNil(snapshot.fh6.localizedIssue)
    }

    func testStalePickerCallbackRejectsWithoutAnyMutation() throws {
        let identity = try fh6Identity()
        var draft = StockCatalogContributionDraft(game: .fh5)
        XCTAssertTrue(draft.isPristineGameOnly)

        draft.observationScreens[.identity] = .carCollection
        let exactAtCallback = draft

        XCTAssertFalse(
            draft.applyOfficialRosterIdentityIfPristine(identity)
        )
        XCTAssertEqual(draft, exactAtCallback)
    }

    private func pickerSnapshot() throws
        -> StockCatalogOfficialRosterPickerSnapshot {
        StockCatalogOfficialRosterPickerSnapshot(
            fh5Result: BundledFH5OfficialRoster.load(),
            fh6Result: BundledFH6OfficialRoster.load()
        )
    }

    private func fh5Identity() throws
        -> OfficialRosterCarIdentity {
        try XCTUnwrap(
            try BundledFH5OfficialRoster.load().get()
                .entries.first?.identity
        )
    }

    private func fh6Identity() throws
        -> OfficialRosterCarIdentity {
        try XCTUnwrap(
            try BundledFH6OfficialRoster.load().get()
                .entries.first?.identity
        )
    }

    private func assertNoStockOrEvidence(
        _ draft: StockCatalogContributionDraft,
        message: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(draft.gameVersion, "", message, file: file, line: line)
        XCTAssertNil(draft.platform, message, file: file, line: line)
        XCTAssertEqual(
            draft.performanceIndex,
            "",
            message,
            file: file,
            line: line
        )
        XCTAssertNil(
            draft.performanceClass,
            message,
            file: file,
            line: line
        )
        XCTAssertNil(draft.drivetrain, message, file: file, line: line)
        XCTAssertEqual(draft.weightPounds, "", message, file: file, line: line)
        XCTAssertEqual(
            draft.frontWeightPercent,
            "",
            message,
            file: file,
            line: line
        )
        XCTAssertEqual(
            draft.peakHorsepower,
            "",
            message,
            file: file,
            line: line
        )
        XCTAssertEqual(draft.peakTorque, "", message, file: file, line: line)
        XCTAssertTrue(
            draft.observationScreens.isEmpty,
            message,
            file: file,
            line: line
        )
        XCTAssertEqual(
            draft.captureConfirmations,
            StockCatalogCaptureConfirmationState(),
            message,
            file: file,
            line: line
        )
    }
}
