//
//  FH5CandidateTrialSections.swift
//  forzadvisor
//

import SwiftUI

struct FH5CandidateTrialBoundarySection: View {
    let carName: String
    let gameVersion: String

    var body: some View {
        Section("Experimental Boundary") {
            Label(
                "Testable hypothesis — not a tune",
                systemImage: "testtube.2"
            )
            .font(.subheadline.weight(.semibold))
            Text(
                "ForzAdvisor generated one narrow candidate from replicated stock-menu evidence. It is not tuning advice, cannot unlock numeric output, and stays inside Outcome Lab."
            )
            .font(.caption)
            .foregroundStyle(ForzAdvisorTheme.warning)
            LabeledContent("Car", value: carName)
            LabeledContent("Game build", value: gameVersion)
            LabeledContent(
                "Target symptom",
                value: TuneFeedback.pushesWide.title
            )
            LabeledContent(
                "Route",
                value: FH5ControlledExperimentRecord.route
            )
        }
    }
}

struct FH5CandidateTrialLockSection: View {
    @Binding var input: ValidationInput
    @Binding var surface: ValidationSurface
    let lockedArtifact: FH5GeneratedCandidateArtifact?
    let lockError: String?
    let onLock: () -> Void

    var body: some View {
        Section("Choose Context And Lock") {
            Picker("Surface", selection: $surface) {
                ForEach(ValidationSurface.allCases) {
                    Text($0.title).tag($0)
                }
            }
            .disabled(lockedArtifact != nil)

            Picker("Input", selection: $input) {
                ForEach(ValidationInput.allCases) {
                    Text($0.title).tag($0)
                }
            }
            .disabled(lockedArtifact != nil)

            if let artifact = lockedArtifact {
                Label(
                    "Candidate locked for \(artifact.context.input.title) · \(artifact.context.surface.title)",
                    systemImage: "lock.fill"
                )
                .font(.caption.weight(.semibold))
                LabeledContent(
                    "Algorithm",
                    value: artifact.candidateBinding.algorithmID.rawValue
                )
                LabeledContent(
                    "Version",
                    value:
                        artifact.candidateBinding.rulesetReference
                            .algorithmVersion
                )
            } else {
                Button("Lock Candidate And Start", action: onLock)
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("lockFH5CandidateTrialButton")
            }

            if let lockError {
                Label(lockError, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(ForzAdvisorTheme.warning)
            }
        }
    }
}

struct FH5CandidateTrialProtocolSection: View {
    let artifact: FH5GeneratedCandidateArtifact
    @Binding var outcome: FH5ExperimentOutcome

    var body: some View {
        Section("Locked A-B-B-A Hypothesis") {
            LabeledContent(
                "A · Stock baseline",
                value: fh5CandidateTrialFormatted(
                    artifact.change.baselineValue,
                    unit: artifact.change.unit
                )
            )
            LabeledContent(
                "B · Experimental variant",
                value: fh5CandidateTrialFormatted(
                    artifact.change.candidateValue,
                    unit: artifact.change.unit
                )
            )
            Text(
                "Run A, then B, then B again, then A again. For every B run change only \(artifact.change.field.projectionLabel). Restore A before saving."
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            Picker("After all four runs", selection: $outcome) {
                ForEach(FH5ExperimentOutcome.allCases) {
                    Text($0.title).tag($0)
                }
            }
            .accessibilityIdentifier("fh5CandidateTrialOutcomePicker")
            Text(
                "Judge only whether the car pushes wide. No lap times, telemetry, notes, or public attribution are collected."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

struct FH5CandidateTrialConfirmationSection: View {
    @Binding var sameRouteAndConditionsConfirmed: Bool
    @Binding var sameAssistsAndInputConfirmed: Bool
    @Binding var onlyDeclaredFieldChangedConfirmed: Bool
    @Binding var sequenceCompletedConfirmed: Bool
    @Binding var stockValuesRestoredConfirmed: Bool
    @Binding var firstPartyAuthorshipConfirmed: Bool

    var body: some View {
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
                "Only front tire pressure changed between A and B",
                isOn: $onlyDeclaredFieldChangedConfirmed
            )
            Toggle(
                "I completed the full A-B-B-A sequence",
                isOn: $sequenceCompletedConfirmed
            )
            Toggle(
                "I restored front tire pressure to its stock value",
                isOn: $stockValuesRestoredConfirmed
            )
            Toggle(
                "I personally drove and observed every run",
                isOn: $firstPartyAuthorshipConfirmed
            )
        }
    }
}

struct FH5CandidateTrialPermissionSection: View {
    @Binding var localStoragePermitted: Bool
    @Binding var deidentifiedReusePermitted: Bool

    var body: some View {
        Section("Local Evidence Permissions") {
            Toggle(
                "Keep this trial with the saved plan",
                isOn: $localStoragePermitted
            )
            Toggle(
                "Allow this local record to count in deidentified outcome evaluation",
                isOn: $deidentifiedReusePermitted
            )
            Text(
                "Evaluation reuse is optional and off by default. When enabled, a separate explicit confirmation can share one deidentified Candidate Outcome JSON copy. Sharing is manual, copies cannot be recalled, and no background upload occurs."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

func fh5CandidateTrialFormatted(
    _ value: Double,
    unit: TuneUnit
) -> String {
    let number = value.formatted(
        .number.precision(.fractionLength(0...3))
    )
    return "\(number) \(unit.rawValue)"
}
