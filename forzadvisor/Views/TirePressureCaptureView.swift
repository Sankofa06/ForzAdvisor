//
//  TirePressureCaptureView.swift
//  forzadvisor
//
//  A deliberately narrow Tune Lab capture for exact FH6 tire-pressure ranges
//  and forward gear count.
//

import SwiftUI

struct TirePressureCaptureView: View {
    let tune: TuneResult
    let snapshot: VehicleBuildSnapshot
    let onBack: () -> Void
    let onSubmit: (TirePressureCapture) -> Void

    @State private var gameBuildVersion: String
    @State private var tireCompound = ""
    @State private var gearCount = ""
    @State private var frontMinimum = ""
    @State private var frontMaximum = ""
    @State private var frontStep = ""
    @State private var frontCurrent = ""
    @State private var rearMinimum = ""
    @State private var rearMaximum = ""
    @State private var rearStep = ""
    @State private var rearCurrent = ""
    @State private var exactStockBuildConfirmed = false
    @State private var localUsePermitted = false
    @State private var hasAttemptedSubmit = false
    @State private var recoveryMessage: String?

    init(
        tune: TuneResult,
        snapshot: VehicleBuildSnapshot,
        onBack: @escaping () -> Void,
        onSubmit: @escaping (TirePressureCapture) -> Void
    ) {
        self.tune = tune
        self.snapshot = snapshot
        self.onBack = onBack
        self.onSubmit = onSubmit
        _gameBuildVersion = State(initialValue: "")
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("FH6 Tune Lab", systemImage: "gauge.with.dots.needle.33percent")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(ForzAdvisorTheme.accent)
                    Text(tune.request.car.displayName)
                        .font(.title2.weight(.bold))
                    Text("Use the untouched stock car. Copy the values exactly as FH6 shows them; do not estimate or round.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(ForzAdvisorTheme.heroRowBackground)

            Section("Game Observation") {
                TextField("Exact FH6 build version", text: $gameBuildVersion)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("tireCaptureBuildVersion")
                TextField("Tire compound shown in game", text: $tireCompound)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("tireCaptureCompound")
                HStack {
                    Text("Forward gear count")
                    Spacer()
                    TextField("—", text: $gearCount)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 110)
                        .accessibilityLabel("Forward gear count")
                        .accessibilityIdentifier("tireCaptureGearCount")
                }
                Text("Find the build version in FH6 settings. Use the compound name shown for this stock car, such as Stock or Street. Enter the number of forward gears shown in the transmission/gearing screen; do not include reverse.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .forzAdvisorRowBackground()

            pressureSection(
                title: "Front Tires",
                minimum: $frontMinimum,
                maximum: $frontMaximum,
                step: $frontStep,
                current: $frontCurrent,
                identifierPrefix: "front"
            )

            ValidationCaptureProgressSection(
                completed: requiredChecks.filter(\.0).count,
                required: requiredChecks.count,
                next: requiredChecks.first { !$0.0 }?.1,
                focusNext: { hasAttemptedSubmit = true }
            )

            pressureSection(
                title: "Rear Tires",
                minimum: $rearMinimum,
                maximum: $rearMaximum,
                step: $rearStep,
                current: $rearCurrent,
                identifierPrefix: "rear"
            )

            Section("Confirm Before Saving") {
                Toggle("This is the exact untouched stock catalog car", isOn: $exactStockBuildConfirmed)
                    .accessibilityIdentifier("tireCaptureStockConfirmation")
                Toggle("Allow this observation to be stored and used locally", isOn: $localUsePermitted)
                    .accessibilityIdentifier("tireCaptureLocalPermission")
                Text("The observation stays in this tune on your device. It is not uploaded or added to the bundled catalog.")
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
                Button("Verify and Regenerate") {
                    hasAttemptedSubmit = true
                    guard validationMessages.isEmpty else { return }
                    onSubmit(capture)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("submitTireCaptureButton")
            }
            .forzAdvisorRowBackground()

            ValidationRecoveryMessageSection(message: recoveryMessage)
            ValidationDraftActionsSection(
                saveAndExit: saveAndExit,
                discard: discardDraft
            )
        }
        .navigationTitle("Verify Tires")
        .forzAdvisorScreenChrome()
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Back", action: saveAndExit)
            }
        }
        .task { restoreDraft() }
    }

    private var capture: TirePressureCapture {
        TirePressureCapture(
            gameBuildVersion: gameBuildVersion,
            tireCompound: tireCompound,
            gearCount: Self.parsedGearCount(gearCount),
            front: TirePressureRangeCapture(
                minimumPSI: parsed(frontMinimum),
                maximumPSI: parsed(frontMaximum),
                stepPSI: parsed(frontStep),
                currentPSI: parsed(frontCurrent)
            ),
            rear: TirePressureRangeCapture(
                minimumPSI: parsed(rearMinimum),
                maximumPSI: parsed(rearMaximum),
                stepPSI: parsed(rearStep),
                currentPSI: parsed(rearCurrent)
            ),
            exactStockBuildConfirmed: exactStockBuildConfirmed,
            localUsePermitted: localUsePermitted
        )
    }

    private var validationMessages: [String] {
        capture.validationIssues(upgrading: snapshot).map(\.localizedDescription)
    }

    private var requiredChecks: [(Bool, String)] {
        [
            (!gameBuildVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "Enter the exact game build"),
            (!tireCompound.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "Enter the tire compound"),
            (Self.parsedGearCount(gearCount) > 0, "Enter a forward gear count from 1 to 10"),
            (frontValues.allSatisfy(isNumeric), "Complete all front tire values"),
            (rearValues.allSatisfy(isNumeric), "Complete all rear tire values"),
            (exactStockBuildConfirmed, "Confirm the exact stock build"),
            (localUsePermitted, "Allow local storage")
        ]
    }

    private var frontValues: [String] {
        [frontMinimum, frontMaximum, frontStep, frontCurrent]
    }

    private var rearValues: [String] {
        [rearMinimum, rearMaximum, rearStep, rearCurrent]
    }

    private func isNumeric(_ value: String) -> Bool {
        LocalizedNumberText.parse(value)?.isFinite == true
    }

    private var recovery: ValidationCaptureRecovery? {
        try? ValidationCaptureRecovery(
            kind: .tirePressureCapture,
            tune: tune,
            gameBuildVersion: snapshot.gameBuild.version,
            captureRevision: "fh6-tire-pressure-v2"
        )
    }

    private var factualFields: [String: String] {
        [
            "gameBuildVersion": gameBuildVersion,
            "tireCompound": tireCompound, "gearCount": gearCount,
            "frontMinimum": frontMinimum, "frontMaximum": frontMaximum,
            "frontStep": frontStep, "frontCurrent": frontCurrent,
            "rearMinimum": rearMinimum, "rearMaximum": rearMaximum,
            "rearStep": rearStep, "rearCurrent": rearCurrent
        ]
    }

    private func restoreDraft() {
        guard let recovery else { return }
        do {
            guard let fields = try recovery.restore() else { return }
            gameBuildVersion = fields["gameBuildVersion"] ?? ""
            tireCompound = fields["tireCompound"] ?? ""
            gearCount = fields["gearCount"] ?? ""
            frontMinimum = fields["frontMinimum"] ?? ""
            frontMaximum = fields["frontMaximum"] ?? ""
            frontStep = fields["frontStep"] ?? ""
            frontCurrent = fields["frontCurrent"] ?? ""
            rearMinimum = fields["rearMinimum"] ?? ""
            rearMaximum = fields["rearMaximum"] ?? ""
            rearStep = fields["rearStep"] ?? ""
            rearCurrent = fields["rearCurrent"] ?? ""
            recoveryMessage = "Resumed the factual fields from your local draft."
        } catch ValidationDraftStoreError.stale {
            recoveryMessage = "An older incompatible draft was discarded."
        } catch {
            recoveryMessage = "An unreadable draft was not restored."
        }
    }

    private func saveAndExit() {
        guard let recovery else {
            recoveryMessage = "This tune revision cannot safely bind a draft."
            return
        }
        do {
            try recovery.save(factualFields: factualFields)
            onBack()
        } catch {
            recoveryMessage = "Draft could not be saved. Your form remains open."
        }
    }

    private func discardDraft() {
        try? recovery?.discard()
        onBack()
    }

    private func parsed(_ text: String) -> Double {
        LocalizedNumberText.parse(text) ?? .nan
    }

    static func parsedGearCount(_ text: String) -> Int {
        guard let value = LocalizedNumberText.parse(text),
              value.isFinite,
              value.rounded(.towardZero) == value,
              (1...10).contains(value) else {
            return 0
        }
        return Int(value)
    }

    private func pressureSection(
        title: String,
        minimum: Binding<String>,
        maximum: Binding<String>,
        step: Binding<String>,
        current: Binding<String>,
        identifierPrefix: String
    ) -> some View {
        Section(title) {
            pressureField("Minimum PSI", text: minimum, identifier: "\(identifierPrefix)TireMinimum")
            pressureField("Maximum PSI", text: maximum, identifier: "\(identifierPrefix)TireMaximum")
            pressureField("Slider step PSI", text: step, identifier: "\(identifierPrefix)TireStep")
            pressureField("Current stock PSI", text: current, identifier: "\(identifierPrefix)TireCurrent")
            Text("Move the in-game slider to each end to read minimum and maximum, then one tick to read the step. Return it to the stock current value before leaving.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .forzAdvisorRowBackground()
    }

    private func pressureField(
        _ title: String,
        text: Binding<String>,
        identifier: String
    ) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("—", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 110)
                .accessibilityIdentifier(identifier)
        }
    }
}
