import SwiftData
import XCTest
@testable import forzadvisor

final class FH5NumericPromotionValidationTests: FH5ResearchTestCase {
    func testNumericPromotionReviewPacketRejectsDuplicateConflictAndReplay()
        async throws {
        let fixture = try await makeCandidateOutcomeFixture(
            reusePermitted: true
        )
        let exporter = FH5NumericPromotionReviewPacketExporter()
        let records = try makePromotionReviewRecords(
            fixture: fixture,
            outcomes: Array(
                repeating: .variantPreferred,
                count: 10
            )
        )
        XCTAssertThrowsError(try exporter.prepare(
            candidateArtifact: fixture.artifact,
            localRecords: records + [records[0]],
            reviewedEntries: []
        )) {
            XCTAssertEqual(
                $0 as? FH5NumericPromotionReviewPacketError,
                .duplicateAmbiguity
            )
        }
        let duplicateData = try FH5CandidateOutcomeExchange()
            .makeExport(
                from: records[0],
                explicitShareConfirmed: true
            ).deterministicJSON()
        let duplicateReview = try FH5CandidateOutcomeReviewEntry
            .locallyReviewed(
                canonicalExportJSON: duplicateData,
                expectedArtifact: fixture.artifact,
                reviewerConfirmedDirectReceiptAndReusePermission:
                    true
            )
        XCTAssertThrowsError(try exporter.prepare(
            candidateArtifact: fixture.artifact,
            localRecords: records,
            reviewedEntries: [duplicateReview]
        )) {
            XCTAssertEqual(
                $0 as? FH5NumericPromotionReviewPacketError,
                .duplicateAmbiguity
            )
        }

        let conflict = try makePromotionReviewRecord(
            fixture: fixture,
            outcome: .baselinePreferred,
            submissionID: records[0].submissionID,
            permissionReceiptID: UUID(),
            createdAt:
                records[0].createdAt.addingTimeInterval(30)
        )
        XCTAssertThrowsError(try exporter.prepare(
            candidateArtifact: fixture.artifact,
            localRecords: records + [conflict],
            reviewedEntries: []
        )) {
            XCTAssertEqual(
                $0 as? FH5NumericPromotionReviewPacketError,
                .submissionConflict
            )
        }

        let receiptReplay = try makePromotionReviewRecord(
            fixture: fixture,
            outcome: .variantPreferred,
            submissionID: UUID(),
            permissionReceiptID:
                records[0].permissionReceiptID,
            createdAt:
                records[0].createdAt.addingTimeInterval(30)
        )
        XCTAssertThrowsError(try exporter.prepare(
            candidateArtifact: fixture.artifact,
            localRecords: records + [receiptReplay],
            reviewedEntries: []
        )) {
            XCTAssertEqual(
                $0 as? FH5NumericPromotionReviewPacketError,
                .permissionReceiptReplay
            )
        }

        let sessionReplay = try makePromotionReviewRecord(
            fixture: fixture,
            outcome: records[0].outcome,
            submissionID: UUID(),
            permissionReceiptID: UUID(),
            createdAt: records[0].createdAt
        )
        XCTAssertThrowsError(try exporter.prepare(
            candidateArtifact: fixture.artifact,
            localRecords: records + [sessionReplay],
            reviewedEntries: []
        )) {
            XCTAssertEqual(
                $0 as? FH5NumericPromotionReviewPacketError,
                .sessionSemanticReplay
            )
        }
    }
    func testNumericPromotionReviewPacketRejectsStaleUnknownNoncanonicalAndTamper()
        async throws {
        let fixture = try await makeCandidateOutcomeFixture(
            reusePermitted: true
        )
        let records = try makePromotionReviewRecords(
            fixture: fixture,
            outcomes: Array(
                repeating: .variantPreferred,
                count: 10
            )
        )
        let exporter = FH5NumericPromotionReviewPacketExporter()
        let packet = try exporter.prepare(
            candidateArtifact: fixture.artifact,
            localRecords: records,
            reviewedEntries: []
        )
        let data = try packet.deterministicJSON()

        XCTAssertThrowsError(try exporter.validate(
            Data(),
            candidateArtifact: fixture.artifact
        )) {
            XCTAssertEqual(
                $0 as? FH5NumericPromotionReviewPacketError,
                .emptyPayload
            )
        }
        XCTAssertThrowsError(try exporter.validate(
            Data(
                repeating: 0x20,
                count:
                    FH5NumericPromotionReviewPacket
                        .maximumPayloadBytes + 1
            ),
            candidateArtifact: fixture.artifact
        )) {
            XCTAssertEqual(
                $0 as? FH5NumericPromotionReviewPacketError,
                .payloadTooLarge
            )
        }
        let foreign = try await makeCandidateOutcomeFixture(
            reusePermitted: true,
            fh5EntryOffset: 1
        )
        XCTAssertThrowsError(try exporter.validate(
            data,
            candidateArtifact: foreign.artifact
        )) {
            XCTAssertEqual(
                $0 as? FH5NumericPromotionReviewPacketError,
                .staleOrForeignCandidate
            )
        }
        XCTAssertThrowsError(try exporter.prepare(
            candidateArtifact: foreign.artifact,
            localRecords: records,
            reviewedEntries: []
        )) {
            XCTAssertEqual(
                $0 as? FH5NumericPromotionReviewPacketError,
                .staleOrForeignCandidate
            )
        }
        let untrustedRegistration = try makeExperimentalRegistration()
        let untrustedRegistry = try FH5TrustedNumericRulesetRegistry(
            validating: [untrustedRegistration]
        )
        let untrustedArtifact = try FH5ControlledExperimentFactory()
            .makeCandidateArtifactForTesting(
                tune: fixture.plan,
                savedTune: fixture.plan,
                isStreaming: false,
                researchRecords: [fixture.research],
                capture: experimentCapture(
                    field: .frontTirePressure,
                    candidate:
                        fixture.artifact.change.candidateValue,
                    reusePermitted: true
                ),
                candidateAlgorithmID:
                    untrustedRegistration.algorithmID,
                registry: untrustedRegistry
            )
        XCTAssertThrowsError(try exporter.prepare(
            candidateArtifact: untrustedArtifact,
            localRecords: records,
            reviewedEntries: []
        )) {
            XCTAssertEqual(
                $0 as? FH5NumericPromotionReviewPacketError,
                .unregisteredCandidate
            )
        }

        var noncanonical = data
        noncanonical.append(0x20)
        XCTAssertThrowsError(try exporter.validate(
            noncanonical,
            candidateArtifact: fixture.artifact
        )) {
            XCTAssertEqual(
                $0 as? FH5NumericPromotionReviewPacketError,
                .nonCanonicalJSON
            )
        }
        let json = try XCTUnwrap(
            String(data: data, encoding: .utf8)
        )
        let unknown = json.replacingOccurrences(
            of: "{\n",
            with: "{\n  \"unknown\": true,\n",
            options: [],
            range: json.startIndex..<json.index(
                json.startIndex,
                offsetBy: 2
            )
        )
        XCTAssertThrowsError(try exporter.validate(
            Data(unknown.utf8),
            candidateArtifact: fixture.artifact
        )) {
            XCTAssertEqual(
                $0 as? FH5NumericPromotionReviewPacketError,
                .unknownRootField
            )
        }
        let tampered = json.replacingOccurrences(
            of: packet.artifactFingerprint,
            with: String(repeating: "b", count: 64)
        )
        XCTAssertThrowsError(try exporter.validate(
            Data(tampered.utf8),
            candidateArtifact: fixture.artifact
        )) {
            XCTAssertEqual(
                $0 as? FH5NumericPromotionReviewPacketError,
                .invalidArtifactFingerprint
            )
        }
        let unsafeBoundary = json.replacingOccurrences(
            of: "\"numericOutputPermitted\" : false",
            with: "\"numericOutputPermitted\" : true"
        )
        XCTAssertNotEqual(unsafeBoundary, json)
        XCTAssertThrowsError(try exporter.validate(
            Data(unsafeBoundary.utf8),
            candidateArtifact: fixture.artifact
        )) {
            XCTAssertEqual(
                $0 as? FH5NumericPromotionReviewPacketError,
                .invalidStructure
            )
        }
    }
}
