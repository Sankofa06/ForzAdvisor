//
//  TirePressureCaptureView.swift
//  forzadvisor
//
//  A deliberately narrow Tune Lab capture for exact FH6 tire-pressure ranges.
//

import SwiftUI

struct TirePressureCaptureView: View {
    let tune: TuneResult
    let snapshot: VehicleBuildSnapshot
    let onBack: () -> Void
    let onSubmit: (TirePressureCapture) -> Void

    @State private var gameBuildVersion = ""
    @State private var tireCompound = ""
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
                Text("Find the build version in FH6 settings. Use the compound name shown for this stock car, such as Stock or Street.")
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
        }
        .navigationTitle("Verify Tires")
        .forzAdvisorScreenChrome()
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Back", action: onBack)
            }
        }
    }

    private var capture: TirePressureCapture {
        TirePressureCapture(
            gameBuildVersion: gameBuildVersion,
            tireCompound: tireCompound,
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

    private func parsed(_ text: String) -> Double {
        LocalizedNumberText.parse(text) ?? .nan
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
