import SwiftUI

struct APIKeySettingsSection: View {
    @Binding var apiKey: String
    let status: APIKeySettingsStatus
    let onSave: () -> Void
    let onClear: () -> Void

    var body: some View {
        Section("Anthropic API key") {
            LabeledContent("Credential", value: status.title)
                .accessibilityIdentifier("apiKeyPresenceStatus")

            SecureField("Paste a new API key", text: $apiKey)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .privacySensitive()
                .accessibilityHint("Existing credentials are never displayed")

            Button(status == .storedOnDeviceNotTested ? "Replace Key" : "Store Key") {
                onSave()
            }
            .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Button("Clear Key", role: .destructive, action: onClear)
                .disabled(status == .missing)

            Text("ForzAdvisor checks only whether a credential exists. It never displays or tests a stored key from Settings.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .forzAdvisorRowBackground()
    }
}
