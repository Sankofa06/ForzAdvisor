import SwiftUI

struct TuneEvidenceHubSection: View {
    let summary: TuneEvidenceSummary
    let isSaved: Bool
    let isStreaming: Bool
    let destination: AnyView?
    let availabilityNote: String?

    var body: some View {
        Section("Optional Validation & Research") {
            Label("Optional", systemImage: "flask")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(ForzAdvisorTheme.accent)
            Text("Use Evidence Hub later if you want to record on-device observations, choose future reuse, or review shared evidence. It never changes available settings automatically.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let availabilityNote {
                Label(
                    availabilityNote,
                    systemImage: "info.circle"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier(
                    "evidenceCaptureAvailabilityNote"
                )
            }

            if isSaved && !isStreaming {
                LabeledContent("Local records", value: "\(summary.localRecordCount)")
                LabeledContent("Reusable records", value: "\(summary.exportableRecordCount)")
                LabeledContent("Reviewed records", value: "\(summary.reviewedRecordCount)")
                if let destination {
                    NavigationLink("Open Evidence Hub", destination: destination)
                        .accessibilityIdentifier("openTuneEvidenceHubButton")
                }
            } else {
                Text("Save the complete result before adding optional evidence.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .forzAdvisorRowBackground()
    }
}
