//
//  CompositeTuneProvider.swift
//  forzadvisor
//
//  Chooses between optional remote tune generation and the deterministic local
//  provider. Remote failures fall back so the app never requires a key to work.
//

import Foundation

struct TuneProviderConfiguration: Equatable {
    var prefersRemoteGeneration: Bool

    static let offlineDefault = TuneProviderConfiguration(prefersRemoteGeneration: false)
}

struct CompositeTuneProvider: TuneProvider {
    var configuration: TuneProviderConfiguration
    var remoteProvider: TuneAPIClient
    var localProvider: LocalSampleTuneProvider

    init(
        configuration: TuneProviderConfiguration = .offlineDefault,
        remoteProvider: TuneAPIClient = TuneAPIClient(),
        localProvider: LocalSampleTuneProvider = LocalSampleTuneProvider()
    ) {
        self.configuration = configuration
        self.remoteProvider = remoteProvider
        self.localProvider = localProvider
    }

    func generateTune(for request: TuneRequest) async throws -> TuneResult {
        guard configuration.prefersRemoteGeneration, remoteProvider.hasConfiguredAPIKey() else {
            return try await localProvider.generateTune(for: request)
        }

        do {
            return try await remoteProvider.generateTune(for: request)
        } catch {
            return try await localProvider.generateTune(for: request)
        }
    }

    func adjustTune(previous tune: TuneResult, adjustment: TuneAdjustment) async throws -> TuneAdjustmentResult {
        guard configuration.prefersRemoteGeneration, remoteProvider.hasConfiguredAPIKey() else {
            return try await localProvider.adjustTune(previous: tune, adjustment: adjustment)
        }

        do {
            return try await remoteProvider.adjustTune(previous: tune, adjustment: adjustment)
        } catch {
            return try await localProvider.adjustTune(previous: tune, adjustment: adjustment)
        }
    }
}
