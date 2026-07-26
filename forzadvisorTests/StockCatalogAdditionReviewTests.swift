//
//  StockCatalogAdditionReviewTests.swift
//  forzadvisorTests
//

import XCTest
@testable import forzadvisor

final class StockCatalogAdditionReviewTests: XCTestCase {
    func testDeterministicRoundTripDerivesExactEntryAndSchemaV2Snapshot()
        throws {
        let fixture = try makeFixture()
        let exporter = StockCatalogAdditionReviewExporter()
        let first = try makeReview(fixture)
        let second = try makeReview(fixture)

        XCTAssertEqual(first.canonicalJSON, second.canonicalJSON)
        XCTAssertEqual(
            try exporter.validate(
                first.canonicalJSON,
                preflightCanonicalJSON:
                    fixture.preflight.canonicalJSON,
                packetCanonicalJSON: fixture.packet.canonicalJSON,
                baseCatalog: fixture.catalog
            ),
            first.review
        )

        let preflight = fixture.preflight.preflight
        let entry = first.review.proposedEntry
        XCTAssertEqual(entry.id, preflight.proposal.catalogID)
        XCTAssertEqual(
            entry.verificationStatus,
            preflight.proposal.verificationStatus
        )
        XCTAssertEqual(entry.game, preflight.selection.game)
        XCTAssertEqual(entry.year, preflight.selection.vehicle.year)
        XCTAssertEqual(entry.make, preflight.selection.vehicle.make)
        XCTAssertEqual(entry.model, preflight.selection.vehicle.model)
        XCTAssertEqual(
            entry.stock,
            preflight.selection.vehicle.stock
        )
        XCTAssertEqual(entry.sources.count, 2)

        let identity = try XCTUnwrap(entry.sources.first {
            $0.id == "identity-source"
        })
        XCTAssertEqual(
            identity.title,
            preflight.identitySourceRightsReview.sourceTitle
        )
        XCTAssertEqual(
            identity.url?.absoluteString,
            preflight.identitySourceRightsReview.sourceURL
        )
        XCTAssertEqual(identity.role, .officialRoster)
        XCTAssertEqual(identity.fields, [.identity])

        let observations = try XCTUnwrap(entry.sources.first {
            $0.id == "first-party-observations"
        })
        XCTAssertEqual(
            observations.title,
            StockCatalogAdditionReviewPolicy
                .firstPartySourceTitle
        )
        XCTAssertNil(observations.url)
        XCTAssertEqual(
            observations.role,
            .firstPartyObservation
        )
        XCTAssertEqual(
            Set(observations.fields),
            Set(CatalogDataField.allCases.filter {
                $0 != .identity
            })
        )

        let proposal = first.review.proposedCatalogSnapshot
        XCTAssertEqual(proposal.schemaVersion, 2)
        XCTAssertEqual(
            proposal.revision,
            preflight.proposal.revision
        )
        XCTAssertEqual(
            Array(proposal.entries.dropLast()),
            fixture.catalog.entries
        )
        XCTAssertEqual(proposal.entries.last, entry)
        XCTAssertEqual(
            proposal.entries.count,
            fixture.catalog.entries.count + 1
        )
        XCTAssertFalse(
            first.review.automaticCatalogMutationPermitted
        )
        XCTAssertFalse(first.review.tuningActivationPermitted)
        XCTAssertFalse(first.review.legalSufficiencyEstablished)
        XCTAssertTrue(first.review.requiresManualBundleChange)
    }

    func testBaseV1ResourceIsUnchangedAndProposalDoesNotMutateIt()
        throws {
        let before = try BundledCarCatalog.load().get()
        let fixture = try makeFixture(catalog: before)
        let artifact = try makeReview(fixture)

        XCTAssertEqual(before.schemaVersion, 1)
        XCTAssertEqual(
            try BundledCarCatalog.load().get(),
            before
        )
        XCTAssertEqual(
            artifact.review.proposedCatalogSnapshot.entries.count,
            before.entries.count + 1
        )
        XCTAssertEqual(
            try BundledCarCatalog.load(
                data: canonicalCatalogData(
                    artifact.review.proposedCatalogSnapshot
                )
            ).get(),
            artifact.review.proposedCatalogSnapshot
        )
    }

    func testStatusRoleDateAndEveryConfirmationFailClosed()
        throws {
        let official = try makeFixture(status: .officialRoster)
        XCTAssertThrowsError(try makeReview(official)) {
            XCTAssertEqual(
                $0 as? StockCatalogAdditionReviewError,
                .invalidStatus
            )
        }

        let fixture = try makeFixture()
        XCTAssertThrowsError(
            try makeReview(
                fixture,
                identityRole: .firstPartyObservation
            )
        ) {
            XCTAssertEqual(
                $0 as? StockCatalogAdditionReviewError,
                .invalidIdentityRole
            )
        }
        XCTAssertThrowsError(
            try makeReview(
                fixture,
                reviewedAt: fixture.catalog.reviewedAt
            )
        ) {
            XCTAssertEqual(
                $0 as? StockCatalogAdditionReviewError,
                .invalidReviewDate
            )
        }

        let incomplete = [
            StockCatalogAdditionReviewConfirmations(
                currentPreflightAndCatalogRevalidated: false,
                identityRoleReviewed: true,
                factsAndStatusReviewed: true,
                rightsSufficientForRelease: true,
                revisionAndDateApproved: true,
                manualBundleChangeUnderstood: true
            ),
            .init(
                currentPreflightAndCatalogRevalidated: true,
                identityRoleReviewed: false,
                factsAndStatusReviewed: true,
                rightsSufficientForRelease: true,
                revisionAndDateApproved: true,
                manualBundleChangeUnderstood: true
            ),
            .init(
                currentPreflightAndCatalogRevalidated: true,
                identityRoleReviewed: true,
                factsAndStatusReviewed: false,
                rightsSufficientForRelease: true,
                revisionAndDateApproved: true,
                manualBundleChangeUnderstood: true
            ),
            .init(
                currentPreflightAndCatalogRevalidated: true,
                identityRoleReviewed: true,
                factsAndStatusReviewed: true,
                rightsSufficientForRelease: false,
                revisionAndDateApproved: true,
                manualBundleChangeUnderstood: true
            ),
            .init(
                currentPreflightAndCatalogRevalidated: true,
                identityRoleReviewed: true,
                factsAndStatusReviewed: true,
                rightsSufficientForRelease: true,
                revisionAndDateApproved: false,
                manualBundleChangeUnderstood: true
            ),
            .init(
                currentPreflightAndCatalogRevalidated: true,
                identityRoleReviewed: true,
                factsAndStatusReviewed: true,
                rightsSufficientForRelease: true,
                revisionAndDateApproved: true,
                manualBundleChangeUnderstood: false
            )
        ]
        for confirmations in incomplete {
            XCTAssertThrowsError(
                try makeReview(
                    fixture,
                    confirmations: confirmations
                )
            ) {
                XCTAssertEqual(
                    $0 as? StockCatalogAdditionReviewError,
                    .incompleteConfirmations
                )
            }
        }
    }
}
