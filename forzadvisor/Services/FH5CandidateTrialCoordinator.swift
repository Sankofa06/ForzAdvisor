//
//  FH5CandidateTrialCoordinator.swift
//  forzadvisor
//
//  Collection-only orchestration for the experimental FH5 candidate trial.
//  This type cannot produce or mutate a TuneResult.
//

import Foundation

struct FH5CandidateTrialSubmission: Equatable, Sendable {
    let capture: FH5ControlledExperimentCapture
    let lockedArtifact: FH5GeneratedCandidateArtifact
}

struct FH5CandidateTrialCoordinator {
    private let registry =
        FH5TrustedNumericRulesetRegistry.experimentalCandidateCollection

    func generate(
        tune: TuneResult,
        savedTune: TuneResult?,
        isStreaming: Bool,
        researchRecords: [FH5ResearchObservationRecord],
        reviewInputs: [FH5ResearchReviewInput],
        input: ValidationInput,
        surface: ValidationSurface
    ) throws -> FH5GeneratedCandidateArtifact {
        try FH5CleanRoomDirectionalCandidateGenerator().generate(
            tune: tune,
            savedTune: savedTune,
            isStreaming: isStreaming,
            researchRecords: researchRecords,
            reviewInputs: reviewInputs,
            targetSymptom: .pushesWide,
            input: input,
            surface: surface,
            algorithmID: .cleanRoomDirectionalV1,
            registry: registry
        )
    }

    func makeRecord(
        tune: TuneResult,
        savedTune: TuneResult?,
        isStreaming: Bool,
        researchRecords: [FH5ResearchObservationRecord],
        reviewInputs: [FH5ResearchReviewInput],
        submission: FH5CandidateTrialSubmission,
        recordID: UUID = UUID(),
        submissionID: UUID = UUID(),
        permissionReceiptID: UUID = UUID(),
        createdAt: Date = .now
    ) throws -> FH5ControlledExperimentRecord {
        let capture = submission.capture
        let regenerated = try generate(
            tune: tune,
            savedTune: savedTune,
            isStreaming: isStreaming,
            researchRecords: researchRecords,
            reviewInputs: reviewInputs,
            input: capture.input,
            surface: capture.surface
        )
        guard regenerated == submission.lockedArtifact else {
            throw FH5ControlledExperimentIssue.candidateArtifactMismatch
        }
        return try FH5ControlledExperimentFactory().makeCandidateBound(
            tune: tune,
            savedTune: savedTune,
            isStreaming: isStreaming,
            researchRecords: researchRecords,
            capture: capture,
            candidateArtifact: submission.lockedArtifact,
            registry: registry,
            recordID: recordID,
            submissionID: submissionID,
            permissionReceiptID: permissionReceiptID,
            createdAt: createdAt
        )
    }
}
