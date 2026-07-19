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

        let baseline = try await baselineProvider.generateTune(for: request)
        let prompt = try promptBuilder.prompt(for: request, baseline: baseline)
        let session = LanguageModelSession(
            model: .default,
            instructions: Self.instructions
        )
        session.prewarm()

        let options = GenerationOptions(
            samplingMode: .greedy,
            temperature: nil,
            maximumResponseTokens: 1_200
        )
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
            .withProviderInfo(.direct(.onDeviceFoundationModel))
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
        .withProviderInfo(.direct(.onDeviceFoundationModel))
    }

    func adjustTune(previous tune: TuneResult, adjustment: TuneAdjustment) async throws -> TuneAdjustmentResult {
        var result = try await baselineProvider.adjustTune(previous: tune, adjustment: adjustment)
        result.tune = result.tune.withProviderInfo(.fallback(
            requestedMode: .onDeviceFoundationModel,
            reason: .onDeviceAdjustmentUsesFormula
        ))
        return result
    }
}

private extension FoundationModelTuneProvider {
    static let instructions = """
    You are ForzAdvisor's private on-device FH6 tuner. Produce structured tune data only.
    Treat supplied baseline numbers as formula-backed source data. Make small, coherent refinements.
    Keep values valid for Forza Horizon 6 and keep note strings concise.
    """
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
