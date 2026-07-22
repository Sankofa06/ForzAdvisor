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

    func testOnDevicePromptUsesSelectedGame() async throws {
        let baselineRequest = TuneRequest(car: SampleTuningData.starterCar, discipline: .road)
        let baseline = try await LocalSampleTuneProvider().generateTune(for: baselineRequest)
        var fh5Car = SampleTuningData.starterCar
        fh5Car.game = .fh5
        fh5Car.performanceClass = .a
        let request = TuneRequest(car: fh5Car, discipline: .road)

        let prompt = try OnDeviceTunePromptBuilder().prompt(for: request, baseline: baseline)

        XCTAssertTrue(prompt.contains("Forza Horizon 5"))
        XCTAssertTrue(prompt.contains("FH5 ranges"))
        XCTAssertFalse(prompt.contains("Forza Horizon 6"))
        XCTAssertFalse(prompt.contains("FH6 ranges"))
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
        XCTAssertEqual(tune.providerInfo?.requestedMode, .onDeviceFoundationModel)
        XCTAssertEqual(tune.providerInfo?.actualMode, .offlineFormula)
        XCTAssertEqual(tune.providerInfo?.fallbackReason, .onDeviceUnavailable)
    }

    func testCompositeProviderFallsBackForAdjustmentWhenOnDeviceModelUnavailable() async throws {
        let request = TuneRequest(car: SampleTuningData.starterCar, discipline: .road)
        let previous = try await LocalSampleTuneProvider().generateTune(for: request)
        let provider = CompositeTuneProvider(
            configuration: TuneProviderConfiguration(mode: .onDeviceFoundationModel),
            remoteProvider: TuneAPIClient(keychainStore: KeychainStore(service: "forzadvisor-tests-\(UUID().uuidString)")),
            onDeviceProvider: PromptTestUnavailableOnDeviceProvider(),
            localProvider: LocalSampleTuneProvider()
        )

        let result = try await provider.adjustTune(previous: previous, adjustment: .moreStability)

        XCTAssertEqual(result.tune.request, request)
        XCTAssertFalse(result.changes.isEmpty)
        XCTAssertEqual(result.tune.providerInfo?.requestedMode, .onDeviceFoundationModel)
        XCTAssertEqual(result.tune.providerInfo?.actualMode, .offlineFormula)
        XCTAssertEqual(result.tune.providerInfo?.fallbackReason, .onDeviceUnavailable)
        XCTAssertGreaterThan(
            try XCTUnwrap(result.tune.section("Antiroll Bars")?.number("Front")),
            try XCTUnwrap(previous.section("Antiroll Bars")?.number("Front"))
        )
        XCTAssertLessThan(
            try XCTUnwrap(result.tune.section("Antiroll Bars")?.number("Rear")),
            try XCTUnwrap(previous.section("Antiroll Bars")?.number("Rear"))
        )
    }

    func testCompositeProviderDoesNotFallbackWhenOnDeviceGenerationIsCancelled() async {
        let provider = CompositeTuneProvider(
            configuration: TuneProviderConfiguration(mode: .onDeviceFoundationModel),
            remoteProvider: TuneAPIClient(keychainStore: KeychainStore(service: "forzadvisor-tests-\(UUID().uuidString)")),
            onDeviceProvider: CancellingOnDeviceProvider(),
            localProvider: FailingFallbackTuneProvider()
        )

        do {
            _ = try await provider.generateTune(for: TuneRequest(car: SampleTuningData.starterCar, discipline: .road))
            XCTFail("Expected cancellation to be rethrown.")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
    }

    func testCompositeProviderDoesNotFallbackWhenOnDeviceAdjustmentIsCancelled() async throws {
        let request = TuneRequest(car: SampleTuningData.starterCar, discipline: .road)
        let previous = try await LocalSampleTuneProvider().generateTune(for: request)
        let provider = CompositeTuneProvider(
            configuration: TuneProviderConfiguration(mode: .onDeviceFoundationModel),
            remoteProvider: TuneAPIClient(keychainStore: KeychainStore(service: "forzadvisor-tests-\(UUID().uuidString)")),
            onDeviceProvider: CancellingOnDeviceProvider(),
            localProvider: FailingFallbackTuneProvider()
        )

        do {
            _ = try await provider.adjustTune(previous: previous, adjustment: .moreStability)
            XCTFail("Expected cancellation to be rethrown.")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
    }

    func testTuneProviderModeHasStableRawValues() {
        XCTAssertEqual(TuneProviderMode.offlineFormula.rawValue, "offlineFormula")
        XCTAssertEqual(TuneProviderMode.onDeviceFoundationModel.rawValue, "onDeviceFoundationModel")
        XCTAssertEqual(TuneProviderMode.anthropicAPI.rawValue, "anthropicAPI")
    }

    func testUnsupportedOperatingSystemAvailabilityExplainsRequirement() {
        let availability = OnDeviceModelAvailability.unsupportedOperatingSystem

        XCTAssertFalse(availability.isAvailable)
        XCTAssertEqual(availability.title, "Requires iOS 26.4")
        XCTAssertEqual(availability.detail, "Update to iOS 26.4 or later to use on-device generation.")
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

private struct CancellingOnDeviceProvider: OnDeviceTuneProviding {
    var availability: OnDeviceModelAvailability {
        .available
    }

    func generateTune(for request: TuneRequest) async throws -> TuneResult {
        throw CancellationError()
    }

    func generateTune(for request: TuneRequest, onPartial: TuneProgressHandler?) async throws -> TuneResult {
        throw CancellationError()
    }

    func adjustTune(previous tune: TuneResult, adjustment: TuneAdjustment) async throws -> TuneAdjustmentResult {
        throw CancellationError()
    }
}

private struct FailingFallbackTuneProvider: TuneProvider {
    func generateTune(for request: TuneRequest) async throws -> TuneResult {
        throw FallbackCalledError()
    }

    func adjustTune(previous tune: TuneResult, adjustment: TuneAdjustment) async throws -> TuneAdjustmentResult {
        throw FallbackCalledError()
    }

    private struct FallbackCalledError: Error {}
}
