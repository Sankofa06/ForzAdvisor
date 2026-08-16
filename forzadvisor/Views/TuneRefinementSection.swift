import SwiftUI
import UIKit

struct TuneRefinementSection: View {
    let tune: TuneResult
    let proposal: TuneRefinementProposal?
    let canUndo: Bool
    let activeFeedback: TuneFeedback?
    let onApply: () -> Void
    let onDiscard: () -> Void
    let onUndo: () -> Void
    let onFeedback: (TuneFeedback) -> Void

    private var eligibleFeedback: [TuneFeedback] {
        let ready = tune.projectionReport?.readyFieldIDs ?? []
        return TuneFeedback.allCases.filter {
            !ready.intersection($0.adjustment.affectedFields).isEmpty
        }
    }

    var body: some View {
        if let proposal {
            TuneRefinementProposalSection(
                proposal: proposal,
                onApply: onApply,
                onDiscard: onDiscard
            )
        } else if canUndo {
            Section("Saved refinement") {
                Label(
                    "Refinement applied. Undo is available for six seconds.",
                    systemImage: "checkmark.circle.fill"
                )
                .foregroundStyle(ForzAdvisorTheme.success)
                Button("Undo refinement") {
                    onUndo()
                    UIAccessibility.post(
                        notification: .announcement,
                        argument: "Refinement undone"
                    )
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("undoRefinementButton")
            }
            .forzAdvisorRowBackground()
        } else if !eligibleFeedback.isEmpty {
            Section("Saved refinement") {
                Text("Choose one observed symptom. A proposal stays in memory until you review and explicitly apply it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(eligibleFeedback) { feedback in
                    Button {
                        onFeedback(feedback)
                    } label: {
                        HStack(spacing: 10) {
                            if activeFeedback == feedback {
                                ProgressView()
                            } else {
                                Image(systemName: feedback.symbolName)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(feedback.title)
                                    .font(.subheadline.weight(.semibold))
                                Text(feedback.prompt)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                    .disabled(activeFeedback != nil)
                    .accessibilityIdentifier("refine-\(feedback.rawValue)")
                }
            }
            .forzAdvisorRowBackground()
        }
    }
}

private struct TuneRefinementProposalSection: View {
    let proposal: TuneRefinementProposal
    let onApply: () -> Void
    let onDiscard: () -> Void

    var body: some View {
        Section("Refinement proposal") {
            Label(
                "Preview only — the saved tune has not changed",
                systemImage: "eye"
            )
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(ForzAdvisorTheme.accent)

            Text(proposal.feedback.rationale)
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(proposal.changes) { change in
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(change.sectionTitle) · \(change.lineLabel)")
                        .font(.subheadline.weight(.semibold))
                    LabeledContent("Current", value: value(change.oldValue, change.unit))
                    LabeledContent("Proposed", value: value(change.newValue, change.unit))
                    Text(change.rationale ?? proposal.feedback.rationale)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }

            Button("Apply refinement") {
                onApply()
                UIAccessibility.post(
                    notification: .announcement,
                    argument: "Refinement applied. Undo available for six seconds."
                )
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("applyRefinementButton")

            Button("Discard proposal", role: .cancel) {
                onDiscard()
                UIAccessibility.post(
                    notification: .announcement,
                    argument: "Refinement proposal discarded"
                )
            }
            .accessibilityIdentifier("discardRefinementButton")
        }
        .forzAdvisorRowBackground()
        .accessibilityIdentifier("refinementProposalSection")
    }

    private func value(_ value: String, _ unit: String) -> String {
        unit.isEmpty ? value : "\(value) \(unit)"
    }
}
