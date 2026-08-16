import SwiftData
import XCTest
@testable import forzadvisor

final class FH5CandidateOutcomeReviewTests: FH5ResearchTestCase {
    func testCandidateOutcomeCollectionPrefersLocalAndQuarantinesSemanticReplay()
        async throws {
        let fixture = try await makeCandidateOutcomeFixture(
            reusePermitted: true,
            submissionID: UUID(),
            permissionReceiptID: UUID(),
            createdAt: capturedAt
        )
        let exchange = FH5CandidateOutcomeExchange()
        let association = try exchange.associationFingerprint(
            for: fixture.artifact
        )
        let duplicateData = try exchange.makeExport(
            from: fixture.record,
            explicitShareConfirmed: true
        ).deterministicJSON()
        let duplicateEntry = try FH5CandidateOutcomeReviewEntry
            .locallyReviewed(
                canonicalExportJSON: duplicateData,
                expectedArtifact: fixture.artifact,
                reviewerConfirmedDirectReceiptAndReusePermission:
                    true,
                now: capturedAt.addingTimeInterval(5)
            )
        let second = try FH5CandidateTrialCoordinator()
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
                        reusePermitted: true,
                        outcome: .noClearDifference
                    ),
                    lockedArtifact: fixture.artifact
                ),
                submissionID: UUID(),
                permissionReceiptID: UUID(),
                createdAt:
                    capturedAt.addingTimeInterval(86_400)
            )
        let report = FH5CandidateOutcomeCollectionEvaluator()
            .evaluate(
                localRecords: [fixture.record, second],
                reviewedEntries: [duplicateEntry],
                matchingAssociationFingerprint: association
            )
        XCTAssertEqual(report.receivedCount, 3)
        XCTAssertEqual(report.verifiedUniqueSessionCount, 2)
        XCTAssertEqual(report.localCount, 2)
        XCTAssertEqual(report.reviewedCount, 0)
        XCTAssertEqual(report.duplicateCount, 1)
        XCTAssertEqual(report.distinctUTCDayCount, 2)
        XCTAssertEqual(report.variantPreferredCount, 1)
        XCTAssertEqual(report.noClearDifferenceCount, 1)
        XCTAssertEqual(report.quarantinedCount, 0)

        let semanticClone = try FH5CandidateTrialCoordinator()
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
                submissionID: UUID(),
                permissionReceiptID: UUID(),
                createdAt: fixture.record.createdAt
            )
        let replayReport =
            FH5CandidateOutcomeCollectionEvaluator().evaluate(
                localRecords: [
                    fixture.record, semanticClone
                ],
                reviewedEntries: [],
                matchingAssociationFingerprint: association
            )
        XCTAssertEqual(
            replayReport.verifiedUniqueSessionCount,
            0
        )
        XCTAssertEqual(replayReport.semanticReplayCount, 2)
        XCTAssertEqual(replayReport.quarantinedCount, 2)

        let reversedReplay =
            FH5CandidateOutcomeCollectionEvaluator().evaluate(
                localRecords: [
                    semanticClone, fixture.record
                ],
                reviewedEntries: [],
                matchingAssociationFingerprint: association
            )
        XCTAssertEqual(reversedReplay.verifiedUniqueSessionCount, 0)
        XCTAssertEqual(reversedReplay.semanticReplayCount, 2)

        let changedOutcomeClone = try FH5CandidateTrialCoordinator()
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
                            fixture.artifact.change.candidateValue,
                        reusePermitted: true,
                        outcome: .baselinePreferred
                    ),
                    lockedArtifact: fixture.artifact
                ),
                submissionID: UUID(),
                permissionReceiptID: UUID(),
                createdAt: fixture.record.createdAt
            )
        for records in [
            [fixture.record, changedOutcomeClone],
            [changedOutcomeClone, fixture.record]
        ] {
            let alteredReport =
                FH5CandidateOutcomeCollectionEvaluator().evaluate(
                    localRecords: records,
                    reviewedEntries: [],
                    matchingAssociationFingerprint: association
                )
            XCTAssertEqual(
                alteredReport.verifiedUniqueSessionCount,
                0
            )
            XCTAssertEqual(alteredReport.semanticReplayCount, 2)
            XCTAssertEqual(alteredReport.quarantinedCount, 2)
        }
    }
    func testCandidateOutcomeShareGateRequiresExactInternalBinding()
        async throws {
        let fixture = try await makeCandidateOutcomeFixture(
            reusePermitted: true
        )
        var authorization =
            FH5CandidateOutcomeShareAuthorization()
        XCTAssertFalse(authorization.consume())
        authorization.confirm()
        XCTAssertTrue(authorization.consume())
        XCTAssertFalse(authorization.consume())

        let secondResearch = try FH5ResearchObservationFactory().make(
            tune: fixture.plan,
            savedTune: fixture.plan,
            isStreaming: false,
            capture: validCapture(
                drivetrain: fixture.plan.request.car.drivetrain,
                gearCount: 6,
                availability: .adjustable
            ),
            capturedAt: capturedAt.addingTimeInterval(30)
        )
        let secondArtifact = try FH5CandidateTrialCoordinator()
            .generate(
                tune: fixture.plan,
                savedTune: fixture.plan,
                isStreaming: false,
                researchRecords: [secondResearch],
                reviewInputs: fixture.reviewInputs,
                input: .controller,
                surface: .dry
            )
        let exchange = FH5CandidateOutcomeExchange()
        XCTAssertEqual(
            try exchange.associationFingerprint(
                for: fixture.artifact
            ),
            try exchange.associationFingerprint(
                for: secondArtifact
            )
        )
        XCTAssertNotEqual(
            fixture.artifact.candidateBinding,
            secondArtifact.candidateBinding
        )
        XCTAssertTrue(
            exchange.canShare(
                fixture.record,
                currentArtifact: fixture.artifact
            )
        )
        XCTAssertFalse(
            exchange.canShare(
                fixture.record,
                currentArtifact: secondArtifact
            )
        )

        var staleAuthorization =
            FH5CandidateOutcomeShareAuthorization()
        staleAuthorization.confirm()
        XCTAssertThrowsError(
            try exchange.prepareShare(
                from: fixture.record,
                currentArtifact: secondArtifact,
                authorization: &staleAuthorization
            )
        ) {
            XCTAssertEqual(
                $0 as? FH5CandidateOutcomeExchangeError,
                .candidateMismatch
            )
        }
        XCTAssertFalse(staleAuthorization.isConfirmed)
        XCTAssertThrowsError(
            try exchange.prepareShare(
                from: fixture.record,
                currentArtifact: fixture.artifact,
                authorization: &staleAuthorization
            )
        ) {
            XCTAssertEqual(
                $0 as? FH5CandidateOutcomeExchangeError,
                .shareConfirmationRequired
            )
        }

        var currentAuthorization =
            FH5CandidateOutcomeShareAuthorization()
        currentAuthorization.confirm()
        _ = try exchange.prepareShare(
            from: fixture.record,
            currentArtifact: fixture.artifact,
            authorization: &currentAuthorization
        )
        XCTAssertFalse(currentAuthorization.isConfirmed)
    }
}
