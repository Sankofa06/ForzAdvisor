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
    let accuracyEvidenceChain:
        FH6AccuracyEvidenceChainAssessment

    var matchingValidationRecordCount: Int {
        accuracyEvidenceChain.matchingValidationCount
    }

    var matchingCommunityTrialCount: Int {
        accuracyEvidenceChain.matchingCommunityComparisonCount
    }
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
            accuracyEvidenceChain:
                try savedTune.fh6AccuracyEvidenceChain(
                    matching: persistedTune
                )
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
        guard savedTuneID == tune.id else {
            return nil
        }
        if tune.request.car.game == .fh5 {
            guard TuneResultBoundarySanitizer()
                    .isSafeFH5BuildPlan(tune),
                  UpgradePartCaptureEligibility()
                    .snapshot(for: tune) != nil else {
                return nil
            }
            return .openUpgradeLab
        }
        guard tune.request.car.game == .fh6,
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
        if snapshot.accuracyEvidenceChain.stage
            == .needsFirstPartyValidation {
            return .openRecordTestDrive
        }
        guard snapshot.accuracyEvidenceChain.stage
            == .readyForCommunityComparison else {
            return nil
        }
        return .openFH6CommunityReferenceTrial
    }
}
