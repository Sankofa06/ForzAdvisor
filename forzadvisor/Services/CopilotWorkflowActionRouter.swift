//
//  CopilotWorkflowActionRouter.swift
//  forzadvisor
//
//  Revalidates explicit Copilot handoffs against one fresh persisted snapshot.
//

import Foundation
import SwiftData

struct CopilotPersistedResultPayload {
    let tune: TuneResult
    let thumbnailData: Data?
    let playerNotes: String
}

struct CopilotPersistedActionSnapshot {
    let result: CopilotPersistedResultPayload
    let matchingValidationRecordCount: Int
    let matchingCommunityTrialCount: Int
}

@MainActor
struct CopilotPersistedActionSnapshotResolver {
    func resolve(
        displayedTune: TuneResult,
        savedTuneID: UUID,
        in modelContext: ModelContext
    ) throws -> CopilotPersistedActionSnapshot? {
        var descriptor = FetchDescriptor<SavedTune>(
            predicate: #Predicate<SavedTune> { tune in
                tune.id == savedTuneID
            }
        )
        descriptor.fetchLimit = 1
        descriptor.includePendingChanges = false
        guard let savedTune =
                try modelContext.fetch(descriptor).first,
              let persistedTune = savedTune.tuneResult,
              persistedTune == displayedTune else {
            return nil
        }
        return CopilotPersistedActionSnapshot(
            result: CopilotPersistedResultPayload(
                tune: persistedTune,
                thumbnailData: savedTune.thumbnailData,
                playerNotes: savedTune.playerNotes
            ),
            matchingValidationRecordCount:
                try savedTune
                    .validValidationRecords(
                        matching: persistedTune
                    ).count,
            matchingCommunityTrialCount:
                try savedTune
                    .fh6CommunityReferenceTrialRecords(
                        matching: persistedTune
                    ).count
        )
    }
}

struct CopilotWorkflowActionRouter {
    func destination(
        for action: CopilotAction,
        from currentStep: WorkflowStep,
        authoritativeSnapshot:
            CopilotPersistedActionSnapshot?
    ) -> WorkflowStep? {
        guard case .result(
            let displayedTune,
            let savedTuneID,
            _,
            _,
            _
        ) = currentStep,
        let savedTuneID,
        let authoritativeSnapshot,
        displayedTune == authoritativeSnapshot.result.tune,
        authoritativeAction(
            for: authoritativeSnapshot,
            savedTuneID: savedTuneID
        ) == action else {
            return nil
        }

        let persistedResult = authoritativeSnapshot.result
        switch action {
        case .openFH6TuneMenuLab:
            return .fh6TuneMenuCapture(
                persistedResult.tune,
                savedTuneID: savedTuneID,
                thumbnailData: persistedResult.thumbnailData,
                playerNotes: persistedResult.playerNotes
            )
        case .openTireLab:
            return .tirePressureCapture(
                persistedResult.tune,
                savedTuneID: savedTuneID,
                thumbnailData: persistedResult.thumbnailData,
                playerNotes: persistedResult.playerNotes
            )
        case .openUpgradeLab:
            return .upgradePartCapture(
                persistedResult.tune,
                savedTuneID: savedTuneID,
                thumbnailData: persistedResult.thumbnailData,
                playerNotes: persistedResult.playerNotes
            )
        case .openRecordTestDrive:
            return .recordTestDrive(
                persistedResult.tune,
                savedTuneID: savedTuneID,
                thumbnailData: persistedResult.thumbnailData,
                playerNotes: persistedResult.playerNotes
            )
        case .openFH6CommunityReferenceTrial:
            return .fh6CommunityReferenceTrialCapture(
                persistedResult.tune,
                savedTuneID: savedTuneID,
                thumbnailData: persistedResult.thumbnailData,
                playerNotes: persistedResult.playerNotes
            )
        }
    }

    func authoritativeAction(
        for snapshot: CopilotPersistedActionSnapshot,
        savedTuneID: UUID
    ) -> CopilotAction? {
        let tune = snapshot.result.tune
        guard savedTuneID == tune.id,
              tune.request.car.game == .fh6,
              tune.purpose == .numericTune,
              let report = tune.projectionReport,
              report.readyCount > 0 else {
            return nil
        }
        if FH6TuneMenuCaptureEligibility().snapshot(
            for: tune,
            isStreaming: false
        ) != nil {
            return .openFH6TuneMenuLab
        }
        if TirePressureCaptureEligibility().snapshot(
            for: tune
        ) != nil {
            return .openTireLab
        }
        if UpgradePartCaptureEligibility().snapshot(
            for: tune
        ) != nil {
            return .openUpgradeLab
        }
        guard case .success =
                FirstPartyValidationRecordFactory()
                    .eligibility(
                        for: tune,
                        savedTune: tune,
                        isStreaming: false
                    ) else {
            return nil
        }
        if snapshot.matchingValidationRecordCount == 0 {
            return .openRecordTestDrive
        }
        guard snapshot.matchingCommunityTrialCount == 0 else {
            return nil
        }
        return .openFH6CommunityReferenceTrial
    }
}
