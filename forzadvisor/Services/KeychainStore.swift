//
//  KeychainStore.swift
//  forzadvisor
//
//  Small Keychain wrapper for optional BYO API key storage. The app can run
//  without a saved key because local tune generation remains the default path.
//

import Foundation
import Security

protocol APIKeyStoring {
    func readAPIKey() throws -> String?
    func saveAPIKey(_ key: String) throws
    func deleteAPIKey() throws
}

extension APIKeyStoring {
    func apiKeyStatus() -> APIKeyStatus {
        do {
            guard let key = try readAPIKey(),
                  !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                return .missing
            }

            return .configured
        } catch {
            return .readFailed(error.localizedDescription)
        }
    }
}

enum APIKeyStatus: Equatable {
    case configured
    case missing
    case readFailed(String)

    var hasConfiguredKey: Bool {
        self == .configured
    }

    var fallbackReason: TuneProviderFallbackReason? {
        switch self {
        case .configured:
            nil
        case .missing:
            .missingAPIKey
        case .readFailed:
            .apiKeyReadFailed
        }
    }
}

struct KeychainStore {
    var service = "com.michaelwilliams.forzadvisor"
    var account = "anthropic-api-key"

    func readAPIKey() throws -> String? {
        var query = baseQuery()
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnData as String] = true

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainError.unhandledStatus(status) }
        guard let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func saveAPIKey(_ key: String) throws {
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            try deleteAPIKey()
            return
        }

        let data = Data(trimmedKey.utf8)
        var query = baseQuery()
        let attributes = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if status == errSecItemNotFound {
            query[kSecValueData as String] = data
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = SecItemAdd(query as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw KeychainError.unhandledStatus(addStatus) }
        } else if status != errSecSuccess {
            throw KeychainError.unhandledStatus(status)
        }
    }

    func deleteAPIKey() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            throw KeychainError.unhandledStatus(status)
        }
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

enum KeychainError: LocalizedError, Equatable {
    case unhandledStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .unhandledStatus(let status):
            "Keychain returned status \(status)."
        }
    }
}

extension KeychainStore: APIKeyStoring {}
