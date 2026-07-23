//
//  TuneProviderMode.swift
//  forzadvisor
//
//  User-selectable tune generation modes shared by SettingsView,
//  ContentView, and CompositeTuneProvider.
//

import Foundation

enum TuneProviderMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case offlineFormula
    case onDeviceFoundationModel
    case anthropicAPI

    var id: String { rawValue }

    var title: String {
        switch self {
        case .offlineFormula: "Offline"
        case .onDeviceFoundationModel: "On Device"
        case .anthropicAPI: "API"
        }
    }

    var detail: String {
        switch self {
        case .offlineFormula:
            "Uses deterministic local formulas for FH6. FH5 uses the local plan-only build planner."
        case .onDeviceFoundationModel:
            "Uses Apple Intelligence for FH6 with formula fallback. FH5 remains local and plan-only."
        case .anthropicAPI:
            "Uses the saved Anthropic key for FH6 with formula fallback. FH5 remains local and plan-only."
        }
    }

    var resultTitle: String {
        switch self {
        case .offlineFormula: "Offline formulas"
        case .onDeviceFoundationModel: "On-device model"
        case .anthropicAPI: "Anthropic API"
        }
    }

    var resultDetail: String {
        switch self {
        case .offlineFormula:
            "Generated entirely on this device with deterministic formulas."
        case .onDeviceFoundationModel:
            "Generated on this device with Apple Intelligence."
        case .anthropicAPI:
            "Generated with the configured Anthropic API key."
        }
    }

    var resultSymbolName: String {
        switch self {
        case .offlineFormula: "function"
        case .onDeviceFoundationModel: "apple.intelligence"
        case .anthropicAPI: "cloud"
        }
    }
}
