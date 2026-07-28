//
//  StockCatalogContributionPrefillTests.swift
//  forzadvisorTests
//
//  Pure contracts for roster-to-contribution identity handoff.
//

import XCTest
@testable import forzadvisor

final class StockCatalogContributionPrefillTests:
    XCTestCase {
    func testGameOnlyDraftStartsWithoutEvidenceSelections() {
        let draft = StockCatalogContributionDraft(game: .fh5)

        XCTAssertEqual(draft.game, .fh5)
        XCTAssertEqual(draft.provenance, .gameOnly)
        XCTAssertFalse(draft.isGameSelectionLocked)
        XCTAssertEqual(draft.gameVersion, "")
        XCTAssertNil(draft.platform)
        XCTAssertEqual(draft.year, "")
        XCTAssertEqual(draft.make, "")
        XCTAssertEqual(draft.model, "")
        XCTAssertEqual(draft.performanceIndex, "")
        XCTAssertNil(draft.performanceClass)
        XCTAssertNil(draft.drivetrain)
        XCTAssertEqual(draft.weightPounds, "")
        XCTAssertEqual(draft.frontWeightPercent, "")
        XCTAssertEqual(draft.peakHorsepower, "")
        XCTAssertEqual(draft.peakTorque, "")
        XCTAssertTrue(draft.observationScreens.isEmpty)
        XCTAssertEqual(
            draft.captureConfirmations,
            StockCatalogCaptureConfirmationState()
        )
    }

    func testFH5RosterDraftCopiesOnlySourceFaithfulIdentity()
        throws {
        let entry = try XCTUnwrap(
            try BundledFH5OfficialRoster.load().get()
                .entries.first {
                    $0.id == "fh5-1986-citroen-bx4tc"
                }
        )
        let draft = StockCatalogContributionDraft(
            officialRosterIdentity: entry.identity
        )

        XCTAssertEqual(draft.game, .fh5)
        XCTAssertEqual(
            draft.provenance,
            .officialRosterIdentity(
                id: entry.id,
                game: .fh5
            )
        )
        XCTAssertTrue(draft.isGameSelectionLocked)
        XCTAssertEqual(draft.year, "1986")
        XCTAssertEqual(draft.make, "")
        XCTAssertEqual(draft.model, "Citroën BX4TC")
        assertNoTransferredEvidence(draft)
    }

    func testFH6RosterDraftDoesNotTransferOfficialPIOrClass()
        throws {
        let entry = try XCTUnwrap(
            try BundledFH6OfficialRoster.load().get()
                .entries.first {
                    $0.id == "fh6-1968-abarth-595-esseesse"
                }
        )
        XCTAssertEqual(entry.performanceIndex, 100)
        XCTAssertEqual(entry.performanceClass, .d)

        let draft = StockCatalogContributionDraft(
            officialRosterIdentity: entry.identity
        )

        XCTAssertEqual(draft.game, .fh6)
        XCTAssertTrue(draft.isGameSelectionLocked)
        XCTAssertEqual(draft.year, "1968")
        XCTAssertEqual(draft.make, "Abarth")
        XCTAssertEqual(draft.model, "595 esseesse")
        assertNoTransferredEvidence(draft)
    }

    func testChangingGameClearsOnlyAnIncompatibleClass() {
        var incompatible =
            StockCatalogContributionDraft(game: .fh6)
        incompatible.performanceClass = .r
        incompatible.game = .fh5
        XCTAssertNil(incompatible.performanceClass)

        var compatible =
            StockCatalogContributionDraft(game: .fh6)
        compatible.performanceClass = .a
        compatible.game = .fh5
        XCTAssertEqual(compatible.performanceClass, .a)
    }

    func testRosterSeedCannotChangeItsSourceGame() throws {
        let identity = try XCTUnwrap(
            try BundledFH6OfficialRoster.load().get()
                .entries.first?.identity
        )
        var draft = StockCatalogContributionDraft(
            officialRosterIdentity: identity
        )

        draft.game = .fh5

        XCTAssertEqual(draft.game, .fh6)
        XCTAssertEqual(
            draft.provenance,
            .officialRosterIdentity(
                id: identity.id,
                game: .fh6
            )
        )
    }

    func testManualEntryContributionRouteIsExplicitAndSourceBound()
        throws {
        let identity = try XCTUnwrap(
            try BundledFH6OfficialRoster.load().get()
                .entries.first?.identity
        )
        let context = ManualEntryStockContributionContext(
            sourceIdentity: identity
        )
        let rosterView = ManualEntryView(
            draft: ManualEntryDraft(
                officialRosterIdentity: identity
            ),
            stockContributionContext: context,
            onCancel: {},
            onContinue: { _ in }
        )
        let ordinaryView = ManualEntryView(
            draft: .empty,
            onCancel: {},
            onContinue: { _ in }
        )

        XCTAssertEqual(
            rosterView.stockContributionContext,
            context
        )
        XCTAssertNil(ordinaryView.stockContributionContext)
        XCTAssertEqual(
            context.contributionDraft,
            StockCatalogContributionDraft(
                officialRosterIdentity: identity
            )
        )
    }

    func testCurationChoicesStartUnselected() {
        let choices = StockCatalogCurationChoiceState()

        XCTAssertNil(choices.proposedVerificationStatus)
        XCTAssertNil(choices.identityRightsBasis)
    }

    func testSharedVehicleYearPolicyAllowsWarthogOnly() {
        XCTAssertTrue(StockCatalogVehicleYearPolicy.allows(1886))
        XCTAssertTrue(StockCatalogVehicleYearPolicy.allows(2100))
        XCTAssertTrue(StockCatalogVehicleYearPolicy.allows(2554))
        XCTAssertFalse(StockCatalogVehicleYearPolicy.allows(1885))
        XCTAssertFalse(StockCatalogVehicleYearPolicy.allows(2101))
        XCTAssertFalse(StockCatalogVehicleYearPolicy.allows(2555))
    }

    private func assertNoTransferredEvidence(
        _ draft: StockCatalogContributionDraft,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(draft.gameVersion, "", file: file, line: line)
        XCTAssertNil(draft.platform, file: file, line: line)
        XCTAssertEqual(
            draft.performanceIndex,
            "",
            file: file,
            line: line
        )
        XCTAssertNil(
            draft.performanceClass,
            file: file,
            line: line
        )
        XCTAssertNil(draft.drivetrain, file: file, line: line)
        XCTAssertEqual(
            draft.weightPounds,
            "",
            file: file,
            line: line
        )
        XCTAssertEqual(
            draft.frontWeightPercent,
            "",
            file: file,
            line: line
        )
        XCTAssertEqual(
            draft.peakHorsepower,
            "",
            file: file,
            line: line
        )
        XCTAssertEqual(draft.peakTorque, "", file: file, line: line)
        XCTAssertTrue(
            draft.observationScreens.isEmpty,
            file: file,
            line: line
        )
        XCTAssertEqual(
            draft.captureConfirmations,
            StockCatalogCaptureConfirmationState(),
            file: file,
            line: line
        )
    }
}
