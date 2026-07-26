//
//  StockCatalogContributionTests.swift
//  forzadvisorTests
//

import XCTest
@testable import forzadvisor

final class StockCatalogContributionTests: XCTestCase {
    func testCompleteFieldCoverageAndAttestationsAreRequired() {
        let valid = record()
        XCTAssertTrue(StockCatalogContributionValidator().isValid(valid))
        XCTAssertEqual(
            valid.reviewedFields,
            CatalogDataField.allCases.sorted {
                $0.rawValue < $1.rawValue
            }
        )

        let missing = record(
            reviewedFields: Array(valid.reviewedFields.dropLast()),
            fieldAttestations:
                Array(valid.fieldAttestations.dropLast())
        )
        XCTAssertFalse(
            StockCatalogContributionValidator().isValid(missing)
        )

        var duplicated = valid.fieldAttestations
        duplicated[1] = duplicated[0]
        XCTAssertFalse(
            StockCatalogContributionValidator().isValid(
                record(fieldAttestations: duplicated)
            )
        )

        let wrongSession = valid.fieldAttestations.map {
            StockCatalogFieldAttestation(
                field: $0.field,
                observationScreen: $0.observationScreen,
                directlyReadInGame: $0.directlyReadInGame,
                untouchedStockConfirmed:
                    $0.untouchedStockConfirmed,
                englishUnitsConfirmedWhenRelevant:
                    $0.englishUnitsConfirmedWhenRelevant,
                observedAt: $0.observedAt.addingTimeInterval(1)
            )
        }
        XCTAssertFalse(
            StockCatalogContributionValidator().isValid(
                record(fieldAttestations: wrongSession)
            )
        )
        let missingEnglishUnits = valid.fieldAttestations.map {
            StockCatalogFieldAttestation(
                field: $0.field,
                observationScreen: $0.observationScreen,
                directlyReadInGame: $0.directlyReadInGame,
                untouchedStockConfirmed:
                    $0.untouchedStockConfirmed,
                englishUnitsConfirmedWhenRelevant:
                    $0.field != .weightPounds,
                observedAt: $0.observedAt
            )
        }
        XCTAssertFalse(
            StockCatalogContributionValidator().isValid(
                record(fieldAttestations: missingEnglishUnits)
            )
        )
        XCTAssertFalse(
            StockCatalogContributionValidator().isValid(
                record(stock: .init(
                    performanceIndex: 710,
                    performanceClass: .s1,
                    drivetrain: .awd,
                    weightPounds: 1_499,
                    frontWeightPercent: 52,
                    peakHorsepower: 500,
                    peakTorqueFootPounds: 450
                ))
            )
        )
    }

    func testReuseRightsDefaultOffAndAllFourGateExport() throws {
        let local = record(rights: .init())
        XCTAssertFalse(local.rights.allGranted)
        XCTAssertThrowsError(
            try StockCatalogContributionExporter()
                .canonicalJSON(for: local)
        ) {
            XCTAssertEqual(
                $0 as? StockCatalogContributionError,
                .exportRightsNotGranted
            )
        }

        let exported = try StockCatalogContributionExporter()
            .canonicalJSON(for: record())
        let validated = try StockCatalogContributionIngestor()
            .validate(exported)
        XCTAssertTrue(validated.export.rights.allGranted)
        XCTAssertEqual(
            validated.export.privacyExclusions,
            StockCatalogContributionPolicy.privacyExclusions
        )
    }

    func testCanonicalExportIsDeterministicAndContainsOnlyAllowListedFacts()
        throws {
        let contribution = record()
        let first = try StockCatalogContributionExporter()
            .canonicalJSON(for: contribution)
        let second = try StockCatalogContributionExporter()
            .canonicalJSON(for: contribution)
        XCTAssertEqual(first, second)
        XCTAssertEqual(
            try StockCatalogContributionIngestor()
                .validate(first).canonicalExportDigest,
            try StockCatalogContributionIngestor()
                .validate(second).canonicalExportDigest
        )

        let text = try XCTUnwrap(
            String(data: first, encoding: .utf8)
        )
        for forbidden in [
            "notes", "screenshot", "ocr", "tuneValue",
            "tuneResult", "provider", "apiKey", "deviceID",
            "account", "location", "shareDestination"
        ] {
            if StockCatalogContributionPolicy.privacyExclusions
                .contains(where: {
                    $0.localizedCaseInsensitiveContains(forbidden)
                }) {
                continue
            }
            XCTAssertFalse(
                text.localizedCaseInsensitiveContains(forbidden),
                forbidden
            )
        }
    }

    func testIngestorRejectsTamperingUnknownFieldsAndOversize()
        throws {
        let data = try StockCatalogContributionExporter()
            .canonicalJSON(for: record())
        var export = try JSONDecoder.iso8601.decode(
            StockCatalogContributionExport.self,
            from: data
        )
        export = StockCatalogContributionExport(
            schemaVersion: export.schemaVersion,
            consentVersion: export.consentVersion,
            submissionID: export.submissionID,
            permissionReceiptID: export.permissionReceiptID,
            capturedAt: export.capturedAt,
            game: export.game,
            gameVersion: export.gameVersion,
            platform: export.platform,
            vehicle: .init(
                year: export.vehicle.year,
                make: export.vehicle.make,
                model: export.vehicle.model,
                stock: .init(
                    performanceIndex:
                        export.vehicle.stock.performanceIndex + 1,
                    performanceClass:
                        export.vehicle.stock.performanceClass,
                    drivetrain: export.vehicle.stock.drivetrain,
                    weightPounds: export.vehicle.stock.weightPounds,
                    frontWeightPercent:
                        export.vehicle.stock.frontWeightPercent,
                    peakHorsepower:
                        export.vehicle.stock.peakHorsepower,
                    peakTorqueFootPounds:
                        export.vehicle.stock.peakTorqueFootPounds
                )
            ),
            reviewedFields: export.reviewedFields,
            fieldAttestations: export.fieldAttestations,
            exactUntouchedStockConfirmed:
                export.exactUntouchedStockConfirmed,
            personallyReadFromGameConfirmed:
                export.personallyReadFromGameConfirmed,
            firstPartyAuthorshipConfirmed:
                export.firstPartyAuthorshipConfirmed,
            rights: export.rights,
            privacyExclusions: export.privacyExclusions,
            contentFingerprint: export.contentFingerprint
        )
        let tampered = try StockCatalogContributionIngestor
            .canonicalData(for: export)
        XCTAssertThrowsError(
            try StockCatalogContributionIngestor().validate(tampered)
        ) {
            XCTAssertEqual(
                $0 as? StockCatalogContributionError,
                .invalidFingerprint
            )
        }

        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data)
                as? [String: Any]
        )
        object["unknown"] = true
        let unknown = try JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys]
        )
        XCTAssertThrowsError(
            try StockCatalogContributionIngestor().validate(unknown)
        ) {
            XCTAssertEqual(
                $0 as? StockCatalogContributionError,
                .unknownFields
            )
        }

        XCTAssertThrowsError(
            try StockCatalogContributionIngestor().validate(
                Data(
                    repeating: 0,
                    count: StockCatalogContributionIngestor
                        .maximumPayloadBytes + 1
                )
            )
        ) {
            XCTAssertEqual(
                $0 as? StockCatalogContributionError,
                .payloadTooLarge
            )
        }
    }

    func testReviewPermissionsDedupeMatchingAndFieldConflicts()
        throws {
        let firstData = try StockCatalogContributionExporter()
            .canonicalJSON(for: record())
        XCTAssertThrowsError(
            try StockCatalogContributionReviewEntry.locallyReviewed(
                canonicalExportJSON: firstData,
                reviewerConfirmedDirectReceipt: false,
                reviewerConfirmedTesterAuthoredStructuredFacts: true,
                reviewerConfirmedStructuredReusePermission: true,
                reviewerConfirmedCatalogCurationPermission: true,
                reviewerConfirmedBundledRedistributionPermission: true,
                existing: []
            )
        )
        XCTAssertThrowsError(
            try StockCatalogContributionReviewEntry.locallyReviewed(
                canonicalExportJSON: firstData,
                reviewerConfirmedDirectReceipt: true,
                reviewerConfirmedTesterAuthoredStructuredFacts: true,
                reviewerConfirmedStructuredReusePermission: true,
                reviewerConfirmedCatalogCurationPermission: false,
                reviewerConfirmedBundledRedistributionPermission: true,
                existing: []
            )
        ) {
            XCTAssertEqual(
                $0 as? StockCatalogContributionError,
                .completeRightsNotConfirmed
            )
        }
        let firstEntry = try StockCatalogContributionReviewEntry
            .locallyReviewed(
                canonicalExportJSON: firstData,
                reviewerConfirmedDirectReceipt: true,
                reviewerConfirmedTesterAuthoredStructuredFacts: true,
                reviewerConfirmedStructuredReusePermission: true,
                reviewerConfirmedCatalogCurationPermission: true,
                reviewerConfirmedBundledRedistributionPermission: true,
                existing: []
            )
        let ingestor = StockCatalogContributionIngestor()
        let evaluator = StockCatalogContributionReviewEvaluator()
        XCTAssertEqual(
            evaluator.disposition(
                for: Data("not-json".utf8),
                existing: []
            ),
            .excluded
        )
        let first = try ingestor.validate(firstData)
        XCTAssertEqual(
            evaluator.disposition(for: first, existing: [firstEntry]),
            .exactDuplicate
        )

        let matchingData = try StockCatalogContributionExporter()
            .canonicalJSON(for: record(
                submissionID: UUID(),
                permissionReceiptID: UUID()
            ))
        XCTAssertEqual(
            evaluator.disposition(
                for: try ingestor.validate(matchingData),
                existing: [firstEntry]
            ),
            .matchingObservation
        )

        let crossPlatformData =
            try StockCatalogContributionExporter()
            .canonicalJSON(for: record(
                submissionID: UUID(),
                permissionReceiptID: UUID(),
                platform: .windowsPC
            ))
        XCTAssertEqual(
            evaluator.disposition(
                for: try ingestor.validate(crossPlatformData),
                existing: [firstEntry]
            ),
            .received
        )

        let conflictingData = try StockCatalogContributionExporter()
            .canonicalJSON(for: record(
                submissionID: UUID(),
                permissionReceiptID: UUID(),
                stock:
                    StockCatalogContributionTests.stock(
                        performanceIndex: 720
                    )
            ))
        XCTAssertEqual(
            evaluator.disposition(
                for: try ingestor.validate(conflictingData),
                existing: [firstEntry]
            ),
            .conflictingObservation(fields: [.performanceIndex])
        )

        let replayedSubmission = try StockCatalogContributionExporter()
            .canonicalJSON(for: record(
                permissionReceiptID: UUID(),
                stock:
                    StockCatalogContributionTests.stock(
                        performanceIndex: 720
                    )
            ))
        XCTAssertEqual(
            evaluator.disposition(
                for: try ingestor.validate(replayedSubmission),
                existing: [firstEntry]
            ),
            .excluded
        )
    }

    func testDedicatedStoreRoundTripsAndMalformedDataFailsClosed()
        throws {
        let suite = "StockCatalogContributionTests.\(UUID())"
        let defaults = try XCTUnwrap(
            UserDefaults(suiteName: suite)
        )
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = StockCatalogContributionStore(defaults: defaults)
        let contribution = record()
        let reviewed = try StockCatalogContributionReviewEntry
            .locallyReviewed(
                canonicalExportJSON:
                    StockCatalogContributionExporter()
                    .canonicalJSON(for: contribution),
                reviewerConfirmedDirectReceipt: true,
                reviewerConfirmedTesterAuthoredStructuredFacts: true,
                reviewerConfirmedStructuredReusePermission: true,
                reviewerConfirmedCatalogCurationPermission: true,
                reviewerConfirmedBundledRedistributionPermission: true,
                existing: []
            )
        let snapshot = StockCatalogContributionStoreSnapshot(
            captured: [contribution],
            reviewed: [reviewed],
            recoveredFromMalformedData: false
        )
        try store.save(snapshot)
        XCTAssertEqual(store.load(), snapshot)

        defaults.set(
            Data("malformed".utf8),
            forKey: StockCatalogContributionStore.storageKey
        )
        let recovered = store.load()
        XCTAssertTrue(recovered.captured.isEmpty)
        XCTAssertTrue(recovered.reviewed.isEmpty)
        XCTAssertTrue(recovered.recoveredFromMalformedData)

        let invalid = record(
            reviewedFields: [.identity],
            fieldAttestations: [record().fieldAttestations[0]]
        )
        defaults.set(
            try JSONEncoder().encode(TestStoreEnvelope(
                schemaVersion: 1,
                captured: [invalid],
                reviewed: []
            )),
            forKey: StockCatalogContributionStore.storageKey
        )
        let invalidRecovered = store.load()
        XCTAssertTrue(invalidRecovered.captured.isEmpty)
        XCTAssertTrue(invalidRecovered.recoveredFromMalformedData)
    }

    func testConfirmationsInvalidateForNewDraftAndPayloadAndResetAfterUse() {
        var capture = StockCatalogCaptureConfirmationState(
            exactStockConfirmed: true,
            personallyReadConfirmed: true,
            englishUnitsConfirmed: true,
            authorshipConfirmed: true,
            localStorageConfirmed: true,
            testerFactsRight: true,
            reuseRight: true,
            curationRight: true,
            redistributionRight: true
        )
        let grantedCapture = capture
        capture.invalidateIfDraftChanged(from: "draft-a", to: "draft-a")
        XCTAssertEqual(capture, grantedCapture)
        capture.invalidateIfDraftChanged(from: "draft-a", to: "draft-b")
        XCTAssertEqual(capture, .init())

        var review = StockCatalogReviewConfirmationState(
            directReceiptConfirmed: true,
            testerFactsConfirmed: true,
            reuseConfirmed: true,
            curationConfirmed: true,
            redistributionConfirmed: true
        )
        let grantedReview = review
        review.invalidateIfPayloadChanged(
            from: "payload-a",
            to: "payload-a"
        )
        XCTAssertEqual(review, grantedReview)
        review.invalidateIfPayloadChanged(
            from: "payload-a",
            to: "payload-b"
        )
        XCTAssertEqual(review, .init())

        capture = grantedCapture
        capture.reset()
        review = grantedReview
        review.reset()
        XCTAssertEqual(capture, .init())
        XCTAssertEqual(review, .init())
    }

    func testReadableStoreEnvelopeRecoversValidCapturedAndReviewedSiblings()
        throws {
        let suite = "StockCatalogSiblingRecovery.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = StockCatalogContributionStore(defaults: defaults)
        let validCaptured = record()
        let invalidCaptured = record(
            reviewedFields: [.identity],
            fieldAttestations: [record().fieldAttestations[0]]
        )
        let validData = try StockCatalogContributionExporter()
            .canonicalJSON(for: validCaptured)
        let validReviewed = try StockCatalogContributionReviewEntry
            .locallyReviewed(
                canonicalExportJSON: validData,
                reviewerConfirmedDirectReceipt: true,
                reviewerConfirmedTesterAuthoredStructuredFacts: true,
                reviewerConfirmedStructuredReusePermission: true,
                reviewerConfirmedCatalogCurationPermission: true,
                reviewerConfirmedBundledRedistributionPermission: true,
                existing: []
            )
        let invalidReviewed = StockCatalogContributionReviewEntry(
            id: UUID(),
            canonicalExportJSON: validData,
            permission: .init(
                directReceiptConfirmed: true,
                testerAuthoredStructuredFactsConfirmed: true,
                structuredReusePermissionConfirmed: true,
                catalogCurationPermissionConfirmed: true,
                bundledRedistributionPermissionConfirmed: false,
                reviewedAt: Date(timeIntervalSince1970: 1_735_689_600)
            ),
            disposition: .received
        )
        defaults.set(
            try JSONEncoder().encode(TestStoreEnvelope(
                schemaVersion: 1,
                captured: [invalidCaptured, validCaptured],
                reviewed: [validReviewed, invalidReviewed]
            )),
            forKey: StockCatalogContributionStore.storageKey
        )

        let recovered = store.load()
        XCTAssertEqual(recovered.captured, [validCaptured])
        XCTAssertEqual(recovered.reviewed, [validReviewed])
        XCTAssertTrue(recovered.recoveredFromMalformedData)
    }

    func testComparisonIdentityNormalizesCaseUnicodeDiacriticsAndWhitespace()
        throws {
        let firstData = try StockCatalogContributionExporter()
            .canonicalJSON(for: record(
                gameVersion: "BUILD ONE",
                make: "Toyota",
                model: "PÓRSCHE"
            ))
        let firstEntry = try reviewedEntry(firstData)
        let equivalentData = try StockCatalogContributionExporter()
            .canonicalJSON(for: record(
                submissionID: UUID(),
                permissionReceiptID: UUID(),
                gameVersion: "build one",
                make: "TOYOTA",
                model: "PO\u{301}RSCHE"
            ))
        let equivalent = try StockCatalogContributionIngestor()
            .validate(equivalentData)
        XCTAssertEqual(
            StockCatalogContributionReviewEvaluator()
                .disposition(for: equivalent, existing: [firstEntry]),
            .matchingObservation
        )
        XCTAssertEqual(
            equivalent.export.vehicle.make,
            "TOYOTA",
            "Comparison normalization must not rewrite exported facts."
        )
        XCTAssertEqual(
            StockCatalogContributionIngestor
                .comparisonNormalizedString("  TÓYOTA   MOTOR "),
            StockCatalogContributionIngestor
                .comparisonNormalizedString("to\u{301}yota motor")
        )
        XCTAssertFalse(
            StockCatalogContributionValidator().isValid(
                record(make: "  Toyota   Motor ")
            ),
            "Capture validation keeps requiring canonical display input."
        )
    }

    func testReviewEntryComputesDispositionAndRejectsExactDuplicates()
        throws {
        let firstData = try StockCatalogContributionExporter()
            .canonicalJSON(for: record())
        let first = try reviewedEntry(firstData)
        XCTAssertEqual(first.disposition, .received)

        XCTAssertThrowsError(
            try reviewedEntry(firstData, existing: [first])
        ) {
            XCTAssertEqual(
                $0 as? StockCatalogContributionError,
                .exactDuplicate
            )
        }

        let matchingData = try StockCatalogContributionExporter()
            .canonicalJSON(for: record(
                submissionID: UUID(),
                permissionReceiptID: UUID()
            ))
        let matching = try reviewedEntry(
            matchingData,
            existing: [first]
        )
        XCTAssertEqual(matching.disposition, .matchingObservation)
    }

    func testStoreRejectsCallerForgedDispositionAndDuplicateQueue()
        throws {
        let suite = "StockCatalogDispositionAuthority.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = StockCatalogContributionStore(defaults: defaults)
        let data = try StockCatalogContributionExporter()
            .canonicalJSON(for: record())
        let valid = try reviewedEntry(data)
        let forged = StockCatalogContributionReviewEntry(
            id: UUID(),
            canonicalExportJSON: data,
            permission: valid.permission,
            disposition: .conflictingObservation(
                fields: [.performanceIndex]
            )
        )

        XCTAssertThrowsError(
            try store.save(.init(
                captured: [],
                reviewed: [forged],
                recoveredFromMalformedData: false
            ))
        )
        XCTAssertThrowsError(
            try store.save(.init(
                captured: [],
                reviewed: [valid, valid],
                recoveredFromMalformedData: false
            ))
        )
        let explicitlyReclassified =
            StockCatalogContributionReviewQueue.reclassify([forged])
        XCTAssertTrue(explicitlyReclassified.changed)
        XCTAssertEqual(
            explicitlyReclassified.entries.first?.disposition,
            .received
        )
        XCTAssertNoThrow(
            try store.save(.init(
                captured: [],
                reviewed: explicitlyReclassified.entries,
                recoveredFromMalformedData: false
            ))
        )

        defaults.set(
            try JSONEncoder().encode(TestStoreEnvelope(
                schemaVersion: 1,
                captured: [],
                reviewed: [forged, valid]
            )),
            forKey: StockCatalogContributionStore.storageKey
        )
        let recovered = store.load()
        XCTAssertEqual(recovered.reviewed.count, 1)
        XCTAssertEqual(recovered.reviewed.first?.id, forged.id)
        XCTAssertEqual(recovered.reviewed.first?.disposition, .received)
        XCTAssertTrue(recovered.recoveredFromMalformedData)
    }

    func testQueueReclassificationAfterAnchorDeletionSavesAndReopens()
        throws {
        let suite = "StockCatalogAnchorDeletion.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = StockCatalogContributionStore(defaults: defaults)
        let a = try reviewedEntry(
            try StockCatalogContributionExporter().canonicalJSON(
                for: record()
            )
        )
        let b = try reviewedEntry(
            try StockCatalogContributionExporter().canonicalJSON(
                for: record(
                    submissionID: UUID(),
                    permissionReceiptID: UUID()
                )
            ),
            existing: [a]
        )
        let c = try reviewedEntry(
            try StockCatalogContributionExporter().canonicalJSON(
                for: record(
                    submissionID: UUID(),
                    permissionReceiptID: UUID(),
                    stock: Self.stock(performanceIndex: 720)
                )
            ),
            existing: [a, b]
        )
        XCTAssertEqual(b.disposition, .matchingObservation)
        XCTAssertEqual(
            c.disposition,
            .conflictingObservation(fields: [.performanceIndex])
        )

        let afterDeletion = StockCatalogContributionReviewQueue
            .reclassify([b, c])
        XCTAssertTrue(afterDeletion.changed)
        XCTAssertEqual(
            afterDeletion.entries.map(\.disposition),
            [
                .received,
                .conflictingObservation(fields: [.performanceIndex])
            ]
        )
        try store.save(.init(
            captured: [],
            reviewed: afterDeletion.entries,
            recoveredFromMalformedData: false
        ))
        let reopened = store.load()
        XCTAssertEqual(reopened.reviewed, afterDeletion.entries)
        XCTAssertFalse(reopened.recoveredFromMalformedData)
    }

    func testRecoverableLoadReclassifiesLaterSiblingsAfterInvalidAnchor()
        throws {
        let suite = "StockCatalogInvalidAnchorRecovery.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = StockCatalogContributionStore(defaults: defaults)
        let a = try reviewedEntry(
            try StockCatalogContributionExporter().canonicalJSON(
                for: record()
            )
        )
        let b = try reviewedEntry(
            try StockCatalogContributionExporter().canonicalJSON(
                for: record(
                    submissionID: UUID(),
                    permissionReceiptID: UUID()
                )
            ),
            existing: [a]
        )
        let c = try reviewedEntry(
            try StockCatalogContributionExporter().canonicalJSON(
                for: record(
                    submissionID: UUID(),
                    permissionReceiptID: UUID(),
                    stock: Self.stock(performanceIndex: 720)
                )
            ),
            existing: [a, b]
        )
        let invalidA = StockCatalogContributionReviewEntry(
            id: a.id,
            canonicalExportJSON: a.canonicalExportJSON,
            permission: .init(
                directReceiptConfirmed: false,
                testerAuthoredStructuredFactsConfirmed: true,
                structuredReusePermissionConfirmed: true,
                catalogCurationPermissionConfirmed: true,
                bundledRedistributionPermissionConfirmed: true,
                reviewedAt: a.permission.reviewedAt
            ),
            disposition: a.disposition
        )
        defaults.set(
            try JSONEncoder().encode(TestStoreEnvelope(
                schemaVersion: 1,
                captured: [],
                reviewed: [invalidA, b, c]
            )),
            forKey: StockCatalogContributionStore.storageKey
        )

        let recovered = store.load()
        XCTAssertEqual(
            recovered.reviewed.map(\.id),
            [b.id, c.id]
        )
        XCTAssertEqual(
            recovered.reviewed.map(\.disposition),
            [
                .received,
                .conflictingObservation(fields: [.performanceIndex])
            ]
        )
        XCTAssertTrue(recovered.recoveredFromMalformedData)
        XCTAssertNoThrow(
            try store.save(.init(
                captured: [],
                reviewed: recovered.reviewed,
                recoveredFromMalformedData: false
            ))
        )
    }

    func testConflictFieldUnionIsDeterministicAcrossExistingOrder()
        throws {
        let firstData = try StockCatalogContributionExporter()
            .canonicalJSON(for: record())
        let first = try reviewedEntry(firstData)
        let secondData = try StockCatalogContributionExporter()
            .canonicalJSON(for: record(
                submissionID: UUID(),
                permissionReceiptID: UUID(),
                stock: Self.stock(performanceIndex: 720)
            ))
        let second = try reviewedEntry(
            secondData,
            existing: [first]
        )
        let candidateData = try StockCatalogContributionExporter()
            .canonicalJSON(for: record(
                submissionID: UUID(),
                permissionReceiptID: UUID(),
                stock: Self.stock(weightPounds: 3_300)
            ))
        let candidate = try StockCatalogContributionIngestor()
            .validate(candidateData)
        let evaluator = StockCatalogContributionReviewEvaluator()
        let expected = StockCatalogReviewDisposition
            .conflictingObservation(
                fields: [.performanceIndex, .weightPounds]
            )

        XCTAssertEqual(
            evaluator.disposition(
                for: candidate,
                existing: [first, second]
            ),
            expected
        )
        XCTAssertEqual(
            evaluator.disposition(
                for: candidate,
                existing: [second, first]
            ),
            expected
        )
    }

    func testContributionQueueCannotChangeBundledCatalogOrActivateOutput()
        throws {
        let before = try BundledCarCatalog.load().get()
        let beforeFH6 = BundledCarCatalog.search(
            before,
            game: .fh6,
            query: ""
        )
        let suite = "StockCatalogIsolation.\(UUID())"
        let defaults = try XCTUnwrap(
            UserDefaults(suiteName: suite)
        )
        defer { defaults.removePersistentDomain(forName: suite) }
        try StockCatalogContributionStore(defaults: defaults).save(
            .init(
                captured: [record()],
                reviewed: [],
                recoveredFromMalformedData: false
            )
        )

        let after = try BundledCarCatalog.load().get()
        XCTAssertEqual(after.revision, before.revision)
        XCTAssertEqual(after.entries.count, before.entries.count)
        XCTAssertEqual(
            BundledCarCatalog.search(after, game: .fh6, query: ""),
            beforeFH6
        )
        XCTAssertFalse(
            StockCatalogContributionPolicy.collectionBoundary
                .localizedCaseInsensitiveContains("activate")
        )
        XCTAssertTrue(
            StockCatalogContributionPolicy.collectionBoundary
                .contains("never create a catalog entry")
        )
        XCTAssertTrue(
            StockCatalogContributionPolicy.collectionBoundary
                .contains("generate tuning")
        )
    }

    private func record(
        submissionID: UUID = UUID(
            uuidString: "11111111-1111-1111-1111-111111111111"
        )!,
        permissionReceiptID: UUID = UUID(
            uuidString: "22222222-2222-2222-2222-222222222222"
        )!,
        gameVersion: String = "1.0.100.0",
        platform: StockContributionPlatform = .xboxSeries,
        make: String = "Test",
        model: String = "Stock Car",
        stock: CatalogStockSpecifications =
            StockCatalogContributionTests.stock(),
        reviewedFields: [CatalogDataField]? = nil,
        fieldAttestations: [StockCatalogFieldAttestation]? = nil,
        rights: StockCatalogContributionRights = .init(
            testerAuthoredStructuredFacts: true,
            deidentifiedStructuredReuse: true,
            catalogCurationUse: true,
            futureBundledRedistribution: true
        )
    ) -> StockCatalogContributionRecord {
        let fields = reviewedFields
            ?? StockCatalogContributionValidator.expectedFields
        let observed = Date(timeIntervalSince1970: 1_800_000_000)
        return StockCatalogContributionRecord(
            id: UUID(
                uuidString: "33333333-3333-3333-3333-333333333333"
            )!,
            submissionID: submissionID,
            permissionReceiptID: permissionReceiptID,
            capturedAt: observed,
            game: .fh6,
            gameVersion: gameVersion,
            platform: platform,
            vehicle: .init(
                year: 2024,
                make: make,
                model: model,
                stock: stock
            ),
            reviewedFields: fields,
            fieldAttestations: fieldAttestations
                ?? fields.map {
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
            rights: rights
        )
    }

    private static func stock(
        performanceIndex: Int = 710,
        weightPounds: Int = 3_200
    ) -> CatalogStockSpecifications {
        .init(
            performanceIndex: performanceIndex,
            performanceClass: .s1,
            drivetrain: .awd,
            weightPounds: weightPounds,
            frontWeightPercent: 52,
            peakHorsepower: 500,
            peakTorqueFootPounds: 450
        )
    }

    private func reviewedEntry(
        _ data: Data,
        existing: [StockCatalogContributionReviewEntry] = []
    ) throws -> StockCatalogContributionReviewEntry {
        try StockCatalogContributionReviewEntry.locallyReviewed(
            canonicalExportJSON: data,
            reviewerConfirmedDirectReceipt: true,
            reviewerConfirmedTesterAuthoredStructuredFacts: true,
            reviewerConfirmedStructuredReusePermission: true,
            reviewerConfirmedCatalogCurationPermission: true,
            reviewerConfirmedBundledRedistributionPermission: true,
            existing: existing
        )
    }
}

private struct TestStoreEnvelope: Encodable {
    let schemaVersion: Int
    let captured: [StockCatalogContributionRecord]
    let reviewed: [StockCatalogContributionReviewEntry]
}

private extension JSONDecoder {
    static var iso8601: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
