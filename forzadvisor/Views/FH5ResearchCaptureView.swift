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

    @State var platform: FH5Platform?
    @State var gameVersion: String
    @State var tireCompound = ""
    @State var gearCount = ""
    @State var drafts: [TuneFieldID: FH5ResearchFieldDraft] = [:]
    @State private var exactStockConfirmed = false
    @State private var slidersRestoredConfirmed = false
    @State private var personallyReadConfirmed = false
    @State private var firstPartyAuthorshipConfirmed = false
    @State private var localStoragePermitted = false
    @State private var hasAttemptedSubmit = false
    @State var recoveryMessage: String?

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
                    Text("Choose platform").tag(nil as FH5Platform?)
                    ForEach(FH5Platform.allCases) { platform in
                        Text(platform.title).tag(Optional(platform))
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
                            FH5ResearchFieldEditor(
                                field: field,
                                draft: fieldDraftBinding(for: field)
                            )
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
                Text("This observation is stored locally first. Reuse can be authorized later for its exact immutable fingerprint and revoked for future exports.")
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
                    guard validationMessages.isEmpty,
                          requiredChecks.allSatisfy(\.0) else { return }
                    onSubmit(capture)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("submitFH5ResearchObservationButton")
            }
            .forzAdvisorRowBackground()

            ValidationRecoveryMessageSection(message: recoveryMessage)
            ValidationDraftActionsSection(
                saveAndExit: saveAndExit,
                discard: discardDraft
            )
        }
        .navigationTitle("FH5 Research")
        .forzAdvisorScreenChrome()
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Back", action: saveAndExit)
            }
        }
        .task { restoreDraft() }
    }

    private var capture: FH5ResearchCapture {
        FH5ResearchCapture(
            platform: platform ?? .xboxSeries,
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
            deidentifiedStructuredReusePermitted: false
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

    private var requiredChecks: [(Bool, String)] {
        [
            (platform != nil, "Choose the platform"),
            (!gameVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "Enter the exact game version"),
            (!tireCompound.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "Enter the tire compound"),
            (parsedGearCount > 0, "Enter a forward gear count from 1 to 10"),
            (expectedFields.allSatisfy { drafts[$0]?.availability != nil }, "Review every menu control"),
            (exactStockConfirmed, "Confirm the exact stock car"),
            (slidersRestoredConfirmed, "Confirm every slider was restored"),
            (personallyReadConfirmed, "Confirm the values were personally read"),
            (firstPartyAuthorshipConfirmed, "Confirm first-party authorship"),
            (localStoragePermitted, "Allow local storage")
        ]
    }

    private var requiredGameVersion: String? {
        FH5ResearchObservationFactory().verifiedUpgradeGameVersion(in: snapshot)
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

    private func fieldDraftBinding(
        for field: TuneFieldID
    ) -> Binding<FH5ResearchFieldDraft> {
        Binding(
            get: { drafts[field] ?? .init() },
            set: { drafts[field] = $0 }
        )
    }

    private func parsed(_ value: String) -> Double? {
        LocalizedNumberText.parse(value)
    }

    private func parsedOptional(_ value: String) -> Double? {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : parsed(value)
    }
}
