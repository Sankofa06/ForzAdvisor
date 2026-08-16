import SwiftData
import XCTest
@testable import forzadvisor

final class FH5CandidateOutcomeExchangeTests: FH5ResearchTestCase {
    func testCandidateOutcomeExchangeIsDistinctCanonicalAndDeidentified()
        async throws {
        let fixture = try await makeCandidateOutcomeFixture(
            reusePermitted: true
        )
        let exchange = FH5CandidateOutcomeExchange()

        XCTAssertThrowsError(try exchange.makeExport(
            from: fixture.record,
            explicitShareConfirmed: false
        )) {
            XCTAssertEqual(
                $0 as? FH5CandidateOutcomeExchangeError,
                .shareConfirmationRequired
            )
        }
        let export = try exchange.makeExport(
            from: fixture.record,
            explicitShareConfirmed: true
        )
        let data = try export.deterministicJSON()
        let validated = try exchange.validate(data)
        XCTAssertTrue(
            try exchange.matches(
                validated,
                locallyRegeneratedArtifact: fixture.artifact
            )
        )
        XCTAssertEqual(
            export.associationFingerprint.count,
            64
        )
        XCTAssertEqual(export.contentFingerprint.count, 64)
        XCTAssertEqual(
            export.association.rulesetReference,
            fixture.artifact.candidateBinding
                .rulesetReference
        )
        XCTAssertThrowsError(try fixture.record.publicExport()) {
            XCTAssertEqual(
                $0 as? FH5ControlledExperimentIssue,
                .candidateBoundExportUnsupported
            )
        }

        let json = try XCTUnwrap(
            String(data: data, encoding: .utf8)
        )
        for excluded in [
            fixture.record.recordID.uuidString,
            fixture.record.planRevisionFingerprint,
            fixture.record.researchContentFingerprint,
            fixture.artifact.candidateBinding
                .generatedCandidateFingerprint
        ] {
            XCTAssertFalse(json.contains(excluded))
        }
        XCTAssertFalse(json.contains("planRevisionFingerprint"))
        XCTAssertFalse(json.contains("researchContentFingerprint"))
        XCTAssertFalse(json.contains("candidateBinding"))
        XCTAssertFalse(json.contains("generatedCandidateFingerprint"))
        XCTAssertFalse(json.contains("providerInfo"))
        XCTAssertTrue(json.contains("\"knowledgeRevision\""))
        XCTAssertTrue(json.contains("\"provenanceIDs\""))
        XCTAssertFalse(json.contains("\"sourceManifests\""))
        XCTAssertEqual(
            export.privacyExclusions,
            FH5CandidateOutcomeExport.privacyExclusions
        )

        var nonCanonical = data
        nonCanonical.append(0x20)
        XCTAssertThrowsError(try exchange.validate(nonCanonical)) {
            XCTAssertEqual(
                $0 as? FH5CandidateOutcomeExchangeError,
                .nonCanonicalJSON
            )
        }
        let tamperedJSON = json.replacingOccurrences(
            of: export.contentFingerprint,
            with: String(repeating: "b", count: 64)
        )
        XCTAssertThrowsError(
            try exchange.validate(Data(tamperedJSON.utf8))
        ) {
            XCTAssertEqual(
                $0 as? FH5CandidateOutcomeExchangeError,
                .invalidContentFingerprint
            )
        }
        XCTAssertThrowsError(try exchange.validate(
            Data(
                repeating: 0x20,
                count:
                    FH5CandidateOutcomeExchange
                        .maximumPayloadBytes + 1
            )
        )) {
            XCTAssertEqual(
                $0 as? FH5CandidateOutcomeExchangeError,
                .payloadTooLarge
            )
        }

        let secondRecord = try FH5CandidateTrialCoordinator()
            .makeRecord(
                tune: fixture.plan,
                savedTune: fixture.plan,
                isStreaming: false,
                researchRecords: [fixture.research],
                reviewInputs: fixture.reviewInputs,
                submission: FH5CandidateTrialSubmission(
                    capture: experimentCapture(
                        field: .frontTirePressure,
                        candidate:
                            fixture.artifact.change
                                .candidateValue,
                        reusePermitted: true
                    ),
                    lockedArtifact: fixture.artifact
                ),
                recordID: UUID(),
                submissionID: UUID(),
                permissionReceiptID: UUID(),
                createdAt:
                    fixture.record.createdAt
                        .addingTimeInterval(60)
            )
        XCTAssertEqual(
            try exchange.makeExport(
                from: secondRecord,
                explicitShareConfirmed: true
            ).associationFingerprint,
            export.associationFingerprint
        )

        let noReuse = try await makeCandidateOutcomeFixture(
            reusePermitted: false
        )
        XCTAssertThrowsError(try exchange.makeExport(
            from: noReuse.record,
            explicitShareConfirmed: true
        )) {
            XCTAssertEqual(
                $0 as? FH5CandidateOutcomeExchangeError,
                .reuseNotPermitted
            )
        }
    }
    func testCandidateOutcomeReviewRequiresPermissionAndExactRegeneration()
        async throws {
        let fixture = try await makeCandidateOutcomeFixture(
            reusePermitted: true
        )
        let data = try FH5CandidateOutcomeExchange()
            .makeExport(
                from: fixture.record,
                explicitShareConfirmed: true
            ).deterministicJSON()

        XCTAssertThrowsError(
            try FH5CandidateOutcomeReviewEntry.locallyReviewed(
                canonicalExportJSON: data,
                expectedArtifact: fixture.artifact,
                reviewerConfirmedDirectReceiptAndReusePermission:
                    false
            )
        ) {
            XCTAssertEqual(
                $0 as? FH5CandidateOutcomeExchangeError,
                .permissionNotConfirmed
            )
        }

        let entry = try FH5CandidateOutcomeReviewEntry
            .locallyReviewed(
                canonicalExportJSON: data,
                expectedArtifact: fixture.artifact,
                reviewerConfirmedDirectReceiptAndReusePermission:
                    true,
                now: capturedAt
            )
        XCTAssertTrue(
            FH5CandidateOutcomeExchange()
                .isValidReviewEntry(entry)
        )

        let wheel = try FH5CandidateTrialCoordinator().generate(
            tune: fixture.plan,
            savedTune: fixture.plan,
            isStreaming: false,
            researchRecords: [fixture.research],
            reviewInputs: fixture.reviewInputs,
            input: .wheel,
            surface: .dry
        )
        XCTAssertThrowsError(
            try FH5CandidateOutcomeReviewEntry.locallyReviewed(
                canonicalExportJSON: data,
                expectedArtifact: wheel,
                reviewerConfirmedDirectReceiptAndReusePermission:
                    true
            )
        ) {
            XCTAssertEqual(
                $0 as? FH5CandidateOutcomeExchangeError,
                .candidateMismatch
            )
        }
    }
}
