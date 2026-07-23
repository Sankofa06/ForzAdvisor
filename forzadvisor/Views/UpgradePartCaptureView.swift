//
//  UpgradePartCaptureView.swift
//  forzadvisor
//
//  Exact stock-car upgrade-shop capture for tuning-control parts only.
//

import SwiftUI

struct UpgradePartCaptureView: View {
    let tune: TuneResult
    let snapshot: VehicleBuildSnapshot
    let onBack: () -> Void
    let onSubmit: (UpgradePartCapture) -> Void

    @State private var gameBuildVersion: String
    @State private var statuses: [TunePartID: UpgradePartCaptureStatus]
    @State private var exactStockBuildConfirmed = false
    @State private var localUsePermitted = false
    @State private var hasAttemptedSubmit = false

    init(
        tune: TuneResult,
        snapshot: VehicleBuildSnapshot,
        onBack: @escaping () -> Void,
        onSubmit: @escaping (UpgradePartCapture) -> Void
    ) {
        self.tune = tune
        self.snapshot = snapshot
        self.onBack = onBack
        self.onSubmit = onSubmit
        _gameBuildVersion = State(initialValue: snapshot.gameBuild.version ?? "")
        _statuses = State(initialValue: Dictionary(uniqueKeysWithValues:
            snapshot.capabilityProfile.parts.compactMap { part in
                switch part.availability {
                case .available: (part.partID, .offered)
                case .unavailable: (part.partID, .notOffered)
                case .installed, .unknown: nil
                }
            }
        ))
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Upgrade Lab", systemImage: "wrench.and.screwdriver")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(ForzAdvisorTheme.accent)
                    Text(tune.request.car.displayName)
                        .font(.title2.weight(.bold))
                    Text("Start with the untouched stock car. Check every tuning-control part in the upgrade shop and record only whether it is offered.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(ForzAdvisorTheme.heroRowBackground)

            Section("Game Observation") {
                TextField("Exact game build version", text: $gameBuildVersion)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("upgradeCaptureBuildVersion")
                Text("Use the exact version shown in \(tune.request.car.game.shortTitle) settings. Do not carry observations between FH5 and FH6 or between game builds.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .forzAdvisorRowBackground()

            ForEach(TunePartCategory.captureOrder, id: \.rawValue) { category in
                Section(category.label) {
                    ForEach(parts(in: category)) { part in
                        VStack(alignment: .leading, spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(part.label)
                                    .font(.subheadline.weight(.semibold))
                                Text(part.slot.label)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Picker("Availability", selection: statusBinding(for: part.id)) {
                                Text("Offered").tag(UpgradePartCaptureStatus?.some(.offered))
                                Text("Not offered").tag(UpgradePartCaptureStatus?.some(.notOffered))
                            }
                            .pickerStyle(.segmented)
                            .accessibilityIdentifier("upgradeCaptureStatus-\(part.id.rawValue)")
                            .accessibilityLabel("\(part.label) availability")
                            .accessibilityValue(statuses[part.id]?.title ?? "Not selected")
                        }
                        .padding(.vertical, 3)
                    }
                }
                .forzAdvisorRowBackground()
            }

            Section("Confirm Before Saving") {
                Toggle("This is the exact untouched stock catalog car", isOn: $exactStockBuildConfirmed)
                    .accessibilityIdentifier("upgradeCaptureStockConfirmation")
                Toggle("Allow this observation to be stored and used locally", isOn: $localUsePermitted)
                    .accessibilityIdentifier("upgradeCaptureLocalPermission")
                Text("This records tuning-control availability only. It does not predict PI, credits, ownership, performance, or installation order, and it is not added to the bundled catalog.")
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
                Button(tune.purpose == .fh5BuildPlan ? "Verify and Rebuild Plan" : "Verify and Regenerate") {
                    hasAttemptedSubmit = true
                    guard validationMessages.isEmpty else { return }
                    onSubmit(capture)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("submitUpgradeCaptureButton")
            }
            .forzAdvisorRowBackground()
        }
        .navigationTitle("Verify Upgrades")
        .forzAdvisorScreenChrome()
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Back", action: onBack)
            }
        }
    }

    private var capture: UpgradePartCapture {
        UpgradePartCapture(
            gameBuildVersion: gameBuildVersion,
            parts: TunePartID.allCases.compactMap { partID in
                statuses[partID].map { UpgradePartCaptureValue(partID: partID, status: $0) }
            },
            exactStockBuildConfirmed: exactStockBuildConfirmed,
            localUsePermitted: localUsePermitted
        )
    }

    private var validationMessages: [String] {
        capture.validationIssues(upgrading: snapshot).compactMap(\.errorDescription)
    }

    private func parts(in category: TunePartCategory) -> [TunePartDefinition] {
        TunePartCatalog.parts.filter { $0.category == category }
    }

    private func statusBinding(for partID: TunePartID) -> Binding<UpgradePartCaptureStatus?> {
        Binding {
            statuses[partID]
        } set: { newValue in
            statuses[partID] = newValue
        }
    }
}

private extension TunePartCategory {
    static let captureOrder: [TunePartCategory] = [
        .drivetrain,
        .platformAndHandling,
        .aeroAndAppearance
    ]
}
