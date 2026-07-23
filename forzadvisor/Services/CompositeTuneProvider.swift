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
        if let fh5Plan = try FH5BuildPlanRouter().route(request) {
            return fh5Plan
        }

        switch configuration.mode {
        case .offlineFormula:
            return try await localProvider.generateTune(for: request, onPartial: onPartial)
                .withProviderInfo(.direct(.offlineFormula))
        case .onDeviceFoundationModel:
            guard onDeviceProvider.availability.isAvailable else {
                return try await fallbackTune(
                    for: request,
                    requestedMode: .onDeviceFoundationModel,
                    reason: .onDeviceUnavailable,
                    onPartial: onPartial
                )
            }

            do {
                let annotatedPartial = partialHandler(
                    requestedMode: .onDeviceFoundationModel,
                    actualMode: .onDeviceFoundationModel,
                    onPartial: onPartial
                )
                return try await onDeviceProvider.generateTune(for: request, onPartial: annotatedPartial)
                    .withProviderInfo(.direct(.onDeviceFoundationModel))
            } catch {
                try Self.rethrowIfCancelled(error)
                return try await fallbackTune(
                    for: request,
                    requestedMode: .onDeviceFoundationModel,
                    reason: .providerError,
                    onPartial: onPartial
                )
            }
        case .anthropicAPI:
            let apiKeyStatus = remoteProvider.apiKeyStatus()
            guard apiKeyStatus.hasConfiguredKey else {
                return try await fallbackTune(
                    for: request,
                    requestedMode: .anthropicAPI,
                    reason: apiKeyStatus.fallbackReason ?? .providerError,
                    onPartial: onPartial
                )
            }

            do {
                return try await remoteProvider.generateTune(for: request, onPartial: onPartial)
                    .withProviderInfo(.direct(.anthropicAPI))
            } catch {
                try Self.rethrowIfCancelled(error)
                return try await fallbackTune(
                    for: request,
                    requestedMode: .anthropicAPI,
                    reason: .providerError,
                    onPartial: onPartial
                )
            }
        }
    }

    func adjustTune(previous tune: TuneResult, adjustment: TuneAdjustment) async throws -> TuneAdjustmentResult {
        guard tune.request.car.game != .fh5,
              tune.purpose != .fh5BuildPlan else {
            throw LocalTuneProviderError.unsupportedRuleset(.fh5)
        }

        switch configuration.mode {
        case .offlineFormula:
            var result = try await localProvider.adjustTune(previous: tune, adjustment: adjustment)
            result.tune = result.tune.withProviderInfo(.direct(.offlineFormula))
            return result
        case .onDeviceFoundationModel:
            guard onDeviceProvider.availability.isAvailable else {
                return try await fallbackAdjustment(
                    previous: tune,
                    adjustment: adjustment,
                    requestedMode: .onDeviceFoundationModel,
                    reason: .onDeviceUnavailable
                )
            }

            do {
                var result = try await onDeviceProvider.adjustTune(previous: tune, adjustment: adjustment)
                if result.tune.providerInfo == nil {
                    result.tune = result.tune.withProviderInfo(.direct(.onDeviceFoundationModel))
                }
                return result
            } catch {
                try Self.rethrowIfCancelled(error)
                return try await fallbackAdjustment(
                    previous: tune,
                    adjustment: adjustment,
                    requestedMode: .onDeviceFoundationModel,
                    reason: .providerError
                )
            }
        case .anthropicAPI:
            let apiKeyStatus = remoteProvider.apiKeyStatus()
            guard apiKeyStatus.hasConfiguredKey else {
                return try await fallbackAdjustment(
                    previous: tune,
                    adjustment: adjustment,
                    requestedMode: .anthropicAPI,
                    reason: apiKeyStatus.fallbackReason ?? .providerError
                )
            }

            do {
                var result = try await remoteProvider.adjustTune(previous: tune, adjustment: adjustment)
                result.tune = result.tune.withProviderInfo(.direct(.anthropicAPI))
                return result
            } catch {
                try Self.rethrowIfCancelled(error)
                return try await fallbackAdjustment(
                    previous: tune,
                    adjustment: adjustment,
                    requestedMode: .anthropicAPI,
                    reason: .providerError
                )
            }
        }
    }

    private func fallbackTune(
        for request: TuneRequest,
        requestedMode: TuneProviderMode,
        reason: TuneProviderFallbackReason,
        onPartial: TuneProgressHandler?
    ) async throws -> TuneResult {
        let info = TuneProviderInfo.fallback(requestedMode: requestedMode, reason: reason)
        let annotatedPartial = partialHandler(providerInfo: info, onPartial: onPartial)
        return try await localProvider.generateTune(for: request, onPartial: annotatedPartial)
            .withProviderInfo(info)
    }

    private func fallbackAdjustment(
        previous tune: TuneResult,
        adjustment: TuneAdjustment,
        requestedMode: TuneProviderMode,
        reason: TuneProviderFallbackReason
    ) async throws -> TuneAdjustmentResult {
        var result = try await localProvider.adjustTune(previous: tune, adjustment: adjustment)
        result.tune = result.tune.withProviderInfo(.fallback(
            requestedMode: requestedMode,
            reason: reason
        ))
        return result
    }

    private func partialHandler(
        requestedMode: TuneProviderMode,
        actualMode: TuneProviderMode,
        onPartial: TuneProgressHandler?
    ) -> TuneProgressHandler? {
        partialHandler(
            providerInfo: TuneProviderInfo(
                requestedMode: requestedMode,
                actualMode: actualMode,
                fallbackReason: nil
            ),
            onPartial: onPartial
        )
    }

    private func partialHandler(
        providerInfo: TuneProviderInfo,
        onPartial: TuneProgressHandler?
    ) -> TuneProgressHandler? {
        guard let onPartial else { return nil }
        return { partialTune in
            onPartial(partialTune.withProviderInfo(providerInfo))
        }
    }

    private static func rethrowIfCancelled(_ error: Error) throws {
        if error is CancellationError {
            throw error
        }

        if let urlError = error as? URLError, urlError.code == .cancelled {
            throw CancellationError()
        }

        if Task.isCancelled {
            throw CancellationError()
        }
    }
}

struct FH5BuildPlanRouter {
    func route(_ request: TuneRequest) throws -> TuneResult? {
        guard request.car.game == .fh5 else { return nil }
        guard request.car.catalogReference != nil,
              !request.car.catalogValuesModified,
              let snapshot = request.buildSnapshot,
              snapshot.kind == .capabilityOnly,
              snapshot.isValid,
              snapshot.matches(car: request.car),
              snapshot.car.catalogReference == request.car.catalogReference,
              !snapshot.car.catalogValuesModified else {
            throw LocalTuneProviderError.unsupportedRuleset(.fh5)
        }

        return TuneResult(
            request: request,
            sections: [],
            notes: TuneNotes(
                bias: "",
                ifPushesWide: "",
                ifSnapsOnLift: "",
                retuneTrigger: ""
            ),
            purpose: .fh5BuildPlan,
            providerInfo: nil,
            rulesetReference: nil
        )
    }
}
