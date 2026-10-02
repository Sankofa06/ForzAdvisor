import SwiftUI

enum TuneResultCaptureActionKind: String, CaseIterable, Identifiable {
    case tuneMenu
    case tirePressures
    case upgradeParts

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tuneMenu: "Verify FH6 Tune Menu"
        case .tirePressures: "Verify Tire Pressures"
        case .upgradeParts: "Verify Upgrade Parts"
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .tuneMenu: "verifyTuneMenuCaptureButton"
        case .tirePressures: "verifyTirePressureCaptureButton"
        case .upgradeParts: "verifyUpgradePartsCaptureButton"
        }
    }

    var hubAccessibilityIdentifier: String {
        switch self {
        case .tuneMenu: "hubVerifyTuneMenuCaptureButton"
        case .tirePressures: "hubVerifyTirePressureCaptureButton"
        case .upgradeParts: "hubVerifyUpgradePartsCaptureButton"
        }
    }
}

struct TuneResultCaptureAction: Identifiable {
    let kind: TuneResultCaptureActionKind
    let perform: () -> Void

    var id: String { kind.id }
    var title: String { kind.title }
    var accessibilityIdentifier: String {
        kind.accessibilityIdentifier
    }
    var hubAccessibilityIdentifier: String {
        kind.hubAccessibilityIdentifier
    }
}

struct TuneResultCaptureActions {
    let onVerifyTuneMenu: (() -> Void)?
    let onVerifyTirePressures: (() -> Void)?
    let onVerifyUpgradeParts: (() -> Void)?
    let isStreaming: Bool

    init(
        onVerifyTuneMenu: (() -> Void)? = nil,
        onVerifyTirePressures: (() -> Void)? = nil,
        onVerifyUpgradeParts: (() -> Void)? = nil,
        isStreaming: Bool = false
    ) {
        self.onVerifyTuneMenu = onVerifyTuneMenu
        self.onVerifyTirePressures = onVerifyTirePressures
        self.onVerifyUpgradeParts = onVerifyUpgradeParts
        self.isStreaming = isStreaming
    }

    var availableActions: [TuneResultCaptureAction] {
        guard !isStreaming else { return [] }

        return [
            onVerifyTuneMenu.map {
                TuneResultCaptureAction(kind: .tuneMenu, perform: $0)
            },
            onVerifyTirePressures.map {
                TuneResultCaptureAction(kind: .tirePressures, perform: $0)
            },
            onVerifyUpgradeParts.map {
                TuneResultCaptureAction(kind: .upgradeParts, perform: $0)
            }
        ].compactMap { $0 }
    }
}

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
    let captureActions: TuneResultCaptureActions
    let evidenceHubDestination: AnyView?
    let upgradePaths: [TuneControlUpgradePath]
    let resolveUpgradePathClipboardText: (String) -> String?
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

            if !upgradePaths.isEmpty {
                Section("Verified tuning-control paths") {
                    TuneControlUpgradePathsView(
                        paths: upgradePaths,
                        resolveClipboardText:
                            resolveUpgradePathClipboardText
                    )
                }
                .forzAdvisorRowBackground()
            }

            TuneEvidenceHubSection(
                summary: evidenceSummary,
                isSaved: isSaved,
                isStreaming: isStreaming,
                captureActions: captureActions,
                destination: evidenceHubDestination,
                availabilityNote: evidenceAvailabilityNote
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
            if presentation.allowsSavedMetadataEdit {
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

    private var evidenceAvailabilityNote: String? {
        if tune.request.car.game == .fh5,
           tune.request.buildSnapshot?.inputFactsSource != .reviewedCatalog {
            return "FH5 Research remains unavailable because photo, OCR, and manual entry do not provide reviewed stock provenance."
        }
        if tune.request.car.game == .fh6,
           (tune.request.car.peakHorsepower == nil
            || tune.request.car.peakTorqueFootPounds == nil) {
            return "Test Drive remains unavailable until optional horsepower and torque are confirmed in a new tune."
        }
        return nil
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
