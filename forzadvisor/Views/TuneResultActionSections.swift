import SwiftUI
import UIKit

struct TuneResultStatusSection: View {
    let tune: TuneResult
    let presentation: TuneResultPresentation
    let thumbnailData: Data?
    let onCancelStreaming: () -> Void

    var body: some View {
        Section {
            HStack(alignment: .top, spacing: 12) {
                TuneResultThumbnail(
                    data: thumbnailData,
                    fallbackSymbol: tune.request.discipline.symbolName
                )
                VStack(alignment: .leading, spacing: 7) {
                    Text(tune.request.car.displayName)
                        .font(.title2.weight(.bold))
                    Text("\(tune.request.discipline.title) · \(tune.request.car.performanceClass.rawValue) \(tune.request.car.performanceIndex) · \(tune.request.car.drivetrain.rawValue)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Label(
                        presentation.statusTitle,
                        systemImage: statusSymbol
                    )
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(statusColor)
                    Text(presentation.statusDetail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TuneActualProviderView(tune: tune)
                }
            }
            .padding(.vertical, 4)

            if presentation.completion == .incomplete {
                Button("Cancel generation", role: .cancel, action: onCancelStreaming)
                    .accessibilityIdentifier("cancelStreamingTuneGenerationButton")
            }
        }
        .listRowBackground(ForzAdvisorTheme.heroRowBackground)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("tuneResultStatus")
        .onAppear {
            guard presentation.completion == .incomplete else { return }
            UIAccessibility.post(
                notification: .announcement,
                argument: presentation.statusDetail
            )
        }
    }

    private var statusSymbol: String {
        switch presentation.completion {
        case .incomplete: "clock.arrow.trianglehead.counterclockwise.rotate.90"
        case .available: presentation.isSaved ? "checkmark.circle.fill" : "checkmark.shield"
        case .legacyUnavailable: "exclamationmark.triangle"
        }
    }

    private var statusColor: Color {
        presentation.completion == .available
            ? ForzAdvisorTheme.success
            : ForzAdvisorTheme.warning
    }
}

struct TuneResultActionSection: View {
    let tune: TuneResult
    let presentation: TuneResultPresentation
    let onSave: () -> Void

    @State private var feedback: String?

    var body: some View {
        Section("Apply in game") {
            if presentation.allowsCopyOrSave {
                if let text = TuneClipboardFormatter.verifiedSettingsText(for: tune) {
                    actionButton(
                        title: "Copy available settings",
                        systemImage: "doc.on.doc",
                        identifier: "copyVerifiedSettingsButton"
                    ) {
                        UIPasteboard.general.string = text
                        announce("Available settings copied")
                    }
                }
                if let text = TuneClipboardFormatter.buildPlanText(for: tune) {
                    actionButton(
                        title: "Copy build plan",
                        systemImage: "doc.on.doc",
                        identifier: "copyBuildPlanButton"
                    ) {
                        UIPasteboard.general.string = text
                        announce("Build plan copied")
                    }
                }

                if presentation.isSaved {
                    Label("Saved locally", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(ForzAdvisorTheme.success)
                        .accessibilityIdentifier("savedTuneStatus")
                } else {
                    actionButton(
                        title: tune.purpose == .fh5BuildPlan ? "Save Plan" : "Save",
                        systemImage: "square.and.arrow.down",
                        identifier: "saveTuneButton"
                    ) {
                        onSave()
                        announce("Save requested")
                    }
                }
            } else {
                Label(
                    "Copy and Save unavailable until this result is complete",
                    systemImage: "lock.fill"
                )
                .font(.subheadline)
                .foregroundStyle(ForzAdvisorTheme.warning)
                .accessibilityIdentifier("incompleteResultActionsUnavailable")
            }

            if let feedback {
                Label(feedback, systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ForzAdvisorTheme.success)
                    .accessibilityIdentifier("tuneResultActionFeedback")
            }
        }
        .forzAdvisorRowBackground()
    }

    private func actionButton(
        title: String,
        systemImage: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }
        .buttonStyle(.borderedProminent)
        .accessibilityIdentifier(identifier)
    }

    private func announce(_ message: String) {
        feedback = message
        UIAccessibility.post(notification: .announcement, argument: message)
    }
}

private struct TuneResultThumbnail: View {
    let data: Data?
    let fallbackSymbol: String

    var body: some View {
        if let data, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 72, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            ForzAdvisorIcon(
                systemName: fallbackSymbol,
                tint: ForzAdvisorTheme.accent,
                size: 44
            )
        }
    }
}

private struct TuneActualProviderView: View {
    let tune: TuneResult

    private var presentation: TuneActualProviderPresentation {
        TuneActualProviderPresentation(tune: tune)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(presentation.title, systemImage: presentation.symbolName)
            Text(presentation.detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
            .font(.caption.weight(.semibold))
            .foregroundStyle(providerColor)
            .accessibilityIdentifier("providerStatus")
    }

    private var providerColor: Color {
        presentation.usedFallback
            ? ForzAdvisorTheme.warning
            : ForzAdvisorTheme.accent
    }
}
