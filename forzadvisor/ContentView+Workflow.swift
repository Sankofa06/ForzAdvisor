//
//  ContentView+Workflow.swift
//  forzadvisor
//
//  Side-effecting workflow actions for ContentView: generation, persistence,
//  retry, saved tune edits, and adjustment updates.
//

import Foundation
import SwiftData

extension ContentView {
    func generateTune(
        for input: CarInput,
        discipline: DrivingDiscipline,
        origin: InputOrigin,
        thumbnailData: Data?,
        saveTo savedTuneID: UUID? = nil,
        playerNotes: String = ""
    ) {
        let request = TuneRequest(car: input, discipline: discipline)
        step = .loading(
            request,
            thumbnailData: thumbnailData,
            savedTuneID: savedTuneID,
            playerNotes: playerNotes
        )

        Task {
            do {
                let tune = try await makeTuneProvider().generateTune(for: request)
                try await MainActor.run {
                    if let savedTuneID {
                        try updateSavedTune(
                            savedTuneID: savedTuneID,
                            with: tune,
                            playerNotes: playerNotes,
                            thumbnailData: thumbnailData
                        )
                    }
                    step = .result(
                        tune,
                        savedTuneID: savedTuneID,
                        adjustmentChanges: [],
                        thumbnailData: thumbnailData,
                        playerNotes: playerNotes
                    )
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    errorRecovery = .generate(
                        request: request,
                        origin: origin,
                        thumbnailData: thumbnailData,
                        savedTuneID: savedTuneID,
                        playerNotes: playerNotes
                    )
                    step = .discipline(input, origin: origin, thumbnailData: thumbnailData)
                }
            }
        }
    }

    func save(_ tune: TuneResult, playerNotes: String, thumbnailData: Data?) -> UUID? {
        if savedTunes.contains(where: { $0.id == tune.id }) {
            return tune.id
        }

        do {
            modelContext.insert(try SavedTune(
                tune: tune,
                playerNotes: playerNotes,
                thumbnailData: thumbnailData
            ))
            try modelContext.save()
            return tune.id
        } catch {
            errorMessage = "Could not save this tune: \(error.localizedDescription)"
            return nil
        }
    }

    func saveEditedTune(
        originalTune: TuneResult,
        savedTuneID: UUID,
        draft: SavedTuneEditDraft,
        thumbnailData: Data?,
        shouldRetune: Bool
    ) {
        let discipline = originalTune.request.discipline

        if shouldRetune {
            generateTune(
                for: draft.car,
                discipline: discipline,
                origin: .manual(draft.car),
                thumbnailData: thumbnailData,
                saveTo: savedTuneID,
                playerNotes: draft.playerNotes
            )
            return
        }

        let updatedTune = draft.metadataUpdatedTune(from: originalTune)

        do {
            try updateSavedTune(
                savedTuneID: savedTuneID,
                with: updatedTune,
                playerNotes: draft.playerNotes,
                thumbnailData: thumbnailData
            )
            step = .result(
                updatedTune,
                savedTuneID: savedTuneID,
                adjustmentChanges: [],
                thumbnailData: thumbnailData,
                playerNotes: draft.playerNotes
            )
        } catch {
            errorMessage = "Could not save tune edits: \(error.localizedDescription)"
        }
    }

    func adjust(_ tune: TuneResult, savedTuneID: UUID, adjustment: TuneAdjustment) {
        let resolvedSavedTune: SavedTune

        do {
            guard let fetchedTune = try savedTune(for: savedTuneID) else {
                errorMessage = "This saved tune could not be adjusted."
                return
            }
            resolvedSavedTune = fetchedTune
        } catch {
            errorMessage = "Could not load this saved tune: \(error.localizedDescription)"
            return
        }

        adjustingAdjustment = adjustment

        Task {
            do {
                let result = try await makeTuneProvider().adjustTune(previous: tune, adjustment: adjustment)
                try await MainActor.run {
                    try resolvedSavedTune.update(with: result.tune)
                    try modelContext.save()
                    adjustingAdjustment = nil
                    step = .result(
                        result.tune,
                        savedTuneID: savedTuneID,
                        adjustmentChanges: result.changes,
                        thumbnailData: resolvedSavedTune.thumbnailData,
                        playerNotes: resolvedSavedTune.playerNotes
                    )
                }
            } catch {
                await MainActor.run {
                    adjustingAdjustment = nil
                    errorMessage = "Could not adjust this tune: \(error.localizedDescription)"
                    step = .result(
                        tune,
                        savedTuneID: savedTuneID,
                        adjustmentChanges: [],
                        thumbnailData: resolvedSavedTune.thumbnailData,
                        playerNotes: resolvedSavedTune.playerNotes
                    )
                }
            }
        }
    }

    func open(_ savedTune: SavedTune) {
        if let tune = savedTune.tuneResult {
            step = .result(
                tune,
                savedTuneID: savedTune.id,
                adjustmentChanges: [],
                thumbnailData: savedTune.thumbnailData,
                playerNotes: savedTune.playerNotes
            )
        } else {
            errorMessage = "This saved tune could not be opened."
        }
    }

    func updateSavedTune(
        savedTuneID: UUID,
        with tune: TuneResult,
        playerNotes: String,
        thumbnailData: Data?
    ) throws {
        guard let savedTune = try savedTune(for: savedTuneID) else {
            throw ContentWorkflowError.missingSavedTune
        }
        try savedTune.update(
            with: tune,
            playerNotes: playerNotes,
            thumbnailData: thumbnailData
        )
        try modelContext.save()
    }

    func savedTune(for id: UUID) throws -> SavedTune? {
        if let savedTune = savedTunes.first(where: { $0.id == id }) {
            return savedTune
        }

        var descriptor = FetchDescriptor<SavedTune>(
            predicate: #Predicate<SavedTune> { tune in
                tune.id == id
            }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    func resolvedSavedTune(for tune: TuneResult, savedTuneID: UUID?) -> SavedTune? {
        if let savedTuneID,
           let savedTune = savedTunes.first(where: { $0.id == savedTuneID }) {
            return savedTune
        }
        return savedTunes.first(where: { $0.id == tune.id })
    }

    func delete(_ savedTune: SavedTune) {
        modelContext.delete(savedTune)

        do {
            try modelContext.save()
        } catch {
            errorMessage = "Could not delete this tune: \(error.localizedDescription)"
        }
    }

    func retry(_ recovery: ErrorRecovery) {
        clearError()

        switch recovery {
        case .generate(let request, let origin, let thumbnailData, let savedTuneID, let playerNotes):
            generateTune(
                for: request.car,
                discipline: request.discipline,
                origin: origin,
                thumbnailData: thumbnailData,
                saveTo: savedTuneID,
                playerNotes: playerNotes
            )
        }
    }

    func clearError() {
        errorMessage = nil
        errorRecovery = nil
    }

    func makeTuneProvider() -> CompositeTuneProvider {
        CompositeTuneProvider(
            configuration: TuneProviderConfiguration(
                prefersRemoteGeneration: prefersRemoteTuneProvider
            ),
            remoteProvider: TuneAPIClient(keychainStore: keychainStore),
            localProvider: LocalSampleTuneProvider()
        )
    }
}

enum WorkflowStep {
    case home
    case newTune
    case ocrReview(OCRConfirmationDraft)
    case manualEntry(CarInput, thumbnailData: Data?)
    case discipline(CarInput, origin: InputOrigin, thumbnailData: Data?)
    case loading(TuneRequest, thumbnailData: Data?, savedTuneID: UUID?, playerNotes: String)
    case result(TuneResult, savedTuneID: UUID?, adjustmentChanges: [TuneAdjustmentChange], thumbnailData: Data?, playerNotes: String)
    case editSavedTune(TuneResult, savedTuneID: UUID, playerNotes: String, thumbnailData: Data?)
}

enum InputOrigin {
    case manual(CarInput)
    case ocr(OCRConfirmationDraft)

    func previousStep(thumbnailData: Data?) -> WorkflowStep {
        switch self {
        case .manual(let input):
            .manualEntry(input, thumbnailData: thumbnailData)
        case .ocr(let draft):
            .ocrReview(draft)
        }
    }
}

enum ErrorRecovery {
    case generate(
        request: TuneRequest,
        origin: InputOrigin,
        thumbnailData: Data?,
        savedTuneID: UUID?,
        playerNotes: String
    )
}

enum ContentWorkflowError: LocalizedError {
    case missingSavedTune

    var errorDescription: String? {
        switch self {
        case .missingSavedTune:
            "The saved tune could not be found."
        }
    }
}
