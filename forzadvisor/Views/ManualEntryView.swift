//
//  ManualEntryView.swift
//  forzadvisor
//
//  Editable car input form used by the MVP while OCR capture is still pending.
//

import SwiftUI

struct ManualEntryView: View {
    let onCancel: () -> Void
    let onContinue: (CarInput) -> Void

    @State private var draft: CarInput

    init(draft: CarInput, onCancel: @escaping () -> Void, onContinue: @escaping (CarInput) -> Void) {
        self._draft = State(initialValue: draft)
        self.onCancel = onCancel
        self.onContinue = onContinue
    }

    var body: some View {
        Form {
            Section("Car") {
                TextField("Year", text: optionalNumberText($draft.year))
                    .keyboardType(.numberPad)
                TextField("Make", text: $draft.make)
                    .textInputAutocapitalization(.words)
                TextField("Model", text: $draft.model)
                    .textInputAutocapitalization(.words)
            }
            .forzAdvisorRowBackground()

            Section("Performance") {
                LabeledContent("Weight") {
                    TextField("lb", value: $draft.weightPounds, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                }

                VStack(alignment: .leading, spacing: 8) {
                    LabeledContent("Front weight", value: "\(draft.frontWeightPercent.formatted(.number.precision(.fractionLength(1))))%")
                    Slider(value: $draft.frontWeightPercent, in: 30...70, step: 0.5)
                }

                LabeledContent("PI") {
                    TextField("100-999", value: $draft.performanceIndex, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                }

                Picker("Class", selection: $draft.performanceClass) {
                    ForEach(PerformanceClass.allCases) { performanceClass in
                        Text(performanceClass.rawValue).tag(performanceClass)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Drivetrain", selection: $draft.drivetrain) {
                    ForEach(Drivetrain.allCases) { drivetrain in
                        Text(drivetrain.rawValue).tag(drivetrain)
                    }
                }
                .pickerStyle(.segmented)
            }
            .forzAdvisorRowBackground()

            Section("Optional") {
                TextField("Horsepower", text: optionalNumberText($draft.peakHorsepower))
                    .keyboardType(.numberPad)
                TextField("Torque", text: optionalNumberText($draft.peakTorqueFootPounds))
                    .keyboardType(.numberPad)
            }
            .forzAdvisorRowBackground()

            if !draft.validationIssues.isEmpty {
                Section("Fix before tuning") {
                    ForEach(draft.validationIssues) { issue in
                        Label(issue.message, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(ForzAdvisorTheme.warning)
                    }
                }
                .forzAdvisorRowBackground()
            }
        }
        .navigationTitle("Manual Entry")
        .forzAdvisorScreenChrome()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel", action: onCancel)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Next") {
                    onContinue(draft)
                }
                .accessibilityIdentifier("manualEntryNextButton")
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
