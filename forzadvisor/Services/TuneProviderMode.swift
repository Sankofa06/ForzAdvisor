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
            "Uses deterministic local formulas. Fastest and always available."
        case .onDeviceFoundationModel:
            "Uses Apple Intelligence on this device with formula fallback."
        case .anthropicAPI:
            "Uses the saved Anthropic key with formula fallback."
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
