//
//  FirstPartyValidationCaptureView.swift
//  forzadvisor
//

import SwiftUI

struct FirstPartyValidationCaptureView: View {
    let tune: TuneResult
    let onBack: () -> Void
    let onSubmit: (FirstPartyValidationCapture) -> Void

    @State private var courseType = ValidationCourseType.roadCircuit
    @State private var surface = ValidationSurface.dry
    @State private var input = ValidationInput.controller
    @State private var runCount = 1
    @State private var verdict = ValidationVerdict.keep
    @State private var feedback = Set<TuneFeedback>()
    @State private var exactSetupConfirmed = false
    @State private var allExportedSettingsApplied = false
    @State private var firstPartyAuthorshipConfirmed = false
    @State private var deidentifiedReusePermitted = false

    var body: some View {
        Form {
            Section("Test Session") {
                Picker("Course type", selection: $courseType) {
                    ForEach(ValidationCourseType.allCases) { Text($0.title).tag($0) }
                }
                .accessibilityIdentifier("validationCourseTypePicker")
                .accessibilityHint("Choose the general event type; track names and locations are not collected.")
                Picker("Surface", selection: $surface) {
                    ForEach(ValidationSurface.allCases) { Text($0.title).tag($0) }
                }
                .accessibilityIdentifier("validationSurfacePicker")
                .accessibilityHint("Choose the surface conditions for this test session.")
                Picker("Input", selection: $input) {
                    ForEach(ValidationInput.allCases) { Text($0.title).tag($0) }
                }
                .accessibilityIdentifier("validationInputPicker")
                .accessibilityHint("Choose the input device used for every recorded run.")
                Stepper("Runs: \(runCount)", value: $runCount, in: 1...99)
                    .accessibilityIdentifier("validationRunCountStepper")
                    .accessibilityHint("Set the number of runs represented by this one session.")
            }

            Section("Outcome") {
                Picker("Verdict", selection: $verdict) {
                    ForEach(ValidationVerdict.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("validationVerdictPicker")
                .accessibilityHint("Choose whether to keep, adjust, or reject this tune after the session.")
                .onChange(of: verdict) { _, newVerdict in
                    if newVerdict == .keep {
                        feedback.removeAll()
                    }
                }

                if verdict != .keep {
                    Text("Select at least one symptom.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(TuneFeedback.allCases) { item in
                        Toggle(item.title, isOn: feedbackBinding(item))
                            .accessibilityIdentifier("validationFeedback-\(item.rawValue)")
                            .accessibilityHint(item.prompt)
                    }
                }
            }

            Section("Confirm What You Tested") {
                Toggle("The car matched the verified stock setup", isOn: $exactSetupConfirmed)
                    .accessibilityIdentifier("validationSetupAttestation")
                    .accessibilityHint("Required. Confirm the tested car matched the locally verified stock build.")
                Toggle("I applied every exported setting", isOn: $allExportedSettingsApplied)
                    .accessibilityIdentifier("validationAppliedSettingsAttestation")
                    .accessibilityHint("Required. Confirm every setting in the exported tune was applied in game.")
                Toggle("This is my own test-drive observation", isOn: $firstPartyAuthorshipConfirmed)
                    .accessibilityIdentifier("validationAuthorshipAttestation")
                    .accessibilityHint("Required. Confirm you personally performed and observed this session.")
            }

            Section("Required Benchmark Permission") {
                Toggle("Allow deidentified benchmark reuse", isOn: $deidentifiedReusePermitted)
                    .accessibilityIdentifier("validationReusePermission")
                    .accessibilityHint("Required to create this record. It remains off until you explicitly opt in.")
                Text("Off by default and required to create a reusable validation record. Turning it on permits this one deidentified session to be reused for tune-quality benchmarking. It does not publish your identity or upload anything in the background.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("What This Record Means") {
                Text("This records one tester's experience in one session. It is evidence, not a guarantee that the tune is accurate, optimal, or best for another driver.")
                    .font(.caption)
                Text("ForzAdvisor does not collect notes, attachments, lap time, telemetry, assists, weather, location, device identifiers, or public attribution in this record.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Validation Status") {
                Label(
                    canSubmit ? "Ready to create" : "\(unmetRequirements.count) requirement\(unmetRequirements.count == 1 ? "" : "s") remaining",
                    systemImage: canSubmit ? "checkmark.circle" : "exclamationmark.circle"
                )
                .foregroundStyle(canSubmit ? ForzAdvisorTheme.accent : ForzAdvisorTheme.warning)
                .accessibilityIdentifier("validationStatusSummary")
                ForEach(unmetRequirements, id: \.self) { requirement in
                    Text(requirement)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button("Create Validation Record") {
                    onSubmit(capture)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSubmit)
                .accessibilityIdentifier("createValidationRecordButton")
                .accessibilityHint(canSubmit ? "Creates and stores the validation record locally." : unmetRequirements.joined(separator: ". "))
            }
        }
        .navigationTitle("Record Test Drive")
        .forzAdvisorScreenChrome()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Back", action: onBack)
            }
        }
    }

    private var capture: FirstPartyValidationCapture {
        FirstPartyValidationCapture(
            courseType: courseType, surface: surface, input: input, runCount: runCount,
            verdict: verdict, feedback: feedback, exactSetupConfirmed: exactSetupConfirmed,
            allExportedSettingsApplied: allExportedSettingsApplied,
            firstPartyAuthorshipConfirmed: firstPartyAuthorshipConfirmed,
            deidentifiedReusePermitted: deidentifiedReusePermitted
        )
    }

    private var canSubmit: Bool {
        unmetRequirements.isEmpty
    }

    private var unmetRequirements: [String] {
        var requirements: [String] = []
        if verdict != .keep && feedback.isEmpty {
            requirements.append("Select at least one handling symptom for Adjust or Reject.")
        }
        if !exactSetupConfirmed { requirements.append("Confirm the verified stock setup.") }
        if !allExportedSettingsApplied { requirements.append("Confirm every exported setting was applied.") }
        if !firstPartyAuthorshipConfirmed { requirements.append("Confirm first-party authorship.") }
        if !deidentifiedReusePermitted { requirements.append("Grant deidentified benchmark reuse permission.") }
        return requirements
    }

    private func feedbackBinding(_ item: TuneFeedback) -> Binding<Bool> {
        Binding {
            feedback.contains(item)
        } set: { enabled in
            if enabled { feedback.insert(item) } else { feedback.remove(item) }
        }
    }
}
