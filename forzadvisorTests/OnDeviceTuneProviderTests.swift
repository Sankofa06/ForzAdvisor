//
//  OnDeviceTuneProviderTests.swift
//  forzadvisorTests
//
//  Coverage for compact on-device prompts and provider fallback behavior.
//

import XCTest
@testable import forzadvisor

final class OnDeviceTuneProviderTests: XCTestCase {
    func testOnDevicePromptStaysCompactAndExcludesLongContext() async throws {
        let request = TuneRequest(car: SampleTuningData.starterCar, discipline: .touge)
        let baseline = try await LocalSampleTuneProvider().generateTune(for: request)

        let prompt = try OnDeviceTunePromptBuilder().prompt(for: request, baseline: baseline)

        XCTAssertLessThan(prompt.count, OnDeviceTunePromptBuilder.maximumPromptCharacters)
        XCTAssertLessThan(prompt.count, 1_700)
        XCTAssertTrue(prompt.contains("wt=3340"))
        XCTAssertTrue(prompt.contains("pi=S1750"))
        XCTAssertTrue(prompt.contains("mode=touge"))
        XCTAssertFalse(prompt.localizedCaseInsensitiveContains("screenshot"))
        XCTAssertFalse(prompt.localizedCaseInsensitiveContains("OCR"))
        XCTAssertFalse(prompt.localizedCaseInsensitiveContains("SKILL"))
    }

    func testCompositeProviderFallsBackWhenOnDeviceModelUnavailable() async throws {
        let provider = CompositeTuneProvider(
            configuration: TuneProviderConfiguration(mode: .onDeviceFoundationModel),
            remoteProvider: TuneAPIClient(keychainStore: KeychainStore(service: "forzadvisor-tests-\(UUID().uuidString)")),
            onDeviceProvider: PromptTestUnavailableOnDeviceProvider(),
            localProvider: LocalSampleTuneProvider()
        )
        let request = TuneRequest(car: SampleTuningData.starterCar, discipline: .road)

        let tune = try await provider.generateTune(for: request)

        XCTAssertEqual(tune.request, request)
        XCTAssertEqual(tune.sections.map(\.title).first, "Tires")
        XCTAssertFalse(tune.sections.isEmpty)
    }

    func testTuneProviderModeHasStableRawValues() {
        XCTAssertEqual(TuneProviderMode.offlineFormula.rawValue, "offlineFormula")
        XCTAssertEqual(TuneProviderMode.onDeviceFoundationModel.rawValue, "onDeviceFoundationModel")
        XCTAssertEqual(TuneProviderMode.anthropicAPI.rawValue, "anthropicAPI")
    }
}

private struct PromptTestUnavailableOnDeviceProvider: OnDeviceTuneProviding {
    var availability: OnDeviceModelAvailability {
        .modelNotReady
    }

    func generateTune(for request: TuneRequest) async throws -> TuneResult {
        throw OnDeviceTuneError.unavailable(.modelNotReady)
    }

    func generateTune(for request: TuneRequest, onPartial: TuneProgressHandler?) async throws -> TuneResult {
        throw OnDeviceTuneError.unavailable(.modelNotReady)
    }

    func adjustTune(previous tune: TuneResult, adjustment: TuneAdjustment) async throws -> TuneAdjustmentResult {
        throw OnDeviceTuneError.unavailable(.modelNotReady)
    }
}
