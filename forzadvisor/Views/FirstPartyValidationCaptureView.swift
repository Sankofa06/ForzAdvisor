import SwiftUI

struct FirstPartyValidationCaptureView: View {
    let tune: TuneResult
    let onBack: () -> Void
    let onSubmit: (FirstPartyValidationCapture) -> Void

    @State private var courseType: ValidationCourseType?
    @State private var surface: ValidationSurface?
    @State private var input: ValidationInput?
    @State private var runCountText = ""
    @State private var verdict: ValidationVerdict?
    @State private var feedback = Set<TuneFeedback>()
    @State private var exactSetupConfirmed = false
    @State private var allSettingsApplied = false
    @State private var authorshipConfirmed = false
    @State private var message: String?
    @State private var showingDiscardConfirmation = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case course, surface, input, runs, verdict }
    private let draftStore = ValidationDraftStore()
    private static let captureRevision = "first-party-test-drive-v2"

    var body: some View {
        Form {
            Section("Optional Validation") {
                Text("This test drive is optional. Saving it locally does not authorize export, sharing, aggregation, or review-packet use.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Required Progress") {
                Label(
                    "\(completedRequiredCount) of \(requiredCount) required fields complete",
                    systemImage: canSubmit ? "checkmark.circle" : "circle.dotted"
                )
                .accessibilityIdentifier("validationProgress")
                if let firstIncompleteMessage {
                    Text("Next: \(firstIncompleteMessage)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button("Go to first incomplete field") { focusFirstIncomplete() }
                    .disabled(canSubmit)
            }
            Section("Test Session") {
                Picker("Course type", selection: $courseType) {
                    Text("Choose course type").tag(nil as ValidationCourseType?)
                    ForEach(ValidationCourseType.allCases) { Text($0.title).tag(Optional($0)) }
                }
                .focused($focusedField, equals: .course)
                Picker("Surface", selection: $surface) {
                    Text("Choose surface").tag(nil as ValidationSurface?)
                    ForEach(ValidationSurface.allCases) { Text($0.title).tag(Optional($0)) }
                }
                .focused($focusedField, equals: .surface)
                Picker("Input", selection: $input) {
                    Text("Choose input").tag(nil as ValidationInput?)
                    ForEach(ValidationInput.allCases) { Text($0.title).tag(Optional($0)) }
                }
                .focused($focusedField, equals: .input)
                TextField("Number of runs (1–99)", text: $runCountText)
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: .runs)
                    .accessibilityIdentifier("validationRunCount")
            }
            Section("Outcome") {
                Picker("Verdict", selection: $verdict) {
                    Text("Choose outcome").tag(nil as ValidationVerdict?)
                    ForEach(ValidationVerdict.allCases) { Text($0.title).tag(Optional($0)) }
                }
                .focused($focusedField, equals: .verdict)
                .onChange(of: verdict) { _, value in
                    if value == .keep { feedback.removeAll() }
                }
                if let verdict, verdict != .keep {
                    Text("Select at least one observed symptom.").font(.caption)
                    ForEach(TuneFeedback.allCases) { item in
                        Toggle(item.title, isOn: feedbackBinding(item))
                    }
                }
            }
            Section("Confirm What You Tested") {
                Toggle("The car matched the verified stock setup", isOn: $exactSetupConfirmed)
                Toggle("I applied every available setting", isOn: $allSettingsApplied)
                Toggle("This is my own test-drive observation", isOn: $authorshipConfirmed)
            }
            Section("Local Evidence") {
                Text("This observation is saved locally first. Reuse is a separate decision you can grant later for the exact saved observation, then revoke for future exports.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let message {
                Section { Text(message).foregroundStyle(ForzAdvisorTheme.warning) }
            }
            Section {
                Button("Save Local Test Drive") { submit() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSubmit)
                    .accessibilityIdentifier("createValidationRecordButton")
                Button("Save & Exit") { saveAndExit() }
                Button("Discard Draft", role: .destructive) { showingDiscardConfirmation = true }
            }
        }
        .navigationTitle("Record Test Drive")
        .forzAdvisorScreenChrome()
        .task { restoreDraft() }
        .confirmationDialog(
            "Discard this validation draft?",
            isPresented: $showingDiscardConfirmation,
            titleVisibility: .visible
        ) {
            Button("Discard Draft", role: .destructive) { discardDraft() }
            Button("Keep Editing", role: .cancel) {}
        } message: { Text("Only this unfinished local draft will be removed.") }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { Button("Back") { saveAndExit() } }
        }
    }

    private var runCount: Int? {
        guard let value = Int(runCountText), (1...99).contains(value) else { return nil }
        return value
    }

    private var requiredChecks: [(Bool, String, Field?)] {
        var values: [(Bool, String, Field?)] = [
            (courseType != nil, "Choose a course type", .course),
            (surface != nil, "Choose a surface", .surface),
            (input != nil, "Enter the input used", .input),
            (runCount != nil, "Enter a run count from 1 to 99", .runs),
            (verdict != nil, "Choose an outcome", .verdict)
        ]
        if verdict != nil && verdict != .keep {
            values.append((!feedback.isEmpty, "Select an observed symptom", nil))
        }
        values += [
            (exactSetupConfirmed, "Confirm the exact setup", nil),
            (allSettingsApplied, "Confirm settings were applied", nil),
            (authorshipConfirmed, "Confirm first-party authorship", nil)
        ]
        return values
    }

    private var requiredCount: Int { requiredChecks.count }
    private var completedRequiredCount: Int { requiredChecks.filter(\.0).count }
    private var firstIncompleteMessage: String? { requiredChecks.first { !$0.0 }?.1 }
    private var canSubmit: Bool { requiredChecks.allSatisfy(\.0) }

    private func focusFirstIncomplete() { focusedField = requiredChecks.first { !$0.0 }?.2 }

    private func submit() {
        guard let courseType, let surface, let input, let runCount, let verdict else {
            focusFirstIncomplete()
            return
        }
        onSubmit(.init(
            courseType: courseType, surface: surface, input: input,
            runCount: runCount, verdict: verdict, feedback: feedback,
            exactSetupConfirmed: exactSetupConfirmed,
            allExportedSettingsApplied: allSettingsApplied,
            firstPartyAuthorshipConfirmed: authorshipConfirmed,
            deidentifiedReusePermitted: false
        ))
    }

    private func saveAndExit() {
        guard let context = draftContext else {
            message = "This tune revision cannot safely bind a draft."
            return
        }
        do {
            let now = Date.now
            let existing = try? draftStore.load(expected: context)
            let document = try ValidationDraftDocument(
                identity: .init(
                    draftID: existing?.identity.draftID ?? UUID(), kind: context.kind,
                    savedTuneID: context.savedTuneID,
                    tuneRevisionFingerprint: context.tuneRevisionFingerprint,
                    gameBuildVersion: context.gameBuildVersion,
                    captureRevision: context.captureRevision
                ),
                lifecycle: .init(createdAt: existing?.lifecycle.createdAt ?? now, updatedAt: now),
                factualFields: factualFields
            )
            try draftStore.save(document)
            onBack()
        } catch {
            message = "Draft could not be saved. Your form remains open."
        }
    }

    private func restoreDraft() {
        guard let context = draftContext else { return }
        do {
            guard let document = try draftStore.load(expected: context) else { return }
            apply(document.factualFields)
            message = "Resumed the factual fields from your local draft."
        } catch ValidationDraftStoreError.migrationRequired {
            do {
                let migrated = try draftStore.migrateLegacy(expected: context)
                apply(migrated.factualFields)
                message = "Resumed and safely updated an older local draft."
            } catch { message = "The older draft could not be safely resumed." }
        } catch ValidationDraftStoreError.stale {
            message = "A draft for an older tune or game build was discarded."
        } catch {
            message = "An unreadable draft was quarantined and not restored."
        }
    }

    private func discardDraft() {
        try? draftStore.delete(kind: .firstPartyTestDrive, savedTuneID: tune.id)
        onBack()
    }

    private var draftContext: ValidationDraftRestoreContext? {
        guard let fingerprint = FirstPartyValidationRecordFactory().revisionFingerprint(for: tune),
              let build = tune.request.buildSnapshot?.gameBuild.version else { return nil }
        return .init(
            kind: .firstPartyTestDrive, savedTuneID: tune.id,
            tuneRevisionFingerprint: fingerprint, gameBuildVersion: build,
            captureRevision: Self.captureRevision
        )
    }

    private var factualFields: [String: String] {
        var fields: [String: String] = ["runCount": runCountText]
        if let courseType { fields["courseType"] = courseType.rawValue }
        if let surface { fields["surface"] = surface.rawValue }
        if let input { fields["input"] = input.rawValue }
        if let verdict { fields["verdict"] = verdict.rawValue }
        if !feedback.isEmpty { fields["feedback"] = feedback.map(\.rawValue).sorted().joined(separator: ",") }
        return fields
    }

    private func apply(_ fields: [String: String]) {
        courseType = fields["courseType"].flatMap(ValidationCourseType.init(rawValue:))
        surface = fields["surface"].flatMap(ValidationSurface.init(rawValue:))
        input = fields["input"].flatMap(ValidationInput.init(rawValue:))
        runCountText = fields["runCount"] ?? ""
        verdict = fields["verdict"].flatMap(ValidationVerdict.init(rawValue:))
        feedback = Set((fields["feedback"] ?? "").split(separator: ",")
            .compactMap { TuneFeedback(rawValue: String($0)) })
    }

    private func feedbackBinding(_ item: TuneFeedback) -> Binding<Bool> {
        Binding { feedback.contains(item) } set: { enabled in
            if enabled { feedback.insert(item) } else { feedback.remove(item) }
        }
    }
}
