import SwiftUI

struct TuneResultScreen: View {
    let tune: TuneResult
    let isSaved: Bool
    let isStreaming: Bool
    let playerNotes: String
    let thumbnailData: Data?
    let adjustmentChanges: [TuneAdjustmentChange]
    let activeFeedback: TuneFeedback?
    let rootActions: TuneResultRootActions
    let showsFirstSavedSetupStepGuideHandoff: Bool
    let evidenceSummary: TuneEvidenceSummary
    let evidenceHubDestination: AnyView?
    let onContinueFirstSavedSetupWithStepGuide: () -> Void
    let onDismissFirstSavedSetupStepGuideHandoff: () -> Void
    let onDone: () -> Void
    let onSave: () -> TuneResultSaveOutcome
    let onEdit: () -> Void
    let onFeedback: (TuneFeedback) -> Void

    @State private var copiedLineID: TuneLine.ID?
    @State private var saveMessage: String?
    @State private var expandedSectionTitles = Set(
        TuneSection.menuOrder.map(\.title)
    )

    private var presentation: TuneResultPresentation {
        TuneResultPresentation(
            tune: tune,
            isSaved: isSaved,
            isStreaming: isStreaming
        )
    }

    var body: some View {
        List {
            TuneResultStatusSection(
                tune: tune,
                presentation: presentation,
                thumbnailData: thumbnailData,
                onCancelStreaming: rootActions.onCancelStreaming
            )

            TuneResultActionSection(
                tune: tune,
                presentation: presentation,
                onSave: save
            )

            if let saveMessage {
                Section {
                    Label(saveMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(ForzAdvisorTheme.warning)
                        .accessibilityIdentifier("saveTuneInlineError")
                }
                .forzAdvisorRowBackground()
            }

            TuneAvailableSettingsSection(
                tune: tune,
                presentation: presentation,
                expandedSectionTitles: $expandedSectionTitles,
                copiedLineID: $copiedLineID
            )

            if presentation.allowsSavedConsequentialActions {
                TuneRefinementSection(
                    tune: tune,
                    proposal: rootActions.refinementProposal,
                    canUndo: rootActions.canUndoRefinement,
                    activeFeedback: activeFeedback,
                    onApply: rootActions.onApplyRefinement,
                    onDiscard: rootActions.onDiscardRefinement,
                    onUndo: rootActions.onUndoRefinement,
                    onFeedback: onFeedback
                )
            }

            TuneAdjustmentHistorySection(changes: adjustmentChanges)
            TuneResultNotesSection(tune: tune, playerNotes: playerNotes)

            TuneEvidenceHubSection(
                summary: evidenceSummary,
                isSaved: isSaved,
                isStreaming: isStreaming,
                destination: evidenceHubDestination
            )

            if showsFirstSavedSetupStepGuideHandoff {
                FirstSavedSetupStepGuideSection(
                    onContinue: onContinueFirstSavedSetupWithStepGuide,
                    onDismiss: onDismissFirstSavedSetupStepGuideHandoff
                )
            }
        }
        .navigationTitle(tune.purpose == .fh5BuildPlan ? "Build Plan" : "Tune")
        .forzAdvisorScreenChrome()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Done", action: onDone)
                    .accessibilityIdentifier("doneTuneButton")
            }
            if presentation.allowsSavedConsequentialActions {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit", action: onEdit)
                        .disabled(activeFeedback != nil || isStreaming)
                        .accessibilityIdentifier("editSavedTuneButton")
                }
            }
        }
        .onDisappear {
            if showsFirstSavedSetupStepGuideHandoff {
                onDismissFirstSavedSetupStepGuideHandoff()
            }
        }
    }

    private func save() {
        switch onSave() {
        case .saved:
            saveMessage = nil
            UIAccessibility.post(
                notification: .announcement,
                argument: "Saved"
            )
        case .failed(let message):
            saveMessage = message
            UIAccessibility.post(
                notification: .announcement,
                argument: message
            )
        }
    }
}

private struct FirstSavedSetupStepGuideSection: View {
    let onContinue: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        Section {
            Label("Your first setup is saved locally", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(ForzAdvisorTheme.success)
            Text("Step Guide can suggest the safest next step for this saved result. It is local, deterministic, and keeps no transcript.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Continue with Step Guide", action: onContinue)
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("continueFirstSavedSetupWithCopilotButton")
            Button("Not Now", action: onDismiss)
                .accessibilityIdentifier("dismissFirstSavedSetupCopilotHandoffButton")
        }
        .forzAdvisorRowBackground()
        .accessibilityIdentifier("firstSavedSetupCopilotHandoffSection")
    }
}
