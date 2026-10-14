import SwiftUI
import UIKit

struct TuneResultStatusSection: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let tune: TuneResult
    let presentation: TuneResultPresentation
    let thumbnailData: Data?
    let onCancelStreaming: () -> Void

    var body: some View {
        Section {
            statusLayout {
                TuneResultThumbnail(
                    data: thumbnailData,
                    fallbackSymbol: tune.request.discipline.symbolName
                )
                VStack(alignment: .leading, spacing: 7) {
                    Text(tune.request.car.displayName)
                        .font(.title2.weight(.bold))
                        .accessibilityAddTraits(.isHeader)
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
                    TuneActualProviderView(
                        tune: tune,
                        isComplete:
                            presentation.completion != .incomplete
                    )
                }
            }
            .padding(.vertical, 4)

            if presentation.completion == .incomplete {
                Button("Cancel generation", role: .cancel, action: onCancelStreaming)
                    .forzAdvisorMinimumTouchTarget()
                    .accessibilityIdentifier("cancelStreamingTuneGenerationButton")
            }
        }
        .listRowBackground(ForzAdvisorTheme.heroRowBackground)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("tuneResultStatus")
        .onAppear {
            guard presentation.completion == .incomplete else { return }
            announceStatus()
        }
        .onChange(of: presentation.completion) { oldValue, newValue in
            guard oldValue == .incomplete, newValue != .incomplete else { return }
            announceStatus()
        }
    }

    private var statusLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
    }

    private func announceStatus() {
        let provider = TuneActualProviderPresentation(
            tune: tune,
            isComplete: presentation.completion != .incomplete
        )
        UIAccessibility.post(
            notification: .announcement,
            argument: "\(presentation.statusTitle). \(presentation.statusDetail) \(provider.title)."
        )
    }

    private var statusSymbol: String {
        switch presentation.completion {
        case .incomplete: "clock.arrow.trianglehead.counterclockwise.rotate.90"
        case .available: presentation.isSaved ? "checkmark.circle.fill" : "checkmark.shield"
        case .plan: "list.bullet.clipboard"
        case .needsEvidence: "checkmark.shield"
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let tune: TuneResult
    let presentation: TuneResultPresentation
    let onSave: () -> Void

    @State private var feedback: String?

    var body: some View {
        Section("Apply in game") {
            if presentation.allowsSave {
                if !presentation.isSaved {
                    saveButton
                }

                if presentation.allowsCopy,
                   let text = TuneClipboardFormatter.verifiedSettingsText(for: tune) {
                    actionButton(
                        title: "Copy available settings",
                        systemImage: "doc.on.doc",
                        identifier: "copyVerifiedSettingsButton",
                        kind: presentation.isSaved ? .primary : .secondary
                    ) {
                        UIPasteboard.general.string = text
                        announce("Available settings copied")
                    }
                }

                if let text = TuneClipboardFormatter.buildPlanText(for: tune) {
                    actionButton(
                        title: "Copy setup plan",
                        systemImage: "doc.on.doc",
                        identifier: "copyBuildPlanButton",
                        kind: .secondary
                    ) {
                        UIPasteboard.general.string = text
                        announce("Setup plan copied")
                    }
                }

                if presentation.isSaved {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .accessibilityHidden(true)
                        Text(presentation.hasAvailableSettings ? "Saved locally" : "Saved setup")
                            .accessibilityIdentifier("savedTuneStatus")
                    }
                    .foregroundStyle(ForzAdvisorTheme.success)
                }

                if !presentation.hasAvailableSettings {
                    Label(
                        "No numeric settings are available. Copying numeric settings and refinement remain unavailable.",
                        systemImage: "slider.horizontal.3"
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("zeroSettingSetupNotice")
                }
            } else if presentation.completion == .incomplete {
                Label(
                    "Copy and Save unavailable until this result is complete",
                    systemImage: "lock.fill"
                )
                .font(.subheadline)
                .foregroundStyle(ForzAdvisorTheme.warning)
                .accessibilityIdentifier("incompleteResultActionsUnavailable")
            } else {
                Label(
                    "Copy and Save unavailable for this legacy result",
                    systemImage: "exclamationmark.triangle"
                )
                .font(.subheadline)
                .foregroundStyle(ForzAdvisorTheme.warning)
                .accessibilityIdentifier("legacyResultActionsUnavailable")
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

    private var saveButton: some View {
        actionButton(
            title: tune.purpose == .fh5BuildPlan
                ? "Save Plan"
                : presentation.hasAvailableSettings ? "Save" : "Save Setup",
            systemImage: "square.and.arrow.down",
            identifier: "saveTuneButton",
            kind: .primary,
            action: onSave
        )
    }

    private func actionButton(
        title: String,
        systemImage: String,
        identifier: String,
        kind: ForzAdvisorActionKind,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            if dynamicTypeSize.isAccessibilitySize {
                Text(title)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            } else {
                Label(title, systemImage: systemImage)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
        }
        .buttonStyle(ForzAdvisorActionButtonStyle(kind: kind))
        .accessibilityLabel(title)
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
    let isComplete: Bool

    private var presentation: TuneActualProviderPresentation {
        TuneActualProviderPresentation(
            tune: tune,
            isComplete: isComplete
        )
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
