import SwiftUI

struct SavedTuneEditView: View {
    let onCancel: () -> Void
    let onSave: (SavedTuneEditDraft) -> Void
    let onSaveAndRetune: (SavedTuneEditDraft) -> Void

    @State private var draft: SavedTuneEditDraft
    private let originalDraft: SavedTuneEditDraft

    init(
        draft: SavedTuneEditDraft,
        onCancel: @escaping () -> Void,
        onSave: @escaping (SavedTuneEditDraft) -> Void,
        onSaveAndRetune: @escaping (SavedTuneEditDraft) -> Void
    ) {
        _draft = State(initialValue: draft)
        originalDraft = draft
        self.onCancel = onCancel
        self.onSave = onSave
        self.onSaveAndRetune = onSaveAndRetune
    }

    private var action: SavedTuneEditAction {
        SavedTuneEditAction.resolve(original: originalDraft, current: draft)
    }

    var body: some View {
        Form {
            SavedTuneIdentityFields(car: $draft.car)
            SavedTunePerformanceFields(car: $draft.car)

            Section("Notes") {
                TextEditor(text: $draft.playerNotes)
                    .frame(minHeight: 100)
                    .accessibilityIdentifier("savedTuneNotesField")
            }
            .forzAdvisorRowBackground()

            Section {
                Label(action.explanation, systemImage: action.symbolName)
                    .font(.subheadline)
                    .foregroundStyle(action.requiresRetune ? ForzAdvisorTheme.warning : .secondary)
                Button(action.title) {
                    if action.requiresRetune {
                        onSaveAndRetune(draft)
                    } else {
                        onSave(draft)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!draft.isValid || action == .noChanges)
                .accessibilityIdentifier("savedTuneEditPrimaryAction")
            }
            .forzAdvisorRowBackground()

            if !draft.validationIssues.isEmpty {
                Section("Fix before saving") {
                    ForEach(draft.validationIssues) { issue in
                        Label(issue.message, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(ForzAdvisorTheme.warning)
                    }
                }
                .forzAdvisorRowBackground()
            }
        }
        .navigationTitle("Edit Tune")
        .forzAdvisorScreenChrome()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel", action: onCancel)
            }
        }
    }
}

enum SavedTuneEditAction: Equatable {
    case noChanges
    case saveChanges
    case retuneAndSave

    static func resolve(
        original: SavedTuneEditDraft,
        current: SavedTuneEditDraft
    ) -> Self {
        guard original != current else { return .noChanges }
        let old = original.car
        let new = current.car
        let generationInputsChanged = old.weightPounds != new.weightPounds
            || old.frontWeightPercent != new.frontWeightPercent
            || old.performanceIndex != new.performanceIndex
            || old.performanceClass != new.performanceClass
            || old.drivetrain != new.drivetrain
        return generationInputsChanged ? .retuneAndSave : .saveChanges
    }

    var requiresRetune: Bool { self == .retuneAndSave }

    var title: String {
        switch self {
        case .noChanges: "No Changes"
        case .saveChanges: "Save Changes"
        case .retuneAndSave: "Re-tune & Save"
        }
    }

    var explanation: String {
        switch self {
        case .noChanges: "Edit identity, notes, or performance details to continue."
        case .saveChanges: "Identity and notes can be saved without changing the tune."
        case .retuneAndSave:
            "Performance inputs changed. The existing tune stays saved unless re-tuning finishes successfully."
        }
    }

    var symbolName: String {
        requiresRetune ? "arrow.triangle.2.circlepath" : "square.and.arrow.down"
    }
}
