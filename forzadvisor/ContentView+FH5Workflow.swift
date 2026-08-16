//
//  Root workflow actions split by bounded ownership.
//

import Foundation
import SwiftData

extension ContentView {
    func recordFH5ResearchObservation(
        _ capture: FH5ResearchCapture,
        for tune: TuneResult,
        savedTuneID: UUID,
        thumbnailData: Data?,
        playerNotes: String
    ) {
        do {
            guard let savedTune = try savedTune(for: savedTuneID),
                  let persistedTune = savedTune.tuneResult else {
                throw ContentWorkflowError.missingSavedTune
            }
            let record = try FH5ResearchObservationFactory().make(
                tune: tune,
                savedTune: persistedTune,
                isStreaming: false,
                capture: capture
            )
            try savedTune.appendFH5ResearchObservationRecord(record)
            try modelContext.save()
            try ValidationDraftStore().deleteAfterConfirmedCommit(
                kind: .fh5ResearchObservation,
                savedTuneID: savedTuneID
            )
            if returnToValidationMission(.completedOnDevice) {
                return
            }
            step = .result(
                TuneResultBoundarySanitizer().sanitize(tune),
                savedTuneID: savedTuneID,
                adjustmentChanges: [],
                thumbnailData: thumbnailData,
                playerNotes: playerNotes
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteFH5ResearchObservationRecord(
        _ record: FH5ResearchObservationRecord,
        savedTuneID: UUID
    ) {
        do {
            guard let savedTune = try savedTune(for: savedTuneID) else {
                throw ContentWorkflowError.missingSavedTune
            }
            _ = try savedTune.deleteFH5ResearchObservationRecord(id: record.recordID)
            try modelContext.save()
        } catch {
            errorMessage = "Could not delete this FH5 observation: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func importFH5ResearchReviewEntry(
        _ entry: FH5ResearchReviewEntry,
        savedTuneID: UUID
    ) -> String? {
        do {
            guard let savedTune = try savedTune(for: savedTuneID) else {
                throw ContentWorkflowError.missingSavedTune
            }
            try savedTune.appendFH5ResearchReviewEntry(entry)
            try modelContext.save()
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    func deleteFH5ResearchReviewEntry(
        _ entry: FH5ResearchReviewEntry,
        savedTuneID: UUID
    ) {
        do {
            guard let savedTune = try savedTune(for: savedTuneID) else {
                throw ContentWorkflowError.missingSavedTune
            }
            _ = try savedTune.deleteFH5ResearchReviewEntry(id: entry.id)
            try modelContext.save()
        } catch {
            errorMessage = "Could not delete this FH5 review entry: \(error.localizedDescription)"
        }
    }

    func recordFH5ControlledExperiment(
        _ capture: FH5ControlledExperimentCapture,
        for tune: TuneResult,
        savedTuneID: UUID,
        thumbnailData: Data?,
        playerNotes: String
    ) {
        do {
            guard let savedTune = try savedTune(for: savedTuneID),
                  let persistedTune = savedTune.tuneResult else {
                throw ContentWorkflowError.missingSavedTune
            }
            let researchRecords = savedTune
                .fh5ResearchObservationRecords(matching: persistedTune)
            let record = try FH5ControlledExperimentFactory().make(
                tune: tune,
                savedTune: persistedTune,
                isStreaming: false,
                researchRecords: researchRecords,
                capture: capture
            )
            try savedTune.appendFH5ControlledExperimentRecord(record)
            try modelContext.save()
            try ValidationDraftStore().deleteAfterConfirmedCommit(
                kind: .fh5ControlledExperiment,
                savedTuneID: savedTuneID
            )
            if returnToValidationMission(.completedOnDevice) {
                return
            }
            step = .result(
                TuneResultBoundarySanitizer().sanitize(tune),
                savedTuneID: savedTuneID,
                adjustmentChanges: [],
                thumbnailData: thumbnailData,
                playerNotes: playerNotes
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func makeFH5CandidateTrialArtifact(
        for tune: TuneResult,
        savedTuneID: UUID,
        input: ValidationInput,
        surface: ValidationSurface
    ) throws -> FH5GeneratedCandidateArtifact {
        guard let savedTune = try savedTune(for: savedTuneID),
              let persistedTune = savedTune.tuneResult else {
            throw ContentWorkflowError.missingSavedTune
        }
        let researchRecords = savedTune
            .fh5ResearchObservationRecords(matching: persistedTune)
        let reviewInputs = savedTune
            .fh5ResearchReviewEntries(matching: persistedTune)
            .map { FH5ResearchReviewInput(entry: $0) }
        return try FH5CandidateTrialCoordinator().generate(
            tune: tune,
            savedTune: persistedTune,
            isStreaming: false,
            researchRecords: researchRecords,
            reviewInputs: reviewInputs,
            input: input,
            surface: surface
        )
    }

    func recordFH5CandidateTrial(
        _ submission: FH5CandidateTrialSubmission,
        for tune: TuneResult,
        savedTuneID: UUID,
        thumbnailData: Data?,
        playerNotes: String
    ) {
        do {
            guard let savedTune = try savedTune(for: savedTuneID),
                  let persistedTune = savedTune.tuneResult else {
                throw ContentWorkflowError.missingSavedTune
            }
            let researchRecords = savedTune
                .fh5ResearchObservationRecords(matching: persistedTune)
            let reviewInputs = savedTune
                .fh5ResearchReviewEntries(matching: persistedTune)
                .map { FH5ResearchReviewInput(entry: $0) }
            let record = try FH5CandidateTrialCoordinator().makeRecord(
                tune: tune,
                savedTune: persistedTune,
                isStreaming: false,
                researchRecords: researchRecords,
                reviewInputs: reviewInputs,
                submission: submission
            )
            try savedTune.appendFH5ControlledExperimentRecord(record)
            try modelContext.save()
            try ValidationDraftStore().deleteAfterConfirmedCommit(
                kind: .fh5CandidateTrial,
                savedTuneID: savedTuneID
            )
            if returnToValidationMission(.completedOnDevice) {
                return
            }
            step = .result(
                TuneResultBoundarySanitizer().sanitize(tune),
                savedTuneID: savedTuneID,
                adjustmentChanges: [],
                thumbnailData: thumbnailData,
                playerNotes: playerNotes
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteFH5ControlledExperimentRecord(
        _ record: FH5ControlledExperimentRecord,
        savedTuneID: UUID
    ) {
        do {
            guard let savedTune = try savedTune(for: savedTuneID) else {
                throw ContentWorkflowError.missingSavedTune
            }
            _ = try savedTune.deleteFH5ControlledExperimentRecord(id: record.recordID)
            try modelContext.save()
        } catch {
            errorMessage = "Could not delete this FH5 experiment: \(error.localizedDescription)"
        }
    }

    func importFH5CandidateOutcomeReviewEntry(
        _ entry: FH5CandidateOutcomeReviewEntry,
        savedTuneID: UUID
    ) -> String? {
        do {
            guard let savedTune = try savedTune(
                for: savedTuneID
            ) else {
                throw ContentWorkflowError.missingSavedTune
            }
            try savedTune.appendFH5CandidateOutcomeReviewEntry(
                entry
            )
            try modelContext.save()
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    func deleteFH5CandidateOutcomeReviewEntry(
        _ entry: FH5CandidateOutcomeReviewEntry,
        savedTuneID: UUID
    ) {
        do {
            guard let savedTune = try savedTune(
                for: savedTuneID
            ) else {
                throw ContentWorkflowError.missingSavedTune
            }
            _ = try savedTune
                .deleteFH5CandidateOutcomeReviewEntry(
                    id: entry.id
                )
            try modelContext.save()
        } catch {
            errorMessage =
                "Could not delete this FH5 Candidate Outcome review: \(error.localizedDescription)"
        }
    }

}
