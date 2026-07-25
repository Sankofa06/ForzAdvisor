//
//  CopilotWorkflowActionRouter.swift
//  forzadvisor
//
//  Revalidates explicit Copilot handoffs against the live root workflow.
//

import Foundation

struct CopilotWorkflowActionRouter {
    func destination(
        for action: CopilotAction,
        from currentStep: WorkflowStep
    ) -> WorkflowStep? {
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
        authoritativeAction(for: tune) == action else {
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
        }
    }

    private func authoritativeAction(for tune: TuneResult) -> CopilotAction? {
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
        return nil
    }
}
