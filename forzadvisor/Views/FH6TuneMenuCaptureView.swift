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

    @State private var gameBuildVersion: String
    @State private var tireCompound: String
    @State private var gearCount: String
    @State private var drafts: [TuneFieldID: ControlDraft] = [:]
    @State private var exactStockConfirmed = false
    @State private var slidersRestored = false
    @State private var personallyRead = false
    @State private var localStoragePermitted = false
    @State private var hasAttemptedSubmit = false

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
        _gameBuildVersion = State(initialValue: snapshot.gameBuild.version ?? "")
        _tireCompound = State(initialValue: snapshot.tireCompound?.displayName ?? "")
        _gearCount = State(initialValue: snapshot.gearCount.map(String.init) ?? "")
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
                        controlEditor(for: field)
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
        }
        .navigationTitle("Verify Tune Menu")
        .forzAdvisorScreenChrome()
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Back", action: onBack)
            }
        }
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

    @ViewBuilder
    private func controlEditor(for field: TuneFieldID) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(field.projectionLabel)
                        .font(.subheadline.weight(.semibold))
                    Text(field.expectedDisplayUnit.isEmpty ? "No unit" : field.expectedDisplayUnit)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Picker("State", selection: availabilityBinding(for: field)) {
                    Text("Not reviewed")
                        .tag(FH6TuneMenuFieldAvailability?.none)
                    ForEach(FH6TuneMenuFieldAvailability.allCases, id: \.rawValue) {
                        Text(availabilityTitle($0))
                            .tag(Optional($0))
                    }
                }
                .labelsHidden()
                .accessibilityLabel("\(field.projectionLabel) state")
            }

            if drafts[field]?.availability == .adjustable {
                HStack(spacing: 8) {
                    compactNumericField("Min", field: field, keyPath: \.minimum)
                    compactNumericField("Max", field: field, keyPath: \.maximum)
                    compactNumericField("Step", field: field, keyPath: \.step)
                    compactNumericField("Current", field: field, keyPath: \.current)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func compactNumericField(
        _ label: String,
        field: TuneFieldID,
        keyPath: WritableKeyPath<ControlDraft, String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            TextField("—", text: draftBinding(for: field, keyPath: keyPath))
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("\(field.projectionLabel) \(label)")
        }
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

    private func availabilityBinding(
        for field: TuneFieldID
    ) -> Binding<FH6TuneMenuFieldAvailability?> {
        Binding(
            get: { drafts[field]?.availability },
            set: { availability in
                var draft = drafts[field] ?? ControlDraft()
                draft.availability = availability
                if availability != .adjustable {
                    draft.minimum = ""
                    draft.maximum = ""
                    draft.step = ""
                    draft.current = ""
                }
                drafts[field] = draft
            }
        )
    }

    private func draftBinding(
        for field: TuneFieldID,
        keyPath: WritableKeyPath<ControlDraft, String>
    ) -> Binding<String> {
        Binding(
            get: { drafts[field]?[keyPath: keyPath] ?? "" },
            set: { value in
                var draft = drafts[field] ?? ControlDraft()
                draft[keyPath: keyPath] = value
                drafts[field] = draft
            }
        )
    }

    private func parsed(_ text: String) -> Double {
        LocalizedNumberText.parse(text) ?? .nan
    }

    private func availabilityTitle(
        _ availability: FH6TuneMenuFieldAvailability
    ) -> String {
        switch availability {
        case .adjustable: "Adjustable"
        case .shownLocked: "Shown locked"
        case .notShown: "Not shown"
        }
    }
}

private struct ControlDraft {
    var availability: FH6TuneMenuFieldAvailability?
    var minimum = ""
    var maximum = ""
    var step = ""
    var current = ""
}
