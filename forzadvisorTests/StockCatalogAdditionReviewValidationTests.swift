//
//  StockCatalogAdditionReviewValidationTests.swift
//  forzadvisorTests
//

import XCTest
@testable import forzadvisor

extension StockCatalogAdditionReviewTests {
    func testTamperedStaleAndWrongBindingsFailClosed() throws {
        let fixture = try makeFixture()
        let artifact = try makeReview(fixture)
        let exporter = StockCatalogAdditionReviewExporter()

        var tamperedPreflight = fixture.preflight.canonicalJSON
        tamperedPreflight.append(0x20)
        XCTAssertThrowsError(
            try exporter.validate(
                artifact.canonicalJSON,
                preflightCanonicalJSON: tamperedPreflight,
                packetCanonicalJSON: fixture.packet.canonicalJSON,
                baseCatalog: fixture.catalog
            )
        )

        let other = try makeFixture(seedOffset: 20)
        XCTAssertThrowsError(
            try exporter.validate(
                artifact.canonicalJSON,
                preflightCanonicalJSON:
                    fixture.preflight.canonicalJSON,
                packetCanonicalJSON: other.packet.canonicalJSON,
                baseCatalog: fixture.catalog
            )
        )

        let stale = CarCatalogSnapshot(
            schemaVersion: fixture.catalog.schemaVersion,
            revision: fixture.catalog.revision + "-changed",
            reviewedAt: fixture.catalog.reviewedAt,
            entries: fixture.catalog.entries
        )
        XCTAssertThrowsError(
            try exporter.validate(
                artifact.canonicalJSON,
                preflightCanonicalJSON:
                    fixture.preflight.canonicalJSON,
                packetCanonicalJSON: fixture.packet.canonicalJSON,
                baseCatalog: stale
            )
        )
    }

    func testValidatorRejectsEmptyOversizeUnknownAndNoncanonical()
        throws {
        let fixture = try makeFixture()
        let artifact = try makeReview(fixture)
        let exporter = StockCatalogAdditionReviewExporter()

        func validate(_ data: Data) throws {
            _ = try exporter.validate(
                data,
                preflightCanonicalJSON:
                    fixture.preflight.canonicalJSON,
                packetCanonicalJSON: fixture.packet.canonicalJSON,
                baseCatalog: fixture.catalog
            )
        }

        XCTAssertThrowsError(try validate(Data())) {
            XCTAssertEqual(
                $0 as? StockCatalogAdditionReviewError,
                .emptyPayload
            )
        }
        XCTAssertThrowsError(
            try validate(
                Data(
                    repeating: 0x20,
                    count:
                        StockCatalogAdditionReviewExporter
                        .maximumPayloadBytes + 1
                )
            )
        ) {
            XCTAssertEqual(
                $0 as? StockCatalogAdditionReviewError,
                .payloadTooLarge
            )
        }

        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: artifact.canonicalJSON
            ) as? [String: Any]
        )
        object["unexpected"] = true
        let unknown = try JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys]
        )
        XCTAssertThrowsError(try validate(unknown)) {
            XCTAssertEqual(
                $0 as? StockCatalogAdditionReviewError,
                .unknownFields
            )
        }

        let noncanonical = try JSONSerialization.data(
            withJSONObject: try JSONSerialization.jsonObject(
                with: artifact.canonicalJSON
            ),
            options: [.prettyPrinted, .sortedKeys]
        )
        XCTAssertThrowsError(try validate(noncanonical)) {
            XCTAssertEqual(
                $0 as? StockCatalogAdditionReviewError,
                .nonCanonicalJSON
            )
        }
    }

    func testValidatorRejectsCanonicalFingerprintTampering()
        throws {
        let fixture = try makeFixture()
        let artifact = try makeReview(fixture)
        let decoded = artifact.review
        let tampered = StockCatalogAdditionReview(
            schemaVersion: decoded.schemaVersion,
            policyVersion: decoded.policyVersion,
            preflightFingerprint: decoded.preflightFingerprint,
            maintainerPacketDigest:
                decoded.maintainerPacketDigest,
            baseCatalogDigest: decoded.baseCatalogDigest,
            candidateDigest: decoded.candidateDigest,
            rightsSummary: decoded.rightsSummary,
            confirmations: decoded.confirmations,
            proposedEntry: decoded.proposedEntry,
            proposedCatalogSnapshot:
                decoded.proposedCatalogSnapshot,
            automaticCatalogMutationPermitted:
                decoded.automaticCatalogMutationPermitted,
            tuningActivationPermitted:
                decoded.tuningActivationPermitted,
            legalSufficiencyEstablished:
                decoded.legalSufficiencyEstablished,
            requiresManualBundleChange:
                decoded.requiresManualBundleChange,
            reviewBoundary: decoded.reviewBoundary,
            privacyExclusions: decoded.privacyExclusions,
            artifactFingerprint: String(repeating: "a", count: 64)
        )
        XCTAssertThrowsError(
            try StockCatalogAdditionReviewExporter().validate(
                canonicalReviewData(tampered),
                preflightCanonicalJSON:
                    fixture.preflight.canonicalJSON,
                packetCanonicalJSON: fixture.packet.canonicalJSON,
                baseCatalog: fixture.catalog
            )
        ) {
            XCTAssertEqual(
                $0 as? StockCatalogAdditionReviewError,
                .invalidFingerprint
            )
        }
    }

    func testReviewJSONOmitsPrivateContributionAndTuningData()
        throws {
        let artifact = try makeReview(makeFixture())
        let text = try XCTUnwrap(
            String(data: artifact.canonicalJSON, encoding: .utf8)
        )
        for forbidden in [
            "submissionID", "permissionReceiptID",
            "observationDigest", "canonicalExportJSON",
            "deviceID", "accountID", "screenshotData",
            "providerConfiguration", "tuningRuleset",
            "tirePressure"
        ] {
            XCTAssertFalse(text.contains(forbidden), forbidden)
        }
        XCTAssertTrue(
            artifact.review.privacyExclusions.contains(
                "observation-digests"
            )
        )
    }
}
