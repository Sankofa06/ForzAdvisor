//
//  FoundationModelTuneProvider.swift
//  forzadvisor
//
//  Optional Apple Foundation Models tune provider. It streams guided,
//  structured output into TuneResult while using the deterministic local
//  provider as the numeric baseline and adjustment fallback.
//

import Foundation

#if canImport(FoundationModels)
import FoundationModels

struct FoundationModelTuneProvider: OnDeviceTuneProviding {
    var baselineProvider: any TuneProvider = LocalSampleTuneProvider()
    var promptBuilder = OnDeviceTunePromptBuilder()

    var availability: OnDeviceModelAvailability {
        OnDeviceModelAvailability.current()
    }

    func generateTune(for request: TuneRequest) async throws -> TuneResult {
        try await generateTune(for: request, onPartial: nil)
    }

    func generateTune(for request: TuneRequest, onPartial: TuneProgressHandler?) async throws -> TuneResult {
        let currentAvailability = availability
        guard currentAvailability.isAvailable else {
            throw OnDeviceTuneError.unavailable(currentAvailability)
        }
        guard #available(iOS 26.4, *) else {
            throw OnDeviceTuneError.unavailable(.unsupportedOperatingSystem)
        }

        let baseline = try await baselineProvider.generateTune(for: request)
        let prompt = try promptBuilder.prompt(for: request, baseline: baseline)
        let session = LanguageModelSession(
            model: .default,
            instructions: Self.instructions(for: request.car.game)
        )
        session.prewarm()

        #if compiler(>=6.4)
        let options = GenerationOptions(
            samplingMode: .greedy,
            temperature: nil,
            maximumResponseTokens: 1_200
        )
        #else
        let options = GenerationOptions(
            sampling: .greedy,
            temperature: nil,
            maximumResponseTokens: 1_200
        )
        #endif
        let stream = session.streamResponse(
            to: prompt,
            generating: OnDeviceTuneResponse.self,
            includeSchemaInPrompt: true,
            options: options
        )

        var completeResponse: OnDeviceTuneResponse?

        for try await snapshot in stream {
            let partialTune = snapshot.content.tuneResult(
                for: request,
                id: baseline.id,
                generatedAt: baseline.generatedAt
            )
            .withProviderInfo(TuneProviderInfo.direct(.onDeviceFoundationModel))
            onPartial?(partialTune)

            if let complete = try? OnDeviceTuneResponse(snapshot.rawContent) {
                completeResponse = complete
            }
        }

        guard let completeResponse else {
            throw OnDeviceTuneError.noCompleteResponse
        }

        return completeResponse.tuneResult(
            for: request,
            id: baseline.id,
            generatedAt: Date()
        )
        .withProviderInfo(TuneProviderInfo.direct(.onDeviceFoundationModel))
    }

    func adjustTune(previous tune: TuneResult, adjustment: TuneAdjustment) async throws -> TuneAdjustmentResult {
        let currentAvailability = availability
        guard currentAvailability.isAvailable else {
            throw OnDeviceTuneError.unavailable(currentAvailability)
        }

        var result = try await baselineProvider.adjustTune(previous: tune, adjustment: adjustment)
        result.tune = result.tune.withProviderInfo(.fallback(
            requestedMode: .onDeviceFoundationModel,
            reason: .onDeviceAdjustmentUsesFormula
        ))
        return result
    }
}

private extension FoundationModelTuneProvider {
    static func instructions(for game: ForzaGame) -> String {
        """
    You are ForzAdvisor's private on-device \(game.title) tuner. Produce structured tune data only.
    Treat supplied baseline numbers as formula-backed source data. Make small, coherent refinements.
    Keep values valid for \(game.title) and keep note strings concise.
    """
    }
}
#else
struct FoundationModelTuneProvider: OnDeviceTuneProviding {
    var availability: OnDeviceModelAvailability {
        .frameworkUnavailable
    }

    func generateTune(for request: TuneRequest) async throws -> TuneResult {
        throw OnDeviceTuneError.unavailable(.frameworkUnavailable)
    }

    func generateTune(for request: TuneRequest, onPartial: TuneProgressHandler?) async throws -> TuneResult {
        throw OnDeviceTuneError.unavailable(.frameworkUnavailable)
    }

    func adjustTune(previous tune: TuneResult, adjustment: TuneAdjustment) async throws -> TuneAdjustmentResult {
        throw OnDeviceTuneError.unavailable(.frameworkUnavailable)
    }
}
#endif
