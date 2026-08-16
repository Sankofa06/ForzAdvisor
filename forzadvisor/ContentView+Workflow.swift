//
//  ContentView+Workflow.swift
//  forzadvisor
//
//  Side-effecting workflow actions for ContentView: generation, persistence,
//  retry, saved tune edits, and adjustment updates.
//

import Foundation
import SwiftData

enum ContentWorkflowError: LocalizedError {
    case missingSavedTune
    case staleBetaMission
    case staleCommunityReferenceTrial
    case missingFirstPartyValidation

    var errorDescription: String? {
        switch self {
        case .missingSavedTune:
            "The saved tune could not be found."
        case .staleBetaMission:
            "This mission is no longer eligible. Reopen Beta Missions for the current list."
        case .staleCommunityReferenceTrial:
            "This saved tune is no longer eligible for a community comparison. Reopen the current saved FH6 tune."
        case .missingFirstPartyValidation:
            "Record a valid first-party test drive for this exact current tune before starting a community comparison."
        }
    }
}

enum BetaMissionOpenFailureDisposition: Equatable {
    case refreshAsStale
    case showGlobalAlert
}

struct BetaMissionOpenFailurePolicy {
    func disposition(for error: Error) -> BetaMissionOpenFailureDisposition {
        guard let workflowError = error as? ContentWorkflowError else {
            return .showGlobalAlert
        }
        switch workflowError {
        case .staleBetaMission, .missingSavedTune,
             .staleCommunityReferenceTrial, .missingFirstPartyValidation:
            return .refreshAsStale
        }
    }
}
@MainActor
struct FH6IndependentValidationReviewPacketReceiver {
    func validate(
        data: Data,
        displayedTune: TuneResult,
        savedTuneID: UUID,
        in container: ModelContainer
    ) throws -> FH6IndependentValidationReviewPacket {
        let readContext = ModelContext(container)
        var descriptor = FetchDescriptor<SavedTune>(
            predicate: #Predicate<SavedTune> { tune in
                tune.id == savedTuneID
            }
        )
        descriptor.fetchLimit = 1
        descriptor.includePendingChanges = false
        guard let savedTune = try readContext.fetch(descriptor).first,
              let persistedTune = savedTune.tuneResult else {
            throw ContentWorkflowError.missingSavedTune
        }
        return try FH6IndependentValidationReviewPacketExporter()
            .validate(
                data,
                candidate: displayedTune,
                persistedCandidate: persistedTune,
                isStreaming: false
            )
    }
}

struct FH6IndependentValidationReviewReceiverEligibility {
    func candidateRevisionFingerprint(
        candidate: TuneResult,
        persistedCandidate: TuneResult?,
        isStreaming: Bool
    ) -> String? {
        guard candidate.request.car.game == .fh6,
              let persistedCandidate,
              persistedCandidate.request.car.game == .fh6,
              candidate.id == persistedCandidate.id,
              candidate.generatedAt == persistedCandidate.generatedAt,
              case .success =
                FirstPartyValidationRecordFactory().eligibility(
                    for: candidate,
                    savedTune: persistedCandidate,
                    isStreaming: isStreaming
                ) else {
            return nil
        }
        return FirstPartyValidationRecordFactory()
            .revisionFingerprint(for: candidate)
    }
}

@MainActor
struct FH5NumericPromotionReviewCommittedCoordinator {
    func preparedInputStateFingerprint(
        displayedTune: TuneResult,
        displayedArtifact: FH5GeneratedCandidateArtifact,
        savedTuneID: UUID,
        in container: ModelContainer
    ) throws -> String {
        let context = try committedContext(
            displayedTune: displayedTune,
            displayedArtifact: displayedArtifact,
            savedTuneID: savedTuneID,
            in: container,
            includeOutcomeEvidence: true
        )
        return try FH5NumericPromotionReviewPacketExporter()
            .preparedInputStateFingerprint(
                candidateArtifact: context.artifact,
                localRecords: context.localRecords,
                reviewedEntries: context.reviewedEntries
            )
    }

    func prepare(
        displayedTune: TuneResult,
        displayedArtifact: FH5GeneratedCandidateArtifact,
        savedTuneID: UUID,
        in container: ModelContainer
    ) throws -> String {
        let context = try committedContext(
            displayedTune: displayedTune,
            displayedArtifact: displayedArtifact,
            savedTuneID: savedTuneID,
            in: container,
            includeOutcomeEvidence: true
        )
        let packet = try FH5NumericPromotionReviewPacketExporter()
            .prepare(
                candidateArtifact: context.artifact,
                localRecords: context.localRecords,
                reviewedEntries: context.reviewedEntries
            )
        return String(decoding: try packet.deterministicJSON(), as: UTF8.self)
    }

    func validate(
        _ data: Data,
        displayedTune: TuneResult,
        displayedArtifact: FH5GeneratedCandidateArtifact,
        savedTuneID: UUID,
        in container: ModelContainer
    ) throws -> FH5NumericPromotionReviewPacket {
        let context = try committedContext(
            displayedTune: displayedTune,
            displayedArtifact: displayedArtifact,
            savedTuneID: savedTuneID,
            in: container,
            includeOutcomeEvidence: false
        )
        return try FH5NumericPromotionReviewPacketExporter()
            .validate(
                data,
                candidateArtifact: context.artifact
            )
    }

    private struct CommittedContext {
        let artifact: FH5GeneratedCandidateArtifact
        let localRecords: [FH5ControlledExperimentRecord]
        let reviewedEntries: [FH5CandidateOutcomeReviewEntry]
    }

    private func committedContext(
        displayedTune: TuneResult,
        displayedArtifact: FH5GeneratedCandidateArtifact,
        savedTuneID: UUID,
        in container: ModelContainer,
        includeOutcomeEvidence: Bool
    ) throws -> CommittedContext {
        let readContext = ModelContext(container)
        readContext.autosaveEnabled = false
        var descriptor = FetchDescriptor<SavedTune>(
            predicate: #Predicate<SavedTune> { tune in
                tune.id == savedTuneID
            }
        )
        descriptor.fetchLimit = 1
        descriptor.includePendingChanges = false
        guard let savedTune = try readContext.fetch(descriptor).first,
              let persistedTune = savedTune.tuneResult else {
            throw ContentWorkflowError.missingSavedTune
        }
        let researchFactory = FH5ResearchObservationFactory()
        guard displayedTune.id == persistedTune.id,
              researchFactory.planRevisionFingerprint(
                for: displayedTune
              ) == researchFactory.planRevisionFingerprint(
                for: persistedTune
              ) else {
            throw FH5NumericPromotionReviewPacketError
                .staleOrForeignCandidate
        }
        let researchRecords =
            try savedTune.exactFH5ResearchObservationRecords(
                matching: persistedTune
            )
        let reviewEntries =
            try savedTune.exactFH5ResearchReviewEntries(
                matching: persistedTune
            )
        let regenerated = try FH5CandidateTrialCoordinator()
            .generate(
                tune: persistedTune,
                savedTune: persistedTune,
                isStreaming: false,
                researchRecords: researchRecords,
                reviewInputs: reviewEntries.map {
                    FH5ResearchReviewInput(entry: $0)
                },
                input: displayedArtifact.context.input,
                surface: displayedArtifact.context.surface
            )
        guard regenerated == displayedArtifact else {
            throw FH5NumericPromotionReviewPacketError
                .staleOrForeignCandidate
        }
        guard includeOutcomeEvidence else {
            return CommittedContext(
                artifact: regenerated,
                localRecords: [],
                reviewedEntries: []
            )
        }
        return CommittedContext(
            artifact: regenerated,
            localRecords:
                try savedTune.allFH5ControlledExperimentRecords(),
            reviewedEntries:
                try savedTune.allFH5CandidateOutcomeReviewEntries()
        )
    }
}
