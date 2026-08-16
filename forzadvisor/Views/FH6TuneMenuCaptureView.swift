//
//  FH6TuneMenuCaptureView.swift
//  forzadvisor
//
//  Exact, first-party FH6 stock tuning-menu capture.
//

import SwiftUI
import UIKit

struct FH6TuneMenuCaptureView: View {
    let tune: TuneResult
    let snapshot: VehicleBuildSnapshot
    let onBack: () -> Void
    let onSubmit: (FH6TuneMenuCapture) -> Void

    @State var gameBuildVersion: String
    @State var tireCompound: String
    @State var gearCount: String
    @State var drafts: [TuneFieldID: FH6TuneMenuControlDraft] = [:]
    @State var exactStockConfirmed = false
    @State var slidersRestored = false
    @State var personallyRead = false
    @State var localStoragePermitted = false
    @State private var hasAttemptedSubmit = false
    @State var recoveryMessage: String?

    init(
        tune: TuneResult,
        snapshot: VehicleBuildSnapshot,
        onBack: @escaping () -> Void,
        onSubmit: @escaping (FH6TuneMenuCapture) -> Void
    ) {
        self.tune = tune
        self.snapshot = snapshot
        self.onBack = onBack
        self.onSubmit = onSubmit
        _gameBuildVersion = State(initialValue: "")
        _tireCompound = State(initialValue: "")
        _gearCount = State(initialValue: "")
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("FH6 Tune Menu Lab", systemImage: "slider.horizontal.3")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(ForzAdvisorTheme.accent)
                    Text(tune.request.car.displayName)
                        .font(.title2.weight(.bold))
                    Text("Use the untouched stock car. Read every control directly from FH6, and restore each slider before moving on.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(ForzAdvisorTheme.heroRowBackground)

            Section("Exact Build") {
                TextField("Exact FH6 build version", text: $gameBuildVersion)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("menuCaptureBuildVersion")
                TextField("Tire compound shown in game", text: $tireCompound)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("menuCaptureTireCompound")
                numericField(
                    "Forward gear count",
                    text: $gearCount,
                    keyboard: .numberPad,
                    identifier: "menuCaptureGearCount"
                )
                Text("Count forward gears only. The list below updates to match that count.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .forzAdvisorRowBackground()

            ForEach(menuSections, id: \.title) { section in
                Section(section.title) {
                    ForEach(section.fields, id: \.stableID) { field in
                            FH6TuneMenuControlEditor(
                                field: field,
                                draft: controlDraftBinding(for: field)
                            )
                    }
                }
                .forzAdvisorRowBackground()
            }

            Section("Confirm Before Saving") {
                Toggle(
                    "This is the exact untouched stock catalog car",
                    isOn: $exactStockConfirmed
                )
                Toggle(
                    "I restored every moved slider to its original value",
                    isOn: $slidersRestored
                )
                Toggle(
                    "I personally read every entry from FH6",
                    isOn: $personallyRead
                )
                Toggle(
                    "Allow this observation to be stored and used locally",
                    isOn: $localStoragePermitted
                )
                Text("This observation stays inside this tune on this device. It is not uploaded, shared, or added to the bundled catalog.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .forzAdvisorRowBackground()

            ValidationCaptureProgressSection(
                completed: requiredChecks.filter(\.0).count,
                required: requiredChecks.count,
                next: requiredChecks.first { !$0.0 }?.1,
                focusNext: { hasAttemptedSubmit = true }
            )

            if hasAttemptedSubmit, !validationMessages.isEmpty {
                Section("Check These Values") {
                    ForEach(validationMessages, id: \.self) { message in
                        Label(message, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(ForzAdvisorTheme.warning)
                    }
                }
                .forzAdvisorRowBackground()
            }

            Section {
                Button("Verify Menu and Regenerate") {
                    hasAttemptedSubmit = true
                    guard validationMessages.isEmpty else { return }
                    onSubmit(capture)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("submitTuneMenuCaptureButton")
            }
            .forzAdvisorRowBackground()

            ValidationRecoveryMessageSection(message: recoveryMessage)
            ValidationDraftActionsSection(
                saveAndExit: saveAndExit,
                discard: discardDraft
            )
        }
        .navigationTitle("Verify Tune Menu")
        .forzAdvisorScreenChrome()
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Back", action: saveAndExit)
            }
        }
        .task { restoreDraft() }
    }

    private var expectedFields: [TuneFieldID] {
        TuneFieldID.expectedFields(
            drivetrain: tune.request.car.drivetrain,
            gearCount: parsedGearCount
        )
    }

    private var menuSections: [(title: String, fields: [TuneFieldID])] {
        TuneSection.menuOrder.compactMap { section in
            let fields = expectedFields.filter {
                $0.projectionSectionTitle == section.title
            }
            return fields.isEmpty ? nil : (section.title, fields)
        }
    }

    private var parsedGearCount: Int? {
        guard let value = LocalizedNumberText.parse(gearCount),
              value.isFinite,
              value.rounded(.towardZero) == value,
              (1...10).contains(value) else {
            return nil
        }
        return Int(value)
    }

    private var capture: FH6TuneMenuCapture {
        FH6TuneMenuCapture(
            gameBuildVersion: gameBuildVersion,
            tireCompoundDisplayName: tireCompound,
            forwardGearCount: parsedGearCount ?? 0,
            controls: expectedFields.compactMap { field in
                guard let draft = drafts[field],
                      let availability = draft.availability else {
                    return nil
                }
                if availability != .adjustable {
                    return FH6TuneMenuFieldObservation(
                        field: field,
                        availability: availability,
                        minimum: nil,
                        maximum: nil,
                        step: nil,
                        current: nil,
                        unit: nil
                    )
                }
                return FH6TuneMenuFieldObservation(
                    field: field,
                    availability: availability,
                    minimum: parsed(draft.minimum),
                    maximum: parsed(draft.maximum),
                    step: parsed(draft.step),
                    current: parsed(draft.current),
                    unit: field.expectedUnit
                )
            },
            exactUntouchedStockConfirmed: exactStockConfirmed,
            allSlidersRestoredConfirmed: slidersRestored,
            personallyReadFromGameConfirmed: personallyRead,
            localStoragePermitted: localStoragePermitted
        )
    }

    private var validationMessages: [String] {
        capture.validationIssues(upgrading: snapshot).map(\.localizedDescription)
    }

    var requiredChecks: [(Bool, String)] {
        [
            (!gameBuildVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "Enter the exact game build"),
            (!tireCompound.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "Enter the tire compound"),
            (parsedGearCount != nil, "Enter a forward gear count from 1 to 10"),
            (expectedFields.allSatisfy { drafts[$0]?.availability != nil }, "Review every menu control"),
            (exactStockConfirmed, "Confirm the exact stock car"),
            (slidersRestored, "Confirm every slider was restored"),
            (personallyRead, "Confirm the values were read in FH6"),
            (localStoragePermitted, "Allow local storage")
        ]
    }

    private func numericField(
        _ title: String,
        text: Binding<String>,
        keyboard: UIKeyboardType,
        identifier: String
    ) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("—", text: text)
                .keyboardType(keyboard)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 120)
                .accessibilityIdentifier(identifier)
        }
    }

    private func controlDraftBinding(
        for field: TuneFieldID
    ) -> Binding<FH6TuneMenuControlDraft> {
        Binding(
            get: { drafts[field] ?? .init() },
            set: { drafts[field] = $0 }
        )
    }

    private func parsed(_ text: String) -> Double {
        LocalizedNumberText.parse(text) ?? .nan
    }

}
