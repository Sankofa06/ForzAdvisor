//
//  FH6CommunityReferenceTrialCaptureView.swift
//  forzadvisor
//
//  Local-first metadata-only A-B-B-A comparison capture.
//

import SwiftUI

struct FH6CommunityReferenceTrialCaptureView: View {
    let tune: TuneResult
    let onBack: () -> Void
    let onSubmit: (FH6CommunityReferenceTrialCapture) -> Void

    @State var draft = FH6CommunityReferenceTrialDraft()
    @State private var showsRestoreAlert = false
    @State var recoveryMessage: String?

    private var association: FH6CommunityReferenceCandidateAssociation? {
        guard let catalogID = tune.request.car.catalogReference?.entryID else {
            return nil
        }
        return .init(
            catalogID: catalogID,
            performanceClass: tune.request.car.performanceClass,
            performanceIndex: tune.request.car.performanceIndex,
            confirmed: true
        )
    }

    var body: some View {
        Form {
            Section("Comparison Boundary") {
                Label(
                    "Comparative observation only",
                    systemImage: "exclamationmark.shield"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(ForzAdvisorTheme.warning)
                Text(
                    "A is this exact saved ForzAdvisor candidate. B is a reference you apply from one direct YouTube or Reddit permalink. Do not enter its settings, parts, share code, prose, media, or metrics."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .forzAdvisorRowBackground()

            Section("Community Reference") {
                Picker("Platform", selection: $draft.kind) {
                    Text("Choose platform").tag(nil as FH6CommunityReferenceKind?)
                    ForEach(FH6CommunityReferenceKind.allCases, id: \.self) {
                        Text($0.title).tag(Optional($0))
                    }
                }
                .accessibilityIdentifier("communityTrialPlatformPicker")
                TextField("Direct content permalink", text: $draft.contentURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("communityTrialPermalinkField")
                TextField(
                    "Publisher label",
                    text: $draft.publisherDisplayName
                )
                .accessibilityIdentifier("communityTrialPublisherField")
            }
            .forzAdvisorRowBackground()

            Section("Controlled Context") {
                Picker("Course", selection: $draft.courseType) {
                    Text("Choose course").tag(nil as ValidationCourseType?)
                    ForEach(ValidationCourseType.allCases) {
                        Text($0.title).tag(Optional($0))
                    }
                }
                Picker("Surface", selection: $draft.surface) {
                    Text("Choose surface").tag(nil as ValidationSurface?)
                    ForEach(ValidationSurface.allCases) {
                        Text($0.title).tag(Optional($0))
                    }
                }
                Picker("Input", selection: $draft.input) {
                    Text("Choose input").tag(nil as ValidationInput?)
                    ForEach(ValidationInput.allCases) {
                        Text($0.title).tag(Optional($0))
                    }
                }
            }
            .forzAdvisorRowBackground()

            Section("Fixed A-B-B-A Runs") {
                ForEach(draft.runs.indices, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(runTitle(draft.runs[index].role))
                            .font(.subheadline.weight(.semibold))
                        Toggle(
                            "Run completed",
                            isOn: $draft.runs[index].completed
                        )
                        .accessibilityIdentifier(
                            "communityTrialRun\(index + 1)Completed"
                        )
                        Toggle(
                            "Correct tune confirmed",
                            isOn: $draft.runs[index].correctTuneConfirmed
                        )
                        .accessibilityIdentifier(
                            "communityTrialRun\(index + 1)CorrectTune"
                        )
                    }
                }
            }
            .forzAdvisorRowBackground()

            Section("Observed Outcome") {
                Picker("Outcome", selection: $draft.outcome) {
                    Text("Choose outcome").tag(nil as FH6CommunityReferenceTrialOutcome?)
                    ForEach(
                        FH6CommunityReferenceTrialOutcome.allCases,
                        id: \.self
                    ) {
                        Text($0.title).tag(Optional($0))
                    }
                }
                if draft.outcome == .referencePreferred {
                    ForEach(TuneFeedback.allCases, id: \.self) { symptom in
                        Toggle(
                            symptom.title,
                            isOn: symptomBinding(symptom)
                        )
                    }
                }
                if !draft.isReady {
                    Text(
                        "Complete the direct-source metadata, all four run checks, the outcome requirements, and every required confirmation."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier(
                        "communityTrialReadinessMessage"
                    )
                }
            }
            .forzAdvisorRowBackground()

            Section("Required Confirmations") {
                confirmationToggles
                Text("This comparison is stored locally first. Reuse can be authorized later for its exact fingerprint.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .forzAdvisorRowBackground()

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

            Section {
                Button("Save Local Comparison") {
                    guard let association,
                          let capture = draft.capture(
                            candidate: association
                          ) else {
                        return
                    }
                    onSubmit(capture)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!draft.isReady || association == nil)
                .accessibilityIdentifier("saveCommunityTrialButton")
            }
            .forzAdvisorRowBackground()
        }
        .navigationTitle("Community Comparison")
        .forzAdvisorScreenChrome()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Back") {
                    if draft.finalCandidateRestoredConfirmed {
                        onBack()
                    } else {
                        showsRestoreAlert = true
                    }
                }
                .accessibilityIdentifier("communityTrialBackButton")
            }
        }
        .alert(
            "Restore the ForzAdvisor candidate first",
            isPresented: $showsRestoreAlert
        ) {
            Button("I Restored It") {
                draft.finalCandidateRestoredConfirmed = true
                onBack()
            }
            Button("Keep Testing", role: .cancel) {}
        } message: {
            Text(
                "Before leaving, reapply the exact ForzAdvisor candidate used for A1 and A2."
            )
        }
        .task { restoreDraft() }
    }

    @ViewBuilder
    private var confirmationToggles: some View {
        Toggle(
            "Same route and conditions for every run",
            isOn: $draft.sameRouteAndConditionsConfirmed
        )
        .accessibilityIdentifier("communityTrialSameConditionsToggle")
        Toggle(
            "Same assists and input for every run",
            isOn: $draft.sameAssistsAndInputConfirmed
        )
        .accessibilityIdentifier("communityTrialSameInputToggle")
        Toggle(
            "Exact ForzAdvisor candidate applied for A",
            isOn: $draft.candidateSettingsAppliedConfirmed
        )
        .accessibilityIdentifier("communityTrialCandidateAppliedToggle")
        Toggle(
            "Reference identity matches the permalink",
            isOn: $draft.communityIdentityConfirmed
        )
        .accessibilityIdentifier("communityTrialReferenceIdentityToggle")
        Toggle(
            "ForzAdvisor candidate restored after A2",
            isOn: $draft.finalCandidateRestoredConfirmed
        )
        .accessibilityIdentifier("communityTrialRestoredToggle")
        Toggle(
            "This comparison is my own observation",
            isOn: $draft.firstPartyAuthorshipConfirmed
        )
        .accessibilityIdentifier("communityTrialAuthorshipToggle")
        Toggle(
            "Allow this metadata and outcome to be stored locally",
            isOn: $draft.localStoragePermitted
        )
        .accessibilityIdentifier("communityTrialLocalStorageToggle")
    }

    private func symptomBinding(_ symptom: TuneFeedback) -> Binding<Bool> {
        Binding(
            get: { draft.candidateDeficiencySymptoms.contains(symptom) },
            set: { selected in
                if selected {
                    draft.candidateDeficiencySymptoms.insert(symptom)
                } else {
                    draft.candidateDeficiencySymptoms.remove(symptom)
                }
            }
        )
    }

    private var requiredChecks: [(Bool, String)] {
        [
            (draft.kind != nil, "Choose the reference platform"),
            (!draft.contentURL.isEmpty, "Enter the direct permalink"),
            (!draft.publisherDisplayName.isEmpty, "Enter the publisher label"),
            (draft.courseType != nil, "Choose the course"),
            (draft.surface != nil, "Choose the surface"),
            (draft.input != nil, "Choose the input"),
            (draft.runs.allSatisfy(\.completed), "Complete all four runs"),
            (draft.runs.allSatisfy(\.correctTuneConfirmed), "Confirm the correct tune for every run"),
            (draft.outcome != nil, "Choose the observed outcome"),
            (draft.outcome != .referencePreferred || !draft.candidateDeficiencySymptoms.isEmpty, "Choose an observed symptom"),
            (draft.sameRouteAndConditionsConfirmed, "Confirm the same conditions"),
            (draft.sameAssistsAndInputConfirmed, "Confirm the same assists and input"),
            (draft.candidateSettingsAppliedConfirmed, "Confirm candidate settings"),
            (draft.communityIdentityConfirmed, "Confirm reference identity"),
            (draft.finalCandidateRestoredConfirmed, "Restore the candidate"),
            (draft.firstPartyAuthorshipConfirmed, "Confirm first-party authorship"),
            (draft.localStoragePermitted, "Allow local storage")
        ]
    }

    private func runTitle(_ role: FH6CommunityReferenceTrialRole) -> String {
        switch role {
        case .a1: "A1 · ForzAdvisor candidate"
        case .b1: "B1 · Community reference"
        case .b2: "B2 · Community reference"
        case .a2: "A2 · ForzAdvisor candidate"
        }
    }
}
