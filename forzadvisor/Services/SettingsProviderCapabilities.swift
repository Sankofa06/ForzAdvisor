import Foundation

extension OnDeviceModelAvailability {
    var tuneProviderCapability: TuneProviderCapability {
        switch self {
        case .available:
            .ready
        case .unsupportedOperatingSystem:
            .unavailable(.unsupportedOperatingSystem)
        case .deviceNotEligible:
            .unavailable(.deviceNotEligible)
        case .appleIntelligenceNotEnabled:
            .unavailable(.appleIntelligenceNotEnabled)
        case .modelNotReady:
            .unavailable(.modelNotReady)
        case .frameworkUnavailable:
            .unavailable(.frameworkUnavailable)
        }
    }
}

struct SettingsProviderCapabilities {
    let onDeviceAvailability: OnDeviceModelAvailability
    let apiKeyStatus: APIKeySettingsStatus

    var value: TuneProviderCapabilities {
        TuneProviderCapabilities(
            onDeviceModel: onDeviceAvailability.tuneProviderCapability,
            anthropicAPI: apiKeyStatus.capability
        )
    }
}
