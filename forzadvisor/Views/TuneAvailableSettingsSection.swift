import SwiftUI

struct TuneAvailableSettingsSection: View {
    let tune: TuneResult
    let presentation: TuneResultPresentation
    @Binding var expandedSectionTitles: Set<String>
    @Binding var copiedLineID: TuneLine.ID?

    var body: some View {
        Section(presentation.sectionTitle) {
            Text(presentation.sectionDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("availableSettingsBoundary")

            if presentation.completion == .plan {
                ContentUnavailableView(
                    "No numeric settings yet",
                    systemImage: "list.bullet.clipboard",
                    description: Text("Use the setup plan and confirm the missing parts or tuning-menu ranges in game. Then generate again when the evidence is ready.")
                )
            } else if presentation.completion == .needsEvidence {
                ContentUnavailableView(
                    "More game evidence needed",
                    systemImage: "checkmark.shield",
                    description: Text("Forza Advisor withheld numeric values because the current build evidence cannot support them yet.")
                )
            } else if tune.sections.isEmpty {
                ContentUnavailableView(
                    presentation.completion == .incomplete
                        ? "Settings still arriving"
                        : "No settings available",
                    systemImage: presentation.completion == .incomplete
                        ? "ellipsis"
                        : "slider.horizontal.3"
                )
            } else {
                HStack(spacing: 10) {
                    Button("Expand all") {
                        expandedSectionTitles = Set(tune.sections.map(\.title))
                    }
                    .buttonStyle(.bordered)
                    Button("Collapse all") {
                        expandedSectionTitles.removeAll()
                    }
                    .buttonStyle(.bordered)
                }
                .disabled(presentation.completion == .incomplete)

                ForEach(tune.sections) { section in
                    TuneSectionDisclosureView(
                        section: section,
                        isStreaming:
                            presentation.completion == .incomplete,
                        allowsCopy: presentation.allowsCopy,
                        isExpanded: expandedBinding(for: section),
                        copiedLineID: $copiedLineID
                    )
                }
            }
        }
        .forzAdvisorRowBackground()
        .accessibilityIdentifier("availableSettingsSection")
    }

    private func expandedBinding(for section: TuneSection) -> Binding<Bool> {
        Binding {
            expandedSectionTitles.contains(section.title)
        } set: { expanded in
            if expanded {
                expandedSectionTitles.insert(section.title)
            } else {
                expandedSectionTitles.remove(section.title)
            }
        }
    }
}

private extension TuneResultPresentation {
    var sectionTitle: String {
        switch completion {
        case .available: "Available settings"
        case .plan: "Setup plan"
        case .needsEvidence: "Evidence needed"
        case .incomplete: "Available settings"
        case .legacyUnavailable: "Available settings"
        }
    }

    var sectionDescription: String {
        switch completion {
        case .available:
            "Availability means these values can be entered in game. It is not an accuracy or validation score."
        case .plan:
            "No numeric values are being presented yet. This plan keeps the next in-game step explicit."
        case .needsEvidence:
            "Numeric values stay hidden until the required build and tuning-menu evidence is trustworthy."
        case .incomplete:
            "Settings remain unavailable until generation completes."
        case .legacyUnavailable:
            "This saved result predates the current availability checks."
        }
    }
}
