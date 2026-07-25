//
//  CopilotWorkflowActionRouter.swift
//  forzadvisor
//
//  Revalidates explicit Copilot handoffs against the live root workflow.
//

import Foundation

struct CopilotPersistedResultPayload {
    let tune: TuneResult
    let thumbnailData: Data?
    let playerNotes: String
}

struct CopilotWorkflowActionRouter {
    func destination(
        for action: CopilotAction,
        from currentStep: WorkflowStep,
        persistedResult: CopilotPersistedResultPayload? = nil,
        matchingCommunityTrialCount: Int? = nil
    ) -> WorkflowStep? {
        if action == .openFH6CommunityReferenceTrial {
            guard case .result(
                _,
                let savedTuneID,
                _,
                _,
                _
            ) = currentStep,
            let savedTuneID,
            let persistedResult,
            authoritativeAction(
                for: persistedResult.tune,
                savedTuneID: savedTuneID,
                persistedTune: persistedResult.tune,
                matchingCommunityTrialCount:
                    matchingCommunityTrialCount
            ) == action else {
                return nil
            }
            return .fh6CommunityReferenceTrialCapture(
                persistedResult.tune,
                savedTuneID: savedTuneID,
                thumbnailData: persistedResult.thumbnailData,
                playerNotes: persistedResult.playerNotes
            )
        }

        guard case .result(
            let tune,
            let savedTuneID,
            _,
            let thumbnailData,
            let playerNotes
        ) = currentStep,
        tune.request.car.game == .fh6,
        tune.purpose == .numericTune,
        let report = tune.projectionReport,
        report.readyCount > 0,
            authoritativeAction(
                for: tune,
                savedTuneID: savedTuneID,
                persistedTune: nil,
                matchingCommunityTrialCount: matchingCommunityTrialCount
            ) == action else {
            return nil
        }

        switch action {
        case .openFH6TuneMenuLab:
            return .fh6TuneMenuCapture(
                tune,
                savedTuneID: savedTuneID,
                thumbnailData: thumbnailData,
                playerNotes: playerNotes
            )
        case .openTireLab:
            return .tirePressureCapture(
                tune,
                savedTuneID: savedTuneID,
                thumbnailData: thumbnailData,
                playerNotes: playerNotes
            )
        case .openUpgradeLab:
            return .upgradePartCapture(
                tune,
                savedTuneID: savedTuneID,
                thumbnailData: thumbnailData,
                playerNotes: playerNotes
            )
        case .openFH6CommunityReferenceTrial:
            return nil
        }
    }

    private func authoritativeAction(
        for tune: TuneResult,
        savedTuneID: UUID?,
        persistedTune: TuneResult?,
        matchingCommunityTrialCount: Int?
    ) -> CopilotAction? {
        if FH6TuneMenuCaptureEligibility().snapshot(
            for: tune,
            isStreaming: false
        ) != nil {
            return .openFH6TuneMenuLab
        }
        if TirePressureCaptureEligibility().snapshot(for: tune) != nil {
            return .openTireLab
        }
        if UpgradePartCaptureEligibility().snapshot(for: tune) != nil {
            return .openUpgradeLab
        }
        if savedTuneID != nil,
           matchingCommunityTrialCount == 0,
           let persistedTune,
           case .success =
            FH6CommunityReferenceTrialFactory().eligibility(
                for: tune,
                savedTune: persistedTune,
                isStreaming: false
            ) {
            return .openFH6CommunityReferenceTrial
        }
        return nil
    }
}
