import SwiftUI

struct TuneResultView: View {
    let tune: TuneResult
    let isSaved: Bool
    var isStreaming = false
    let playerNotes: String
    let thumbnailData: Data?
    let adjustmentChanges: [TuneAdjustmentChange]
    let activeFeedback: TuneFeedback?
    let rootActions: TuneResultRootActions
    let showsFirstSavedSetupCopilotHandoff: Bool
    let onContinueFirstSavedSetupWithCopilot: () -> Void
    let onDismissFirstSavedSetupCopilotHandoff: () -> Void
    let onDone: () -> Void
    let onSave: () -> Void
    let onEdit: () -> Void
    let onVerifyTuneMenu: (() -> Void)?
    let onVerifyTirePressures: (() -> Void)?
    let onVerifyUpgradeParts: (() -> Void)?
    let latestFH5ResearchRecord: FH5ResearchObservationRecord?
    let fh5NumericReadiness: FH5NumericReadinessAssessment?
    let onOpenFH5Research: (() -> Void)?
    let onDeleteFH5ResearchRecord: (FH5ResearchObservationRecord) -> Void
    let fh5ResearchReviewEntries: [FH5ResearchReviewEntry]
    let onImportFH5ResearchReviewEntry: ((FH5ResearchReviewEntry) -> String?)?
    let onDeleteFH5ResearchReviewEntry: (FH5ResearchReviewEntry) -> Void
    let latestFH5ControlledExperimentRecord: FH5ControlledExperimentRecord?
    let fh5CandidateTrialAvailable: Bool
    let fh5CandidateOutcomeReport: FH5ControlledOutcomePolicyReport?
    let fh5CandidateTrialArtifact: FH5GeneratedCandidateArtifact?
    let fh5CandidateOutcomeReviewEntries: [FH5CandidateOutcomeReviewEntry]
    let fh5CandidateOutcomeCollectionReport: FH5CandidateOutcomeCollectionReport
    let fh5CandidateOutcomeReviewLoadError: String?
    let onImportFH5CandidateOutcomeReviewEntry: ((FH5CandidateOutcomeReviewEntry) -> String?)?
    let onDeleteFH5CandidateOutcomeReviewEntry: (FH5CandidateOutcomeReviewEntry) -> Void
    let onPrepareFH5NumericPromotionReviewPacket: (() throws -> String)?
    let fh5NumericPromotionPreparedInputStateFingerprint: String?
    let onValidateFH5NumericPromotionReviewPacket: ((Data) throws -> FH5NumericPromotionReviewPacket)?
    let fh5NumericPromotionReceiverCandidateFingerprint: String?
    let onOpenFH5ControlledExperiment: (() -> Void)?
    let onDeleteFH5ControlledExperimentRecord: (FH5ControlledExperimentRecord) -> Void
    let latestValidationRecord: FirstPartyValidationRecord?
    let onRecordTestDrive: (() -> Void)?
    let onDeleteValidationRecord: (FirstPartyValidationRecord) -> Void
    let fh6ValidationReviewEntries: [FH6ValidationReviewEntry]
    let fh6ValidationReviewLoadError: String?
    let onImportFH6ValidationReviewEntry: ((FH6ValidationReviewEntry) -> String?)?
    let onDeleteFH6ValidationReviewEntry: (FH6ValidationReviewEntry) -> Void
    let onPrepareFH6IndependentValidationReviewPacket: (() throws -> String)?
    let fh6IndependentValidationPreparedInputStateFingerprint: String?
    let onValidateFH6IndependentValidationReviewPacket: ((Data) throws -> FH6IndependentValidationReviewPacket)?
    let fh6IndependentValidationReceiverCandidateFingerprint: String?
    let fh6CommunityReferenceTrialRecords: [FH6CommunityReferenceTrialRecord]
    let fh6AccuracyEvidenceChain: FH6AccuracyEvidenceChainAssessment?
    let fh6CommunityReferenceTrialLoadError: String?
    let onRunFH6CommunityReferenceTrial: (() -> Void)?
    let onDeleteFH6CommunityReferenceTrialRecord: (FH6CommunityReferenceTrialRecord) -> Void
    let fh6CommunityOutcomeReviewEntries: [FH6CommunityOutcomeReviewEntry]
    let fh6CommunityOutcomeCollectionReport: FH6CommunityOutcomeCollectionReport
    let fh6CommunityOutcomeReviewLoadError: String?
    let onImportFH6CommunityOutcomeReviewEntry: ((FH6CommunityOutcomeReviewEntry) -> String?)?
    let onValidateFH6CommunityOutcomeReviewJSON: ((Data) -> String?)?
    let onDeleteFH6CommunityOutcomeReviewEntry: (FH6CommunityOutcomeReviewEntry) -> Void
    let onFeedback: (TuneFeedback) -> Void

    private var evidenceSummary: TuneEvidenceSummary {
        let localCount = [
            latestFH5ResearchRecord != nil,
            latestFH5ControlledExperimentRecord != nil,
            latestValidationRecord != nil
        ].filter { $0 }.count + fh6CommunityReferenceTrialRecords.count
        let reviewedCount = fh5ResearchReviewEntries.count
            + fh5CandidateOutcomeReviewEntries.count
            + fh6ValidationReviewEntries.count
            + fh6CommunityOutcomeReviewEntries.count
        return TuneEvidenceSummary(
            savedTuneID: tune.id,
            localOnlyRecordCount: localCount,
            reusableRecordCount: 0,
            reviewedRecordCount: reviewedCount
        )
    }

    var body: some View {
        TuneResultScreen(
            tune: tune,
            isSaved: isSaved,
            isStreaming: isStreaming,
            playerNotes: playerNotes,
            thumbnailData: thumbnailData,
            adjustmentChanges: adjustmentChanges,
            activeFeedback: activeFeedback,
            rootActions: rootActions,
            showsFirstSavedSetupStepGuideHandoff:
                showsFirstSavedSetupCopilotHandoff,
            evidenceSummary: evidenceSummary,
            onContinueFirstSavedSetupWithStepGuide:
                onContinueFirstSavedSetupWithCopilot,
            onDismissFirstSavedSetupStepGuideHandoff:
                onDismissFirstSavedSetupCopilotHandoff,
            onDone: onDone,
            onSave: onSave,
            onEdit: onEdit,
            onFeedback: onFeedback
        )
    }
}
