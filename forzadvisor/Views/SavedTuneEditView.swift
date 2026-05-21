//
//  SavedTuneEditView.swift
//  forzadvisor
//
//  Garage edit screen for car metadata, performance inputs, notes, and the
//  PRD re-tune nudge when weight or front distribution shifts materially.
//

import SwiftUI

struct SavedTuneEditView: View {
    let onCancel: () -> Void
    let onSave: (SavedTuneEditDraft) -> Void
    let onSaveAndRetune: (SavedTuneEditDraft) -> Void

    @State private var draft: SavedTuneEditDraft

    init(
        draft: SavedTuneEditDraft,
        onCancel: @escaping () -> Void,
        onSave: @escaping (SavedTuneEditDraft) -> Void,
        onSaveAndRetune: @escaping (SavedTuneEditDraft) -> Void
    ) {
        self._draft = State(initialValue: draft)
        self.onCancel = onCancel
        self.onSave = onSave
        self.onSaveAndRetune = onSaveAndRetune
    }

    var body: some View {
        Form {
            Section("Car") {
                TextField("Year", text: optionalNumberText($draft.car.year))
                    .keyboardType(.numberPad)
                TextField("Make", text: $draft.car.make)
                    .textInputAutocapitalization(.words)
                TextField("Model", text: $draft.car.model)
                    .textInputAutocapitalization(.words)
            }

            Section("Performance") {
                LabeledContent("Weight") {
                    TextField("lb", value: $draft.car.weightPounds, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                }

                VStack(alignment: .leading, spacing: 8) {
                    LabeledContent("Front weight", value: "\(draft.car.frontWeightPercent.formatted(.number.precision(.fractionLength(1))))%")
                    Slider(value: $draft.car.frontWeightPercent, in: 30...70, step: 0.5)
                }

                LabeledContent("PI") {
                    TextField("100-999", value: $draft.car.performanceIndex, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                }

                Picker("Class", selection: $draft.car.performanceClass) {
                    ForEach(PerformanceClass.allCases) { performanceClass in
                        Text(performanceClass.rawValue).tag(performanceClass)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Drivetrain", selection: $draft.car.drivetrain) {
                    ForEach(Drivetrain.allCases) { drivetrain in
                        Text(drivetrain.rawValue).tag(drivetrain)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Notes") {
                TextEditor(text: $draft.playerNotes)
                    .frame(minHeight: 100)
            }

            if draft.needsRetune {
                Section("Re-tune recommended") {
                    Label("Weight or front distribution changed by more than 2%.", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Button("Save & Re-tune") {
                        onSaveAndRetune(draft)
                    }
                    .disabled(!draft.isValid)
                }
            }

            if !draft.validationIssues.isEmpty {
                Section("Fix before saving") {
                    ForEach(draft.validationIssues) { issue in
                        Label(issue.message, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .navigationTitle("Edit Tune")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel", action: onCancel)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    onSave(draft)
                }
                .disabled(!draft.isValid)
            }
        }
    }

    private func optionalNumberText(_ value: Binding<Int?>) -> Binding<String> {
        Binding {
            value.wrappedValue.map(String.init) ?? ""
        } set: { newValue in
            let digits = newValue.filter(\.isNumber)
            value.wrappedValue = digits.isEmpty ? nil : Int(digits)
        }
    }
}
