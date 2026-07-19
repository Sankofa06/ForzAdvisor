import Foundation

struct TuneProviderInfo: Codable, Equatable, Sendable {
    var requestedMode: TuneProviderMode
    var actualMode: TuneProviderMode
    var fallbackReason: TuneProviderFallbackReason?

    static func direct(_ mode: TuneProviderMode) -> TuneProviderInfo {
        TuneProviderInfo(
            requestedMode: mode,
            actualMode: mode,
            fallbackReason: nil
        )
    }

    static func fallback(
        requestedMode: TuneProviderMode,
        reason: TuneProviderFallbackReason
    ) -> TuneProviderInfo {
        TuneProviderInfo(
            requestedMode: requestedMode,
            actualMode: .offlineFormula,
            fallbackReason: reason
        )
    }

    var statusTitle: String {
        if fallbackReason != nil {
            return "\(actualMode.resultTitle) fallback"
        }
        return actualMode.resultTitle
    }

    var statusDetail: String {
        if let fallbackReason {
            return fallbackReason.detail(requestedMode: requestedMode)
        }
        return actualMode.resultDetail
    }

    var symbolName: String {
        if fallbackReason != nil {
            return "arrow.triangle.2.circlepath"
        }

        return actualMode.resultSymbolName
    }
}

enum TuneProviderFallbackReason: String, Codable, Equatable, Sendable {
    case missingAPIKey
    case apiKeyReadFailed
    case onDeviceUnavailable
    case providerError
    case onDeviceAdjustmentUsesFormula

    func detail(requestedMode: TuneProviderMode) -> String {
        switch self {
        case .missingAPIKey:
            "API key was not configured, so offline formulas generated this tune."
        case .apiKeyReadFailed:
            "The API key could not be read, so offline formulas generated this tune."
        case .onDeviceUnavailable:
            "On-device generation was unavailable, so offline formulas generated this tune."
        case .providerError:
            "\(requestedMode.title) could not finish, so offline formulas generated this tune."
        case .onDeviceAdjustmentUsesFormula:
            "On-device guided refinement uses bounded offline formula adjustments."
        }
    }
}

extension TuneResult {
    func withProviderInfo(_ providerInfo: TuneProviderInfo) -> TuneResult {
        var result = self
        result.providerInfo = providerInfo
        return result
    }
}
