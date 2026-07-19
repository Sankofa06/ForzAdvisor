//
//  SettingsView.swift
//  forzadvisor
//
//  Tune provider settings. Offline formulas are always available; on-device
//  Foundation Models and remote API generation fall back to those formulas.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("tuneProviderMode") private var tuneProviderMode = TuneProviderMode.offlineFormula
    @AppStorage("prefersRemoteTuneProvider") private var legacyPrefersRemoteTuneProvider = false

    let keychainStore: any APIKeyStoring

    @Environment(\.dismiss) private var dismiss
    @State private var apiKey = ""
    @State private var apiKeyStatus: APIKeyStatus = .missing
    @State private var onDeviceAvailability = OnDeviceModelAvailability.current()
    @State private var statusMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Tune Generation") {
                    Picker("Provider", selection: $tuneProviderMode) {
                        ForEach(TuneProviderMode.allCases) { mode in
                            Text(mode.title)
                                .tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(tuneProviderMode.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ProviderStatusRow(
                        mode: tuneProviderMode,
                        onDeviceAvailability: onDeviceAvailability,
                        apiKeyStatus: apiKeyStatus
                    )
                }
                .forzAdvisorRowBackground()

                if tuneProviderMode == .onDeviceFoundationModel {
                    Section("On-Device Status") {
                        Label(onDeviceAvailability.title, systemImage: onDeviceAvailability.isAvailable ? "checkmark.circle" : "exclamationmark.triangle")
                            .foregroundStyle(onDeviceAvailability.isAvailable ? ForzAdvisorTheme.success : ForzAdvisorTheme.warning)
                        Text(onDeviceAvailability.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("Refresh Status") {
                            onDeviceAvailability = OnDeviceModelAvailability.current()
                        }
                    }
                    .forzAdvisorRowBackground()
                }

                if tuneProviderMode == .anthropicAPI {
                    Section("Anthropic API Key") {
                        SecureField("Paste API key", text: $apiKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        Button("Save Key") {
                            saveKey()
                        }
                        .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        Button("Clear Key", role: .destructive) {
                            clearKey()
                        }
                        .disabled(!apiKeyStatus.hasConfiguredKey && apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .forzAdvisorRowBackground()
                }

                if let statusMessage {
                    Section {
                        Text(statusMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .forzAdvisorRowBackground()
                }

                Section("Privacy") {
                    Label("Offline by default", systemImage: "lock.shield")
                        .foregroundStyle(ForzAdvisorTheme.success)
                    Text("Screenshots are processed on device. API mode sends confirmed car details and notes to Anthropic using your saved key; screenshots are not uploaded.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .forzAdvisorRowBackground()

                Section("About") {
                    LabeledContent("Version", value: appVersion)
                    Text("ForzAdvisor is an unofficial tuning tool and is not affiliated with or endorsed by Microsoft, Xbox, Turn 10, Playground Games, or the Forza franchise.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .forzAdvisorRowBackground()
            }
            .navigationTitle("Settings")
            .forzAdvisorScreenChrome()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                migrateLegacyRemotePreference()
                onDeviceAvailability = OnDeviceModelAvailability.current()
                loadAPIKeyStatus()
            }
        }
    }

    private func loadAPIKeyStatus() {
        do {
            if let savedKey = try keychainStore.readAPIKey() {
                apiKey = savedKey
                apiKeyStatus = savedKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .missing : .configured
            } else {
                apiKey = ""
                apiKeyStatus = .missing
            }
        } catch {
            apiKeyStatus = .readFailed(error.localizedDescription)
            statusMessage = "Could not read API key: \(error.localizedDescription)"
        }
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func saveKey() {
        do {
            let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            try keychainStore.saveAPIKey(trimmedKey)
            apiKey = trimmedKey
            apiKeyStatus = .configured
            statusMessage = "API key saved."
        } catch {
            statusMessage = "Could not save key: \(error.localizedDescription)"
        }
    }

    private func clearKey() {
        do {
            try keychainStore.deleteAPIKey()
            apiKey = ""
            apiKeyStatus = .missing
            statusMessage = "API key cleared."
        } catch {
            statusMessage = "Could not clear key: \(error.localizedDescription)"
        }
    }

    private func migrateLegacyRemotePreference() {
        guard legacyPrefersRemoteTuneProvider else { return }
        if tuneProviderMode == .offlineFormula {
            tuneProviderMode = .anthropicAPI
        }
        legacyPrefersRemoteTuneProvider = false
    }
}

private struct ProviderStatusRow: View {
    let mode: TuneProviderMode
    let onDeviceAvailability: OnDeviceModelAvailability
    let apiKeyStatus: APIKeyStatus

    var body: some View {
        Label(statusText, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var statusText: String {
        switch mode {
        case .offlineFormula:
            "Offline formulas ready."
        case .onDeviceFoundationModel:
            onDeviceAvailability.isAvailable
                ? "On-device model ready."
                : "\(onDeviceAvailability.title); using offline formulas."
        case .anthropicAPI:
            switch apiKeyStatus {
            case .configured:
                "API key saved; remote tuning ready."
            case .missing:
                "No API key saved; using offline formulas."
            case .readFailed:
                "Could not read API key; using offline formulas."
            }
        }
    }

    private var systemImage: String {
        isReady ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
    }

    private var tint: Color {
        isReady ? ForzAdvisorTheme.success : ForzAdvisorTheme.warning
    }

    private var isReady: Bool {
        switch mode {
        case .offlineFormula:
            true
        case .onDeviceFoundationModel:
            onDeviceAvailability.isAvailable
        case .anthropicAPI:
            apiKeyStatus.hasConfiguredKey
        }
    }
}
