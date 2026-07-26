//
//  FH6AccuracyEvidenceChain.swift
//  forzadvisor
//
//  Candidate-bound sequencing for local FH6 accuracy evidence.
//  Evidence collection never establishes an accuracy claim.
//

import Foundation

enum FH6AccuracyEvidenceChainStage: String, Equatable, Sendable {
    case needsFirstPartyValidation
    case readyForCommunityComparison
    case communityComparisonCollected
}

struct FH6AccuracyEvidenceChainAssessment: Equatable, Sendable {
    let stage: FH6AccuracyEvidenceChainStage
    let matchingValidationCount: Int
    let matchingCommunityComparisonCount: Int

    /// This boundary is intentionally immutable: evidence remains
    /// collection-only regardless of record count.
    let accuracyClaimEstablished = false

    var accuracyClaimNotEstablished: Bool {
        !accuracyClaimEstablished
    }

    var permitsCommunityComparison: Bool {
        stage != .needsFirstPartyValidation
    }
}

struct FH6AccuracyEvidenceChainPolicy {
    func assess(
        tune: TuneResult,
        savedTune: TuneResult?,
        isStreaming: Bool,
        validationRecords: [FirstPartyValidationRecord],
        communityComparisonRecords:
            [FH6CommunityReferenceTrialRecord]
    ) -> FH6AccuracyEvidenceChainAssessment {
        let validationFactory = FirstPartyValidationRecordFactory()
        let communityFactory = FH6CommunityReferenceTrialFactory()
        guard case .success(let exactTune) =
                validationFactory.eligibility(
                    for: tune,
                    savedTune: savedTune,
                    isStreaming: isStreaming
                ),
              let savedTune,
              let revision =
                validationFactory.revisionFingerprint(
                    for: exactTune
                ),
              validationFactory.revisionFingerprint(
                  for: savedTune
              ) == revision else {
            return .init(
                stage: .needsFirstPartyValidation,
                matchingValidationCount: 0,
                matchingCommunityComparisonCount: 0
            )
        }

        let validationCount = validationRecords.reduce(into: 0) {
            count, record in
            if validationFactory.isValid(record),
               record.tuneRevisionFingerprint == revision {
                count += 1
            }
        }
        let comparisonCount = communityComparisonRecords.reduce(into: 0) {
            count, record in
            if communityFactory.isValid(record),
               communityFactory.matches(record, tune: exactTune) {
                count += 1
            }
        }
        let stage: FH6AccuracyEvidenceChainStage
        if validationCount == 0 {
            stage = .needsFirstPartyValidation
        } else if comparisonCount == 0 {
            stage = .readyForCommunityComparison
        } else {
            stage = .communityComparisonCollected
        }
        return .init(
            stage: stage,
            matchingValidationCount: validationCount,
            matchingCommunityComparisonCount: comparisonCount
        )
    }
}
