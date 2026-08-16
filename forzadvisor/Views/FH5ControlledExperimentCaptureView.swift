import SwiftUI

struct FH5ControlledExperimentCaptureView: View {
    let tune: TuneResult
    let researchRecord: FH5ResearchObservationRecord
    let onBack: () -> Void
    let onSubmit: (FH5ControlledExperimentCapture) -> Void

    @State var field: TuneFieldID
    @State var direction: FH5ExperimentDirection?
    @State var input: ValidationInput?
    @State var surface: ValidationSurface?
    @State var targetSymptom: TuneFeedback?
    @State var outcome: FH5ExperimentOutcome?
    @State var sameRouteAndConditionsConfirmed = false
    @State var sameAssistsAndInputConfirmed = false
    @State var onlyDeclaredFieldChangedConfirmed = false
    @State var sequenceCompletedConfirmed = false
    @State var stockValuesRestoredConfirmed = false
    @State var firstPartyAuthorshipConfirmed = false
    @State var localStoragePermitted = false
    @State private var showsExitRestorationReminder = false
    @State var recoveryMessage: String?

    init(
        tune: TuneResult,
        researchRecord: FH5ResearchObservationRecord,
        onBack: @escaping () -> Void,
        onSubmit: @escaping (FH5ControlledExperimentCapture) -> Void
    ) {
        self.tune = tune
        self.researchRecord = researchRecord
        self.onBack = onBack
        self.onSubmit = onSubmit
        let first = researchRecord.controls.first {
            $0.availability == .adjustable
                && $0.minimum != nil
                && $0.maximum != nil
                && $0.step != nil
                && $0.current != nil
                && $0.unit != nil
        }
        _field = State(initialValue: first?.field ?? .frontTirePressure)
    }

    var body: some View {
        Form {
            Section("Experiment Boundary") {
                Label(
                    "Calibration evidence only",
                    systemImage: "testtube.2"
                )
                .font(.subheadline.weight(.semibold))
                Text(
                    "This does not create or unlock an FH5 tune. It tests one user-selected slider step and always ends by restoring the stock value."
                )
                .font(.caption)
                .foregroundStyle(ForzAdvisorTheme.warning)
                LabeledContent("Car", value: tune.request.car.displayName)
                LabeledContent("Game build", value: researchRecord.gameVersion)
                LabeledContent("Route", value: FH5ControlledExperimentRecord.route)
            }

            Section("One Declared Change") {
                Picker("Control", selection: $field) {
                    ForEach(adjustableObservations, id: \.field) { observation in
                        Text(observation.field.projectionLabel)
                            .tag(observation.field)
                    }
                }
                .accessibilityIdentifier("fh5ExperimentFieldPicker")
                .onChange(of: field) { _, _ in
                    if direction.map(availableDirections.contains) != true {
                        direction = nil
                    }
                }

                Picker("Variant", selection: $direction) {
                    Text("Choose direction").tag(nil as FH5ExperimentDirection?)
                    ForEach(availableDirections) { direction in
                        Text(direction.title).tag(Optional(direction))
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("fh5ExperimentDirectionPicker")

                if let observation = selectedObservation,
                   let baseline = observation.current,
                   let candidateValue {
                    LabeledContent(
                        "A · Stock baseline",
                        value: formatted(baseline, unit: observation.unit)
                    )
                    LabeledContent(
                        "B · One-step variant",
                        value: formatted(candidateValue, unit: observation.unit)
                    )
                    Text(
                        "For every A run use the stock value. For every B run change only \(observation.field.projectionLabel), then return it to stock."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            Section("Fixed A-B-B-A Test") {
                Text("Run A, then B, then B again, then A again on the same Horizon Test Track route.")
                    .font(.subheadline.weight(.semibold))
                Text("Keep weather, assists, input device, route, and driving approach unchanged. Do not change any other setting.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Surface", selection: $surface) {
                    Text("Choose surface").tag(nil as ValidationSurface?)
                    ForEach(ValidationSurface.allCases) {
                        Text($0.title).tag(Optional($0))
                    }
                }
                Picker("Input", selection: $input) {
                    Text("Choose input").tag(nil as ValidationInput?)
                    ForEach(ValidationInput.allCases) {
                        Text($0.title).tag(Optional($0))
                    }
                }
                Picker("Target symptom", selection: $targetSymptom) {
                    Text("Choose symptom").tag(nil as TuneFeedback?)
                    ForEach(TuneFeedback.allCases) {
                        Text($0.title).tag(Optional($0))
                    }
                }
                .accessibilityIdentifier("fh5ExperimentTargetPicker")
            }

            Section("Comparative Outcome") {
                Picker("After all four runs", selection: $outcome) {
                    Text("Choose outcome").tag(nil as FH5ExperimentOutcome?)
                    ForEach(FH5ExperimentOutcome.allCases) {
                        Text($0.title).tag(Optional($0))
                    }
                }
                .accessibilityIdentifier("fh5ExperimentOutcomePicker")
                Text(
                    "Judge only the selected target symptom. No lap times, notes, telemetry, or public attribution are collected."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section("Confirm The Protocol") {
                Toggle(
                    "Same route, surface, and conditions for every run",
                    isOn: $sameRouteAndConditionsConfirmed
                )
                Toggle(
                    "Same assists and input device for every run",
                    isOn: $sameAssistsAndInputConfirmed
                )
                Toggle(
                    "Only the declared control changed between A and B",
                    isOn: $onlyDeclaredFieldChangedConfirmed
                )
                Toggle(
                    "I completed the full A-B-B-A sequence",
                    isOn: $sequenceCompletedConfirmed
                )
                Toggle(
                    "I restored the tested control to its stock value",
                    isOn: $stockValuesRestoredConfirmed
                )
                Toggle(
                    "I personally drove and observed every run",
                    isOn: $firstPartyAuthorshipConfirmed
                )
            }

            Section("Evidence Permissions") {
                Toggle(
                    "Keep this experiment with the saved plan",
                    isOn: $localStoragePermitted
                )
                Text(
                    "This experiment is stored locally first. Reuse can be authorized later for its exact immutable fingerprint."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section("Status") {
                Label(
                    canSubmit
                        ? "Ready to record"
                        : "\(unmetRequirementCount) requirement\(unmetRequirementCount == 1 ? "" : "s") remaining",
                    systemImage: canSubmit
                        ? "checkmark.circle"
                        : "exclamationmark.circle"
                )
                .foregroundStyle(
                    canSubmit ? ForzAdvisorTheme.success : ForzAdvisorTheme.warning
                )
                if let nextRequirement {
                    Text("Next: \(nextRequirement)")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            ValidationRecoveryMessageSection(message: recoveryMessage)
            ValidationDraftActionsSection(
                saveAndExit: saveAndExit,
                discard: discardDraft
            )

            Section {
                Button("Record Paired Experiment") {
                    guard let candidateValue, let input, let surface,
                          let targetSymptom, let outcome else { return }
                    onSubmit(FH5ControlledExperimentCapture(
                        field: field,
                        candidateValue: candidateValue,
                        input: input,
                        surface: surface,
                        targetSymptom: targetSymptom,
                        outcome: outcome,
                        sameRouteAndConditionsConfirmed:
                            sameRouteAndConditionsConfirmed,
                        sameAssistsAndInputConfirmed:
                            sameAssistsAndInputConfirmed,
                        onlyDeclaredFieldChangedConfirmed:
                            onlyDeclaredFieldChangedConfirmed,
                        sequenceCompletedConfirmed:
                            sequenceCompletedConfirmed,
                        stockValuesRestoredConfirmed:
                            stockValuesRestoredConfirmed,
                        firstPartyAuthorshipConfirmed:
                            firstPartyAuthorshipConfirmed,
                        localStoragePermitted: localStoragePermitted,
                        deidentifiedReusePermitted: false
                    ))
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSubmit)
                .accessibilityIdentifier("recordFH5ControlledExperimentButton")
            }
        }
        .navigationTitle("FH5 Outcome Lab")
        .forzAdvisorScreenChrome()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Back") {
                    showsExitRestorationReminder = true
                }
            }
        }
        .alert(
            "Restore the stock A value first",
            isPresented: $showsExitRestorationReminder
        ) {
            Button("I Restored It") {
                saveAndExit()
            }
            Button("Stay in Outcome Lab", role: .cancel) {}
        } message: {
            if let observation = selectedObservation,
               let current = observation.current {
                Text(
                    "Before leaving FH5, restore \(observation.field.projectionLabel) to \(formatted(current, unit: observation.unit))."
                )
            } else {
                Text("Before leaving FH5, restore every changed control to its stock value.")
            }
        }
        .onAppear {
            if direction.map(availableDirections.contains) != true {
                direction = nil
            }
        }
        .task { restoreDraft() }
    }

    private var adjustableObservations: [FH5TuneFieldObservation] {
        researchRecord.controls.filter {
            $0.availability == .adjustable
                && $0.minimum != nil
                && $0.maximum != nil
                && $0.step != nil
                && $0.current != nil
                && $0.unit != nil
        }
    }

    private var selectedObservation: FH5TuneFieldObservation? {
        adjustableObservations.first { $0.field == field }
    }

    private var availableDirections: [FH5ExperimentDirection] {
        guard let observation = selectedObservation,
              let minimum = observation.minimum,
              let maximum = observation.maximum,
              let current = observation.current,
              let step = observation.step else {
            return []
        }
        let tolerance = max(1e-9, step * 1e-6)
        return FH5ExperimentDirection.allCases.filter { direction in
            let candidate = current + direction.multiplier * step
            return candidate >= minimum - tolerance
                && candidate <= maximum + tolerance
        }
    }

    var candidateValue: Double? {
        guard let direction, availableDirections.contains(direction),
              let current = selectedObservation?.current,
              let step = selectedObservation?.step else {
            return nil
        }
        return current + direction.multiplier * step
    }

}
