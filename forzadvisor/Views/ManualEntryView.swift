//
//  ManualEntryView.swift
//  forzadvisor
//
//  Editable car input form for players who prefer typing values or need a
//  fallback when photo or screenshot OCR is unavailable.
//

import SwiftUI

struct ManualEntryView: View {
    let onCancel: () -> Void
    let onContinue: (CarInput) -> Void

    @State private var draft: ManualEntryDraft
    @FocusState private var focusedField: ManualEntryField?

    init(draft: ManualEntryDraft, onCancel: @escaping () -> Void, onContinue: @escaping (CarInput) -> Void) {
        self._draft = State(initialValue: draft)
        self.onCancel = onCancel
        self.onContinue = onContinue
    }

    var body: some View {
        Form {
            Section("Car") {
                TextField("Year", text: optionalNumberText($draft.year))
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: .year)
                    .accessibilityIdentifier("manualEntryYearField")
                TextField("Make", text: $draft.make)
                    .textInputAutocapitalization(.words)
                    .focused($focusedField, equals: .make)
                    .accessibilityIdentifier("manualEntryMakeField")
                TextField("Model", text: $draft.model)
                    .textInputAutocapitalization(.words)
                    .focused($focusedField, equals: .model)
                    .accessibilityIdentifier("manualEntryModelField")
            }
            .forzAdvisorRowBackground()

            Section("Performance") {
                LabeledContent("Weight") {
                    TextField("lb", text: optionalNumberText($draft.weightPounds))
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .focused($focusedField, equals: .weight)
                        .accessibilityIdentifier("manualEntryWeightField")
                }

                LabeledContent("Front weight") {
                    TextField("%", text: optionalPercentText($draft.frontWeightPercent))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .focused($focusedField, equals: .frontWeight)
                        .accessibilityIdentifier("manualEntryFrontWeightField")
                }

                LabeledContent("PI") {
                    TextField("100-999", text: optionalNumberText($draft.performanceIndex))
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .focused($focusedField, equals: .performanceIndex)
                        .accessibilityIdentifier("manualEntryPerformanceIndexField")
                }

                classPicker
                drivetrainPicker
            }
            .forzAdvisorRowBackground()

            Section("Optional") {
                TextField("Horsepower", text: optionalNumberText($draft.peakHorsepower))
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: .horsepower)
                TextField("Torque", text: optionalNumberText($draft.peakTorqueFootPounds))
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: .torque)
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
        .scrollDismissesKeyboard(.interactively)
        .forzAdvisorScreenChrome()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    focusedField = nil
                    onCancel()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Next") {
                    focusedField = nil
                    if let car = draft.confirmedCarInput() {
                        onContinue(car)
                    }
                }
                .accessibilityIdentifier("manualEntryNextButton")
                .disabled(draft.confirmedCarInput() == nil)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    focusedField = nil
                }
                .accessibilityIdentifier("manualEntryKeyboardDoneButton")
            }
        }
    }

    private var classPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Class")
                .font(.subheadline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(PerformanceClass.allCases) { performanceClass in
                        choiceButton(
                            performanceClass.rawValue,
                            isSelected: draft.performanceClass == performanceClass,
                            identifier: "manualEntryClass-\(performanceClass.rawValue)"
                        ) {
                            focusedField = nil
                            draft.performanceClass = performanceClass
                        }
                    }
                }
            }
        }
    }

    private var drivetrainPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Drivetrain")
                .font(.subheadline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Drivetrain.allCases) { drivetrain in
                        choiceButton(
                            drivetrain.rawValue,
                            isSelected: draft.drivetrain == drivetrain,
                            identifier: "manualEntryDrivetrain-\(drivetrain.rawValue)"
                        ) {
                            focusedField = nil
                            draft.drivetrain = drivetrain
                        }
                    }
                }
            }
        }
    }

    private func choiceButton(
        _ title: String,
        isSelected: Bool,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(minWidth: 38)
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .foregroundStyle(isSelected ? ForzAdvisorTheme.accent : .secondary)
                .background(
                    isSelected ? ForzAdvisorTheme.accent.opacity(0.16) : Color.secondary.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    private func optionalNumberText(_ value: Binding<Int?>) -> Binding<String> {
        Binding {
            value.wrappedValue.map(String.init) ?? ""
        } set: { newValue in
            let digits = newValue.filter(\.isNumber)
            value.wrappedValue = digits.isEmpty ? nil : Int(digits)
        }
    }

    private func optionalPercentText(_ value: Binding<Double?>) -> Binding<String> {
        Binding {
            value.wrappedValue.map { LocalizedNumberText.format($0, fractionDigits: 1) } ?? ""
        } set: { newValue in
            value.wrappedValue = LocalizedNumberText.parse(newValue)
        }
    }
}

private enum ManualEntryField: Hashable {
    case year
    case make
    case model
    case weight
    case frontWeight
    case performanceIndex
    case horsepower
    case torque
}
