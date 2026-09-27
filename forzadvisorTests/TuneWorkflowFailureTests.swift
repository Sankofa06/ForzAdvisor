import Combine
import XCTest
@testable import forzadvisor

@MainActor
final class TuneWorkflowFailureTests: XCTestCase {
    func testGenerationFailureReturnsExactSessionAfterClearingBusyState() async {
        let controller = TuneWorkflowController()
        let session = makeSession(.dirt)
        let failed = expectation(description: "Provider failure delivered")

        controller.generateTune(
            session: session,
            provider: ImmediateWorkflowProvider(error: URLError(.timedOut)),
            onPartial: { _ in XCTFail("Failed generation delivered a partial") },
            onSuccess: { _ in XCTFail("Failed generation succeeded") },
            onFailure: { recoveredSession, error in
                XCTAssertEqual(recoveredSession, session)
                XCTAssertEqual((error as? URLError)?.code, .timedOut)
                XCTAssertFalse(controller.isGenerating)
                XCTAssertNil(controller.activeGenerationSession)
                failed.fulfill()
            }
        )

        XCTAssertTrue(controller.isGenerating)
        XCTAssertEqual(controller.activeGenerationSession, session)
        await fulfillment(of: [failed], timeout: 2)
    }

    func testGenerationSaveFailureIsDeliveredOnceAndAllowsRetry() async {
        let controller = TuneWorkflowController()
        let session = makeSession(.road)
        let retried = expectation(description: "Retry succeeds after save failure")
        var saveAttempts = 0
        var failures = 0

        controller.generateTune(
            session: session,
            provider: ImmediateWorkflowProvider(),
            onPartial: { _ in },
            onSuccess: { _ in
                saveAttempts += 1
                throw WorkflowFailure.save
            },
            onFailure: { recoveredSession, error in
                failures += 1
                XCTAssertEqual(error as? WorkflowFailure, .save)
                XCTAssertEqual(recoveredSession, session)
                XCTAssertFalse(controller.isGenerating)
                XCTAssertNil(controller.activeGenerationSession)
                controller.generateTune(
                    session: recoveredSession,
                    provider: ImmediateWorkflowProvider(),
                    onPartial: { _ in },
                    onSuccess: { tune in
                        XCTAssertEqual(tune.request, session.request)
                        retried.fulfill()
                    },
                    onFailure: { _, _ in XCTFail("Retry failed") }
                )
            }
        )

        await fulfillment(of: [retried], timeout: 2)
        XCTAssertEqual(saveAttempts, 1)
        XCTAssertEqual(failures, 1)
        XCTAssertFalse(controller.isGenerating)
        XCTAssertNil(controller.activeGenerationSession)
    }

    func testGenerationCancellationErrorClearsStateWithoutFailure() async {
        await assertSilentCancellation(CancellationError(), adjusting: false)
    }

    func testGenerationURLCancellationClearsStateWithoutFailure() async {
        await assertSilentCancellation(URLError(.cancelled), adjusting: false)
    }

    func testAdjustmentCancellationErrorClearsStateWithoutFailure() async {
        await assertSilentCancellation(CancellationError(), adjusting: true)
    }

    func testAdjustmentURLCancellationClearsStateWithoutFailure() async {
        await assertSilentCancellation(URLError(.cancelled), adjusting: true)
    }

    func testAdjustmentFailureClearsFeedbackBeforeReportingError() async {
        let controller = TuneWorkflowController()
        let baseline = makeTune(makeSession(.road).request)
        let failed = expectation(description: "Adjustment failure delivered")

        controller.adjustTune(
            previous: baseline, savedTuneID: baseline.id, feedback: .pushesWide,
            provider: ImmediateWorkflowProvider(error: URLError(.notConnectedToInternet)),
            onSuccess: { _ in XCTFail("Failed adjustment succeeded") },
            onFailure: { error in
                XCTAssertEqual((error as? URLError)?.code, .notConnectedToInternet)
                XCTAssertFalse(controller.isAdjusting)
                XCTAssertNil(controller.activeFeedback(for: baseline.id))
                failed.fulfill()
            }
        )

        XCTAssertTrue(controller.isAdjusting)
        XCTAssertEqual(controller.activeFeedback(for: baseline.id), .pushesWide)
        await fulfillment(of: [failed], timeout: 2)
    }

    func testAdjustmentSaveFailureClearsFeedbackAndReportsOriginalError() async {
        let controller = TuneWorkflowController()
        let baseline = makeTune(makeSession(.road).request)
        let failed = expectation(description: "Adjustment save failure delivered")
        var saveAttempts = 0

        controller.adjustTune(
            previous: baseline, savedTuneID: baseline.id, feedback: .needsMorePull,
            provider: ImmediateWorkflowProvider(),
            onSuccess: { _ in
                saveAttempts += 1
                throw WorkflowFailure.save
            },
            onFailure: { error in
                XCTAssertEqual(error as? WorkflowFailure, .save)
                XCTAssertFalse(controller.isAdjusting)
                XCTAssertNil(controller.activeFeedback(for: baseline.id))
                failed.fulfill()
            }
        )

        await fulfillment(of: [failed], timeout: 2)
        XCTAssertEqual(saveAttempts, 1)
    }

    func testAdjustmentPreservesProviderRationaleAndFillsOnlyMissingRationale() async throws {
        let controller = TuneWorkflowController()
        let baseline = makeTune(makeSession(.road).request)
        let completed = expectation(description: "Adjustment delivered")
        var delivered: TuneAdjustmentResult?
        let changes = [nil, "Provider-specific explanation"].map { rationale in
            TuneAdjustmentChange(
                sectionTitle: "Gearing", lineLabel: "Final drive",
                oldValue: "3.50", newValue: "3.65", unit: "", rationale: rationale
            )
        }

        controller.adjustTune(
            previous: baseline, savedTuneID: baseline.id, feedback: .needsMorePull,
            provider: ImmediateWorkflowProvider(changes: changes),
            onSuccess: { delivered = $0; completed.fulfill() },
            onFailure: { _ in XCTFail("Adjustment failed") }
        )
        // Removing a different saved tune must not cancel this adjustment.
        controller.cancelAdjustment(for: UUID())
        XCTAssertEqual(controller.activeFeedback(for: baseline.id), .needsMorePull)

        await fulfillment(of: [completed], timeout: 2)
        let result = try XCTUnwrap(delivered)
        var expectedChanges = changes
        expectedChanges[0].rationale = TuneFeedback.needsMorePull.rationale
        XCTAssertEqual(result.changes, expectedChanges)
        XCTAssertEqual(result.tune, baseline)
        XCTAssertFalse(controller.isAdjusting)
        XCTAssertNil(controller.activeFeedback(for: baseline.id))
    }

    func testSuccessCallbackCanStartReplacementWithoutOldCleanupClearingIt() async {
        let controller = TuneWorkflowController()
        let first = makeSession(.road)
        let second = makeSession(.drag)
        let completed = expectation(description: "Replacement request completed")
        var deliveredRequests: [TuneRequest] = []

        controller.generateTune(
            session: first, provider: ImmediateWorkflowProvider(), onPartial: { _ in },
            onSuccess: { tune in
                deliveredRequests.append(tune.request)
                controller.generateTune(
                    session: second,
                    provider: ImmediateWorkflowProvider(onGenerate: { request in
                        // This runs after the first callback and its cleanup return.
                        XCTAssertEqual(request, second.request)
                        XCTAssertTrue(controller.isGenerating)
                        XCTAssertEqual(controller.activeGenerationSession, second)
                    }),
                    onPartial: { _ in },
                    onSuccess: { replacement in
                        deliveredRequests.append(replacement.request)
                        completed.fulfill()
                    },
                    onFailure: { _, _ in XCTFail("Replacement failed") }
                )
            },
            onFailure: { _, _ in XCTFail("Initial request failed") }
        )

        await fulfillment(of: [completed], timeout: 2)
        XCTAssertEqual(deliveredRequests, [first.request, second.request])
        XCTAssertFalse(controller.isGenerating)
        XCTAssertNil(controller.activeGenerationSession)
    }

    private func assertSilentCancellation(_ error: Error, adjusting: Bool) async {
        let controller = TuneWorkflowController()
        let session = makeSession(.road)
        let baseline = makeTune(session.request)
        let provider = ImmediateWorkflowProvider(error: error)
        let finished = expectation(description: "Cancelled provider returns to idle")
        var callbacks = 0

        if adjusting {
            controller.adjustTune(
                previous: baseline, savedTuneID: baseline.id, feedback: .pushesWide,
                provider: provider,
                onSuccess: { _ in callbacks += 1 }, onFailure: { _ in callbacks += 1 }
            )
        } else {
            controller.generateTune(
                session: session, provider: provider,
                onPartial: { _ in callbacks += 1 }, onSuccess: { _ in callbacks += 1 },
                onFailure: { _, _ in callbacks += 1 }
            )
        }

        // Subscribe after starting: the initial busy value is skipped, and the
        // actual idle transition proves the catch path ran. No settling sleep.
        let observation = (adjusting ? controller.$isAdjusting : controller.$isGenerating)
            .dropFirst().filter { !$0 }.prefix(1).sink { _ in finished.fulfill() }
        await fulfillment(of: [finished], timeout: 2)
        withExtendedLifetime(observation) {}
        XCTAssertEqual(callbacks, 0)
        XCTAssertFalse(controller.isGenerating)
        XCTAssertFalse(controller.isAdjusting)
        XCTAssertNil(controller.activeGenerationSession)
        XCTAssertNil(controller.activeFeedback(for: baseline.id))
    }

    private func makeSession(_ discipline: DrivingDiscipline) -> TuneGenerationSession {
        let request = TuneRequest(car: SampleTuningData.starterCar, discipline: discipline)
        let thumbnail = Data("local source photo".utf8)
        return TuneGenerationSession(
            request: request, origin: .manual(request.car), thumbnailData: thumbnail,
            preferredProviderMode: .anthropicAPI,
            providerDisclosure: .init(
                preferredMode: .anthropicAPI,
                capabilities: .init(onDeviceModel: .ready, anthropicAPI: .storedOnDeviceNotTested)
            ),
            returnContext: .newTune(.init(stage: .discipline(
                car: request.car, origin: .manual(request.car),
                thumbnailData: thumbnail, selection: discipline
            )))
        )
    }
}

private enum WorkflowFailure: Error { case save }

@MainActor
private struct ImmediateWorkflowProvider: TuneProvider {
    var error: Error?
    var changes: [TuneAdjustmentChange] = []
    var onGenerate: (TuneRequest) -> Void = { _ in }

    func generateTune(for request: TuneRequest) async throws -> TuneResult {
        onGenerate(request)
        if let error { throw error }
        return makeTune(request)
    }

    func adjustTune(previous tune: TuneResult, adjustment: TuneAdjustment) async throws -> TuneAdjustmentResult {
        if let error { throw error }
        return TuneAdjustmentResult(tune: tune, changes: changes)
    }
}

private func makeTune(_ request: TuneRequest) -> TuneResult {
    TuneResult(
        request: request, sections: [],
        notes: .init(bias: "Baseline", ifPushesWide: "", ifSnapsOnLift: "", retuneTrigger: "")
    )
}
