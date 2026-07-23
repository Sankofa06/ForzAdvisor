//
//  FH5ResearchCaptureView.swift
//  forzadvisor
//
//  Guided, manual-only capture of the untouched-stock FH5 tuning menu.
//

import SwiftUI

struct FH5ResearchCaptureView: View {
    let tune: TuneResult
    let snapshot: VehicleBuildSnapshot
    let onBack: () -> Void
    let onSubmit: (FH5ResearchCapture) -> Void

    @State private var platform = FH5Platform.xboxSeries
    @State private var gameVersion: String
    @State private var tireCompound = ""
    @State private var gearCount = "6"
    @State private var drafts: [TuneFieldID: FieldDraft] = [:]
    @State private var exactStockConfirmed = false
    @State private var slidersRestoredConfirmed = false
    @State private var personallyReadConfirmed = false
    @State private var firstPartyAuthorshipConfirmed = false
    @State private var localStoragePermitted = false
    @State private var deidentifiedReusePermitted = false
    @State private var hasAttemptedSubmit = false

    init(
        tune: TuneResult,
        snapshot: VehicleBuildSnapshot,
        onBack: @escaping () -> Void,
        onSubmit: @escaping (FH5ResearchCapture) -> Void
    ) {
        self.tune = tune
        self.snapshot = snapshot
        self.onBack = onBack
        self.onSubmit = onSubmit
        _gameVersion = State(initialValue:
            FH5ResearchObservationFactory().verifiedUpgradeGameVersion(in: snapshot)
                ?? snapshot.gameBuild.version
                ?? ""
        )
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("FH5 Research Lab", systemImage: "checklist.checked")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(ForzAdvisorTheme.accent)
                    Text(tune.request.car.displayName)
                        .font(.title2.weight(.bold))
                    Text("Record raw first-party menu evidence. This does not create a tune or make FH5 numeric tuning ready.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(ForzAdvisorTheme.heroRowBackground)

            Section("Test Track Protocol") {
                Label(
                    "Use the untouched stock car in Horizon Test Track. Do not install or save upgrades.",
                    systemImage: "car.side"
                )
                Label(
                    "Use English units for this first slice. Enter only values you personally read in FH5.",
                    systemImage: "character.book.closed"
                )
                Label(
                    "For each adjustable slider, read both ends and one tick, then restore the original current value.",
                    systemImage: "slider.horizontal.3"
                )
                Text("Do not copy values from YouTube, Reddit, shared tunes, or share codes.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ForzAdvisorTheme.warning)
            }
            .forzAdvisorRowBackground()

            Section("Observation Context") {
                Picker("Platform", selection: $platform) {
                    ForEach(FH5Platform.allCases) { platform in
                        Text(platform.title).tag(platform)
                    }
                }
                .accessibilityIdentifier("fh5ResearchPlatform")

                if let requiredGameVersion {
                    LabeledContent("Exact FH5 game version") {
                        Text(requiredGameVersion)
                            .font(.body.monospacedDigit())
                    }
                    .accessibilityIdentifier("fh5ResearchBuildVersionLocked")
                    Text("Locked to the complete Upgrade Lab observation already attached to this plan.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    TextField("Exact FH5 game version", text: $gameVersion)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("fh5ResearchBuildVersion")
                }

                TextField("Tire compound shown in FH5", text: $tireCompound)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("fh5ResearchTireCompound")

                HStack {
                    Text("Forward gear count")
                    Spacer()
                    TextField("1–10", text: $gearCount)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 100)
                        .accessibilityIdentifier("fh5ResearchGearCount")
                }
                Text("The version is stored exactly with the selected platform. ForzAdvisor never infers a platform from a version prefix.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .forzAdvisorRowBackground()

            ForEach(TuneSection.menuOrder, id: \.title) { section in
                let fields = fields(in: section.title)
                if !fields.isEmpty {
                    Section {
                        ForEach(fields, id: \.stableID) { field in
                            fieldEditor(field)
                        }
                    } header: {
                        Label(section.title, systemImage: section.symbolName)
                    }
                    .forzAdvisorRowBackground()
                }
            }

            Section("Confirm Before Saving") {
                Toggle("This is the exact untouched stock catalog car", isOn: $exactStockConfirmed)
                    .accessibilityIdentifier("fh5ResearchStockConfirmation")
                Toggle("Every moved slider was restored to its original value", isOn: $slidersRestoredConfirmed)
                    .accessibilityIdentifier("fh5ResearchRestoreConfirmation")
                Toggle("I personally read these values in FH5", isOn: $personallyReadConfirmed)
                    .accessibilityIdentifier("fh5ResearchPersonallyReadConfirmation")
                Toggle("This is my own first-party observation", isOn: $firstPartyAuthorshipConfirmed)
                    .accessibilityIdentifier("fh5ResearchAuthorshipConfirmation")
                Toggle("Allow local storage with this saved plan", isOn: $localStoragePermitted)
                    .accessibilityIdentifier("fh5ResearchLocalPermission")
                Toggle(
                    "Allow deidentified structured reuse and JSON sharing",
                    isOn: $deidentifiedReusePermitted
                )
                .accessibilityIdentifier("fh5ResearchReusePermission")

                Text("Reuse is off by default and applies only to the structured record. Screenshots, notes, tune IDs, provider data, device data, and locations are excluded.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .forzAdvisorRowBackground()

            if hasAttemptedSubmit, !validationMessages.isEmpty {
                Section("Check This Observation") {
                    ForEach(validationMessages, id: \.self) { message in
                        Label(message, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(ForzAdvisorTheme.warning)
                    }
                }
                .forzAdvisorRowBackground()
            }

            Section {
                Button("Save Stock Observation") {
                    hasAttemptedSubmit = true
                    guard validationMessages.isEmpty else { return }
                    onSubmit(capture)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("submitFH5ResearchObservationButton")
            }
            .forzAdvisorRowBackground()
        }
        .navigationTitle("FH5 Research")
        .forzAdvisorScreenChrome()
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Back", action: onBack)
            }
        }
    }

    @ViewBuilder
    private func fieldEditor(_ field: TuneFieldID) -> some View {
        let draft = draftBinding(for: field)
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(field.projectionLabel)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if !field.expectedDisplayUnit.isEmpty {
                    Text(field.expectedDisplayUnit)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            Picker("Availability", selection: availabilityBinding(for: field)) {
                Text("Adjustable").tag(FH5TuneFieldAvailability?.some(.adjustable))
                Text("Locked").tag(FH5TuneFieldAvailability?.some(.shownLocked))
                Text("Not shown").tag(FH5TuneFieldAvailability?.some(.notShown))
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("fh5ResearchAvailability-\(field.stableID)")

            switch draft.wrappedValue.availability {
            case .adjustable:
                numericField("Minimum", text: valueBinding(draft, \.minimum), field: field, suffix: "minimum")
                numericField("Maximum", text: valueBinding(draft, \.maximum), field: field, suffix: "maximum")
                numericField("Slider step", text: valueBinding(draft, \.step), field: field, suffix: "step")
                numericField("Current stock value", text: valueBinding(draft, \.current), field: field, suffix: "current")
            case .shownLocked:
                numericField(
                    "Current shown value (optional)",
                    text: valueBinding(draft, \.current),
                    field: field,
                    suffix: "lockedCurrent"
                )
            case .notShown:
                Text("No numeric values are stored for a control that is not shown.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case nil:
                Text("Choose exactly one state after checking this menu position in FH5.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
    }

    private func numericField(
        _ title: String,
        text: Binding<String>,
        field: TuneFieldID,
        suffix: String
    ) -> some View {
        HStack {
            Text(title)
                .font(.caption)
            Spacer()
            TextField("—", text: text)
                .keyboardType(supportsSignedInput(field) ? .numbersAndPunctuation : .decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 120)
                .accessibilityIdentifier("fh5Research-\(field.stableID)-\(suffix)")
        }
    }

    private var capture: FH5ResearchCapture {
        FH5ResearchCapture(
            platform: platform,
            gameVersion: gameVersion,
            tireCompoundDisplayName: tireCompound,
            forwardGearCount: parsedGearCount,
            controls: expectedFields.compactMap { field in
                guard let draft = drafts[field],
                      let availability = draft.availability else {
                    return nil
                }
                switch availability {
                case .adjustable:
                    return FH5TuneFieldObservation(
                        field: field,
                        availability: availability,
                        minimum: parsed(draft.minimum),
                        maximum: parsed(draft.maximum),
                        step: parsed(draft.step),
                        current: parsed(draft.current),
                        unit: field.expectedUnit
                    )
                case .shownLocked:
                    let current = parsedOptional(draft.current)
                    return FH5TuneFieldObservation(
                        field: field,
                        availability: availability,
                        current: current,
                        unit: current == nil ? nil : field.expectedUnit
                    )
                case .notShown:
                    return FH5TuneFieldObservation(field: field, availability: availability)
                }
            },
            exactUntouchedStockConfirmed: exactStockConfirmed,
            allSlidersRestoredConfirmed: slidersRestoredConfirmed,
            personallyReadFromGameConfirmed: personallyReadConfirmed,
            firstPartyAuthorshipConfirmed: firstPartyAuthorshipConfirmed,
            localStoragePermitted: localStoragePermitted,
            deidentifiedStructuredReusePermitted: deidentifiedReusePermitted
        )
    }

    private var validationMessages: [String] {
        FH5ResearchObservationFactory()
            .validationIssues(
                capture: capture,
                drivetrain: tune.request.car.drivetrain,
                requiredGameVersion: requiredGameVersion
            )
            .compactMap(\.errorDescription)
    }

    private var requiredGameVersion: String? {
        FH5ResearchObservationFactory().verifiedUpgradeGameVersion(in: snapshot)
    }

    private func supportsSignedInput(_ field: TuneFieldID) -> Bool {
        switch field {
        case .frontCamber, .rearCamber, .frontToe, .rearToe:
            true
        default:
            false
        }
    }

    private var parsedGearCount: Int {
        guard let value = LocalizedNumberText.parse(gearCount),
              value.isFinite,
              value.rounded(.towardZero) == value,
              (1...10).contains(value) else {
            return 0
        }
        return Int(value)
    }

    private var expectedFields: [TuneFieldID] {
        TuneFieldID.expectedFields(
            drivetrain: tune.request.car.drivetrain,
            gearCount: parsedGearCount > 0 ? parsedGearCount : nil
        )
    }

    private func fields(in section: String) -> [TuneFieldID] {
        expectedFields.filter { $0.projectionSectionTitle == section }
    }

    private func availabilityBinding(
        for field: TuneFieldID
    ) -> Binding<FH5TuneFieldAvailability?> {
        Binding {
            drafts[field]?.availability
        } set: { newValue in
            var draft = drafts[field] ?? FieldDraft()
            draft.availability = newValue
            switch newValue {
            case .adjustable:
                break
            case .shownLocked:
                draft.minimum = ""
                draft.maximum = ""
                draft.step = ""
            case .notShown, nil:
                draft.minimum = ""
                draft.maximum = ""
                draft.step = ""
                draft.current = ""
            }
            drafts[field] = draft
        }
    }

    private func draftBinding(for field: TuneFieldID) -> Binding<FieldDraft> {
        Binding {
            drafts[field] ?? FieldDraft()
        } set: { drafts[field] = $0 }
    }

    private func valueBinding(
        _ draft: Binding<FieldDraft>,
        _ keyPath: WritableKeyPath<FieldDraft, String>
    ) -> Binding<String> {
        Binding {
            draft.wrappedValue[keyPath: keyPath]
        } set: { value in
            var updated = draft.wrappedValue
            updated[keyPath: keyPath] = value
            draft.wrappedValue = updated
        }
    }

    private func parsed(_ value: String) -> Double? {
        LocalizedNumberText.parse(value)
    }

    private func parsedOptional(_ value: String) -> Double? {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : parsed(value)
    }
}

private struct FieldDraft: Equatable {
    var availability: FH5TuneFieldAvailability?
    var minimum = ""
    var maximum = ""
    var step = ""
    var current = ""
}
