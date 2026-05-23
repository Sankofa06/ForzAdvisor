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

    let keychainStore: KeychainStore

    @Environment(\.dismiss) private var dismiss
    @State private var apiKey = ""
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
                if let savedKey = try? keychainStore.readAPIKey() {
                    apiKey = savedKey
                }
            }
        }
    }

    private func saveKey() {
        do {
            try keychainStore.saveAPIKey(apiKey)
            statusMessage = "API key saved."
        } catch {
            statusMessage = "Could not save key: \(error.localizedDescription)"
        }
    }

    private func clearKey() {
        do {
            try keychainStore.deleteAPIKey()
            apiKey = ""
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
