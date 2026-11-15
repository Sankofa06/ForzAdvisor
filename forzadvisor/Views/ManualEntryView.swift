//
//  ManualEntryView.swift
//  forzadvisor
//
//  Editable car input form for players who prefer typing values or need a
//  fallback when photo or screenshot OCR is unavailable.
//

import SwiftUI
import UIKit

struct ManualEntryView: View {
    let onCancel: () -> Void
    let onContinue: (CarInput) -> Void
    let onDraftChanged: (ManualEntryDraft) -> Void
    let stockContributionContext:
        ManualEntryStockContributionContext?

    @State private var draft: ManualEntryDraft
    @State private var formState = ManualEntryFormState()
    @State private var frontWeightText: String
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @FocusState private var focusedField: InputFieldFocus?

    init(
        draft: ManualEntryDraft,
        stockContributionContext:
            ManualEntryStockContributionContext? = nil,
        onDraftChanged: @escaping (ManualEntryDraft) -> Void = { _ in },
        onCancel: @escaping () -> Void,
        onContinue: @escaping (CarInput) -> Void
    ) {
        let initialDraft = MarketingScreenshotSeed.isEnabled && draft == .empty
            ? MarketingScreenshotSeed.manualDraft : draft
        self._draft = State(initialValue: initialDraft)
        self._frontWeightText = State(
            initialValue: initialDraft.frontWeightPercent.map {
                LocalizedNumberText.editableFormat($0, maximumFractionDigits: 1)
            } ?? ""
        )
        self.stockContributionContext =
            stockContributionContext
        self.onDraftChanged = onDraftChanged
        self.onCancel = onCancel
        self.onContinue = onContinue
    }

    var body: some View {
        ScrollViewReader { scrollProxy in
            Form {
                Section { ForzAdvisorWorkflowProgress(step: .details) }
                    .forzAdvisorRowBackground()
                Section("Car") {
                    ForzaGamePicker(
                        selection: $draft.game,
                        accessibilityPrefix: "manualEntryGame"
                    )
                    TextField("Year · Required", text: optionalNumberText($draft.year, field: .year))
                        .keyboardType(.numberPad)
                        .focused($focusedField, equals: .year)
                        .accessibilityIdentifier("manualEntryYearField")
                        .inputFieldLabel("Year · Required")
                        .id(InputFieldFocus.year)
                    inlineIssues(for: .year)
                    TextField("Make", text: trackedText($draft.make, field: .identity))
                        .textInputAutocapitalization(.words)
                        .focused($focusedField, equals: .make)
                        .accessibilityIdentifier("manualEntryMakeField")
                        .inputFieldLabel("Make · Required if model is blank")
                        .id(InputFieldFocus.make)
                    TextField("Model", text: trackedText($draft.model, field: .identity))
                        .textInputAutocapitalization(.words)
                        .focused($focusedField, equals: .model)
                        .accessibilityIdentifier("manualEntryModelField")
                        .inputFieldLabel("Model · Required if make is blank")
                        .id(InputFieldFocus.model)
                    inlineIssues(for: .identity)
                }
                .forzAdvisorRowBackground()

                Section("Performance") {
                    LabeledContent("Weight (lb)") {
                        TextField("lb", text: optionalNumberText($draft.weightPounds, field: .weight))
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .weight)
                            .accessibilityIdentifier("manualEntryWeightField")
                            .accessibilityLabel("Weight in pounds")
                    }
                    .id(InputFieldFocus.weight)
                    inlineIssues(for: .weight)

                    LabeledContent("Front weight (%)") {
                        TextField("%", text: $frontWeightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .frontWeight)
                            .accessibilityIdentifier("manualEntryFrontWeightField")
                            .accessibilityLabel("Front weight percentage")
                            .onChange(of: frontWeightText) { _, newValue in
                                formState.markTouched(.frontWeight)
                                draft.frontWeightPercent = LocalizedNumberText.parse(newValue)
                            }
                    }
                    .id(InputFieldFocus.frontWeight)
                    inlineIssues(for: .frontWeight)

                    HStack {
                        Text("PI")
                            .accessibilityHidden(true)
                        Spacer()
                        TextField("100-999", text: optionalNumberText($draft.performanceIndex, field: .performanceIndex))
                            .frame(minWidth: 120, idealWidth: 120)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .performanceIndex)
                            .accessibilityLabel("PI")
                            .accessibilityIdentifier("manualEntryPerformanceIndexField")
                    }

                    .id(InputFieldFocus.performanceIndex)
                    inlineIssues(for: .performanceIndex)
                    classPicker.id(InputFieldFocus.performanceClass)
                    inlineIssues(for: .performanceClass)
                    drivetrainPicker.id(InputFieldFocus.drivetrain)
                    inlineIssues(for: .drivetrain)
                }
                .forzAdvisorRowBackground()

                Section("Optional Performance") {
                    TextField("Horsepower · Optional", text: optionalNumberText($draft.peakHorsepower, field: .horsepower))
                        .keyboardType(.numberPad)
                        .focused($focusedField, equals: .horsepower)
                        .inputFieldLabel("Horsepower (hp) · Optional")
                    TextField("Torque · Optional", text: optionalNumberText($draft.peakTorqueFootPounds, field: .torque))
                        .keyboardType(.numberPad)
                        .focused($focusedField, equals: .torque)
                        .inputFieldLabel("Torque (lb-ft) · Optional")
                }
                .forzAdvisorRowBackground()

                let visibleIssues = formState.visibleIssues(for: draft)
                if visibleIssues.isEmpty {
                    Section("Before you continue") {
                        Label(
                            "Enter the required performance values shown in Forza. Optional power and torque can stay blank.",
                            systemImage: "info.circle"
                        )
                        .foregroundStyle(.secondary)
                    }
                    .forzAdvisorRowBackground()
                } else {
                    Section("Fix before tuning") {
                        Label("\(visibleIssues.count) fields need attention. Tap Next to go to the first field.",
                              systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(ForzAdvisorTheme.warning)
                    }
                    .forzAdvisorRowBackground()
                }
            }
            .onAppear {
                if MarketingScreenshotSeed.isEnabled { onDraftChanged(draft) }
            }
            .onChange(of: draft) { _, newDraft in
                onDraftChanged(newDraft)
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
                        submit(scrollProxy)
                    }
                    .accessibilityIdentifier("manualEntryNextButton")
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
    }

    private var classPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Class")
                .font(.subheadline)
            Group {
                LazyVGrid(columns: choiceColumns, alignment: .leading, spacing: 8) {
                    ForEach(draft.game.supportedPerformanceClasses) { performanceClass in
                        choiceButton(
                            performanceClass.rawValue,
                            isSelected: draft.performanceClass == performanceClass,
                            identifier: "manualEntryClass-\(performanceClass.rawValue)"
                        ) {
                            formState.markTouched(.performanceClass)
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
            Group {
                LazyVGrid(columns: choiceColumns, alignment: .leading, spacing: 8) {
                    ForEach(Drivetrain.allCases) { drivetrain in
                        choiceButton(
                            drivetrain.rawValue,
                            isSelected: draft.drivetrain == drivetrain,
                            identifier: "manualEntryDrivetrain-\(drivetrain.rawValue)"
                        ) {
                            formState.markTouched(.drivetrain)
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
            Label(title, systemImage: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 8)
                .frame(minHeight: ForzAdvisorTheme.minimumTouchTarget)
                .foregroundStyle(isSelected ? ForzAdvisorTheme.accent : .secondary)
                .background(
                    isSelected ? ForzAdvisorTheme.accent.opacity(0.16) : Color.secondary.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(
            isSelected
                ? .isSelected
                : []
        )
    }

    private func inlineIssues(for field: ManualEntryField) -> some View {
        ForEach(formState.visibleIssues(for: draft).filter { $0.field == field }) { issue in
            Label(issue.message, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(ForzAdvisorTheme.warning)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func trackedText(
        _ value: Binding<String>,
        field: ManualEntryField
    ) -> Binding<String> {
        Binding {
            value.wrappedValue
        } set: { newValue in
            formState.markTouched(field)
            value.wrappedValue = newValue
        }
    }

    private func optionalNumberText(
        _ value: Binding<Int?>,
        field: ManualEntryField? = nil
    ) -> Binding<String> {
        Binding {
            value.wrappedValue.map(String.init) ?? ""
        } set: { newValue in
            if let field { formState.markTouched(field) }
            let digits = newValue.filter(\.isNumber)
            value.wrappedValue = digits.isEmpty ? nil : Int(digits)
        }
    }

    private var choiceColumns: [GridItem] {
        dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.adaptive(minimum: 88))]
    }

    private func submit(_ scrollProxy: ScrollViewProxy) {
        formState.markSubmitted()
        if let unresolved = formState.firstUnresolvedField(in: draft) {
            let target = InputFieldFocus(manual: unresolved)
            focusedField = unresolved == .performanceClass || unresolved == .drivetrain ? nil : target
            scrollProxy.scrollTo(target, anchor: .top)
            UIAccessibility.post(
                notification: .announcement,
                argument: "Check \(unresolved.title)."
            )
            return
        }
        focusedField = nil
        if let car = draft.confirmedCarInput() {
            onContinue(car)
        }
    }
}
