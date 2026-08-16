//
//  FH5CandidateTrialCaptureView.swift
//  forzadvisor
//
//  A collection-only UI for one registry-bound experimental hypothesis.
//

import SwiftUI

struct FH5CandidateTrialCaptureView: View {
    let tune: TuneResult
    let researchRecord: FH5ResearchObservationRecord
    let onBack: () -> Void
    let onLockCandidate:
        (ValidationInput, ValidationSurface) throws
            -> FH5GeneratedCandidateArtifact
    let onSubmit: (FH5CandidateTrialSubmission) -> Void

    @State var input: ValidationInput?
    @State var surface: ValidationSurface?
    @State private var lockedArtifact: FH5GeneratedCandidateArtifact?
    @State private var lockError: String?
    @State var outcome: FH5ExperimentOutcome?
    @State private var sameRouteAndConditionsConfirmed = false
    @State private var sameAssistsAndInputConfirmed = false
    @State private var onlyDeclaredFieldChangedConfirmed = false
    @State private var sequenceCompletedConfirmed = false
    @State private var stockValuesRestoredConfirmed = false
    @State private var firstPartyAuthorshipConfirmed = false
    @State private var localStoragePermitted = false
    @State private var showsExitRestorationReminder = false
    @State var recoveryMessage: String?

    var body: some View {
        Form {
            FH5CandidateTrialBoundarySection(
                carName: tune.request.car.displayName,
                gameVersion: researchRecord.gameVersion
            )
            FH5CandidateTrialLockSection(
                input: $input,
                surface: $surface,
                lockedArtifact: lockedArtifact,
                lockError: lockError,
                onLock: lockCandidate
            )

            if let lockedArtifact {
                FH5CandidateTrialProtocolSection(
                    artifact: lockedArtifact,
                    outcome: $outcome
                )
                FH5CandidateTrialConfirmationSection(
                    sameRouteAndConditionsConfirmed:
                        $sameRouteAndConditionsConfirmed,
                    sameAssistsAndInputConfirmed:
                        $sameAssistsAndInputConfirmed,
                    onlyDeclaredFieldChangedConfirmed:
                        $onlyDeclaredFieldChangedConfirmed,
                    sequenceCompletedConfirmed:
                        $sequenceCompletedConfirmed,
                    stockValuesRestoredConfirmed:
                        $stockValuesRestoredConfirmed,
                    firstPartyAuthorshipConfirmed:
                        $firstPartyAuthorshipConfirmed
                )
                FH5CandidateTrialPermissionSection(
                    localStoragePermitted: $localStoragePermitted
                )

                ValidationCaptureProgressSection(
                    completed: requiredChecks.filter(\.0).count,
                    required: requiredChecks.count,
                    next: requiredChecks.first { !$0.0 }?.1,
                    focusNext: nil
                )

                ValidationRecoveryMessageSection(message: recoveryMessage)
                ValidationDraftActionsSection(
                    saveAndExit: saveAndExit,
                    discard: discardDraft
                )

                Section("Status") {
                    Label(
                        canSubmit
                            ? "Ready to record locally"
                            : "\(unmetRequirementCount) requirement\(unmetRequirementCount == 1 ? "" : "s") remaining",
                        systemImage: canSubmit
                            ? "checkmark.circle"
                            : "exclamationmark.circle"
                    )
                    .foregroundStyle(
                        canSubmit
                            ? ForzAdvisorTheme.success
                            : ForzAdvisorTheme.warning
                    )
                }

                Section {
                    Button("Record Experimental Trial") {
                        submit(artifact: lockedArtifact)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSubmit)
                    .accessibilityIdentifier(
                        "recordFH5CandidateTrialButton"
                    )
                }
            }
        }
        .navigationTitle("FH5 Candidate Trial")
        .forzAdvisorScreenChrome()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Back") {
                    if lockedArtifact == nil {
                        saveAndExit()
                    } else {
                        showsExitRestorationReminder = true
                    }
                }
            }
        }
        .alert(
            "Restore the stock A value first",
            isPresented: $showsExitRestorationReminder
        ) {
            Button("I Restored It", action: saveAndExit)
            Button("Stay in Candidate Trial", role: .cancel) {}
        } message: {
            if let artifact = lockedArtifact {
                Text(
                    "Before leaving FH5, restore \(artifact.change.field.projectionLabel) to \(fh5CandidateTrialFormatted(artifact.change.baselineValue, unit: artifact.change.unit))."
                )
            }
        }
        .task { restoreDraft() }
    }

    private var canSubmit: Bool {
        lockedArtifact != nil
            && outcome != nil
            && sameRouteAndConditionsConfirmed
            && sameAssistsAndInputConfirmed
            && onlyDeclaredFieldChangedConfirmed
            && sequenceCompletedConfirmed
            && stockValuesRestoredConfirmed
            && firstPartyAuthorshipConfirmed
            && localStoragePermitted
    }

    private var unmetRequirementCount: Int {
        requiredChecks.count { !$0.0 }
    }

    private var requiredChecks: [(Bool, String)] {
        [
            (lockedArtifact != nil, "Choose context and lock a candidate"),
            (outcome != nil, "Choose the comparative outcome"),
            (sameRouteAndConditionsConfirmed, "Confirm the same route and conditions"),
            (sameAssistsAndInputConfirmed, "Confirm the same assists and input"),
            (onlyDeclaredFieldChangedConfirmed, "Confirm only one field changed"),
            (sequenceCompletedConfirmed, "Complete the A-B-B-A sequence"),
            (stockValuesRestoredConfirmed, "Restore the stock value"),
            (firstPartyAuthorshipConfirmed, "Confirm first-party authorship"),
            (localStoragePermitted, "Allow local storage")
        ]
    }

    private func lockCandidate() {
        guard let input, let surface else {
            lockError = "Choose the input and surface before locking a candidate."
            return
        }
        do {
            lockedArtifact = try onLockCandidate(input, surface)
            lockError = nil
        } catch {
            lockedArtifact = nil
            lockError = error.localizedDescription
        }
    }

    private func submit(artifact: FH5GeneratedCandidateArtifact) {
        guard let outcome else { return }
        onSubmit(FH5CandidateTrialSubmission(
            capture: FH5ControlledExperimentCapture(
                field: artifact.change.field,
                candidateValue: artifact.change.candidateValue,
                input: artifact.context.input,
                surface: artifact.context.surface,
                targetSymptom: artifact.targetSymptom,
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
            ),
            lockedArtifact: artifact
        ))
    }
}
