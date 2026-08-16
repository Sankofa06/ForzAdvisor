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
    let evidenceSummary: TuneEvidenceSummary
    let showsFirstSavedSetupCopilotHandoff: Bool
    let onContinueFirstSavedSetupWithCopilot: () -> Void
    let onDismissFirstSavedSetupCopilotHandoff: () -> Void
    let onDone: () -> Void
    let onSave: () -> TuneResultSaveOutcome
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
    let validationEvidenceRecords: [ValidationEvidenceRecord]
    let evidenceAuthorization:
        (String) -> ValidationEvidenceAuthorizationEnvelope?
    let onGrantEvidenceReuse:
        (String) throws -> ValidationEvidenceAuthorizationEnvelope
    let onRevokeEvidenceReuse:
        (FirstPartyValidationRecord) throws
            -> ValidationEvidenceAuthorizationEnvelope?
    let onDeleteValidationEvidence:
        (ValidationEvidenceRecord) throws -> Void
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

    private var evidenceHubDestination: AnyView {
        AnyView(TuneEvidenceHubView(adapter: .init(
            summary: evidenceSummary,
            evidenceRecords: validationEvidenceRecords,
            onRecordTestDrive: onRecordTestDrive,
            onOpenFH5Research: onOpenFH5Research,
            onOpenFH5Experiment: onOpenFH5ControlledExperiment,
            onRunFH6CommunityTrial: onRunFH6CommunityReferenceTrial,
            fh5ResearchReview: fh5ResearchReviewDestination,
            fh5CandidateReview: fh5CandidateReviewDestination,
            fh6ValidationReview: fh6ValidationReviewDestination,
            fh6CommunityReview: fh6CommunityReviewDestination,
            authorization: evidenceAuthorization,
            onGrant: onGrantEvidenceReuse,
            onRevoke: onRevokeEvidenceReuse,
            onDelete: onDeleteValidationEvidence
        )))
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
            evidenceHubDestination:
                isSaved && !isStreaming ? evidenceHubDestination : nil,
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

    private var fh5ResearchReviewDestination: AnyView? {
        guard let onImportFH5ResearchReviewEntry else { return nil }
        return AnyView(FH5ResearchReviewView(
            tune: tune,
            entries: fh5ResearchReviewEntries,
            onImport: onImportFH5ResearchReviewEntry,
            onDelete: onDeleteFH5ResearchReviewEntry
        ))
    }

    private var fh5CandidateReviewDestination: AnyView? {
        guard let artifact = fh5CandidateTrialArtifact,
              let onImportFH5CandidateOutcomeReviewEntry else { return nil }
        return AnyView(FH5CandidateOutcomeReviewView(
            artifact: artifact,
            entries: fh5CandidateOutcomeReviewEntries,
            report: fh5CandidateOutcomeCollectionReport,
            storageError: fh5CandidateOutcomeReviewLoadError,
            onImport: onImportFH5CandidateOutcomeReviewEntry,
            onDelete: onDeleteFH5CandidateOutcomeReviewEntry,
            onPrepareNumericPromotionReviewPacket:
                onPrepareFH5NumericPromotionReviewPacket,
            preparedInputStateFingerprint:
                fh5NumericPromotionPreparedInputStateFingerprint,
            onValidateNumericPromotionReviewPacket:
                onValidateFH5NumericPromotionReviewPacket,
            receiverCandidateFingerprint:
                fh5NumericPromotionReceiverCandidateFingerprint
        ))
    }

    private var fh6ValidationReviewDestination: AnyView? {
        guard let onImportFH6ValidationReviewEntry,
              let fh6AccuracyEvidenceChain else { return nil }
        return AnyView(FH6ValidationReviewView(
            tune: tune,
            entries: fh6ValidationReviewEntries,
            storageError: fh6ValidationReviewLoadError,
            onImport: onImportFH6ValidationReviewEntry,
            onDelete: onDeleteFH6ValidationReviewEntry,
            onPrepareIndependentReviewPacket:
                onPrepareFH6IndependentValidationReviewPacket,
            preparedInputStateFingerprint:
                fh6IndependentValidationPreparedInputStateFingerprint,
            onValidateIndependentReviewPacket:
                onValidateFH6IndependentValidationReviewPacket,
            receiverCandidateRevisionFingerprint:
                fh6IndependentValidationReceiverCandidateFingerprint,
            communityReferenceRecords: fh6CommunityReferenceTrialRecords,
            accuracyEvidenceChain: fh6AccuracyEvidenceChain,
            onRunCommunityReferenceTrial:
                onRunFH6CommunityReferenceTrial,
            onOpenCommunityOutcomeReview: nil
        ))
    }

    private var fh6CommunityReviewDestination: AnyView? {
        guard let onImportFH6CommunityOutcomeReviewEntry,
              let onValidateFH6CommunityOutcomeReviewJSON else { return nil }
        return AnyView(FH6CommunityOutcomeReviewView(
            tune: tune,
            localRecords: fh6CommunityReferenceTrialRecords,
            entries: fh6CommunityOutcomeReviewEntries,
            report: fh6CommunityOutcomeCollectionReport,
            storageError: fh6CommunityOutcomeReviewLoadError,
            onImport: onImportFH6CommunityOutcomeReviewEntry,
            onValidateCurrentCandidate:
                onValidateFH6CommunityOutcomeReviewJSON,
            onDelete: onDeleteFH6CommunityOutcomeReviewEntry
        ))
    }
}
