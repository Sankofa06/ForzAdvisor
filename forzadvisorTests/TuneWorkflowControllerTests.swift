//
//  TuneWorkflowControllerTests.swift
//  forzadvisorTests
//
//  Unit coverage for tune workflow task coordination without UI automation.
//

import XCTest
@testable import forzadvisor

@MainActor
final class TuneWorkflowControllerTests: XCTestCase {
    func testLatestGenerationWinsWhenEarlierGenerationCompletesLate() async {
        let provider = QueuedTuneProvider()
        let controller = TuneWorkflowController()
        let firstRequest = request(.road)
        let secondRequest = request(.drag)
        var deliveredTunes: [TuneResult] = []
        var failures: [Error] = []

        controller.generateTune(
            for: firstRequest,
            provider: provider,
            onPartial: { _ in },
            onSuccess: { deliveredTunes.append($0) },
            onFailure: { failures.append($0) }
        )
        await waitUntil(provider.generationCount == 1)

        controller.generateTune(
            for: secondRequest,
            provider: provider,
            onPartial: { _ in },
            onSuccess: { deliveredTunes.append($0) },
            onFailure: { failures.append($0) }
        )
        await waitUntil(provider.generationCount == 2)

        provider.completeGeneration(at: 0, with: tune(for: firstRequest))
        await settleMainActorWork()
        XCTAssertTrue(deliveredTunes.isEmpty)
        XCTAssertTrue(failures.isEmpty)
        XCTAssertTrue(controller.isGenerating)

        provider.completeGeneration(at: 1, with: tune(for: secondRequest))
        await waitUntil(deliveredTunes.count == 1)

        XCTAssertEqual(deliveredTunes.first?.request, secondRequest)
        XCTAssertTrue(failures.isEmpty)
        XCTAssertFalse(controller.isGenerating)
    }

    func testStaleGenerationPartialIsIgnored() async {
        let provider = QueuedTuneProvider()
        let controller = TuneWorkflowController()
        let firstRequest = request(.road)
        let secondRequest = request(.touge)
        var partials: [TuneResult] = []

        controller.generateTune(
            for: firstRequest,
            provider: provider,
            onPartial: { partials.append($0) },
            onSuccess: { _ in },
            onFailure: { _ in }
        )
        await waitUntil(provider.generationCount == 1)

        controller.generateTune(
            for: secondRequest,
            provider: provider,
            onPartial: { partials.append($0) },
            onSuccess: { _ in },
            onFailure: { _ in }
        )
        await waitUntil(provider.generationCount == 2)

        provider.emitGenerationPartial(at: 0, tune: tune(for: firstRequest))
        await settleMainActorWork()
        XCTAssertTrue(partials.isEmpty)

        provider.emitGenerationPartial(at: 1, tune: tune(for: secondRequest))
        await waitUntil(partials.count == 1)
        XCTAssertEqual(partials.first?.request, secondRequest)

        provider.completeGeneration(at: 0, with: tune(for: firstRequest))
        provider.completeGeneration(at: 1, with: tune(for: secondRequest))
    }

    func testCancelGenerationSuppressesDelayedSuccessAndFailure() async {
        let provider = QueuedTuneProvider()
        let controller = TuneWorkflowController()
        var deliveredTunes: [TuneResult] = []
        var failures: [Error] = []

        controller.generateTune(
            for: request(.road),
            provider: provider,
            onPartial: { _ in },
            onSuccess: { deliveredTunes.append($0) },
            onFailure: { failures.append($0) }
        )
        await waitUntil(provider.generationCount == 1)

        controller.cancelGeneration()
        provider.completeGeneration(at: 0, with: tune(for: request(.road)))
        await settleMainActorWork()

        XCTAssertTrue(deliveredTunes.isEmpty)
        XCTAssertTrue(failures.isEmpty)
        XCTAssertFalse(controller.isGenerating)

        controller.generateTune(
            for: request(.drag),
            provider: provider,
            onPartial: { _ in },
            onSuccess: { deliveredTunes.append($0) },
            onFailure: { failures.append($0) }
        )
        await waitUntil(provider.generationCount == 2)

        controller.cancelGeneration()
        provider.failGeneration(at: 1, with: TestWorkflowError())
        await settleMainActorWork()

        XCTAssertTrue(deliveredTunes.isEmpty)
        XCTAssertTrue(failures.isEmpty)
        XCTAssertFalse(controller.isGenerating)
    }

    func testLatestAdjustmentWinsWhenEarlierAdjustmentCompletesLate() async {
        let provider = QueuedTuneProvider()
        let controller = TuneWorkflowController()
        let savedTuneID = UUID()
        let baseline = tune(for: request(.road))
        var deliveredResults: [TuneAdjustmentResult] = []
        var failures: [Error] = []

        controller.adjustTune(
            previous: baseline,
            savedTuneID: savedTuneID,
            feedback: .pushesWide,
            provider: provider,
            onSuccess: { deliveredResults.append($0) },
            onFailure: { failures.append($0) }
        )
        await waitUntil(provider.adjustmentCount == 1)

        controller.adjustTune(
            previous: baseline,
            savedTuneID: savedTuneID,
            feedback: .needsMorePull,
            provider: provider,
            onSuccess: { deliveredResults.append($0) },
            onFailure: { failures.append($0) }
        )
        await waitUntil(provider.adjustmentCount == 2)

        provider.completeAdjustment(
            at: 0,
            with: adjustmentResult(for: baseline, adjustment: .moreRotation)
        )
        await settleMainActorWork()
        XCTAssertTrue(deliveredResults.isEmpty)
        XCTAssertTrue(failures.isEmpty)
        XCTAssertEqual(controller.activeFeedback(for: savedTuneID), .needsMorePull)

        provider.completeAdjustment(
            at: 1,
            with: adjustmentResult(for: baseline, adjustment: .moreAcceleration)
        )
        await waitUntil(deliveredResults.count == 1)

        XCTAssertEqual(deliveredResults.first?.changes.first?.rationale, TuneFeedback.needsMorePull.rationale)
        XCTAssertTrue(failures.isEmpty)
        XCTAssertFalse(controller.isAdjusting)
        XCTAssertNil(controller.activeFeedback(for: savedTuneID))
    }

    func testCancelAdjustmentSuppressesDelayedFailure() async {
        let provider = QueuedTuneProvider()
        let controller = TuneWorkflowController()
        let savedTuneID = UUID()
        var deliveredResults: [TuneAdjustmentResult] = []
        var failures: [Error] = []

        controller.adjustTune(
            previous: tune(for: request(.road)),
            savedTuneID: savedTuneID,
            feedback: .pushesWide,
            provider: provider,
            onSuccess: { deliveredResults.append($0) },
            onFailure: { failures.append($0) }
        )
        await waitUntil(provider.adjustmentCount == 1)

        controller.cancelAdjustment()
        provider.failAdjustment(at: 0, with: TestWorkflowError())
        await settleMainActorWork()

        XCTAssertTrue(deliveredResults.isEmpty)
        XCTAssertTrue(failures.isEmpty)
        XCTAssertFalse(controller.isAdjusting)
        XCTAssertNil(controller.activeFeedback(for: savedTuneID))
    }

    private func request(_ discipline: DrivingDiscipline) -> TuneRequest {
        TuneRequest(car: SampleTuningData.starterCar, discipline: discipline)
    }

    private func tune(for request: TuneRequest) -> TuneResult {
        TuneResult(
            request: request,
            sections: [
                TuneSection(
                    title: "Gearing",
                    symbolName: "gearshape.2",
                    lines: [TuneLine(label: "Final drive", value: "3.50", unit: "")]
                )
            ],
            notes: TuneNotes(
                bias: "Baseline.",
                ifPushesWide: "Add rotation.",
                ifSnapsOnLift: "Add stability.",
                retuneTrigger: "Retune after major changes."
            )
        )
    }

    private func adjustmentResult(
        for tune: TuneResult,
        adjustment: TuneAdjustment
    ) -> TuneAdjustmentResult {
        var adjustedTune = tune
        adjustedTune.notes.bias = adjustment.title
        return TuneAdjustmentResult(
            tune: adjustedTune,
            changes: [
                TuneAdjustmentChange(
                    sectionTitle: "Gearing",
                    lineLabel: "Final drive",
                    oldValue: "3.50",
                    newValue: "3.65",
                    unit: ""
                )
            ]
        )
    }

    private func waitUntil(
        _ condition: @autoclosure @escaping @MainActor () async -> Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        for _ in 0..<100 {
            if await condition() { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Timed out waiting for condition.", file: file, line: line)
    }

    private func settleMainActorWork() async {
        try? await Task.sleep(for: .milliseconds(30))
    }
}

@MainActor
private final class QueuedTuneProvider: TuneProvider {
    private struct GenerationCall {
        var request: TuneRequest
        var onPartial: TuneProgressHandler?
        var continuation: CheckedContinuation<TuneResult, Error>
    }

    private struct AdjustmentCall {
        var tune: TuneResult
        var adjustment: TuneAdjustment
        var continuation: CheckedContinuation<TuneAdjustmentResult, Error>
    }

    private var generationCalls: [GenerationCall] = []
    private var adjustmentCalls: [AdjustmentCall] = []

    var generationCount: Int {
        generationCalls.count
    }

    var adjustmentCount: Int {
        adjustmentCalls.count
    }

    func generateTune(for request: TuneRequest) async throws -> TuneResult {
        try await generateTune(for: request, onPartial: nil)
    }

    func generateTune(for request: TuneRequest, onPartial: TuneProgressHandler?) async throws -> TuneResult {
        try await withCheckedThrowingContinuation { continuation in
            generationCalls.append(GenerationCall(
                request: request,
                onPartial: onPartial,
                continuation: continuation
            ))
        }
    }

    func adjustTune(previous tune: TuneResult, adjustment: TuneAdjustment) async throws -> TuneAdjustmentResult {
        try await withCheckedThrowingContinuation { continuation in
            adjustmentCalls.append(AdjustmentCall(
                tune: tune,
                adjustment: adjustment,
                continuation: continuation
            ))
        }
    }

    func emitGenerationPartial(at index: Int, tune: TuneResult) {
        generationCalls[index].onPartial?(tune)
    }

    func completeGeneration(at index: Int, with tune: TuneResult) {
        generationCalls[index].continuation.resume(returning: tune)
    }

    func failGeneration(at index: Int, with error: Error) {
        generationCalls[index].continuation.resume(throwing: error)
    }

    func completeAdjustment(at index: Int, with result: TuneAdjustmentResult) {
        adjustmentCalls[index].continuation.resume(returning: result)
    }

    func failAdjustment(at index: Int, with error: Error) {
        adjustmentCalls[index].continuation.resume(throwing: error)
    }
}

private struct TestWorkflowError: Error {}
