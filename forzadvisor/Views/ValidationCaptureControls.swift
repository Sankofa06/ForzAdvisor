import SwiftUI

struct ValidationCaptureProgressSection: View {
    let completed: Int
    let required: Int
    let next: String?
    let focusNext: (() -> Void)?

    var body: some View {
        Section("Required Progress") {
            Label(
                "\(completed) of \(required) required fields complete",
                systemImage: completed == required
                    ? "checkmark.circle" : "circle.dotted"
            )
            if let next {
                Text("Next: \(next)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let focusNext {
                    Button("Go to first incomplete field", action: focusNext)
                }
            }
        }
    }
}

struct ValidationDraftActionsSection: View {
    let saveAndExit: () -> Void
    let discard: () -> Void

    @State private var confirmingDiscard = false

    var body: some View {
        Section {
            Button("Save & Exit", action: saveAndExit)
            Button("Discard Draft", role: .destructive) {
                confirmingDiscard = true
            }
        }
        .confirmationDialog(
            "Discard this validation draft?",
            isPresented: $confirmingDiscard,
            titleVisibility: .visible
        ) {
            Button("Discard Draft", role: .destructive, action: discard)
            Button("Keep Editing", role: .cancel) {}
        } message: {
            Text("Only the unfinished factual fields stored on this device will be removed.")
        }
    }
}

struct ValidationRecoveryMessageSection: View {
    let message: String?

    var body: some View {
        if let message {
            Section {
                Label(message, systemImage: "info.circle")
                    .font(.caption)
            }
        }
    }
}
