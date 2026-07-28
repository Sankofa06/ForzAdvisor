//
//  FH6OfficialRosterTests.swift
//  forzadvisorTests
//
//  Contracts for official identity browsing without unreviewed stock claims.
//

import XCTest
@testable import forzadvisor

final class FH6OfficialRosterTests: XCTestCase {
    func testRealBundleLoadsExactReviewedOfficialRoster() throws {
        let roster = try loadedRoster()

        XCTAssertEqual(roster.schemaVersion, 1)
        XCTAssertEqual(
            roster.revision,
            BundledFH6OfficialRoster.expectedRevision
        )
        XCTAssertEqual(
            roster.sourceURL,
            BundledFH6OfficialRoster.expectedSourceURL
        )
        XCTAssertEqual(
            roster.sourceUpdatedAt,
            BundledFH6OfficialRoster.expectedSourceUpdatedAt
        )
        XCTAssertEqual(
            roster.sourceSHA256,
            BundledFH6OfficialRoster.expectedSourceSHA256
        )
        XCTAssertEqual(roster.entries.count, 627)
        XCTAssertEqual(
            Set(roster.entries.map(\.id)).count,
            627
        )
        XCTAssertTrue(
            roster.entries.allSatisfy {
                $0.officialDesignation
                    == "\($0.year) \($0.make) \($0.model)"
            }
        )
    }

    func testOverlayHasExactReviewedAndIdentityOnlyBoundary()
        throws {
        let catalog = try loadedCatalog()
        let roster = try loadedRoster()
        let overlay = try CarCatalogBrowseOverlay.make(
            catalog: catalog,
            fh5Roster: loadedFH5Roster(),
            fh6Roster: roster
        ).get()

        let fh6 = overlay.entries.filter { $0.game == .fh6 }
        let fh5 = overlay.entries.filter { $0.game == .fh5 }
        XCTAssertEqual(fh6.count, 627)
        XCTAssertEqual(fh5.count, 902)
        XCTAssertEqual(
            fh6.filter(\.isReviewedStock).count,
            8
        )
        XCTAssertEqual(
            fh6.filter { !$0.isReviewedStock }.count,
            619
        )
        XCTAssertEqual(Set(fh6.map(\.id)).count, 627)
        XCTAssertEqual(fh5.filter(\.isReviewedStock).count, 3)
        XCTAssertNil(
            overlay.rosterIssueDescription(for: .fh6)
        )

        let reviewedIDs = Set(
            catalog.entries
                .filter { $0.game == .fh6 }
                .map(\.id)
        )
        XCTAssertEqual(
            Set(
                fh6.filter(\.isReviewedStock).map(\.id)
            ),
            reviewedIDs
        )
    }

    func testSearchFindsArbitraryOfficialRosterCars()
        throws {
        let overlay = try overlay()

        XCTAssertEqual(
            CarCatalogBrowseOverlay.search(
                overlay,
                game: .fh6,
                query: "  MÉGANE r26.r "
            ).map(\.id),
            ["fh6-2008-renault-megane-r26-r"]
        )
        XCTAssertEqual(
            CarCatalogBrowseOverlay.search(
                overlay,
                game: .fh6,
                query: "M12S Warthog"
            ).map(\.id),
            [
                "fh6-2554-amg-transport-dynamics-m12s-warthog-cst"
            ]
        )
        XCTAssertTrue(
            CarCatalogBrowseOverlay.search(
                overlay,
                game: .fh6,
                query: "Warthog"
            ).allSatisfy { $0.game == .fh6 }
        )
    }

    func testAllEightReviewedIdentitiesMatchOfficialRosterExactly()
        throws {
        let catalog = try loadedCatalog()
        let rosterByID = Dictionary(
            uniqueKeysWithValues: try loadedRoster().entries.map {
                ($0.id, $0)
            }
        )

        for entry in catalog.entries where entry.game == .fh6 {
            let identity = try XCTUnwrap(rosterByID[entry.id])
            XCTAssertEqual(identity.year, entry.year, entry.id)
            XCTAssertEqual(identity.make, entry.make, entry.id)
            XCTAssertEqual(identity.model, entry.model, entry.id)
        }
    }

    func testIdentityOnlyDraftPrefillsOnlyOfficialFields()
        throws {
        let overlay = try overlay()
        let identityOnly = try XCTUnwrap(
            overlay.entries.first {
                $0.id == "fh6-1968-abarth-595-esseesse"
            }
        )
        XCTAssertNil(identityOnly.reviewedSelection)

        let draft = ManualEntryDraft(
            officialRosterIdentity: identityOnly.identity
        )

        XCTAssertEqual(draft.game, .fh6)
        XCTAssertEqual(draft.year, 1968)
        XCTAssertEqual(draft.make, "Abarth")
        XCTAssertEqual(draft.model, "595 esseesse")
        XCTAssertEqual(draft.performanceIndex, 100)
        XCTAssertEqual(draft.performanceClass, .d)
        XCTAssertNil(draft.weightPounds)
        XCTAssertNil(draft.frontWeightPercent)
        XCTAssertNil(draft.drivetrain)
        XCTAssertNil(draft.peakHorsepower)
        XCTAssertNil(draft.peakTorqueFootPounds)
        XCTAssertNil(draft.catalogReference)
        XCTAssertFalse(draft.catalogValuesModified)
        XCTAssertNil(draft.confirmedCarInput())
    }

    func testRosterFailureFallsBackToCurrentReviewedCatalog()
        throws {
        let catalog = try loadedCatalog()
        let fallback = CarCatalogBrowseOverlay.resolve(
            catalog: catalog,
            fh5RosterResult: .success(try loadedFH5Roster()),
            fh6RosterResult: .failure(.decodingFailed)
        )

        XCTAssertEqual(fallback.entries.count, 910)
        XCTAssertEqual(
            fallback.entries.filter { $0.game == .fh6 }.count,
            8
        )
        XCTAssertEqual(
            fallback.entries.filter { $0.game == .fh5 }.count,
            902
        )
        XCTAssertEqual(
            fallback.entries.filter(\.isReviewedStock).count,
            11
        )
        XCTAssertNotNil(
            fallback.rosterIssueDescription(for: .fh6)
        )
        XCTAssertNil(
            fallback.rosterIssueDescription(for: .fh5)
        )
    }

    func testOverlayRejectsReviewedIdentityMismatch()
        throws {
        let catalog = try loadedCatalog()
        let target = try XCTUnwrap(
            catalog.entries.first { $0.game == .fh6 }
        )
        let mismatched = CatalogCarEntry(
            id: target.id,
            game: target.game,
            year: target.year,
            make: target.make,
            model: "\(target.model) altered",
            stock: target.stock,
            verificationStatus: target.verificationStatus,
            sources: target.sources
        )
        let changedCatalog = CarCatalogSnapshot(
            schemaVersion: catalog.schemaVersion,
            revision: catalog.revision,
            reviewedAt: catalog.reviewedAt,
            legacyEntryCount: catalog.legacyEntryCount,
            entries: catalog.entries.map {
                $0.id == target.id ? mismatched : $0
            }
        )

        XCTAssertEqual(
            CarCatalogBrowseOverlay.make(
                catalog: changedCatalog,
                fh5Roster: try loadedFH5Roster(),
                fh6Roster: try loadedRoster()
            ),
            .failure(
                .reviewedIdentityMismatch(.fh6, target.id)
            )
        )
        let fallback = CarCatalogBrowseOverlay.resolve(
            catalog: changedCatalog,
            fh5RosterResult: .success(try loadedFH5Roster()),
            fh6RosterResult: .success(try loadedRoster())
        )
        XCTAssertEqual(fallback.entries.count, 910)
        XCTAssertNotNil(
            fallback.rosterIssueDescription(for: .fh6)
        )
    }

    func testLoaderRejectsMalformedDuplicateAndChangedIdentity()
        throws {
        XCTAssertEqual(
            BundledFH6OfficialRoster.load(
                data: Data("not json".utf8)
            ),
            .failure(.decodingFailed)
        )

        let roster = try loadedRoster()
        var duplicateEntries = roster.entries
        duplicateEntries[duplicateEntries.count - 1] =
            duplicateEntries[0]
        let duplicate = replacing(
            roster,
            entries: duplicateEntries
        )
        XCTAssertEqual(
            BundledFH6OfficialRoster.load(
                data: try encoded(duplicate)
            ),
            .failure(
                .duplicateEntryID(
                    duplicateEntries[0].id
                )
            )
        )

        var changedEntries = roster.entries
        let first = changedEntries[0]
        changedEntries[0] = FH6OfficialRosterEntry(
            id: first.id,
            year: first.year,
            make: first.make,
            model: "\(first.model) altered",
            officialDesignation: first.officialDesignation,
            performanceIndex: first.performanceIndex,
            performanceClass: first.performanceClass
        )
        let changed = replacing(
            roster,
            entries: changedEntries
        )
        XCTAssertEqual(
            BundledFH6OfficialRoster.load(
                data: try encoded(changed)
            ),
            .failure(.invalidIdentity(first.id))
        )
    }

    func testLoaderRejectsChangedSourceContract() throws {
        let roster = try loadedRoster()
        let changed = FH6OfficialRosterSnapshot(
            schemaVersion: roster.schemaVersion,
            revision: "unreviewed",
            sourceURL: roster.sourceURL,
            sourceUpdatedAt: roster.sourceUpdatedAt,
            sourceSHA256: roster.sourceSHA256,
            entries: roster.entries
        )

        XCTAssertEqual(
            BundledFH6OfficialRoster.load(
                data: try encoded(changed)
            ),
            .failure(.unexpectedRevision("unreviewed"))
        )
    }

    private func loadedRoster() throws
        -> FH6OfficialRosterSnapshot {
        try BundledFH6OfficialRoster.load().get()
    }

    private func loadedCatalog() throws
        -> CarCatalogSnapshot {
        try BundledCarCatalog.load().get()
    }

    private func loadedFH5Roster() throws
        -> FH5OfficialRosterSnapshot {
        try BundledFH5OfficialRoster.load().get()
    }

    private func overlay() throws
        -> CarCatalogBrowseSnapshot {
        try CarCatalogBrowseOverlay.make(
            catalog: loadedCatalog(),
            fh5Roster: loadedFH5Roster(),
            fh6Roster: loadedRoster()
        ).get()
    }

    private func replacing(
        _ roster: FH6OfficialRosterSnapshot,
        entries: [FH6OfficialRosterEntry]
    ) -> FH6OfficialRosterSnapshot {
        FH6OfficialRosterSnapshot(
            schemaVersion: roster.schemaVersion,
            revision: roster.revision,
            sourceURL: roster.sourceURL,
            sourceUpdatedAt: roster.sourceUpdatedAt,
            sourceSHA256: roster.sourceSHA256,
            entries: entries
        )
    }

    private func encoded(
        _ roster: FH6OfficialRosterSnapshot
    ) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(roster)
    }
}
