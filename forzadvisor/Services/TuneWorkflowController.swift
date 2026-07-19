//
//  TuneWorkflowController.swift
//  forzadvisor
//
//  Testable task coordinator for tune generation and guided adjustments.
//

import Combine
import Foundation

typealias TuneGenerationPartialHandler = @MainActor @Sendable (TuneResult) -> Void
typealias TuneGenerationSuccessHandler = @MainActor @Sendable (TuneResult) throws -> Void
typealias TuneWorkflowFailureHandler = @MainActor @Sendable (Error) -> Void
typealias TuneAdjustmentSuccessHandler = @MainActor @Sendable (TuneAdjustmentResult) throws -> Void

@MainActor
final class TuneWorkflowController: ObservableObject {
    @Published private(set) var isGenerating = false
    @Published private(set) var isAdjusting = false

    private var activeGenerationID: UUID?
    private var generationTask: Task<Void, Never>?
    private var activeAdjustment: ActiveTuneAdjustment?
    private var adjustmentTask: Task<Void, Never>?

    func activeFeedback(for savedTuneID: UUID?) -> TuneFeedback? {
        guard activeAdjustment?.savedTuneID == savedTuneID else { return nil }
        return activeAdjustment?.feedback
    }

    func generateTune(
        for request: TuneRequest,
        provider: any TuneProvider,
        onPartial: @escaping TuneGenerationPartialHandler,
        onSuccess: @escaping TuneGenerationSuccessHandler,
        onFailure: @escaping TuneWorkflowFailureHandler
    ) {
        cancelActiveTuneWork()

        let generationID = UUID()
        activeGenerationID = generationID
        isGenerating = true

        generationTask = Task { @MainActor [weak self] in
            guard let self else { return }

            do {
                let tune = try await provider.generateTune(for: request) { partialTune in
                    guard self.isCurrentGeneration(generationID) else { return }
                    onPartial(partialTune)
                }
                try Task.checkCancellation()
                guard self.isCurrentGeneration(generationID) else { return }
                try onSuccess(tune)
                self.finishGeneration(generationID)
            } catch {
                guard self.isCurrentGeneration(generationID) else { return }
                self.finishGeneration(generationID)
                guard !Self.isCancellation(error) else { return }
                onFailure(error)
            }
        }
    }

    func adjustTune(
        previous tune: TuneResult,
        savedTuneID: UUID,
        feedback: TuneFeedback,
        provider: any TuneProvider,
        onSuccess: @escaping TuneAdjustmentSuccessHandler,
        onFailure: @escaping TuneWorkflowFailureHandler
    ) {
        cancelAdjustment()

        let adjustmentID = UUID()
        activeAdjustment = ActiveTuneAdjustment(
            id: adjustmentID,
            savedTuneID: savedTuneID,
            feedback: feedback
        )
        isAdjusting = true

        adjustmentTask = Task { @MainActor [weak self] in
            guard let self else { return }

            do {
                var result = try await provider.adjustTune(previous: tune, adjustment: feedback.adjustment)
                result.changes = result.changes.map { change in
                    var resolvedChange = change
                    if resolvedChange.rationale == nil {
                        resolvedChange.rationale = feedback.rationale
                    }
                    return resolvedChange
                }
                try Task.checkCancellation()
                guard self.isCurrentAdjustment(adjustmentID) else { return }
                try onSuccess(result)
                self.finishAdjustment(adjustmentID)
            } catch {
                guard self.isCurrentAdjustment(adjustmentID) else { return }
                self.finishAdjustment(adjustmentID)
                guard !Self.isCancellation(error) else { return }
                onFailure(error)
            }
        }
    }

    func cancelActiveTuneWork() {
        cancelGeneration()
        cancelAdjustment()
    }

    func cancelGeneration() {
        generationTask?.cancel()
        generationTask = nil
        activeGenerationID = nil
        isGenerating = false
    }

    func cancelAdjustment() {
        adjustmentTask?.cancel()
        adjustmentTask = nil
        activeAdjustment = nil
        isAdjusting = false
    }

    func cancelAdjustment(for savedTuneID: UUID) {
        guard activeAdjustment?.savedTuneID == savedTuneID else { return }
        cancelAdjustment()
    }

    private func finishGeneration(_ generationID: UUID) {
        guard activeGenerationID == generationID else { return }
        generationTask = nil
        activeGenerationID = nil
        isGenerating = false
    }

    private func finishAdjustment(_ adjustmentID: UUID) {
        guard activeAdjustment?.id == adjustmentID else { return }
        adjustmentTask = nil
        activeAdjustment = nil
        isAdjusting = false
    }

    private func isCurrentGeneration(_ generationID: UUID) -> Bool {
        activeGenerationID == generationID && !Task.isCancelled
    }

    private func isCurrentAdjustment(_ adjustmentID: UUID) -> Bool {
        activeAdjustment?.id == adjustmentID && !Task.isCancelled
    }

    private static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }

        if let urlError = error as? URLError, urlError.code == .cancelled {
            return true
        }

        return false
    }
}
