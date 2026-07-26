//
//  StockCatalogCurationPreflightTests.swift
//  forzadvisorTests
//

import XCTest
@testable import forzadvisor

final class StockCatalogCurationPreflightTests: XCTestCase {
    func testCanonicalRoundTripIsDeterministicAndBindsExactInputs()
        throws {
        let fixture = try makeFixture()
        let exporter = StockCatalogCurationPreflightExporter()

        let first = try exporter.makeArtifact(
            packetCanonicalJSON: fixture.packet.canonicalJSON,
            baseCatalog: fixture.catalog,
            request: fixture.request
        )
        let second = try exporter.makeArtifact(
            packetCanonicalJSON: fixture.packet.canonicalJSON,
            baseCatalog: fixture.catalog,
            request: fixture.request
        )

        XCTAssertEqual(first.canonicalJSON, second.canonicalJSON)
        XCTAssertEqual(
            try exporter.validate(
                first.canonicalJSON,
                packetCanonicalJSON: fixture.packet.canonicalJSON,
                baseCatalog: fixture.catalog
            ),
            first.preflight
        )
        XCTAssertFalse(
            first.preflight.automaticCatalogMutationPermitted
        )
        XCTAssertFalse(first.preflight.tuningActivationPermitted)
        XCTAssertTrue(
            first.preflight.requiresSeparateReleaseReview
        )
        XCTAssertTrue(
            first.preflight.reviewBoundary.contains(
                "does not establish legal sufficiency"
            )
        )
    }

    func testOrderAndDuplicateInputEntriesDoNotChangePacketOrPreflight()
        throws {
        let catalog = try BundledCarCatalog.load().get()
        let first = try reviewedEntry(for: record(seed: 1))
        let second = try reviewedEntry(
            for: record(seed: 2),
            existing: [first]
        )
        let packetExporter =
            StockCatalogMaintainerReviewPacketExporter()
        let forward = try packetExporter.makeArtifact(
            reviewedEntries: [first, second, first],
            baseCatalog: catalog
        )
        let reverse = try packetExporter.makeArtifact(
            reviewedEntries: [second, first, first],
            baseCatalog: catalog
        )
        XCTAssertEqual(forward.canonicalJSON, reverse.canonicalJSON)

        let request = try request(for: forward.packet)
        let exporter = StockCatalogCurationPreflightExporter()
        XCTAssertEqual(
            try exporter.makeArtifact(
                packetCanonicalJSON: forward.canonicalJSON,
                baseCatalog: catalog,
                request: request
            ).canonicalJSON,
            try exporter.makeArtifact(
                packetCanonicalJSON: reverse.canonicalJSON,
                baseCatalog: catalog,
                request: request
            ).canonicalJSON
        )
    }

    func testSingleObservationAndConflictGroupsFailClosed()
        throws {
        let catalog = try BundledCarCatalog.load().get()
        let packetExporter =
            StockCatalogMaintainerReviewPacketExporter()
        let single = try packetExporter.makeArtifact(
            reviewedEntries: [
                try reviewedEntry(for: record(seed: 1))
            ],
            baseCatalog: catalog
        )
        XCTAssertThrowsError(
            try StockCatalogCurationPreflightExporter()
                .makeArtifact(
                    packetCanonicalJSON: single.canonicalJSON,
                    baseCatalog: catalog,
                    request: try request(
                        for: single.packet,
                        allowSingleObservation: true
                    )
                )
        ) {
            XCTAssertEqual(
                $0 as? StockCatalogCurationPreflightError,
                .insufficientEvidence
            )
        }

        let first = try reviewedEntry(for: record(seed: 1))
        let conflicting = try reviewedEntry(
            for: record(seed: 2, performanceIndex: 711),
            existing: [first]
        )
        let conflictPacket = try packetExporter.makeArtifact(
            reviewedEntries: [first, conflicting],
            baseCatalog: catalog
        )
        let conflict = try XCTUnwrap(
            conflictPacket.packet.conflicts.first
        )
        XCTAssertThrowsError(
            try StockCatalogCurationPreflightExporter()
                .makeArtifact(
                    packetCanonicalJSON:
                        conflictPacket.canonicalJSON,
                    baseCatalog: catalog,
                    request: request(
                        groupID: conflict.groupID,
                        variant: conflict.variants[0]
                    )
                )
        ) {
            XCTAssertEqual(
                $0 as? StockCatalogCurationPreflightError,
                .candidateNotFound
            )
        }
    }

    func testExistingCatalogCandidateIsNotEligible() throws {
        let catalog = try BundledCarCatalog.load().get()
        let existing = try XCTUnwrap(catalog.entries.first)
        let first = try reviewedEntry(
            for: record(seed: 1, matching: existing)
        )
        let second = try reviewedEntry(
            for: record(seed: 2, matching: existing),
            existing: [first]
        )
        let packet = try StockCatalogMaintainerReviewPacketExporter()
            .makeArtifact(
                reviewedEntries: [first, second],
                baseCatalog: catalog
            )
        XCTAssertEqual(
            packet.packet.candidates[0].variant
                .catalogComparison.status,
            .exactStockMatch
        )
        XCTAssertThrowsError(
            try StockCatalogCurationPreflightExporter()
                .makeArtifact(
                    packetCanonicalJSON: packet.canonicalJSON,
                    baseCatalog: catalog,
                    request: try request(for: packet.packet)
                )
        ) {
            XCTAssertEqual(
                $0 as? StockCatalogCurationPreflightError,
                .candidateNotEligible
            )
        }
    }

    func testFieldEvidenceMustBeCompleteExactAndCandidateBound()
        throws {
        let fixture = try makeFixture()
        let candidate = fixture.packet.packet.candidates[0]
        let good = try request(for: fixture.packet.packet)
        var missing = good.fieldDecisions
        missing.removeLast()
        XCTAssertThrowsError(
            try make(
                fixture,
                replacingDecisions: missing
            )
        ) {
            XCTAssertEqual(
                $0 as? StockCatalogCurationPreflightError,
                .invalidFieldDecisions
            )
        }

        var duplicate = good.fieldDecisions
        duplicate[1] = .init(
            field: duplicate[0].field,
            observationDigests:
                duplicate[0].observationDigests
        )
        XCTAssertThrowsError(
            try make(fixture, replacingDecisions: duplicate)
        )

        var foreign = good.fieldDecisions
        foreign[0] = .init(
            field: foreign[0].field,
            observationDigests: [
                String(repeating: "a", count: 64),
                candidate.variant.observations[0]
                    .observationDigest
            ].sorted()
        )
        XCTAssertThrowsError(
            try make(fixture, replacingDecisions: foreign)
        ) {
            XCTAssertEqual(
                $0 as? StockCatalogCurationPreflightError,
                .invalidFieldDecisions
            )
        }
    }

    func testChangedCatalogWithSameRevisionAndDifferentPacketFailBinding()
        throws {
        let fixture = try makeFixture()
        let artifact = try make(fixture)
        let sourceTemplate = try XCTUnwrap(
            fixture.catalog.entries.first { $0.game == .fh6 }
        )
        let extra = CatalogCarEntry(
            id: "fh6-2099-binding-test",
            game: .fh6,
            year: 2099,
            make: "Binding",
            model: "Test",
            stock: .init(
                performanceIndex: 100,
                performanceClass: .d,
                drivetrain: .rwd,
                weightPounds: 2_000,
                frontWeightPercent: 50,
                peakHorsepower: 100,
                peakTorqueFootPounds: 100
            ),
            verificationStatus: .officialRoster,
            sources: sourceTemplate.sources
        )
        let changed = CarCatalogSnapshot(
            schemaVersion: fixture.catalog.schemaVersion,
            revision: fixture.catalog.revision,
            reviewedAt: fixture.catalog.reviewedAt,
            entries: fixture.catalog.entries + [extra]
        )
        XCTAssertThrowsError(
            try StockCatalogCurationPreflightExporter()
                .validate(
                    artifact.canonicalJSON,
                    packetCanonicalJSON:
                        fixture.packet.canonicalJSON,
                    baseCatalog: changed
                )
        ) {
            XCTAssertEqual(
                $0 as? StockCatalogCurationPreflightError,
                .catalogBindingMismatch
            )
        }

        let other = try makeFixture(seedOffset: 10)
        XCTAssertThrowsError(
            try StockCatalogCurationPreflightExporter()
                .validate(
                    artifact.canonicalJSON,
                    packetCanonicalJSON:
                        other.packet.canonicalJSON,
                    baseCatalog: fixture.catalog
                )
        ) {
            XCTAssertEqual(
                $0 as? StockCatalogCurationPreflightError,
                .packetBindingMismatch
            )
        }
    }

    func testCreationRecomputesCandidateAbsenceAgainstExactCatalog()
        throws {
        let fixture = try makeFixture()
        let candidate = try XCTUnwrap(
            fixture.packet.packet.candidates.first?.variant
        )
        let sourceTemplate = try XCTUnwrap(
            fixture.catalog.entries.first {
                $0.game == candidate.game
            }
        )
        let injected = CatalogCarEntry(
            id: "fh6-2098-different-unused-id",
            game: candidate.game,
            year: candidate.vehicle.year,
            make: candidate.vehicle.make.uppercased(),
            model: candidate.vehicle.model.uppercased(),
            stock: candidate.vehicle.stock,
            verificationStatus: .officialRoster,
            sources: sourceTemplate.sources
        )
        let changed = CarCatalogSnapshot(
            schemaVersion: fixture.catalog.schemaVersion,
            revision: fixture.catalog.revision,
            reviewedAt: fixture.catalog.reviewedAt,
            entries: fixture.catalog.entries + [injected]
        )

        XCTAssertEqual(
            fixture.packet.packet.candidates[0].variant
                .catalogComparison.status,
            .absent
        )
        XCTAssertThrowsError(
            try StockCatalogCurationPreflightExporter()
                .makeArtifact(
                    packetCanonicalJSON:
                        fixture.packet.canonicalJSON,
                    baseCatalog: changed,
                    request: fixture.request
                )
        ) {
            XCTAssertEqual(
                $0 as? StockCatalogCurationPreflightError,
                .candidateNotEligible
            )
        }
    }

    func testBaseCatalogMustPassFullBundledSemanticValidation()
        throws {
        let fixture = try makeFixture()
        let original = try XCTUnwrap(fixture.catalog.entries.first)
        let invalid = CatalogCarEntry(
            id: original.id,
            game: original.game,
            year: original.year,
            make: original.make,
            model: original.model,
            stock: original.stock,
            verificationStatus: original.verificationStatus,
            sources: []
        )
        let catalog = CarCatalogSnapshot(
            schemaVersion: fixture.catalog.schemaVersion,
            revision: fixture.catalog.revision,
            reviewedAt: fixture.catalog.reviewedAt,
            entries: [invalid]
                + Array(fixture.catalog.entries.dropFirst())
        )
        XCTAssertThrowsError(
            try StockCatalogCurationPreflightExporter()
                .makeArtifact(
                    packetCanonicalJSON:
                        fixture.packet.canonicalJSON,
                    baseCatalog: catalog,
                    request: fixture.request
                )
        ) {
            XCTAssertEqual(
                $0 as? StockCatalogCurationPreflightError,
                .invalidBaseCatalog
            )
        }
    }

    func testRightsReviewAndProposalValidationFailClosed()
        throws {
        let fixture = try makeFixture()
        let badURL = replacingRequest(
            fixture.request,
            rights: rights(sourceURL: "http://example.com/roster")
        )
        XCTAssertThrowsError(
            try StockCatalogCurationPreflightExporter()
                .makeArtifact(
                    packetCanonicalJSON:
                        fixture.packet.canonicalJSON,
                    baseCatalog: fixture.catalog,
                    request: badURL
                )
        ) {
            XCTAssertEqual(
                $0 as? StockCatalogCurationPreflightError,
                .invalidSourceRightsReview
            )
        }

        let badDigest = replacingRequest(
            fixture.request,
            rights: rights(
                digest: String(repeating: "A", count: 64)
            )
        )
        XCTAssertThrowsError(
            try StockCatalogCurationPreflightExporter()
                .makeArtifact(
                    packetCanonicalJSON:
                        fixture.packet.canonicalJSON,
                    baseCatalog: fixture.catalog,
                    request: badDigest
                )
        )

        let wrongID = replacingRequest(
            fixture.request,
            proposal: .init(
                catalogID: "fh5-2024-test-stock-car",
                revision: "catalog-next",
                verificationStatus: .officialRoster
            )
        )
        XCTAssertThrowsError(
            try StockCatalogCurationPreflightExporter()
                .makeArtifact(
                    packetCanonicalJSON:
                        fixture.packet.canonicalJSON,
                    baseCatalog: fixture.catalog,
                    request: wrongID
                )
        ) {
            XCTAssertEqual(
                $0 as? StockCatalogCurationPreflightError,
                .invalidProposal
            )
        }

        let collidingID = replacingRequest(
            fixture.request,
            proposal: .init(
                catalogID:
                    try XCTUnwrap(
                        fixture.catalog.entries.first {
                            $0.game == .fh6
                        }
                    ).id,
                revision: "catalog-next",
                verificationStatus: .officialRoster
            )
        )
        XCTAssertThrowsError(
            try StockCatalogCurationPreflightExporter()
                .makeArtifact(
                    packetCanonicalJSON:
                        fixture.packet.canonicalJSON,
                    baseCatalog: fixture.catalog,
                    request: collidingID
                )
        ) {
            XCTAssertEqual(
                $0 as? StockCatalogCurationPreflightError,
                .invalidProposal
            )
        }
    }

    func testCompatibleLicenseRightsReviewIsAccepted() throws {
        let fixture = try makeFixture()
        let request = replacingRequest(
            fixture.request,
            rights: rights(basis: .compatibleLicense)
        )
        let artifact = try StockCatalogCurationPreflightExporter()
            .makeArtifact(
                packetCanonicalJSON:
                    fixture.packet.canonicalJSON,
                baseCatalog: fixture.catalog,
                request: request
            )
        XCTAssertEqual(
            artifact.preflight.identitySourceRightsReview
                .rightsBasis,
            .compatibleLicense
        )
    }

    func testEveryRightsConfirmationIsIndependentlyRequired()
        throws {
        let fixture = try makeFixture()
        let reviews = [
            rights(rightsReviewed: false),
            rights(noFacts: false),
            rights(noProse: false),
            rights(noMedia: false)
        ]
        for review in reviews {
            XCTAssertThrowsError(
                try StockCatalogCurationPreflightExporter()
                    .makeArtifact(
                        packetCanonicalJSON:
                            fixture.packet.canonicalJSON,
                        baseCatalog: fixture.catalog,
                        request: replacingRequest(
                            fixture.request,
                            rights: review
                        )
                    )
            ) {
                XCTAssertEqual(
                    $0 as? StockCatalogCurationPreflightError,
                    .invalidSourceRightsReview
                )
            }
        }
    }

    func testUnsafeRightsMetadataFailsClosed() throws {
        let fixture = try makeFixture()
        let reviews = [
            rights(title: " Bad title"),
            rights(accessedOn: "2026-02-30"),
            rights(reference: "Bad\nreference")
        ]
        for review in reviews {
            XCTAssertThrowsError(
                try StockCatalogCurationPreflightExporter()
                    .makeArtifact(
                        packetCanonicalJSON:
                            fixture.packet.canonicalJSON,
                        baseCatalog: fixture.catalog,
                        request: replacingRequest(
                            fixture.request,
                            rights: review
                        )
                    )
            ) {
                XCTAssertEqual(
                    $0 as? StockCatalogCurationPreflightError,
                    .invalidSourceRightsReview
                )
            }
        }
    }

    func testUnknownFieldsTamperNoncanonicalAndOversizeFailClosed()
        throws {
        let fixture = try makeFixture()
        let artifact = try make(fixture)
        let exporter = StockCatalogCurationPreflightExporter()
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: artifact.canonicalJSON
            ) as? [String: Any]
        )
        object["unknown"] = true
        XCTAssertThrowsError(
            try exporter.validate(
                JSONSerialization.data(
                    withJSONObject: object,
                    options: [.sortedKeys, .prettyPrinted]
                ),
                packetCanonicalJSON:
                    fixture.packet.canonicalJSON,
                baseCatalog: fixture.catalog
            )
        ) {
            XCTAssertEqual(
                $0 as? StockCatalogCurationPreflightError,
                .unknownFields
            )
        }

        object.removeValue(forKey: "unknown")
        object["reviewBoundary"] = "changed"
        let tampered = try JSONSerialization.data(
            withJSONObject: object,
            options: [
                .sortedKeys, .prettyPrinted, .withoutEscapingSlashes
            ]
        )
        XCTAssertThrowsError(
            try exporter.validate(
                tampered,
                packetCanonicalJSON:
                    fixture.packet.canonicalJSON,
                baseCatalog: fixture.catalog
            )
        )

        let compact = try JSONSerialization.data(
            withJSONObject: JSONSerialization.jsonObject(
                with: artifact.canonicalJSON
            ),
            options: [.sortedKeys]
        )
        XCTAssertThrowsError(
            try exporter.validate(
                compact,
                packetCanonicalJSON:
                    fixture.packet.canonicalJSON,
                baseCatalog: fixture.catalog
            )
        ) {
            XCTAssertEqual(
                $0 as? StockCatalogCurationPreflightError,
                .nonCanonicalJSON
            )
        }

        XCTAssertThrowsError(
            try exporter.validate(
                Data(
                    repeating: 0x20,
                    count:
                        StockCatalogCurationPreflightExporter
                        .maximumPayloadBytes + 1
                ),
                packetCanonicalJSON:
                    fixture.packet.canonicalJSON,
                baseCatalog: fixture.catalog
            )
        ) {
            XCTAssertEqual(
                $0 as? StockCatalogCurationPreflightError,
                .payloadTooLarge
            )
        }
    }

    func testArtifactPrivacyAndCatalogIsolation() throws {
        let before = try BundledCarCatalog.load().get()
        let fixture = try makeFixture(catalog: before)
        let artifact = try make(fixture)
        let text = try XCTUnwrap(
            String(data: artifact.canonicalJSON, encoding: .utf8)
        )
        for forbidden in [
            "submissionID", "permissionReceiptID",
            "canonicalExportJSON", "reviewedAt",
            "providerConfiguration", "tuningRuleset",
            "tirePressure", "screenshotData", "deviceID"
        ] {
            XCTAssertFalse(text.contains(forbidden), forbidden)
        }
        XCTAssertTrue(
            artifact.preflight.privacyExclusions.contains(
                "provider-configuration"
            )
        )
        XCTAssertTrue(
            artifact.preflight.privacyExclusions.contains(
                "screenshots"
            )
        )
        XCTAssertEqual(
            try BundledCarCatalog.load().get(),
            before
        )
    }

    // MARK: - Fixtures

    private typealias Fixture = (
        catalog: CarCatalogSnapshot,
        packet: StockCatalogMaintainerReviewPacketArtifact,
        request: StockCatalogCurationPreflightRequest
    )

    private func makeFixture(
        catalog suppliedCatalog: CarCatalogSnapshot? = nil,
        seedOffset: Int = 0
    ) throws -> Fixture {
        let catalog =
            try suppliedCatalog ?? BundledCarCatalog.load().get()
        let first = try reviewedEntry(
            for: record(seed: 1 + seedOffset)
        )
        let second = try reviewedEntry(
            for: record(seed: 2 + seedOffset),
            existing: [first]
        )
        let packet = try StockCatalogMaintainerReviewPacketExporter()
            .makeArtifact(
                reviewedEntries: [second, first],
                baseCatalog: catalog
            )
        return (
            catalog,
            packet,
            try request(for: packet.packet)
        )
    }

    private func make(
        _ fixture: Fixture,
        replacingDecisions decisions:
            [StockCatalogCurationFieldDecision]? = nil
    ) throws -> StockCatalogCurationPreflightArtifact {
        let request = StockCatalogCurationPreflightRequest(
            groupID: fixture.request.groupID,
            variantID: fixture.request.variantID,
            fieldDecisions:
                decisions ?? fixture.request.fieldDecisions,
            identitySourceRightsReview:
                fixture.request.identitySourceRightsReview,
            proposal: fixture.request.proposal,
            allPermissionedEvidenceUsedForEveryField: true,
            separateReleaseReviewConfirmed: true
        )
        return try StockCatalogCurationPreflightExporter()
            .makeArtifact(
                packetCanonicalJSON: fixture.packet.canonicalJSON,
                baseCatalog: fixture.catalog,
                request: request
            )
    }

    private func request(
        for packet: StockCatalogMaintainerReviewPacket,
        allowSingleObservation: Bool = false
    ) throws -> StockCatalogCurationPreflightRequest {
        let candidate = try XCTUnwrap(packet.candidates.first)
        if !allowSingleObservation {
            XCTAssertGreaterThanOrEqual(
                candidate.variant.observations.count,
                2
            )
        }
        return request(
            groupID: candidate.groupID,
            variant: candidate.variant
        )
    }

    private func request(
        groupID: String,
        variant: StockCatalogMaintainerEvidenceVariant
    ) -> StockCatalogCurationPreflightRequest {
        let decisions = StockCatalogContributionValidator
            .expectedFields.map { field in
                StockCatalogCurationFieldDecision(
                    field: field,
                    observationDigests:
                        variant.observations.filter {
                            $0.fields.contains { $0.field == field }
                        }.map(\.observationDigest).sorted()
                )
            }
        return .init(
            groupID: groupID,
            variantID: variant.variantID,
            fieldDecisions: decisions,
            identitySourceRightsReview: rights(),
            proposal: .init(
                catalogID: "fh6-2024-test-stock-car",
                revision: "catalog-next",
                verificationStatus: .officialRoster
            ),
            allPermissionedEvidenceUsedForEveryField: true,
            separateReleaseReviewConfirmed: true
        )
    }

    private func replacingRequest(
        _ value: StockCatalogCurationPreflightRequest,
        rights:
            StockCatalogIdentitySourceRightsReview? = nil,
        proposal: StockCatalogCurationProposal? = nil
    ) -> StockCatalogCurationPreflightRequest {
        .init(
            groupID: value.groupID,
            variantID: value.variantID,
            fieldDecisions: value.fieldDecisions,
            identitySourceRightsReview:
                rights ?? value.identitySourceRightsReview,
            proposal: proposal ?? value.proposal,
            allPermissionedEvidenceUsedForEveryField: true,
            separateReleaseReviewConfirmed: true
        )
    }

    private func rights(
        title: String = "Official roster",
        sourceURL: String = "https://example.com/official-roster",
        accessedOn: String = "2026-07-25",
        basis: StockCatalogIdentityRightsBasis =
            .explicitPermission,
        reference: String = "Permission archive 2026-07",
        digest: String = String(repeating: "a", count: 64),
        rightsReviewed: Bool = true,
        noFacts: Bool = true,
        noProse: Bool = true,
        noMedia: Bool = true
    ) -> StockCatalogIdentitySourceRightsReview {
        .init(
            sourceTitle: title,
            sourceURL: sourceURL,
            accessedOn: accessedOn,
            rightsBasis: basis,
            rightsEvidenceReference: reference,
            rightsEvidenceSHA256: digest,
            rightsIndependentlyReviewed: rightsReviewed,
            noSourceFactsCopied: noFacts,
            noSourceProseCopied: noProse,
            noSourceMediaCopied: noMedia
        )
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
            now: Date(timeIntervalSince1970: 1_800_100_000)
        )
    }

    private func record(
        seed: Int,
        performanceIndex: Int = 710,
        matching entry: CatalogCarEntry? = nil
    ) -> StockCatalogContributionRecord {
        let observed =
            Date(timeIntervalSince1970: 1_800_000_000 + Double(seed))
        let fields =
            StockCatalogContributionValidator.expectedFields
        let vehicle = entry.map {
            StockCatalogContributionVehicle(
                year: $0.year,
                make: $0.make,
                model: $0.model,
                stock: $0.stock
            )
        } ?? .init(
            year: 2024,
            make: "Test",
            model: "Stock Car",
            stock: .init(
                performanceIndex: performanceIndex,
                performanceClass: .s1,
                drivetrain: .awd,
                weightPounds: 3_200,
                frontWeightPercent: 52,
                peakHorsepower: 500,
                peakTorqueFootPounds: 450
            )
        )
        return .init(
            id: uuid(seed),
            submissionID: uuid(1_000 + seed),
            permissionReceiptID: uuid(2_000 + seed),
            capturedAt: observed,
            game: entry?.game ?? .fh6,
            gameVersion: "1.0.100.0",
            platform: .xboxSeries,
            vehicle: vehicle,
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

    private func uuid(_ value: Int) -> UUID {
        UUID(
            uuidString: String(
                format: "00000000-0000-0000-0000-%012d",
                abs(value) % 1_000_000_000_000
            )
        )!
    }
}
