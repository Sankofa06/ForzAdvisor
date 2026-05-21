//
//  SettingsView.swift
//  forzadvisor
//
//  Optional remote tuning settings. Saving an API key enables API-ready flows,
//  but the local offline provider remains available and is the default.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("prefersRemoteTuneProvider") private var prefersRemoteTuneProvider = false

    let keychainStore: KeychainStore

    @Environment(\.dismiss) private var dismiss
    @State private var apiKey = ""
    @State private var statusMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Tune Generation") {
                    Toggle("Prefer API generation", isOn: $prefersRemoteTuneProvider)
                    Text("If the API key is missing or a request fails, ForzAdvisor uses the offline tune provider.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

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

                if let statusMessage {
                    Section {
                        Text(statusMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
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
            prefersRemoteTuneProvider = false
            statusMessage = "API key cleared."
        } catch {
            statusMessage = "Could not clear key: \(error.localizedDescription)"
        }
    }
}
