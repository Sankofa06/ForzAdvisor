//
//  CompositeTuneProvider.swift
//  forzadvisor
//
//  Chooses between offline formulas, optional on-device Foundation Models, and
//  optional remote generation. All non-offline paths fall back to formulas.
//

import Foundation

struct TuneProviderConfiguration: Equatable {
    var mode: TuneProviderMode

    static let offlineDefault = TuneProviderConfiguration(mode: .offlineFormula)
}

struct CompositeTuneProvider: TuneProvider {
    var configuration: TuneProviderConfiguration
    var remoteProvider: TuneAPIClient
    var onDeviceProvider: any OnDeviceTuneProviding
    var localProvider: any TuneProvider

    init(
        configuration: TuneProviderConfiguration = .offlineDefault,
        remoteProvider: TuneAPIClient = TuneAPIClient(),
        onDeviceProvider: any OnDeviceTuneProviding = FoundationModelTuneProvider(),
        localProvider: any TuneProvider = LocalSampleTuneProvider()
    ) {
        self.configuration = configuration
        self.remoteProvider = remoteProvider
        self.onDeviceProvider = onDeviceProvider
        self.localProvider = localProvider
    }

    func generateTune(for request: TuneRequest) async throws -> TuneResult {
        try await generateTune(for: request, onPartial: nil)
    }

    func generateTune(for request: TuneRequest, onPartial: TuneProgressHandler?) async throws -> TuneResult {
        switch configuration.mode {
        case .offlineFormula:
            return try await localProvider.generateTune(for: request, onPartial: onPartial)
        case .onDeviceFoundationModel:
            guard onDeviceProvider.availability.isAvailable else {
                return try await localProvider.generateTune(for: request, onPartial: onPartial)
            }

            do {
                return try await onDeviceProvider.generateTune(for: request, onPartial: onPartial)
            } catch {
                return try await localProvider.generateTune(for: request, onPartial: onPartial)
            }
        case .anthropicAPI:
            guard remoteProvider.hasConfiguredAPIKey() else {
                return try await localProvider.generateTune(for: request, onPartial: onPartial)
            }

            do {
                return try await remoteProvider.generateTune(for: request, onPartial: onPartial)
            } catch {
                return try await localProvider.generateTune(for: request, onPartial: onPartial)
            }
        }
    }

    func adjustTune(previous tune: TuneResult, adjustment: TuneAdjustment) async throws -> TuneAdjustmentResult {
        switch configuration.mode {
        case .offlineFormula:
            return try await localProvider.adjustTune(previous: tune, adjustment: adjustment)
        case .onDeviceFoundationModel:
            guard onDeviceProvider.availability.isAvailable else {
                return try await localProvider.adjustTune(previous: tune, adjustment: adjustment)
            }

            do {
                return try await onDeviceProvider.adjustTune(previous: tune, adjustment: adjustment)
            } catch {
                return try await localProvider.adjustTune(previous: tune, adjustment: adjustment)
            }
        case .anthropicAPI:
            guard remoteProvider.hasConfiguredAPIKey() else {
                return try await localProvider.adjustTune(previous: tune, adjustment: adjustment)
            }

            do {
                return try await remoteProvider.adjustTune(previous: tune, adjustment: adjustment)
            } catch {
                return try await localProvider.adjustTune(previous: tune, adjustment: adjustment)
            }
        }
    }
}
