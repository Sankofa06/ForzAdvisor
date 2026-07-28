//
//  FH5OfficialRosterTests.swift
//  forzadvisorTests
//
//  Contracts for the complete official FH5 identity-only roster.
//

import XCTest
@testable import forzadvisor

final class FH5OfficialRosterTests: XCTestCase {
    func testRealBundleLoadsExactOfficialListingContract()
        throws {
        let roster = try loadedRoster()

        XCTAssertEqual(roster.schemaVersion, 1)
        XCTAssertEqual(
            roster.revision,
            BundledFH5OfficialRoster.expectedRevision
        )
        XCTAssertEqual(
            roster.sourceURL,
            BundledFH5OfficialRoster.expectedSourceURL
        )
        XCTAssertEqual(
            roster.sourceUpdatedAt,
            BundledFH5OfficialRoster.expectedSourceUpdatedAt
        )
        XCTAssertEqual(
            roster.sourceSHA256,
            BundledFH5OfficialRoster.expectedSourceSHA256
        )
        XCTAssertEqual(roster.entries.count, 902)
        XCTAssertEqual(Set(roster.entries.map(\.id)).count, 902)
        XCTAssertTrue(
            roster.entries.allSatisfy {
                !$0.carType.isEmpty
                    && !$0.collect.isEmpty
                    && !$0.added.isEmpty
                    && !$0.nickname.isEmpty
            }
        )
    }

    func testOfficialNumericIDCollisionsRemainMetadata()
        throws {
        let roster = try loadedRoster()
        let groups = Dictionary(
            grouping: roster.entries,
            by: \.officialID
        )
        let duplicateIDs = Set(
            groups.compactMap { id, entries in
                entries.count > 1 ? id : nil
            }
        )

        XCTAssertEqual(
            duplicateIDs,
            [1_253, 1_328, 1_451, 1_539]
        )
        XCTAssertEqual(Set(roster.entries.map(\.id)).count, 902)
    }

    func testDualOverlayKeepsExactPerGameBoundaries() throws {
        let overlay = try completeOverlay()
        let fh5 = overlay.entries.filter { $0.game == .fh5 }
        let fh6 = overlay.entries.filter { $0.game == .fh6 }

        XCTAssertEqual(fh5.count, 902)
        XCTAssertEqual(fh5.filter(\.isReviewedStock).count, 3)
        XCTAssertEqual(
            fh5.filter { !$0.isReviewedStock }.count,
            899
        )
        XCTAssertEqual(Set(fh5.map(\.id)).count, 902)
        XCTAssertEqual(fh6.count, 627)
        XCTAssertEqual(fh6.filter(\.isReviewedStock).count, 8)
        XCTAssertEqual(
            fh6.filter { !$0.isReviewedStock }.count,
            619
        )
        XCTAssertEqual(Set(fh6.map(\.id)).count, 627)
        XCTAssertTrue(overlay.rosterIssueDescriptions.isEmpty)
    }

    func testReviewedSubaruMatchesWithoutChangingOfficialDisplay()
        throws {
        let overlay = try completeOverlay()
        let subaru = try XCTUnwrap(
            overlay.entries.first {
                $0.id == "fh5-2022-subaru-brz"
            }
        )
        let selection = try XCTUnwrap(subaru.reviewedSelection)

        XCTAssertEqual(
            subaru.officialDesignation,
            "2022 SUBARU BRZ"
        )
        XCTAssertEqual(subaru.make, "")
        XCTAssertEqual(subaru.model, "SUBARU BRZ")
        XCTAssertEqual(selection.entry.make, "Subaru")
        XCTAssertEqual(selection.entry.model, "BRZ")
        XCTAssertEqual(
            selection.carInput.performanceIndex,
            selection.entry.stock.performanceIndex
        )
    }

    func testIdentityOnlyDraftContainsNoGuessedOrStockFields()
        throws {
        let rosterEntry = try XCTUnwrap(
            try loadedRoster().entries.first {
                $0.id == "fh5-1986-citroen-bx4tc"
            }
        )
        let draft = ManualEntryDraft(
            officialRosterIdentity: rosterEntry.identity
        )

        XCTAssertEqual(draft.game, .fh5)
        XCTAssertEqual(draft.year, 1986)
        XCTAssertEqual(draft.make, "")
        XCTAssertEqual(draft.model, "Citroën BX4TC")
        XCTAssertNil(draft.performanceIndex)
        XCTAssertNil(draft.performanceClass)
        XCTAssertNil(draft.weightPounds)
        XCTAssertNil(draft.frontWeightPercent)
        XCTAssertNil(draft.drivetrain)
        XCTAssertNil(draft.peakHorsepower)
        XCTAssertNil(draft.peakTorqueFootPounds)
        XCTAssertNil(draft.catalogReference)
        XCTAssertFalse(draft.catalogValuesModified)
        XCTAssertNil(draft.confirmedCarInput())
    }

    func testSearchPreservesUnicodeAndPunctuation() throws {
        let overlay = try completeOverlay()

        XCTAssertEqual(
            CarCatalogBrowseOverlay.search(
                overlay,
                game: .fh5,
                query: "  CITROËN bx4tc "
            ).map(\.id),
            ["fh5-1986-citroen-bx4tc"]
        )
        XCTAssertEqual(
            CarCatalogBrowseOverlay.search(
                overlay,
                game: .fh5,
                query: "C10 ‘Slayer’"
            ).map(\.id),
            ["fh5-1965-deberti-chevrolet-c10-slayer"]
        )
    }

    func testFH5FailureFallsBackWithoutReducingFH6()
        throws {
        let fallback = CarCatalogBrowseOverlay.resolve(
            catalog: try loadedCatalog(),
            fh5RosterResult: .failure(.decodingFailed),
            fh6RosterResult: .success(try loadedFH6Roster())
        )

        XCTAssertEqual(
            fallback.entries.filter { $0.game == .fh5 }.count,
            3
        )
        XCTAssertEqual(
            fallback.entries.filter { $0.game == .fh6 }.count,
            627
        )
        XCTAssertNotNil(
            fallback.rosterIssueDescription(for: .fh5)
        )
        XCTAssertNil(
            fallback.rosterIssueDescription(for: .fh6)
        )
    }

    func testReviewedFH5MismatchFallsBackOnlyFH5() throws {
        let catalog = try loadedCatalog()
        let target = try XCTUnwrap(
            catalog.entries.first { $0.game == .fh5 }
        )
        let changedEntry = CatalogCarEntry(
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
                $0.id == target.id ? changedEntry : $0
            }
        )
        let resolved = CarCatalogBrowseOverlay.resolve(
            catalog: changedCatalog,
            fh5RosterResult: .success(try loadedRoster()),
            fh6RosterResult: .success(try loadedFH6Roster())
        )

        XCTAssertEqual(
            resolved.entries.filter { $0.game == .fh5 }.count,
            3
        )
        XCTAssertEqual(
            resolved.entries.filter { $0.game == .fh6 }.count,
            627
        )
        XCTAssertNotNil(
            resolved.rosterIssueDescription(for: .fh5)
        )
        XCTAssertNil(
            resolved.rosterIssueDescription(for: .fh6)
        )
    }

    func testLoaderRejectsMalformedDuplicateAndInvalidSlug()
        throws {
        XCTAssertEqual(
            BundledFH5OfficialRoster.load(
                data: Data("not json".utf8)
            ),
            .failure(.decodingFailed)
        )

        let roster = try loadedRoster()
        var duplicateEntries = roster.entries
        duplicateEntries[duplicateEntries.count - 1] =
            duplicateEntries[0]
        XCTAssertEqual(
            BundledFH5OfficialRoster.load(
                data: try encoded(
                    replacing(roster, entries: duplicateEntries)
                )
            ),
            .failure(.duplicateEntryID(duplicateEntries[0].id))
        )

        var changedEntries = roster.entries
        let first = changedEntries[0]
        changedEntries[0] = FH5OfficialRosterEntry(
            id: "fh5-wrong",
            year: first.year,
            officialDesignation: first.officialDesignation,
            carType: first.carType,
            collect: first.collect,
            added: first.added,
            nickname: first.nickname,
            officialID: first.officialID
        )
        XCTAssertEqual(
            BundledFH5OfficialRoster.load(
                data: try encoded(
                    replacing(roster, entries: changedEntries)
                )
            ),
            .failure(.mismatchedID("fh5-wrong"))
        )
    }

    func testLoaderRejectsSourcePerformanceAndListingChanges()
        throws {
        let roster = try loadedRoster()
        let changedSource = FH5OfficialRosterSnapshot(
            schemaVersion: roster.schemaVersion,
            revision: "unreviewed",
            sourceURL: roster.sourceURL,
            sourceUpdatedAt: roster.sourceUpdatedAt,
            sourceSHA256: roster.sourceSHA256,
            entries: roster.entries
        )
        XCTAssertEqual(
            BundledFH5OfficialRoster.load(
                data: try encoded(changedSource)
            ),
            .failure(.unexpectedRevision("unreviewed"))
        )

        var root = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: encoded(roster)
            ) as? [String: Any]
        )
        var entries = try XCTUnwrap(
            root["entries"] as? [[String: Any]]
        )
        let firstID = try XCTUnwrap(entries[0]["id"] as? String)
        entries[0]["performanceIndex"] = 500
        root["entries"] = entries
        XCTAssertEqual(
            BundledFH5OfficialRoster.load(
                data: try JSONSerialization.data(
                    withJSONObject: root
                )
            ),
            .failure(.unexpectedPerformance(firstID))
        )

        entries[0].removeValue(forKey: "nickname")
        entries[0].removeValue(forKey: "performanceIndex")
        root["entries"] = entries
        XCTAssertEqual(
            BundledFH5OfficialRoster.load(
                data: try JSONSerialization.data(
                    withJSONObject: root
                )
            ),
            .failure(.incompleteListingMetadata(firstID))
        )
    }

    private func loadedRoster() throws
        -> FH5OfficialRosterSnapshot {
        try BundledFH5OfficialRoster.load().get()
    }

    private func loadedFH6Roster() throws
        -> FH6OfficialRosterSnapshot {
        try BundledFH6OfficialRoster.load().get()
    }

    private func loadedCatalog() throws -> CarCatalogSnapshot {
        try BundledCarCatalog.load().get()
    }

    private func completeOverlay() throws
        -> CarCatalogBrowseSnapshot {
        try CarCatalogBrowseOverlay.make(
            catalog: loadedCatalog(),
            fh5Roster: loadedRoster(),
            fh6Roster: loadedFH6Roster()
        ).get()
    }

    private func replacing(
        _ roster: FH5OfficialRosterSnapshot,
        entries: [FH5OfficialRosterEntry]
    ) -> FH5OfficialRosterSnapshot {
        FH5OfficialRosterSnapshot(
            schemaVersion: roster.schemaVersion,
            revision: roster.revision,
            sourceURL: roster.sourceURL,
            sourceUpdatedAt: roster.sourceUpdatedAt,
            sourceSHA256: roster.sourceSHA256,
            entries: entries
        )
    }

    private func encoded(
        _ roster: FH5OfficialRosterSnapshot
    ) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(roster)
    }
}
