//
//  FH5CleanRoomDirectionalCandidateGenerator.swift
//  forzadvisor
//
//  A registry-gated, one-variable FH5 research hypothesis. It produces only
//  an outcome-lab artifact; it never produces a tune or authorizes output.
//

import Foundation

/// An opaque handoff that can only be constructed by this generator file.
struct FH5CleanRoomDirectionalProposal: Sendable {
    let field: TuneFieldID
    let candidateValue: Double
    let input: ValidationInput
    let surface: ValidationSurface
    let targetSymptom: TuneFeedback

    fileprivate init(
        field: TuneFieldID,
        candidateValue: Double,
        input: ValidationInput,
        surface: ValidationSurface,
        targetSymptom: TuneFeedback
    ) {
        self.field = field
        self.candidateValue = candidateValue
        self.input = input
        self.surface = surface
        self.targetSymptom = targetSymptom
    }
}

enum FH5CleanRoomDirectionalCandidateIssue:
    Error,
    LocalizedError,
    Equatable,
    Sendable {
    case experiment(FH5ControlledExperimentIssue)
    case invalidResearchRecord
    case malformedReview
    case conflictingReplication
    case exactReplicationRequired
    case unsupportedAlgorithm
    case unsupportedSymptom
    case frontTirePressureNotAdjustable
    case invalidFrontTirePressureMeasurement
    case frontTirePressureAlreadyAtMinimum

    var errorDescription: String? {
        switch self {
        case .experiment(let issue): issue.errorDescription
        case .invalidResearchRecord:
            "The selected Research Lab observation failed its integrity checks."
        case .malformedReview:
            "The Research review contains invalid, quarantined, or replayed evidence."
        case .conflictingReplication:
            "Independent Research observations conflict for this exact stock context."
        case .exactReplicationRequired:
            "Two independent Research observations must agree on this exact stock menu."
        case .unsupportedAlgorithm:
            "This generator does not implement the requested experimental algorithm."
        case .unsupportedSymptom:
            "This experiment currently supports only a car that pushes wide."
        case .frontTirePressureNotAdjustable:
            "Front tire pressure was not observed as adjustable."
        case .invalidFrontTirePressureMeasurement:
            "Front tire pressure needs a valid PSI range, step, and restored stock value."
        case .frontTirePressureAlreadyAtMinimum:
            "Front tire pressure cannot move one observed step lower."
        }
    }
}

struct FH5CleanRoomDirectionalCandidateGenerator {
    func generate(
        tune: TuneResult,
        savedTune: TuneResult?,
        isStreaming: Bool,
        researchRecords: [FH5ResearchObservationRecord],
        reviewInputs: [FH5ResearchReviewInput],
        targetSymptom: TuneFeedback,
        input: ValidationInput,
        surface: ValidationSurface,
        algorithmID: FH5ExperimentalAlgorithmID,
        registry: FH5TrustedNumericRulesetRegistry
    ) throws -> FH5GeneratedCandidateArtifact {
        guard algorithmID == .cleanRoomDirectionalV1 else {
            throw FH5CleanRoomDirectionalCandidateIssue.unsupportedAlgorithm
        }
        guard targetSymptom == .pushesWide else {
            throw FH5CleanRoomDirectionalCandidateIssue.unsupportedSymptom
        }

        let sourceRecord: FH5ResearchObservationRecord
        do {
            switch FH5ControlledExperimentFactory().eligibility(
                tune: tune,
                savedTune: savedTune,
                isStreaming: isStreaming,
                researchRecords: researchRecords
            ) {
            case .success(let record):
                sourceRecord = try deterministicLatest(
                    selected: record,
                    records: researchRecords,
                    tune: tune
                )
            case .failure(let issue):
                throw FH5CleanRoomDirectionalCandidateIssue.experiment(issue)
            }
        } catch let issue as FH5CleanRoomDirectionalCandidateIssue {
            throw issue
        }

        guard FH5ResearchObservationFactory().isValid(sourceRecord) else {
            throw FH5CleanRoomDirectionalCandidateIssue.invalidResearchRecord
        }
        do {
            _ = try FH5ResearchReviewEvaluator().exactReplicationProof(
                inputs: reviewInputs,
                for: sourceRecord
            )
        } catch let issue as FH5ExactReplicationProofIssue {
            switch issue {
            case .invalidResearchRecord:
                throw FH5CleanRoomDirectionalCandidateIssue
                    .invalidResearchRecord
            case .malformedEvidence:
                throw FH5CleanRoomDirectionalCandidateIssue.malformedReview
            case .conflictingEvidence:
                throw FH5CleanRoomDirectionalCandidateIssue
                    .conflictingReplication
            case .exactReplicationRequired:
                throw FH5CleanRoomDirectionalCandidateIssue
                    .exactReplicationRequired
            }
        }
        guard let observation = sourceRecord.controls.first(where: {
            $0.field == .frontTirePressure
        }), observation.availability == .adjustable else {
            throw FH5CleanRoomDirectionalCandidateIssue
                .frontTirePressureNotAdjustable
        }
        guard let minimum = observation.minimum,
              let maximum = observation.maximum,
              let step = observation.step,
              let current = observation.current,
              observation.unit == .psi,
              minimum.isFinite,
              maximum.isFinite,
              step.isFinite,
              current.isFinite,
              minimum < maximum,
              step > 0 else {
            throw FH5CleanRoomDirectionalCandidateIssue
                .invalidFrontTirePressureMeasurement
        }
        let tolerance = max(1e-9, step * 1e-6)
        let currentLattice = (current - minimum) / step
        guard current >= minimum - tolerance,
              current <= maximum + tolerance,
              abs(currentLattice - currentLattice.rounded()) <= 1e-6 else {
            throw FH5CleanRoomDirectionalCandidateIssue
                .invalidFrontTirePressureMeasurement
        }
        let candidate = current - step
        guard candidate >= minimum - tolerance else {
            throw FH5CleanRoomDirectionalCandidateIssue
                .frontTirePressureAlreadyAtMinimum
        }

        let proposal = FH5CleanRoomDirectionalProposal(
            field: .frontTirePressure,
            candidateValue: candidate,
            input: input,
            surface: surface,
            targetSymptom: targetSymptom
        )
        do {
            return try FH5ControlledExperimentFactory()
                .makeGeneratedCandidateArtifact(
                    tune: tune,
                    savedTune: savedTune,
                    isStreaming: isStreaming,
                    researchRecord: sourceRecord,
                    proposal: proposal,
                    algorithmID: algorithmID,
                    registry: registry
                )
        } catch let issue as FH5ControlledExperimentIssue {
            throw FH5CleanRoomDirectionalCandidateIssue.experiment(issue)
        }
    }

    private func deterministicLatest(
        selected: FH5ResearchObservationRecord,
        records: [FH5ResearchObservationRecord],
        tune: TuneResult
    ) throws -> FH5ResearchObservationRecord {
        let matching = records.filter {
            FH5ResearchObservationFactory().matches($0, tune: tune)
        }
        guard let latestDate = matching.map(\.capturedAt).max() else {
            return selected
        }
        let latest = matching.filter { $0.capturedAt == latestDate }
        guard Set(latest.map(\.contentFingerprint)).count == 1,
              let deterministic = latest.sorted(by: {
                  $0.contentFingerprint < $1.contentFingerprint
              }).first else {
            throw FH5CleanRoomDirectionalCandidateIssue.invalidResearchRecord
        }
        return deterministic
    }

}
