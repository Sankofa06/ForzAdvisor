import SwiftUI

struct SettingsView: View {
    @AppStorage("tuneProviderMode") private var tuneProviderMode = TuneProviderMode.offlineFormula
    @AppStorage("prefersRemoteTuneProvider") private var legacyPrefersRemoteTuneProvider = false

    @Environment(\.dismiss) private var dismiss
    @StateObject private var keyController: APIKeySettingsController
    @State private var apiKey = ""
    @State private var onDeviceAvailability = OnDeviceModelAvailability.current()

    init(keychainStore: any APIKeySettingsStoring) {
        _keyController = StateObject(
            wrappedValue: APIKeySettingsController(store: keychainStore)
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                providerSection
                fh5OverrideSection

                if tuneProviderMode == .onDeviceFoundationModel {
                    onDeviceSection
                }
                if tuneProviderMode == .anthropicAPI {
                    apiKeySection
                }
                if let message = keyController.message {
                    statusSection(message)
                }

                privacySection
                aboutSection
            }
            .navigationTitle("Settings")
            .forzAdvisorScreenChrome()
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    ModalCopilotToolbarLink(destination: .settings)
                    Button("Done") { dismiss() }
                }
            }
            .task {
                migrateLegacyRemotePreference()
                refreshCapabilities()
            }
            .confirmationDialog(
                confirmationTitle,
                isPresented: confirmationBinding,
                titleVisibility: .visible
            ) {
                Button(confirmationButtonTitle, role: confirmationRole) {
                    keyController.confirmPendingAction()
                    apiKey = ""
                }
                Button("Cancel", role: .cancel) {
                    keyController.cancelPendingAction()
                    apiKey = ""
                }
            } message: {
                Text("The current credential stays in place unless this change succeeds.")
            }
        }
    }

    private var providerSection: some View {
        Section("Preferred generation method") {
            ForEach(TuneProviderMode.allCases) { mode in
                ProviderPreferenceCard(
                    mode: mode,
                    disclosure: disclosure(for: mode),
                    isSelected: tuneProviderMode == mode,
                    onSelect: { tuneProviderMode = mode }
                )
            }
        }
        .forzAdvisorRowBackground()
    }

    private var fh5OverrideSection: some View {
        Section("Forza Horizon 5") {
            Label("FH5 always uses the local build planner", systemImage: "lock.shield")
                .font(.subheadline.weight(.semibold))
            Text("Your preferred generation method applies to FH6 only. FH5 remains local and plan-only.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .forzAdvisorRowBackground()
    }

    private var onDeviceSection: some View {
        Section("On-device status") {
            Label(
                onDeviceAvailability.title,
                systemImage: onDeviceAvailability.isAvailable
                    ? "checkmark.circle" : "exclamationmark.triangle"
            )
            Text(onDeviceAvailability.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Refresh status") { refreshCapabilities() }
        }
        .forzAdvisorRowBackground()
    }

    private var apiKeySection: some View {
        APIKeySettingsSection(
            apiKey: $apiKey,
            status: keyController.status,
            onSave: {
                let awaitsConfirmation = keyController.requestSave(apiKey)
                if !awaitsConfirmation { apiKey = "" }
            },
            onClear: keyController.requestClear
        )
    }

    private func statusSection(_ message: String) -> some View {
        Section {
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("apiKeyStatusMessage")
        }
        .forzAdvisorRowBackground()
    }

    private var privacySection: some View {
        let providerDisclosure = disclosure(for: tuneProviderMode)
        return Section("Privacy") {
            Label(
                providerDisclosure.dataBoundary == .localOnly
                    ? "Local-only route expected" : "Remote attempt may occur",
                systemImage: "lock.shield"
            )
            .foregroundStyle(ForzAdvisorTheme.success)
            Text(providerDisclosure.dataBoundary.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
            if providerDisclosure.route.fallbackMode != nil {
                Text("If the preferred attempt cannot start or finish, FH6 falls back to offline formulas on this device.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .forzAdvisorRowBackground()
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: appVersion)
            Text("ForzAdvisor is an unofficial tuning tool and is not affiliated with or endorsed by Microsoft, Xbox, Turn 10, Playground Games, or the Forza franchise.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .forzAdvisorRowBackground()
    }

    private var capabilities: TuneProviderCapabilities {
        SettingsProviderCapabilities(
            onDeviceAvailability: onDeviceAvailability,
            apiKeyStatus: keyController.status
        ).value
    }

    private func disclosure(for mode: TuneProviderMode) -> TuneProviderDisclosure {
        TuneProviderDisclosure(preferredMode: mode, capabilities: capabilities)
    }

    private func refreshCapabilities() {
        onDeviceAvailability = OnDeviceModelAvailability.current()
        keyController.refresh()
    }

    private var confirmationBinding: Binding<Bool> {
        Binding(
            get: { keyController.pendingAction != nil },
            set: { if !$0 { keyController.cancelPendingAction() } }
        )
    }

    private var confirmationTitle: String {
        switch keyController.pendingAction {
        case .replace: "Replace the stored API key?"
        case .clear: "Clear the stored API key?"
        case nil: "Confirm credential change"
        }
    }

    private var confirmationButtonTitle: String {
        if case .clear = keyController.pendingAction { "Clear Key" } else { "Replace Key" }
    }

    private var confirmationRole: ButtonRole? {
        if case .clear = keyController.pendingAction { .destructive } else { nil }
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func migrateLegacyRemotePreference() {
        guard legacyPrefersRemoteTuneProvider else { return }
        if tuneProviderMode == .offlineFormula { tuneProviderMode = .anthropicAPI }
        legacyPrefersRemoteTuneProvider = false
    }
}
