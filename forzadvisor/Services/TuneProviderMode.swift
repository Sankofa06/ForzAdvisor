//
//  TuneProviderMode.swift
//  forzadvisor
//
//  User-selectable tune generation modes shared by SettingsView,
//  ContentView, and CompositeTuneProvider.
//

import Foundation

enum TuneProviderMode: String, CaseIterable, Codable, Identifiable {
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
}
