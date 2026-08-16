import Foundation
import Combine

enum APIKeySettingsStatus: Equatable {
    case missing
    case storedOnDeviceNotTested
    case unavailable(String)

    var title: String {
        switch self {
        case .missing:
            "Missing"
        case .storedOnDeviceNotTested:
            "Stored on this device - not tested"
        case .unavailable:
            "Status unavailable"
        }
    }

    var capability: TuneProviderCapability {
        switch self {
        case .missing:
            .setupRequired(.apiKey)
        case .storedOnDeviceNotTested:
            .storedOnDeviceNotTested
        case .unavailable:
            .unavailable(.credentialStatusUnavailable)
        }
    }
}

enum APIKeyCredentialAction: Equatable {
    case replace(String)
    case clear
}

@MainActor
final class APIKeySettingsController: ObservableObject {
    @Published private(set) var status: APIKeySettingsStatus = .missing
    @Published private(set) var pendingAction: APIKeyCredentialAction?
    @Published private(set) var message: String?

    private let store: any APIKeySettingsStoring

    init(store: any APIKeySettingsStoring) {
        self.store = store
    }

    func refresh() {
        do {
            status = try store.containsAPIKey()
                ? .storedOnDeviceNotTested
                : .missing
            message = nil
        } catch {
            status = .unavailable(error.localizedDescription)
            message = "Credential status is unavailable. The stored key was not changed."
        }
    }

    @discardableResult
    func requestSave(_ key: String) -> Bool {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        if status != .missing {
            pendingAction = .replace(trimmed)
            return true
        }
        save(trimmed)
        return false
    }

    func requestClear() {
        pendingAction = .clear
    }

    func cancelPendingAction() {
        pendingAction = nil
    }

    func confirmPendingAction() {
        let action = pendingAction
        pendingAction = nil
        switch action {
        case .replace(let key):
            save(key)
        case .clear:
            clear()
        case nil:
            break
        }
    }

    private func save(_ key: String) {
        let priorStatus = status
        do {
            try store.saveAPIKey(key)
            status = .storedOnDeviceNotTested
            message = "API key stored on this device. It has not been tested."
        } catch {
            status = priorStatus
            message = "Could not store the API key. The prior credential was preserved."
        }
    }

    private func clear() {
        let priorStatus = status
        do {
            try store.deleteAPIKey()
            status = .missing
            message = "API key cleared from this device."
        } catch {
            status = priorStatus
            message = "Could not clear the API key. The prior credential was preserved."
        }
    }
}
