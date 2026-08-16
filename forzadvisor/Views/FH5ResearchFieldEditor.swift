import SwiftUI

struct FH5ResearchFieldDraft: Equatable {
    var availability: FH5TuneFieldAvailability?
    var minimum = ""
    var maximum = ""
    var step = ""
    var current = ""
}

struct FH5ResearchFieldEditor: View {
    let field: TuneFieldID
    @Binding var draft: FH5ResearchFieldDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(field.projectionLabel)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if !field.expectedDisplayUnit.isEmpty {
                    Text(field.expectedDisplayUnit)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            Picker("Availability", selection: availability) {
                Text("Not reviewed").tag(nil as FH5TuneFieldAvailability?)
                Text("Adjustable").tag(Optional(FH5TuneFieldAvailability.adjustable))
                Text("Locked").tag(Optional(FH5TuneFieldAvailability.shownLocked))
                Text("Not shown").tag(Optional(FH5TuneFieldAvailability.notShown))
            }
            .accessibilityIdentifier("fh5ResearchAvailability-\(field.stableID)")

            switch draft.availability {
            case .adjustable:
                number("Minimum", value: $draft.minimum, suffix: "minimum")
                number("Maximum", value: $draft.maximum, suffix: "maximum")
                number("Slider step", value: $draft.step, suffix: "step")
                number("Current stock value", value: $draft.current, suffix: "current")
            case .shownLocked:
                number("Current shown value (optional)", value: $draft.current, suffix: "lockedCurrent")
            case .notShown:
                Text("No numeric values are stored for a control that is not shown.")
                    .font(.caption).foregroundStyle(.secondary)
            case nil:
                Text("Choose a state after checking this menu position in FH5.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
    }

    private var availability: Binding<FH5TuneFieldAvailability?> {
        Binding(
            get: { draft.availability },
            set: { value in
                draft.availability = value
                if value != .adjustable {
                    draft.minimum = ""
                    draft.maximum = ""
                    draft.step = ""
                }
                if value == .notShown || value == nil { draft.current = "" }
            }
        )
    }

    private func number(
        _ title: String,
        value: Binding<String>,
        suffix: String
    ) -> some View {
        HStack {
            Text(title).font(.caption)
            Spacer()
            TextField("—", text: value)
                .keyboardType(signedInput
                    ? .numbersAndPunctuation : .decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 120)
                .accessibilityIdentifier(
                    "fh5Research-\(field.stableID)-\(suffix)"
                )
        }
    }

    private var signedInput: Bool {
        switch field {
        case .frontCamber, .rearCamber, .frontToe, .rearToe: true
        default: false
        }
    }
}
