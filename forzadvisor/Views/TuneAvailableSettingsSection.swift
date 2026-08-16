import SwiftUI

struct TuneAvailableSettingsSection: View {
    let tune: TuneResult
    let presentation: TuneResultPresentation
    @Binding var expandedSectionTitles: Set<String>
    @Binding var copiedLineID: TuneLine.ID?

    var body: some View {
        Section("Available settings") {
            Text("Availability means these values can be entered in game. It is not an accuracy or validation score.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("availableSettingsBoundary")

            if tune.sections.isEmpty {
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
                        allowsCopy: presentation.allowsCopyOrSave,
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
