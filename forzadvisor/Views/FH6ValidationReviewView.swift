//
//  FH6ValidationReviewView.swift
//  forzadvisor
//
//  Plain-language hub for optional, tune-scoped FH6 review work.
//

import SwiftUI

struct FH6ValidationReviewView: View {
    let tune: TuneResult
    let entries: [FH6ValidationReviewEntry]
    let storageError: String?
    let onImport: (FH6ValidationReviewEntry) -> String?
    let onDelete: (FH6ValidationReviewEntry) -> Void
    let onPrepareIndependentReviewPacket: (() throws -> String)?
    let preparedInputStateFingerprint: String?
    let onValidateIndependentReviewPacket:
        ((Data) throws -> FH6IndependentValidationReviewPacket)?
    let receiverCandidateRevisionFingerprint: String?
    let communityReferenceRecords: [FH6CommunityReferenceTrialRecord]
    let accuracyEvidenceChain: FH6AccuracyEvidenceChainAssessment
    let onRunCommunityReferenceTrial: (() -> Void)?
    let onOpenCommunityOutcomeReview: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var importState = FH6ValidationImportPresentationState()
    @State private var packetState = FH6IndependentReviewPresentationState()
    @State private var showsDiscardWarning = false

    private var report: FH6ValidationReviewReport {
        FH6ValidationReviewEvaluator().evaluate(entries)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("Optional review workspace", systemImage: "checkmark.shield")
                        .font(.headline)
                    Text("Review shared test-drive observations without changing this tune, its settings, or its ruleset.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .forzAdvisorRowBackground()

                if let storageError {
                    Section("On this device") {
                        Label(storageError, systemImage: "externaldrive.badge.exclamationmark")
                            .font(.caption)
                            .foregroundStyle(ForzAdvisorTheme.warning)
                    }
                    .forzAdvisorRowBackground()
                }

                Section("Choose a task") {
                    destinationLink(
                        .importSharedSession,
                        detail: importState.hasUnimportedText
                            ? "Pasted text is waiting for you"
                            : "Check and add a shared test-drive session"
                    ) {
                        FH6ValidationImportView(
                            tune: tune,
                            storageError: storageError,
                            state: $importState,
                            packetState: $packetState,
                            onImport: onImport
                        )
                    }

                    destinationLink(
                        .reviewedSessions,
                        detail: "\(report.verifiedUniqueSessionCount) accepted session\(report.verifiedUniqueSessionCount == 1 ? "" : "s")"
                    ) {
                        FH6ValidationReviewedSessionsView(report: report)
                    }

                    destinationLink(
                        .localReviewQueue,
                        detail: "\(entries.count) local reviewed cop\(entries.count == 1 ? "y" : "ies")"
                    ) {
                        FH6ValidationLocalQueueView(
                            entries: entries,
                            packetState: $packetState,
                            onDelete: onDelete
                        )
                    }

                    destinationLink(
                        .independentReviewFiles,
                        detail: "Create or inspect a review-only file"
                    ) {
                        FH6IndependentReviewFilesView(
                            tune: tune,
                            state: $packetState,
                            preparedInputStateFingerprint:
                                preparedInputStateFingerprint,
                            onPrepare: onPrepareIndependentReviewPacket,
                            candidateRevisionFingerprint:
                                receiverCandidateRevisionFingerprint,
                            onValidate: onValidateIndependentReviewPacket
                        )
                    }
                }
                .forzAdvisorRowBackground()

                Section("Related on the result screen") {
                    Text("Community comparisons remain a separate optional activity on the Tune Result screen; they are not duplicated or counted as imported validation sessions here.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .forzAdvisorRowBackground()
            }
            .navigationTitle("Validation Review")
            .forzAdvisorScreenChrome()
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    ModalCopilotToolbarLink(
                        destination: .fh6ValidationReview(
                            carDisplayName: tune.request.car.displayName,
                            gameTitle: tune.request.car.game.shortTitle,
                            disciplineTitle: tune.request.discipline.title
                        )
                    )
                    Button("Done") { requestDismissal() }
                }
            }
            .alert("Discard pasted text?", isPresented: $showsDiscardWarning) {
                Button("Keep Reviewing", role: .cancel) {}
                Button("Discard & Close", role: .destructive) {
                    clearTransientState()
                    dismiss()
                }
            } message: {
                Text("Pasted review text is still in memory. Closing now clears it without importing or saving it.")
            }
        }
        .interactiveDismissDisabled(hasTransientPastedText)
        .onDisappear { clearTransientState() }
    }

    private func destinationLink<Destination: View>(
        _ destination: FH6ValidationReviewHubDestination,
        detail: String,
        @ViewBuilder content: () -> Destination
    ) -> some View {
        NavigationLink(destination: content()) {
            Label {
                VStack(alignment: .leading, spacing: 3) {
                    Text(destination.title).font(.subheadline.weight(.semibold))
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: destination.systemImage)
                    .foregroundStyle(ForzAdvisorTheme.accent)
                    .frame(width: 28)
            }
        }
        .accessibilityIdentifier(destination.accessibilityIdentifier)
    }

    private func requestDismissal() {
        if hasTransientPastedText {
            showsDiscardWarning = true
        } else {
            clearTransientState()
            dismiss()
        }
    }

    private func clearTransientState() {
        importState.clear()
        packetState.clearAll()
    }

    private var hasTransientPastedText: Bool {
        importState.hasUnimportedText || packetState.hasPastedPacketText
    }
}
