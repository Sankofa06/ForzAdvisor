import SwiftData
import XCTest
@testable import forzadvisor

extension FH5ResearchTestCase {
    func makePromotionReviewRecords(
        fixture: (
            plan: TuneResult,
            research: FH5ResearchObservationRecord,
            reviewInputs: [FH5ResearchReviewInput],
            artifact: FH5GeneratedCandidateArtifact,
            record: FH5ControlledExperimentRecord
        ),
        outcomes: [FH5ExperimentOutcome]
    ) throws -> [FH5ControlledExperimentRecord] {
        try outcomes.enumerated().map { index, outcome in
            try makePromotionReviewRecord(
                fixture: fixture,
                outcome: outcome,
                submissionID: UUID(),
                permissionReceiptID: UUID(),
                createdAt: capturedAt.addingTimeInterval(
                    Double(
                        (index < outcomes.count / 2 ? 0 : 86_400)
                            + index * 60
                    )
                )
            )
        }
    }

    func makePromotionReviewRecord(
        fixture: (
            plan: TuneResult,
            research: FH5ResearchObservationRecord,
            reviewInputs: [FH5ResearchReviewInput],
            artifact: FH5GeneratedCandidateArtifact,
            record: FH5ControlledExperimentRecord
        ),
        outcome: FH5ExperimentOutcome,
        submissionID: UUID,
        permissionReceiptID: UUID,
        createdAt: Date
    ) throws -> FH5ControlledExperimentRecord {
        try FH5CandidateTrialCoordinator().makeRecord(
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
                    outcome: outcome
                ),
                lockedArtifact: fixture.artifact
            ),
            submissionID: submissionID,
            permissionReceiptID: permissionReceiptID,
            createdAt: createdAt
        )
    }

    func makeCandidateOutcomeFixture(
        reusePermitted: Bool,
        submissionID: UUID = UUID(),
        permissionReceiptID: UUID = UUID(),
        createdAt: Date? = nil,
        fh5EntryOffset: Int = 0
    ) async throws -> (
        plan: TuneResult,
        research: FH5ResearchObservationRecord,
        reviewInputs: [FH5ResearchReviewInput],
        artifact: FH5GeneratedCandidateArtifact,
        record: FH5ControlledExperimentRecord
    ) {
        let plan = try await makePlan(
            upgradeBuild: "3.688.109.0",
            fh5EntryOffset: fh5EntryOffset
        )
        let research = try FH5ResearchObservationFactory().make(
            tune: plan,
            savedTune: plan,
            isStreaming: false,
            capture: validCapture(
                drivetrain: plan.request.car.drivetrain,
                gearCount: 6,
                availability: .adjustable
            ),
            capturedAt: capturedAt
        )
        let reviewInputs = try reviewedReplicationInputs(
            plan: plan
        )
        let coordinator = FH5CandidateTrialCoordinator()
        let artifact = try coordinator.generate(
            tune: plan,
            savedTune: plan,
            isStreaming: false,
            researchRecords: [research],
            reviewInputs: reviewInputs,
            input: .controller,
            surface: .dry
        )
        let record = try coordinator.makeRecord(
            tune: plan,
            savedTune: plan,
            isStreaming: false,
            researchRecords: [research],
            reviewInputs: reviewInputs,
            submission: FH5CandidateTrialSubmission(
                capture: experimentCapture(
                    field: .frontTirePressure,
                    candidate: artifact.change.candidateValue,
                    reusePermitted: reusePermitted
                ),
                lockedArtifact: artifact
            ),
            submissionID: submissionID,
            permissionReceiptID: permissionReceiptID,
            createdAt:
                createdAt
                ?? capturedAt.addingTimeInterval(120)
        )
        return (
            plan, research, reviewInputs, artifact, record
        )
    }

    @MainActor
    func persistCandidatePrerequisites(
        fixture: (
            plan: TuneResult,
            research: FH5ResearchObservationRecord,
            reviewInputs: [FH5ResearchReviewInput],
            artifact: FH5GeneratedCandidateArtifact,
            record: FH5ControlledExperimentRecord
        ),
        in savedTune: SavedTune
    ) throws {
        try savedTune.appendFH5ResearchObservationRecord(
            fixture.research
        )
        for input in fixture.reviewInputs {
            let entry = try FH5ResearchReviewEntry.locallyReviewed(
                canonicalExportJSON: input.exportJSON,
                reviewerConfirmedDirectReceiptAndReusePermission:
                    true,
                now: capturedAt
            )
            try savedTune.appendFH5ResearchReviewEntry(entry)
        }
    }

    func experimentCapture(
        field: TuneFieldID,
        candidate: Double,
        reusePermitted: Bool = false,
        outcome: FH5ExperimentOutcome = .variantPreferred
    ) -> FH5ControlledExperimentCapture {
        FH5ControlledExperimentCapture(
            field: field,
            candidateValue: candidate,
            input: .controller,
            surface: .dry,
            targetSymptom: .pushesWide,
            outcome: outcome,
            sameRouteAndConditionsConfirmed: true,
            sameAssistsAndInputConfirmed: true,
            onlyDeclaredFieldChangedConfirmed: true,
            sequenceCompletedConfirmed: true,
            stockValuesRestoredConfirmed: true,
            firstPartyAuthorshipConfirmed: true,
            localStoragePermitted: true,
            deidentifiedReusePermitted: reusePermitted
        )
    }

    func makeBoundExperiments(
        plan: TuneResult,
        research: FH5ResearchObservationRecord,
        registry: FH5TrustedNumericRulesetRegistry,
        registration: FH5NumericRulesetRegistration,
        outcomes: [FH5ExperimentOutcome],
        dates: [Date]? = nil,
        reuseExcludedIndex: Int? = nil
    ) throws -> [FH5ControlledExperimentRecord] {
        let dates = dates ?? outcomes.indices.map { index in
            let dayOffset = index < outcomes.count / 2 ? 0 : 86_400
            return capturedAt.addingTimeInterval(
                Double(dayOffset + index * 60)
            )
        }
        precondition(dates.count == outcomes.count)
        return try outcomes.enumerated().map { index, outcome in
            try FH5ControlledExperimentFactory().makeCandidateBoundForTesting(
                tune: plan,
                savedTune: plan,
                isStreaming: false,
                researchRecords: [research],
                capture: experimentCapture(
                    field: try XCTUnwrap(research.controls.first?.field),
                    candidate: 49,
                    reusePermitted: index != reuseExcludedIndex,
                    outcome: outcome
                ),
                candidateAlgorithmID: registration.algorithmID,
                registry: registry,
                createdAt: dates[index]
            )
        }
    }

    func replicatedReviewReport(
        for record: FH5ResearchObservationRecord
    ) -> FH5ResearchReviewReport {
        FH5ResearchReviewReport(
            receivedCount: 2,
            verifiedUniqueObservationCount: 2,
            invalidCount: 0,
            quarantinedCount: 0,
            duplicateCount: 0,
            administrativeConflictCount: 0,
            receiptReplayCount: 0,
            groups: [
                FH5ResearchReviewGroup(
                    associationFingerprint:
                        "synthetic-matching-association",
                    association: FH5ResearchReviewAssociation(
                        platform: record.platform,
                        gameVersion: record.gameVersion,
                        vehicle: record.vehicle,
                        tireCompoundDisplayName:
                            record.tireCompoundDisplayName,
                        forwardGearCount: record.forwardGearCount
                    ),
                    observationCount: 2,
                    measurementVariantCount: 1,
                    measurementFingerprint: FH5ResearchReviewIngestor()
                        .measurementFingerprint(for: record.controls),
                    status: .replicated
                )
            ]
        )
    }

    func copyExperiment(
        _ record: FH5ControlledExperimentRecord,
        schemaVersion: Int,
        consentVersion: String,
        candidateBinding: FH5RulesetCandidateBinding?,
        recordID: UUID? = nil,
        submissionID: UUID? = nil,
        permissionReceiptID: UUID? = nil,
        contentFingerprint: String? = nil
    ) -> FH5ControlledExperimentRecord {
        FH5ControlledExperimentRecord(
            schemaVersion: schemaVersion,
            consentVersion: consentVersion,
            protocolVersion: record.protocolVersion,
            recordID: recordID ?? record.recordID,
            submissionID: submissionID ?? record.submissionID,
            permissionReceiptID:
                permissionReceiptID ?? record.permissionReceiptID,
            createdAt: record.createdAt,
            game: record.game,
            planRevisionFingerprint: record.planRevisionFingerprint,
            researchContentFingerprint:
                record.researchContentFingerprint,
            measurementFingerprint: record.measurementFingerprint,
            context: record.context,
            change: record.change,
            targetSymptom: record.targetSymptom,
            outcome: record.outcome,
            attestations: record.attestations,
            candidateBinding: candidateBinding,
            contentFingerprint:
                contentFingerprint ?? record.contentFingerprint
        )
    }

    func makeExperimentalRegistration(
        sourceManifests: [FH5NumericRulesetSourceManifest]? = nil
    ) throws -> FH5NumericRulesetRegistration {
        let algorithmID = FH5ExperimentalAlgorithmID.cleanRoomDirectionalV1
        let sources = sourceManifests ?? [
            FH5NumericRulesetSourceManifest(
                sourceID: "first-party.clean-room",
                sourceVersion: "1",
                owner: "ForzAdvisor",
                rightsBasis: .firstPartyCleanRoom,
                rightsEvidenceID: "internal.clean-room-record",
                usagePermission: .permitted
            )
        ]
        let fingerprint = FH5NumericRulesetSourceManifest.fingerprint(
            for: sources
        ) ?? String(repeating: "0", count: 64)
        let reference = try XCTUnwrap(TuneRulesetReference(
            descriptor: TuneRulesetDescriptor(
                id: algorithmID.rawValue,
                game: .fh5,
                schemaVersion: 1,
                algorithmVersion: "1",
                knowledgeRevision: fingerprint,
                validationStatus: .experimental,
                provenanceIDs: sources.map(\.sourceID).sorted()
            )
        ))
        return FH5NumericRulesetRegistration(
            algorithmID: algorithmID,
            reference: reference,
            sourceManifests: sources,
            outcomeThreshold: .currentExperimental
        )
    }
}
