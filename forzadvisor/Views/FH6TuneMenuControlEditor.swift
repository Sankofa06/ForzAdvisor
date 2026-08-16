import SwiftUI

struct FH6TuneMenuControlDraft {
    var availability: FH6TuneMenuFieldAvailability?
    var minimum = ""
    var maximum = ""
    var step = ""
    var current = ""
}

struct FH6TuneMenuControlEditor: View {
    let field: TuneFieldID
    @Binding var draft: FH6TuneMenuControlDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(field.projectionLabel)
                        .font(.subheadline.weight(.semibold))
                    Text(field.expectedDisplayUnit.isEmpty
                         ? "No unit" : field.expectedDisplayUnit)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Picker("State", selection: availability) {
                    Text("Not reviewed")
                        .tag(FH6TuneMenuFieldAvailability?.none)
                    ForEach(
                        FH6TuneMenuFieldAvailability.allCases,
                        id: \.rawValue
                    ) {
                        Text(title($0)).tag(Optional($0))
                    }
                }
                .labelsHidden()
                .accessibilityLabel("\(field.projectionLabel) state")
            }
            if draft.availability == .adjustable {
                HStack(spacing: 8) {
                    number("Min", value: $draft.minimum)
                    number("Max", value: $draft.maximum)
                    number("Step", value: $draft.step)
                    number("Current", value: $draft.current)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var availability: Binding<FH6TuneMenuFieldAvailability?> {
        Binding(
            get: { draft.availability },
            set: { value in
                draft.availability = value
                if value != .adjustable {
                    draft.minimum = ""
                    draft.maximum = ""
                    draft.step = ""
                    draft.current = ""
                }
            }
        )
    }

    private func number(_ label: String, value: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            TextField("—", text: value)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("\(field.projectionLabel) \(label)")
        }
    }

    private func title(_ value: FH6TuneMenuFieldAvailability) -> String {
        switch value {
        case .adjustable: "Adjustable"
        case .shownLocked: "Shown locked"
        case .notShown: "Not shown"
        }
    }
}
