//
//  OnDeviceModelAvailability.swift
//  forzadvisor
//
//  Small availability facade for Apple Foundation Models so provider routing
//  and SettingsView do not depend directly on framework-specific enum cases.
//

import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

enum OnDeviceModelAvailability {
    case available
    case unsupportedOperatingSystem
    case deviceNotEligible
    case appleIntelligenceNotEnabled
    case modelNotReady
    case frameworkUnavailable

    var isAvailable: Bool {
        if case .available = self {
            return true
        }
        return false
    }

    var title: String {
        switch self {
        case .available:
            "Available"
        case .unsupportedOperatingSystem:
            "Requires iOS 26.4"
        case .deviceNotEligible:
            "Device not eligible"
        case .appleIntelligenceNotEnabled:
            "Apple Intelligence off"
        case .modelNotReady:
            "Model not ready"
        case .frameworkUnavailable:
            "Foundation Models unavailable"
        }
    }

    var detail: String {
        switch self {
        case .available:
            "On-device generation can stream private tune output."
        case .unsupportedOperatingSystem:
            "Update to iOS 26.4 or later to use on-device generation."
        case .deviceNotEligible:
            "This device cannot run Apple Intelligence models."
        case .appleIntelligenceNotEnabled:
            "Enable Apple Intelligence in Settings to use on-device generation."
        case .modelNotReady:
            "Apple Intelligence is preparing the local model. Try again later."
        case .frameworkUnavailable:
            "This build cannot import the Foundation Models framework."
        }
    }

    static func current() -> OnDeviceModelAvailability {
        #if canImport(FoundationModels)
        if #available(iOS 26.4, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return .available
            case .unavailable(.deviceNotEligible):
                return .deviceNotEligible
            case .unavailable(.appleIntelligenceNotEnabled):
                return .appleIntelligenceNotEnabled
            case .unavailable(.modelNotReady):
                return .modelNotReady
            @unknown default:
                return .frameworkUnavailable
            }
        }
        return .unsupportedOperatingSystem
        #else
        return .frameworkUnavailable
        #endif
    }
}

protocol OnDeviceTuneProviding: TuneProvider {
    var availability: OnDeviceModelAvailability { get }
}
