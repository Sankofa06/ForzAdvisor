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
        playerNotes: String = "",
        preserving buildSnapshot: VehicleBuildSnapshot? = nil
    ) {
        let resolvedBuildSnapshot = origin.resolvedBuildSnapshot(
            matching: input,
            preserving: buildSnapshot
        )
        let request = TuneRequest(
            car: input,
            discipline: discipline,
            buildSnapshot: resolvedBuildSnapshot
        )
        step = .loading(
            request,
            thumbnailData: thumbnailData,
            savedTuneID: savedTuneID,
            playerNotes: playerNotes,
            partialTune: nil
        )

        let provider = makeTuneProvider()
        tuneWorkflow.generateTune(
            for: request,
            provider: provider,
            onPartial: { partialTune in
                step = .loading(
                    request,
                    thumbnailData: thumbnailData,
                    savedTuneID: savedTuneID,
                    playerNotes: playerNotes,
                    partialTune: partialTune
                )
            },
            onSuccess: { tune in
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
            },
            onFailure: { error in
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
        )
    }

    func save(_ tune: TuneResult, playerNotes: String, thumbnailData: Data?) -> UUID? {
        if savedTunes.contains(where: { $0.id == tune.id }) {
            return tune.id
        }

        do {
            let persistedTune = TuneOutputProjector().project(tune)
            modelContext.insert(try SavedTune(
                tune: persistedTune,
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
                playerNotes: draft.playerNotes,
                preserving: originalTune.request.buildSnapshot
            )
            return
        }

        let updatedTune = draft.metadataUpdatedTune(from: originalTune)
        let resultTune = originalTune.projectionReport == nil
            ? updatedTune
            : TuneOutputProjector().project(updatedTune)

        do {
            try updateSavedTune(
                savedTuneID: savedTuneID,
                with: resultTune,
                playerNotes: draft.playerNotes,
                thumbnailData: thumbnailData
            )
            step = .result(
                resultTune,
                savedTuneID: savedTuneID,
                adjustmentChanges: [],
                thumbnailData: thumbnailData,
                playerNotes: draft.playerNotes
            )
        } catch {
            errorMessage = "Could not save tune edits: \(error.localizedDescription)"
        }
    }

    func adjust(_ tune: TuneResult, savedTuneID: UUID, feedback: TuneFeedback) {
        do {
            guard try savedTune(for: savedTuneID) != nil else {
                errorMessage = "This saved tune could not be adjusted."
                return
            }
        } catch {
            errorMessage = "Could not load this saved tune: \(error.localizedDescription)"
            return
        }

        let provider = makeTuneProvider()
        tuneWorkflow.adjustTune(
            previous: tune,
            savedTuneID: savedTuneID,
            feedback: feedback,
            provider: provider,
            onSuccess: { result in
                guard let resolvedSavedTune = try savedTune(for: savedTuneID) else {
                    throw ContentWorkflowError.missingSavedTune
                }
                try resolvedSavedTune.update(with: result.tune)
                try modelContext.save()
                step = .result(
                    result.tune,
                    savedTuneID: savedTuneID,
                    adjustmentChanges: result.changes,
                    thumbnailData: resolvedSavedTune.thumbnailData,
                    playerNotes: resolvedSavedTune.playerNotes
                )
            },
            onFailure: { error in
                let resolvedSavedTune = try? savedTune(for: savedTuneID)
                errorMessage = "Could not adjust this tune: \(error.localizedDescription)"
                step = .result(
                    tune,
                    savedTuneID: savedTuneID,
                    adjustmentChanges: [],
                    thumbnailData: resolvedSavedTune?.thumbnailData,
                    playerNotes: resolvedSavedTune?.playerNotes ?? ""
                )
            }
        )
    }

    func eligibleTireCaptureSnapshot(for tune: TuneResult) -> VehicleBuildSnapshot? {
        TirePressureCaptureEligibility().snapshot(for: tune)
    }

    func eligibleUpgradeCaptureSnapshot(for tune: TuneResult) -> VehicleBuildSnapshot? {
        UpgradePartCaptureEligibility().snapshot(for: tune)
    }

    func applyTirePressureCapture(
        _ capture: TirePressureCapture,
        to tune: TuneResult,
        savedTuneID: UUID?,
        thumbnailData: Data?,
        playerNotes: String
    ) {
        guard let snapshot = eligibleTireCaptureSnapshot(for: tune) else {
            errorMessage = "This tune is no longer eligible for stock tire verification."
            return
        }

        do {
            let exactSnapshot = try capture.exactBuildSnapshot(upgrading: snapshot)
            generateTune(
                for: tune.request.car,
                discipline: tune.request.discipline,
                origin: .manual(tune.request.car),
                thumbnailData: thumbnailData,
                saveTo: savedTuneID,
                playerNotes: playerNotes,
                preserving: exactSnapshot
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func applyUpgradePartCapture(
        _ capture: UpgradePartCapture,
        to tune: TuneResult,
        savedTuneID: UUID?,
        thumbnailData: Data?,
        playerNotes: String
    ) {
        guard let snapshot = eligibleUpgradeCaptureSnapshot(for: tune) else {
            errorMessage = "This tune is no longer eligible for stock upgrade verification."
            return
        }

        do {
            let verifiedSnapshot = try capture.verifiedSnapshot(upgrading: snapshot)
            generateTune(
                for: tune.request.car,
                discipline: tune.request.discipline,
                origin: .manual(tune.request.car),
                thumbnailData: thumbnailData,
                saveTo: savedTuneID,
                playerNotes: playerNotes,
                preserving: verifiedSnapshot
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func recordTestDrive(
        _ capture: FirstPartyValidationCapture,
        for tune: TuneResult,
        savedTuneID: UUID,
        thumbnailData: Data?,
        playerNotes: String
    ) {
        do {
            guard let savedTune = try savedTune(for: savedTuneID),
                  let persistedTune = savedTune.tuneResult else {
                throw ContentWorkflowError.missingSavedTune
            }
            let record = try FirstPartyValidationRecordFactory().make(
                tune: tune,
                savedTune: persistedTune,
                isStreaming: false,
                capture: capture
            )
            try savedTune.appendValidationRecord(record)
            try modelContext.save()
            step = .result(
                tune,
                savedTuneID: savedTuneID,
                adjustmentChanges: [],
                thumbnailData: thumbnailData,
                playerNotes: playerNotes
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteValidationRecord(
        _ record: FirstPartyValidationRecord,
        savedTuneID: UUID
    ) {
        do {
            guard let savedTune = try savedTune(for: savedTuneID) else {
                throw ContentWorkflowError.missingSavedTune
            }
            _ = try savedTune.deleteValidationRecord(id: record.recordID)
            try modelContext.save()
        } catch {
            errorMessage = "Could not delete this validation record: \(error.localizedDescription)"
        }
    }

    func open(_ savedTune: SavedTune) {
        cancelActiveTuneWork()
        if let tune = savedTune.tuneResult {
            let displayTune = tune.projectionReport == nil
                ? tune
                : TuneOutputProjector().project(tune)
            step = .result(
                displayTune,
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
        let persistedTune = savedTune.tuneResult?.projectionReport == nil
            && tune.projectionReport == nil
            ? tune
            : TuneOutputProjector().project(tune)
        try savedTune.update(
            with: persistedTune,
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
        tuneWorkflow.cancelAdjustment(for: savedTune.id)
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
                playerNotes: playerNotes,
                preserving: request.buildSnapshot
            )
        }
    }

    func clearError() {
        errorMessage = nil
        errorRecovery = nil
    }

    func cancelActiveTuneWork() {
        tuneWorkflow.cancelActiveTuneWork()
    }

    func makeTuneProvider() -> any TuneProvider {
        CapabilityProjectingTuneProvider(base: CompositeTuneProvider(
            configuration: TuneProviderConfiguration(
                mode: tuneProviderMode
            ),
            remoteProvider: TuneAPIClient(keychainStore: keychainStore),
            onDeviceProvider: FoundationModelTuneProvider(),
            localProvider: LocalSampleTuneProvider()
        ))
    }
}

enum WorkflowStep {
    case home
    case newTune
    case catalogPicker(initialGame: ForzaGame = .fh6)
    case catalogReview(CatalogCarSelection)
    case catalogEdit(CatalogCarSelection)
    case ocrReview(OCRConfirmationDraft)
    case manualEntry(ManualEntryDraft, thumbnailData: Data?)
    case discipline(CarInput, origin: InputOrigin, thumbnailData: Data?)
    case loading(TuneRequest, thumbnailData: Data?, savedTuneID: UUID?, playerNotes: String, partialTune: TuneResult?)
    case result(TuneResult, savedTuneID: UUID?, adjustmentChanges: [TuneAdjustmentChange], thumbnailData: Data?, playerNotes: String)
    case tirePressureCapture(TuneResult, savedTuneID: UUID?, thumbnailData: Data?, playerNotes: String)
    case upgradePartCapture(TuneResult, savedTuneID: UUID?, thumbnailData: Data?, playerNotes: String)
    case recordTestDrive(TuneResult, savedTuneID: UUID, thumbnailData: Data?, playerNotes: String)
    case editSavedTune(TuneResult, savedTuneID: UUID, playerNotes: String, thumbnailData: Data?)
}

enum InputOrigin {
    case manual(CarInput)
    case ocr(OCRConfirmationDraft)
    case catalog(CatalogCarSelection)

    func previousStep(thumbnailData: Data?) -> WorkflowStep {
        switch self {
        case .manual(let input):
            .manualEntry(ManualEntryDraft(car: input), thumbnailData: thumbnailData)
        case .ocr(let draft):
            .ocrReview(draft)
        case .catalog(let selection):
            .catalogReview(selection)
        }
    }

    func buildSnapshot(matching input: CarInput, capturedAt: Date = .now) -> VehicleBuildSnapshot? {
        guard case .catalog(let selection) = self,
              input == selection.carInput else {
            return nil
        }
        return selection.capabilityOnlyBuildSnapshot(capturedAt: capturedAt)
    }

    func resolvedBuildSnapshot(
        matching input: CarInput,
        preserving snapshot: VehicleBuildSnapshot?,
        capturedAt: Date = .now
    ) -> VehicleBuildSnapshot? {
        if snapshot?.isValid == true, snapshot?.matches(car: input) == true {
            return snapshot
        }
        return buildSnapshot(matching: input, capturedAt: capturedAt)
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

struct ActiveTuneAdjustment {
    let id: UUID
    let savedTuneID: UUID
    let feedback: TuneFeedback
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
