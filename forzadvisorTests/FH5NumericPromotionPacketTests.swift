import SwiftData
import XCTest
@testable import forzadvisor

final class FH5NumericPromotionPacketTests: FH5ResearchTestCase {
    func testNumericPromotionReviewPacketRoundTripsAtExactSyntheticThreshold()
        async throws {
        // Synthetic-only evidence: these records do not represent real players
        // and cannot establish accuracy or authorize production behavior.
        let fixture = try await makeCandidateOutcomeFixture(
            reusePermitted: true
        )
        let records = try makePromotionReviewRecords(
            fixture: fixture,
            outcomes: Array(
                repeating: .variantPreferred,
                count: 8
            ) + [
                .noClearDifference,
                .inconclusive
            ]
        )
        let exchange = FH5CandidateOutcomeExchange()
        let reviewedData = try exchange.makeExport(
            from: records.last!,
            explicitShareConfirmed: true
        ).deterministicJSON()
        let reviewed = try FH5CandidateOutcomeReviewEntry
            .locallyReviewed(
                canonicalExportJSON: reviewedData,
                expectedArtifact: fixture.artifact,
                reviewerConfirmedDirectReceiptAndReusePermission:
                    true,
                now: capturedAt
            )
        let exporter = FH5NumericPromotionReviewPacketExporter()
        let packet = try exporter.prepare(
            candidateArtifact: fixture.artifact,
            localRecords: Array(records.dropLast()),
            reviewedEntries: [reviewed]
        )
        let data = try packet.deterministicJSON()
        let reordered = try exporter.prepare(
            candidateArtifact: fixture.artifact,
            localRecords: Array(records.dropLast().reversed()),
            reviewedEntries: [reviewed]
        )

        XCTAssertEqual(try reordered.deterministicJSON(), data)
        XCTAssertEqual(
            try exporter.validate(
                data,
                candidateArtifact: fixture.artifact
            ),
            packet
        )
        XCTAssertEqual(packet.status, .eligibleForMaintainerReview)
        XCTAssertEqual(packet.counts.uniqueSessionCount, 10)
        XCTAssertEqual(packet.counts.variantPreferredCount, 8)
        XCTAssertEqual(packet.counts.nonDecisiveCount, 2)
        XCTAssertEqual(packet.counts.baselinePreferredCount, 0)
        XCTAssertEqual(packet.counts.distinctUTCDayCount, 2)
        XCTAssertEqual(packet.counts.localCount, 9)
        XCTAssertEqual(packet.counts.reviewedCount, 1)
        XCTAssertEqual(
            packet.outcomeThreshold,
            .currentExperimental
        )
        XCTAssertFalse(packet.accuracyClaimEstablished)
        XCTAssertFalse(packet.automaticPromotionPermitted)
        XCTAssertFalse(packet.productionRegistrationPermitted)
        XCTAssertFalse(packet.numericOutputPermitted)
        XCTAssertTrue(packet.independentMaintainerReviewRequired)
        XCTAssertTrue(
            FH5TrustedNumericRulesetRegistry.production.isEmpty
        )
        XCTAssertEqual(fixture.plan.purpose, .fh5BuildPlan)
        XCTAssertTrue(fixture.plan.sections.isEmpty)
        XCTAssertNil(fixture.plan.providerInfo)
        XCTAssertNil(fixture.plan.rulesetReference)
    }
    func testNumericPromotionReviewPacketFailsClosedForThresholdAndBadInput()
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
            localRecords: Array(
                repeating: records[0],
                count:
                    FH5NumericPromotionReviewPacket
                        .maximumInputCount + 1
            ),
            reviewedEntries: []
        )) {
            XCTAssertEqual(
                $0 as? FH5NumericPromotionReviewPacketError,
                .tooManyLocalRecords
            )
        }

        XCTAssertThrowsError(try exporter.prepare(
            candidateArtifact: fixture.artifact,
            localRecords: Array(records.dropLast()),
            reviewedEntries: []
        )) {
            XCTAssertEqual(
                $0 as? FH5NumericPromotionReviewPacketError,
                .insufficientEvidence
            )
        }
        let invalid = copyExperiment(
            records[0],
            schemaVersion: records[0].schemaVersion,
            consentVersion: records[0].consentVersion,
            candidateBinding: records[0].candidateBinding,
            contentFingerprint: String(repeating: "b", count: 64)
        )
        XCTAssertThrowsError(try exporter.prepare(
            candidateArtifact: fixture.artifact,
            localRecords: records + [invalid],
            reviewedEntries: []
        )) {
            XCTAssertEqual(
                $0 as? FH5NumericPromotionReviewPacketError,
                .invalidLocalEvidence
            )
        }

        let data = try FH5CandidateOutcomeExchange().makeExport(
            from: records[0],
            explicitShareConfirmed: true
        ).deterministicJSON()
        let entry = try FH5CandidateOutcomeReviewEntry
            .locallyReviewed(
                canonicalExportJSON: data,
                expectedArtifact: fixture.artifact,
                reviewerConfirmedDirectReceiptAndReusePermission:
                    true,
                now: capturedAt
            )
        let invalidEntry = FH5CandidateOutcomeReviewEntry(
            id: entry.id,
            importedAt:
                entry.importedAt.addingTimeInterval(1),
            canonicalExportJSON: entry.canonicalExportJSON,
            permission: entry.permission
        )
        XCTAssertThrowsError(try exporter.prepare(
            candidateArtifact: fixture.artifact,
            localRecords: records,
            reviewedEntries: [invalidEntry]
        )) {
            XCTAssertEqual(
                $0 as? FH5NumericPromotionReviewPacketError,
                .invalidReviewedEvidence
            )
        }
    }
    func testNumericPromotionReviewPacketPreparationEnforcesOutboundSizeLimit()
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

        XCTAssertThrowsError(
            try FH5NumericPromotionReviewPacketExporter(
                maximumPayloadBytes: 1
            ).prepare(
                candidateArtifact: fixture.artifact,
                localRecords: records,
                reviewedEntries: []
            )
        ) {
            XCTAssertEqual(
                $0 as? FH5NumericPromotionReviewPacketError,
                .payloadTooLarge
            )
        }
    }
}
