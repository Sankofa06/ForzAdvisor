import SwiftUI

struct TuneResultNotesSection: View {
    let tune: TuneResult
    let playerNotes: String

    var body: some View {
        if tune.purpose != .fh5BuildPlan || !playerNotes.isEmpty {
            Section("Notes") {
                if tune.purpose != .fh5BuildPlan {
                    NoteRow(title: "Bias", text: tune.notes.bias)
                    NoteRow(title: "If pushes wide", text: tune.notes.ifPushesWide)
                    NoteRow(title: "If snaps on lift", text: tune.notes.ifSnapsOnLift)
                    NoteRow(title: "Retune", text: tune.notes.retuneTrigger)
                }
                if !playerNotes.isEmpty {
                    NoteRow(title: "Garage notes", text: playerNotes)
                }
            }
            .forzAdvisorRowBackground()
        }
    }
}

struct TuneAdjustmentHistorySection: View {
    let changes: [TuneAdjustmentChange]

    var body: some View {
        if !changes.isEmpty {
            Section("Last applied changes") {
                ForEach(changes) { change in
                    VStack(alignment: .leading, spacing: 5) {
                        Text("\(change.sectionTitle) · \(change.lineLabel)")
                            .font(.subheadline.weight(.semibold))
                        Text("\(value(change.oldValue, change.unit)) → \(value(change.newValue, change.unit))")
                            .font(.system(.body, design: .monospaced))
                        if let rationale = change.rationale {
                            Text(rationale)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .forzAdvisorRowBackground()
        }
    }

    private func value(_ value: String, _ unit: String) -> String {
        unit.isEmpty ? value : "\(value) \(unit)"
    }
}

private struct NoteRow: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.subheadline)
        }
        .accessibilityElement(children: .combine)
    }
}
