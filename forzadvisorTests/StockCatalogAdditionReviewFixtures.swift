//
//  StockCatalogAdditionReviewFixtures.swift
//  forzadvisorTests
//

import Foundation
import XCTest
@testable import forzadvisor

extension StockCatalogAdditionReviewTests {
    // MARK: - Fixtures

    struct Fixture {
        let catalog: CarCatalogSnapshot
        let packet: StockCatalogMaintainerReviewPacketArtifact
        let preflight: StockCatalogCurationPreflightArtifact
    }

    func makeFixture(
        catalog suppliedCatalog: CarCatalogSnapshot? = nil,
        status: CatalogVerificationStatus =
            .communityCrossChecked,
        seedOffset: Int = 0
    ) throws -> Fixture {
        let catalog =
            try suppliedCatalog ?? BundledCarCatalog.load().get()
        let first = try reviewedEntry(
            record(seed: 1 + seedOffset)
        )
        let second = try reviewedEntry(
            record(seed: 2 + seedOffset),
            existing: [first]
        )
        let packet = try StockCatalogMaintainerReviewPacketExporter()
            .makeArtifact(
                reviewedEntries: [second, first],
                baseCatalog: catalog
            )
        let candidate = try XCTUnwrap(packet.packet.candidates.first)
        let decisions = StockCatalogContributionValidator
            .expectedFields.map { field in
                StockCatalogCurationFieldDecision(
                    field: field,
                    observationDigests:
                        candidate.variant.observations
                        .filter {
                            $0.fields.contains {
                                $0.field == field
                            }
                        }
                        .map(\.observationDigest)
                        .sorted()
                )
            }
        let request = StockCatalogCurationPreflightRequest(
            groupID: candidate.groupID,
            variantID: candidate.variant.variantID,
            fieldDecisions: decisions,
            identitySourceRightsReview: .init(
                sourceTitle: "Official roster",
                sourceURL:
                    "https://example.com/official-roster",
                accessedOn: "2026-07-25",
                rightsBasis: .explicitPermission,
                rightsEvidenceReference:
                    "Permission archive 2026-07",
                rightsEvidenceSHA256:
                    String(repeating: "b", count: 64),
                rightsIndependentlyReviewed: true,
                noSourceFactsCopied: true,
                noSourceProseCopied: true,
                noSourceMediaCopied: true
            ),
            proposal: .init(
                catalogID: "fh6-2024-test-stock-car",
                revision: "catalog-next",
                verificationStatus: status
            ),
            allPermissionedEvidenceUsedForEveryField: true,
            separateReleaseReviewConfirmed: true
        )
        let preflight = try StockCatalogCurationPreflightExporter()
            .makeArtifact(
                packetCanonicalJSON: packet.canonicalJSON,
                baseCatalog: catalog,
                request: request
            )
        return .init(
            catalog: catalog,
            packet: packet,
            preflight: preflight
        )
    }

    func makeReview(
        _ fixture: Fixture,
        reviewedAt: Date? = nil,
        identityRole: CatalogSourceRole = .officialRoster,
        confirmations:
            StockCatalogAdditionReviewConfirmations = .complete
    ) throws -> StockCatalogAdditionReviewArtifact {
        try StockCatalogAdditionReviewExporter().makeArtifact(
            preflightCanonicalJSON:
                fixture.preflight.canonicalJSON,
            packetCanonicalJSON: fixture.packet.canonicalJSON,
            baseCatalog: fixture.catalog,
            request: .init(
                reviewedAt:
                    reviewedAt
                    ?? fixture.catalog.reviewedAt
                        .addingTimeInterval(86_400),
                identitySourceRole: identityRole,
                confirmations: confirmations
            )
        )
    }

    func reviewedEntry(
        _ record: StockCatalogContributionRecord,
        existing: [StockCatalogContributionReviewEntry] = []
    ) throws -> StockCatalogContributionReviewEntry {
        try StockCatalogContributionReviewEntry.locallyReviewed(
            canonicalExportJSON:
                StockCatalogContributionExporter()
                .canonicalJSON(for: record),
            reviewerConfirmedDirectReceipt: true,
            reviewerConfirmedTesterAuthoredStructuredFacts: true,
            reviewerConfirmedStructuredReusePermission: true,
            reviewerConfirmedCatalogCurationPermission: true,
            reviewerConfirmedBundledRedistributionPermission: true,
            existing: existing,
            now: Date(timeIntervalSince1970: 1_800_100_000)
        )
    }

    func record(
        seed: Int
    ) -> StockCatalogContributionRecord {
        let observed = Date(
            timeIntervalSince1970:
                1_800_000_000 + Double(seed)
        )
        let fields =
            StockCatalogContributionValidator.expectedFields
        return .init(
            id: uuid(seed),
            submissionID: uuid(1_000 + seed),
            permissionReceiptID: uuid(2_000 + seed),
            capturedAt: observed,
            game: .fh6,
            gameVersion: "1.0.100.0",
            platform: .xboxSeries,
            vehicle: .init(
                year: 2024,
                make: "Test",
                model: "Stock Car",
                stock: .init(
                    performanceIndex: 710,
                    performanceClass: .s1,
                    drivetrain: .awd,
                    weightPounds: 3_200,
                    frontWeightPercent: 52,
                    peakHorsepower: 500,
                    peakTorqueFootPounds: 450
                )
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

    func uuid(_ value: Int) -> UUID {
        UUID(
            uuidString: String(
                format:
                    "00000000-0000-0000-0000-%012d",
                abs(value) % 1_000_000_000_000
            )
        )!
    }

    func canonicalCatalogData(
        _ catalog: CarCatalogSnapshot
    ) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [
            .sortedKeys,
            .withoutEscapingSlashes
        ]
        return try encoder.encode(catalog)
    }

    func canonicalReviewData(
        _ review: StockCatalogAdditionReview
    ) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [
            .sortedKeys,
            .withoutEscapingSlashes
        ]
        return try encoder.encode(review)
    }
}
