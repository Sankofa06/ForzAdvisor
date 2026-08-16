import SwiftUI
import UIKit

struct OCRConfirmationView: View {
    let onBack: () -> Void
    let onUseManualEntry: (OCRConfirmationDraft) -> Void
    let onContinue: (CarInput, OCRConfirmationDraft) -> Void
    let onDraftChanged: (OCRConfirmationDraft) -> Void

    @State private var draft: OCRConfirmationDraft
    @State private var frontWeightText: String
    @FocusState private var focusedField: OCRConfirmationUnresolvedField?

    init(
        draft: OCRConfirmationDraft,
        onDraftChanged: @escaping (OCRConfirmationDraft) -> Void = { _ in },
        onBack: @escaping () -> Void,
        onUseManualEntry: @escaping (OCRConfirmationDraft) -> Void,
        onContinue: @escaping (CarInput, OCRConfirmationDraft) -> Void
    ) {
        self._draft = State(initialValue: draft)
        self._frontWeightText = State(
            initialValue: draft.frontWeightPercent.map {
                LocalizedNumberText.editableFormat($0, maximumFractionDigits: 1)
            } ?? ""
        )
        self.onDraftChanged = onDraftChanged
        self.onBack = onBack
        self.onUseManualEntry = onUseManualEntry
        self.onContinue = onContinue
    }

    var body: some View {
        Form {
            reviewSummary
            OCRSourceEvidenceView(
                imageData: draft.thumbnailData,
                region: relevantEvidenceRegion
            )
            carSection
            performanceSection
            optionalSection
            Section {
                Button("Enter manually instead") { onUseManualEntry(draft) }
            }
            .forzAdvisorRowBackground()
        }
        .onChange(of: draft) { _, newDraft in onDraftChanged(newDraft) }
        .navigationTitle("Confirm Inputs")
        .forzAdvisorScreenChrome()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Back", action: onBack)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Next", action: submit)
                    .accessibilityIdentifier("ocrConfirmationNextButton")
            }
        }
    }

    private var reviewSummary: some View {
        Section {
            if let unresolved = draft.firstUnresolvedField {
                Label(
                    "Check \(unresolved.title) before continuing.",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .foregroundStyle(ForzAdvisorTheme.warning)
                .accessibilityIdentifier("ocrFirstUnresolvedField")
            } else {
                Label("Required inputs are ready.", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(ForzAdvisorTheme.success)
            }
            Text("Needs Check comes from OCR uncertainty. Confirm or correct the value using the game screen.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .forzAdvisorRowBackground()
    }

    private var carSection: some View {
        Section("Car") {
            ForzaGamePicker(
                selection: $draft.game,
                accessibilityPrefix: "ocrConfirmationGame"
            )
            TextField("Year · Required", text: optionalNumberText($draft.year))
                .keyboardType(.numberPad)
                .focused($focusedField, equals: .year)
                .accessibilityIdentifier("ocrConfirmationYearField")
            TextField("Make", text: $draft.make)
                .textInputAutocapitalization(.words)
                .focused($focusedField, equals: .identity)
                .accessibilityIdentifier("ocrConfirmationMakeField")
            TextField("Model", text: $draft.model)
                .textInputAutocapitalization(.words)
                .focused($focusedField, equals: .identity)
        }
        .forzAdvisorRowBackground()
    }

    private var performanceSection: some View {
        Section("Required Performance") {
            intField(.weightPounds, placeholder: "lb", value: $draft.weightPounds)
            frontWeightField
            intField(.performanceIndex, placeholder: "100-999", value: $draft.performanceIndex)
            classPicker
            drivetrainPicker
        }
    }

    private var classPicker: some View {
        reviewPicker(field: .performanceClass) {
            Picker("Class", selection: $draft.performanceClass) {
                Text("Select").tag(nil as PerformanceClass?)
                ForEach(draft.game.supportedPerformanceClasses) {
                    Text($0.rawValue).tag(Optional($0))
                }
            }
            .focused($focusedField, equals: .performanceClass)
            .onChange(of: draft.performanceClass) { _, _ in
                draft.markCorrected(.performanceClass)
            }
        }
    }

    private var drivetrainPicker: some View {
        reviewPicker(field: .drivetrain) {
            Picker("Drivetrain", selection: $draft.drivetrain) {
                Text("Select").tag(nil as Drivetrain?)
                ForEach(Drivetrain.allCases) {
                    Text($0.rawValue).tag(Optional($0))
                }
            }
            .pickerStyle(.segmented)
            .focused($focusedField, equals: .drivetrain)
            .onChange(of: draft.drivetrain) { _, _ in
                draft.markCorrected(.drivetrain)
            }
        }
    }

    private var optionalSection: some View {
        Section("Optional Performance") {
            TextField("Horsepower · Optional", text: optionalNumberText($draft.peakHorsepower))
                .keyboardType(.numberPad)
            TextField("Torque · Optional", text: optionalNumberText($draft.peakTorqueFootPounds))
                .keyboardType(.numberPad)
        }
        .forzAdvisorRowBackground()
    }

    private var relevantEvidenceRegion: CGRect? {
        guard let field = draft.firstUnresolvedField?.inputField else { return nil }
        return draft.evidence(for: field).boundingBox
    }

    private func intField(
        _ field: OCRInputField,
        placeholder: String,
        value: Binding<Int?>
    ) -> some View {
        OCRReviewNumberField(
            title: field.title,
            placeholder: placeholder,
            text: optionalNumberText(value, correctedField: field),
            evidence: draft.evidence(for: field),
            state: draft.reviewState(for: field),
            candidates: draft.candidates(for: field),
            focus: $focusedField,
            focusValue: field.unresolvedField,
            onConfirm: { draft.confirm(field) },
            onCandidate: {
                value.wrappedValue = Int($0.filter(\.isNumber))
                draft.markCorrected(field)
            }
        )
    }

    private var frontWeightField: some View {
        let field = OCRInputField.frontWeightPercent
        return OCRReviewNumberField(
            title: field.title,
            placeholder: "%",
            text: $frontWeightText,
            evidence: draft.evidence(for: field),
            state: draft.reviewState(for: field),
            candidates: draft.candidates(for: field),
            focus: $focusedField,
            focusValue: field.unresolvedField,
            onConfirm: { draft.confirm(field) },
            onCandidate: {
                frontWeightText = $0
                draft.frontWeightPercent = LocalizedNumberText.parse($0)
                draft.markCorrected(field)
            }
        )
        .onChange(of: frontWeightText) { _, newValue in
            draft.frontWeightPercent = LocalizedNumberText.parse(newValue)
            draft.markCorrected(field)
        }
    }

    private func reviewPicker<Content: View>(
        field: OCRInputField,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let state = draft.reviewState(for: field)
        return VStack(alignment: .leading, spacing: 8) {
            content()
            OCRReviewStatusRow(state: state) { draft.confirm(field) }
            OCRCandidateChipRow(candidates: draft.candidates(for: field)) { value in
                if field == .performanceClass { draft.performanceClass = PerformanceClass(rawValue: value) }
                if field == .drivetrain { draft.drivetrain = Drivetrain(rawValue: value) }
                draft.markCorrected(field)
            }
        }
        .ocrReviewRow(state: state)
    }

    private func optionalNumberText(
        _ value: Binding<Int?>,
        correctedField: OCRInputField? = nil
    ) -> Binding<String> {
        Binding {
            value.wrappedValue.map(String.init) ?? ""
        } set: { newValue in
            value.wrappedValue = Int(newValue.filter(\.isNumber))
            if let correctedField { draft.markCorrected(correctedField) }
        }
    }

    private func submit() {
        if let unresolved = draft.firstUnresolvedField {
            focusedField = unresolved
            UIAccessibility.post(
                notification: .announcement,
                argument: "Check \(unresolved.title)."
            )
            return
        }
        focusedField = nil
        if let car = draft.confirmedCarInput() { onContinue(car, draft) }
    }
}
