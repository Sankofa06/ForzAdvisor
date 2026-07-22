//
//  OCRConfirmationView.swift
//  forzadvisor
//
//  Editable review screen for OCRConfirmationDraft values before they become a
//  validated CarInput and enter the discipline picker.
//

import SwiftUI

struct OCRConfirmationView: View {
    let onBack: () -> Void
    let onUseManualEntry: (OCRConfirmationDraft) -> Void
    let onContinue: (CarInput) -> Void

    @State private var draft: OCRConfirmationDraft

    init(
        draft: OCRConfirmationDraft,
        onBack: @escaping () -> Void,
        onUseManualEntry: @escaping (OCRConfirmationDraft) -> Void,
        onContinue: @escaping (CarInput) -> Void
    ) {
        self._draft = State(initialValue: draft)
        self.onBack = onBack
        self.onUseManualEntry = onUseManualEntry
        self.onContinue = onContinue
    }

    var body: some View {
        Form {
            if !draft.fieldsNeedingReview.isEmpty {
                Section {
                    Label("Review highlighted fields before continuing.", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(ForzAdvisorTheme.warning)
                }
                .forzAdvisorRowBackground()
            }

            Section("Car") {
                TextField("Year", text: optionalNumberText($draft.year))
                    .keyboardType(.numberPad)
                TextField("Make", text: $draft.make)
                    .textInputAutocapitalization(.words)
                TextField("Model", text: $draft.model)
                    .textInputAutocapitalization(.words)
            }
            .forzAdvisorRowBackground()

            Section("Required Performance") {
                ConfirmedNumberField(
                    title: "Weight",
                    placeholder: "lb",
                    text: optionalNumberText($draft.weightPounds),
                    evidence: draft.evidence(for: .weightPounds),
                    candidates: draft.candidates(for: .weightPounds)
                )

                ConfirmedNumberField(
                    title: "Front weight",
                    placeholder: "%",
                    text: optionalPercentText($draft.frontWeightPercent),
                    evidence: draft.evidence(for: .frontWeightPercent),
                    candidates: draft.candidates(for: .frontWeightPercent)
                )

                ConfirmedNumberField(
                    title: "PI",
                    placeholder: "100-999",
                    text: optionalNumberText($draft.performanceIndex),
                    evidence: draft.evidence(for: .performanceIndex),
                    candidates: draft.candidates(for: .performanceIndex)
                )

                Picker("Class", selection: $draft.performanceClass) {
                    Text("Select").tag(nil as PerformanceClass?)
                    ForEach(draft.game.supportedPerformanceClasses) { performanceClass in
                        Text(performanceClass.rawValue).tag(Optional(performanceClass))
                    }
                }
                .reviewTint(draft.evidence(for: .performanceClass).needsReview)
                CandidateChipRow(candidates: draft.candidates(for: .performanceClass)) { value in
                    draft.performanceClass = PerformanceClass(rawValue: value)
                }
                .forzAdvisorRowBackground()

                Picker("Drivetrain", selection: $draft.drivetrain) {
                    Text("Select").tag(nil as Drivetrain?)
                    ForEach(Drivetrain.allCases) { drivetrain in
                        Text(drivetrain.rawValue).tag(Optional(drivetrain))
                    }
                }
                .pickerStyle(.segmented)
                .reviewTint(draft.evidence(for: .drivetrain).needsReview)
                CandidateChipRow(candidates: draft.candidates(for: .drivetrain)) { value in
                    draft.drivetrain = Drivetrain(rawValue: value)
                }
                .forzAdvisorRowBackground()
            }

            Section("Optional") {
                TextField("Horsepower", text: optionalNumberText($draft.peakHorsepower))
                    .keyboardType(.numberPad)
                TextField("Torque", text: optionalNumberText($draft.peakTorqueFootPounds))
                    .keyboardType(.numberPad)
            }
            .forzAdvisorRowBackground()

            Section {
                Button("Enter manually instead") {
                    onUseManualEntry(draft)
                }
            }
            .forzAdvisorRowBackground()
        }
        .navigationTitle("Confirm Inputs")
        .forzAdvisorScreenChrome()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Back", action: onBack)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Next") {
                    if let car = draft.confirmedCarInput() {
                        onContinue(car)
                    }
                }
                .disabled(draft.confirmedCarInput() == nil)
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

    private func optionalPercentText(_ value: Binding<Double?>) -> Binding<String> {
        Binding {
            value.wrappedValue.map { LocalizedNumberText.format($0, fractionDigits: 1) } ?? ""
        } set: { newValue in
            value.wrappedValue = LocalizedNumberText.parse(newValue)
        }
    }
}

private struct ConfirmedNumberField: View {
    let title: String
    let placeholder: String
    let text: Binding<String>
    let evidence: OCRFieldEvidence
    let candidates: [OCRFieldCandidate]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            LabeledContent(title) {
                TextField(placeholder, text: text)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }

            HStack(spacing: 8) {
                Text("Confidence \(evidence.confidencePercentText)")
                    .font(.caption)
                    .foregroundStyle(evidence.needsReview ? ForzAdvisorTheme.warning : .secondary)
                if let rawText = evidence.rawText {
                    Text(rawText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text("No OCR value found")
                        .font(.caption)
                        .foregroundStyle(ForzAdvisorTheme.warning)
                }
            }

            CandidateChipRow(candidates: candidates) { value in
                text.wrappedValue = value
            }
        }
        .reviewTint(evidence.needsReview)
    }
}

private struct CandidateChipRow: View {
    let candidates: [OCRFieldCandidate]
    let onSelect: (String) -> Void

    private var uniqueCandidates: [OCRFieldCandidate] {
        var seen = Set<String>()
        return candidates.filter { seen.insert($0.value).inserted }.prefix(3).map { $0 }
    }

    var body: some View {
        if !uniqueCandidates.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(uniqueCandidates) { candidate in
                        Button {
                            onSelect(candidate.value)
                        } label: {
                            Text(candidate.value)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .foregroundStyle(ForzAdvisorTheme.accent)
                                .background(ForzAdvisorTheme.accent.opacity(0.14), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private extension View {
    @ViewBuilder
    func reviewTint(_ needsReview: Bool) -> some View {
        if needsReview {
            listRowBackground(ForzAdvisorTheme.warning.opacity(0.13))
        } else {
            self.forzAdvisorRowBackground()
        }
    }
}
