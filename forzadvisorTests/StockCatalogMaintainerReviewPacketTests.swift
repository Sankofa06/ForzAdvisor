//
//  StockCatalogMaintainerReviewPacketTests.swift
//  forzadvisorTests
//

import XCTest
@testable import forzadvisor

final class StockCatalogMaintainerReviewPacketTests: XCTestCase {
    func testCanonicalPacketIsDeterministicAndOmitsAdministrativeIDs()
        throws {
        let entry = try reviewedEntry(for: record())
        let catalog = try BundledCarCatalog.load().get()
        let exporter = StockCatalogMaintainerReviewPacketExporter()

        let first = try exporter.makeArtifact(
            reviewedEntries: [entry],
            baseCatalog: catalog
        )
        let second = try exporter.makeArtifact(
            reviewedEntries: [entry],
            baseCatalog: catalog
        )

        XCTAssertEqual(first.canonicalJSON, second.canonicalJSON)
        XCTAssertEqual(
            try exporter.validate(first.canonicalJSON),
            first.packet
        )
        let text = try XCTUnwrap(
            String(data: first.canonicalJSON, encoding: .utf8)
        )
        for forbidden in [
            "submissionID", "permissionReceiptID", entry.id.uuidString
        ] {
            XCTAssertFalse(text.contains(forbidden), forbidden)
        }
        XCTAssertEqual(
            text.components(separatedBy: "\"reviewedAt\"").count - 1,
            1
        )
        XCTAssertFalse(first.packet.automaticPromotionPermitted)
        XCTAssertTrue(first.packet.requiresIndependentSourceReview)
    }

    func testConflictingReviewedFactsBecomeOneQuarantinedGroup()
        throws {
        let first = try reviewedEntry(for: record())
        let second = try reviewedEntry(
            for: record(
                submissionID:
                    Self.uuid("44444444-4444-4444-4444-444444444444"),
                permissionReceiptID:
                    Self.uuid("55555555-5555-5555-5555-555555555555"),
                stock: Self.stock(performanceIndex: 720)
            ),
            existing: [first]
        )

        let packet = try StockCatalogMaintainerReviewPacketExporter()
            .makeArtifact(
                reviewedEntries: [first, second],
                baseCatalog: try BundledCarCatalog.load().get()
            ).packet

        XCTAssertTrue(packet.candidates.isEmpty)
        XCTAssertEqual(packet.conflicts.count, 1)
        XCTAssertEqual(
            packet.conflicts[0].conflictingFields,
            [.performanceIndex]
        )
        XCTAssertEqual(packet.conflicts[0].variants.count, 2)
        XCTAssertEqual(
            packet.conflicts[0].variants,
            packet.conflicts[0].variants.sorted {
                $0.variantID < $1.variantID
            }
        )
    }

    func testReplayedSubmissionQuarantinesEveryAffectedObservation()
        throws {
        let sharedSubmission =
            Self.uuid("66666666-6666-6666-6666-666666666666")
        let first = try reviewedEntry(for: record(
            submissionID: sharedSubmission
        ))
        let second = try reviewedEntry(
            for: record(
                submissionID: sharedSubmission,
                permissionReceiptID:
                    Self.uuid("77777777-7777-7777-7777-777777777777"),
                model: "Other Car"
            ),
            existing: [first]
        )

        XCTAssertThrowsError(
            try StockCatalogMaintainerReviewPacketExporter()
                .makeArtifact(
                    reviewedEntries: [first, second],
                    baseCatalog: try BundledCarCatalog.load().get()
                )
        ) {
            XCTAssertEqual(
                $0 as? StockCatalogMaintainerReviewPacketError,
                .noReviewableEvidence
            )
        }
    }

    func testCatalogComparisonIsReadOnlyAndClassifiesExactMatch()
        throws {
        let before = try BundledCarCatalog.load().get()
        let existing = try XCTUnwrap(before.entries.first)
        let contribution = record(
            game: existing.game,
            year: existing.year,
            make: existing.make,
            model: existing.model,
            stock: existing.stock
        )

        let packet = try StockCatalogMaintainerReviewPacketExporter()
            .makeArtifact(
                reviewedEntries: [
                    try reviewedEntry(for: contribution)
                ],
                baseCatalog: before
            ).packet
        let comparison = try XCTUnwrap(
            packet.candidates.first?.variant.catalogComparison
        )
        XCTAssertEqual(comparison.status, .exactStockMatch)
        XCTAssertEqual(comparison.existingEntryIDs, [existing.id])
        XCTAssertTrue(comparison.differingFields.isEmpty)

        let after = try BundledCarCatalog.load().get()
        XCTAssertEqual(after, before)
    }

    func testValidatorRejectsUnknownFieldsAndFingerprintTampering()
        throws {
        let exporter = StockCatalogMaintainerReviewPacketExporter()
        let artifact = try exporter.makeArtifact(
            reviewedEntries: [try reviewedEntry(for: record())],
            baseCatalog: try BundledCarCatalog.load().get()
        )
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: artifact.canonicalJSON)
                as? [String: Any]
        )
        object["unknown"] = true
        let unknown = try JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys, .prettyPrinted]
        )
        XCTAssertThrowsError(try exporter.validate(unknown)) {
            XCTAssertEqual(
                $0 as? StockCatalogMaintainerReviewPacketError,
                .unknownFields
            )
        }

        object.removeValue(forKey: "unknown")
        object["artifactFingerprint"] = String(repeating: "0", count: 64)
        let tampered = try JSONSerialization.data(
            withJSONObject: object,
            options: [
                .sortedKeys, .prettyPrinted, .withoutEscapingSlashes
            ]
        )
        XCTAssertThrowsError(try exporter.validate(tampered)) {
            XCTAssertEqual(
                $0 as? StockCatalogMaintainerReviewPacketError,
                .invalidFingerprint
            )
        }
    }

    private func reviewedEntry(
        for record: StockCatalogContributionRecord,
        existing: [StockCatalogContributionReviewEntry] = []
    ) throws -> StockCatalogContributionReviewEntry {
        try StockCatalogContributionReviewEntry.locallyReviewed(
            canonicalExportJSON:
                try StockCatalogContributionExporter()
                .canonicalJSON(for: record),
            reviewerConfirmedDirectReceipt: true,
            reviewerConfirmedTesterAuthoredStructuredFacts: true,
            reviewerConfirmedStructuredReusePermission: true,
            reviewerConfirmedCatalogCurationPermission: true,
            reviewerConfirmedBundledRedistributionPermission: true,
            existing: existing,
            now: Date(timeIntervalSince1970: 1_800_000_100)
        )
    }

    private func record(
        submissionID: UUID? = nil,
        permissionReceiptID: UUID? = nil,
        game: ForzaGame = .fh6,
        year: Int = 2024,
        make: String = "Test",
        model: String = "Stock Car",
        stock: CatalogStockSpecifications? = nil
    ) -> StockCatalogContributionRecord {
        let observed = Date(timeIntervalSince1970: 1_800_000_000)
        let fields = StockCatalogContributionValidator.expectedFields
        return .init(
            id: Self.uuid("33333333-3333-3333-3333-333333333333"),
            submissionID: submissionID
                ?? Self.uuid(
                    "11111111-1111-1111-1111-111111111111"
                ),
            permissionReceiptID: permissionReceiptID
                ?? Self.uuid(
                    "22222222-2222-2222-2222-222222222222"
                ),
            capturedAt: observed,
            game: game,
            gameVersion: "1.0.100.0",
            platform: .xboxSeries,
            vehicle: .init(
                year: year,
                make: make,
                model: model,
                stock: stock ?? Self.stock()
            ),
            reviewedFields: fields,
            fieldAttestations: fields.map {
                .init(
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

    private static func stock(
        performanceIndex: Int = 710
    ) -> CatalogStockSpecifications {
        .init(
            performanceIndex: performanceIndex,
            performanceClass: .s1,
            drivetrain: .awd,
            weightPounds: 3_200,
            frontWeightPercent: 52,
            peakHorsepower: 500,
            peakTorqueFootPounds: 450
        )
    }

    private static func uuid(_ value: String) -> UUID {
        UUID(uuidString: value)!
    }
}
