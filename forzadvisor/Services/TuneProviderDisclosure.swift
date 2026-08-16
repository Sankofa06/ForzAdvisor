import Foundation

enum TuneProviderCapability: Equatable, Sendable {
    case ready
    case storedOnDeviceNotTested
    case setupRequired(TuneProviderSetupRequirement)
    case unavailable(TuneProviderUnavailabilityReason)

    var supportsPreferredAttempt: Bool {
        switch self {
        case .ready, .storedOnDeviceNotTested:
            true
        case .setupRequired, .unavailable:
            false
        }
    }

    var readinessTitle: String {
        switch self {
        case .ready:
            "Ready"
        case .storedOnDeviceNotTested:
            "Stored on this device - not tested"
        case .setupRequired(.apiKey):
            "API key required"
        case .unavailable(let reason):
            reason.title
        }
    }
}

enum TuneProviderSetupRequirement: Equatable, Sendable {
    case apiKey
}

enum TuneProviderUnavailabilityReason: Equatable, Sendable {
    case unsupportedOperatingSystem
    case deviceNotEligible
    case appleIntelligenceNotEnabled
    case modelNotReady
    case frameworkUnavailable
    case credentialStatusUnavailable

    var title: String {
        switch self {
        case .unsupportedOperatingSystem:
            "Requires a newer iOS version"
        case .deviceNotEligible:
            "Device not eligible"
        case .appleIntelligenceNotEnabled:
            "Apple Intelligence off"
        case .modelNotReady:
            "Model not ready"
        case .frameworkUnavailable:
            "On-device model unavailable"
        case .credentialStatusUnavailable:
            "Credential status unavailable"
        }
    }
}

struct TuneProviderCapabilities: Equatable, Sendable {
    var onDeviceModel: TuneProviderCapability
    var anthropicAPI: TuneProviderCapability

    func capability(for mode: TuneProviderMode) -> TuneProviderCapability {
        switch mode {
        case .offlineFormula:
            .ready
        case .onDeviceFoundationModel:
            onDeviceModel
        case .anthropicAPI:
            anthropicAPI
        }
    }
}

struct TuneProviderRouteExpectation: Equatable, Sendable {
    let preferredMode: TuneProviderMode
    let expectedFirstMode: TuneProviderMode
    let fallbackMode: TuneProviderMode?
    let preferredModeWillBeAttempted: Bool
}

enum TuneProviderDataBoundary: Equatable, Sendable {
    case localOnly
    case remoteGeneration

    var summary: String {
        switch self {
        case .localOnly:
            "Generation and refinement stay on this device."
        case .remoteGeneration:
            "A remote generation attempt sends confirmed car facts and discipline. A remote refinement attempt sends the prior generated tune and the selected adjustment. Screenshots and API keys are never included."
        }
    }
}

struct TuneProviderDisclosure: Equatable, Sendable {
    let preferredMode: TuneProviderMode
    let readiness: TuneProviderCapability
    let route: TuneProviderRouteExpectation
    let dataBoundary: TuneProviderDataBoundary

    init(
        preferredMode: TuneProviderMode,
        capabilities: TuneProviderCapabilities
    ) {
        let readiness = capabilities.capability(for: preferredMode)
        let canAttemptPreference = readiness.supportsPreferredAttempt

        self.preferredMode = preferredMode
        self.readiness = readiness
        self.route = TuneProviderRouteExpectation(
            preferredMode: preferredMode,
            expectedFirstMode: canAttemptPreference
                ? preferredMode
                : .offlineFormula,
            fallbackMode: preferredMode == .offlineFormula
                ? nil
                : .offlineFormula,
            preferredModeWillBeAttempted: canAttemptPreference
        )
        self.dataBoundary = preferredMode == .anthropicAPI
            && canAttemptPreference
            ? .remoteGeneration
            : .localOnly
    }
}

extension TuneProviderInfo {
    var actualProviderMode: TuneProviderMode { actualMode }
}
