//
//  Root workflow actions split by bounded ownership.
//

import Foundation
import SwiftData

extension ContentView {
    func recordTestDrive(
        _ capture: FirstPartyValidationCapture,
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
            let record = try FirstPartyValidationRecordFactory().make(
                tune: tune,
                savedTune: persistedTune,
                isStreaming: false,
                capture: capture
            )
            try savedTune.appendValidationRecord(record)
            try modelContext.save()
            step = .result(
                tune,
                savedTuneID: savedTuneID,
                adjustmentChanges: [],
                thumbnailData: thumbnailData,
                playerNotes: playerNotes
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteValidationRecord(
        _ record: FirstPartyValidationRecord,
        savedTuneID: UUID
    ) {
        do {
            guard let savedTune = try savedTune(for: savedTuneID) else {
                throw ContentWorkflowError.missingSavedTune
            }
            _ = try savedTune.deleteValidationRecord(id: record.recordID)
            try modelContext.save()
        } catch {
            errorMessage = "Could not delete this validation record: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func importFH6ValidationReviewEntry(
        _ entry: FH6ValidationReviewEntry,
        savedTuneID: UUID
    ) -> String? {
        do {
            guard let savedTune = try savedTune(for: savedTuneID) else {
                throw ContentWorkflowError.missingSavedTune
            }
            try savedTune.appendFH6ValidationReviewEntry(entry)
            try modelContext.save()
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    func deleteFH6ValidationReviewEntry(
        _ entry: FH6ValidationReviewEntry,
        savedTuneID: UUID
    ) {
        do {
            guard let savedTune = try savedTune(for: savedTuneID) else {
                throw ContentWorkflowError.missingSavedTune
            }
            _ = try savedTune.deleteFH6ValidationReviewEntry(id: entry.id)
            try modelContext.save()
        } catch {
            errorMessage = "Could not delete this FH6 review entry: \(error.localizedDescription)"
        }
    }

    func prepareFH6IndependentValidationReviewPacket(
        displayedTune: TuneResult,
        savedTuneID: UUID
    ) throws -> String {
        guard let savedTune = try savedTune(for: savedTuneID),
              let persistedTune = savedTune.tuneResult else {
            throw ContentWorkflowError.missingSavedTune
        }
        let artifact =
            try FH6IndependentValidationReviewPacketExporter()
                .makeArtifact(
                    candidate: displayedTune,
                    persistedCandidate: persistedTune,
                    isStreaming: false,
                    firstPartyTestDrives:
                        try savedTune
                            .allFirstPartyValidationRecords(),
                    localCommunityOutcomes:
                        try savedTune
                            .allFH6CommunityReferenceTrialRecords(),
                    reviewedCommunityOutcomes:
                        try savedTune
                            .allFH6CommunityOutcomeReviewEntries()
                )
        return String(decoding: artifact.canonicalJSON, as: UTF8.self)
    }

    func validateFH6IndependentValidationReviewPacket(
        data: Data,
        displayedTune: TuneResult,
        savedTuneID: UUID
    ) throws -> FH6IndependentValidationReviewPacket {
        try FH6IndependentValidationReviewPacketReceiver()
            .validate(
                data: data,
                displayedTune: displayedTune,
                savedTuneID: savedTuneID,
                in: modelContext.container
            )
    }

    func recordFH6CommunityReferenceTrial(
        _ capture: FH6CommunityReferenceTrialCapture,
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
            let record = try FH6CommunityReferenceTrialFactory().make(
                tune: tune,
                savedTune: persistedTune,
                isStreaming: false,
                validationRecords:
                    try savedTune.validValidationRecords(
                        matching: persistedTune
                    ),
                capture: capture
            )
            try savedTune.appendFH6CommunityReferenceTrialRecord(record)
            try modelContext.save()
            step = .result(
                TuneResultBoundarySanitizer().sanitize(persistedTune),
                savedTuneID: savedTuneID,
                adjustmentChanges: [],
                thumbnailData: savedTune.thumbnailData ?? thumbnailData,
                playerNotes: savedTune.playerNotes
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func openFH6CommunityReferenceTrial(
        savedTuneID: UUID,
        requiresNoCurrentTrial: Bool
    ) {
        do {
            guard let savedTune = try savedTune(for: savedTuneID),
                  let persistedTune = savedTune.tuneResult,
                  case .success(let exactTune) =
                    FH6CommunityReferenceTrialFactory().eligibility(
                        for: persistedTune,
                        savedTune: persistedTune,
                        isStreaming: false
                    ) else {
                throw ContentWorkflowError.staleCommunityReferenceTrial
            }
            let chain = try savedTune.fh6AccuracyEvidenceChain(
                matching: exactTune
            )
            guard chain.permitsCommunityComparison else {
                throw ContentWorkflowError
                    .missingFirstPartyValidation
            }
            if requiresNoCurrentTrial {
                guard try savedTune
                    .fh6CommunityReferenceTrialRecords(
                        matching: exactTune
                    ).isEmpty else {
                    throw ContentWorkflowError
                        .staleCommunityReferenceTrial
                }
            }
            tuneWorkflow.cancelAdjustment()
            step = .fh6CommunityReferenceTrialCapture(
                TuneResultBoundarySanitizer().sanitize(exactTune),
                savedTuneID: savedTuneID,
                thumbnailData: savedTune.thumbnailData,
                playerNotes: savedTune.playerNotes
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteFH6CommunityReferenceTrialRecord(
        _ record: FH6CommunityReferenceTrialRecord,
        savedTuneID: UUID
    ) {
        do {
            guard let savedTune = try savedTune(for: savedTuneID) else {
                throw ContentWorkflowError.missingSavedTune
            }
            _ = try savedTune.deleteFH6CommunityReferenceTrialRecord(
                id: record.recordID
            )
            try modelContext.save()
        } catch {
            errorMessage =
                "Could not delete this community comparison: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func importFH6CommunityOutcomeReviewEntry(
        _ entry: FH6CommunityOutcomeReviewEntry,
        savedTuneID: UUID
    ) -> String? {
        do {
            guard let savedTune =
                try FH6CommunityOutcomeSavedTuneResolver()
                    .fetch(
                        id: savedTuneID,
                        from: modelContext
                    )
            else {
                throw ContentWorkflowError.missingSavedTune
            }
            try savedTune
                .appendFH6CommunityOutcomeReviewEntry(entry)
            try modelContext.save()
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    func deleteFH6CommunityOutcomeReviewEntry(
        _ entry: FH6CommunityOutcomeReviewEntry,
        savedTuneID: UUID
    ) {
        do {
            guard let savedTune = try savedTune(
                for: savedTuneID
            ) else {
                throw ContentWorkflowError.missingSavedTune
            }
            _ = try savedTune
                .deleteFH6CommunityOutcomeReviewEntry(
                    id: entry.id
                )
            try modelContext.save()
        } catch {
            errorMessage =
                "Could not delete this Community Outcome review: \(error.localizedDescription)"
        }
    }

    func validateFH6CommunityOutcomeReviewJSON(
        _ data: Data,
        displayedTune: TuneResult,
        savedTuneID: UUID
    ) -> String? {
        do {
            guard let savedTune =
                try FH6CommunityOutcomeSavedTuneResolver()
                    .fetch(
                        id: savedTuneID,
                        from: modelContext
                    )
            else {
                throw ContentWorkflowError.missingSavedTune
            }
            _ = try FH6CommunityOutcomeReviewIngestor()
                .validateCurrentCandidate(
                    data,
                    displayedTune: displayedTune,
                    persistedTune: savedTune.tuneResult
                )
            return nil
        } catch {
            return error.localizedDescription
        }
    }

}
