//
//  Root workflow actions split by bounded ownership.
//

import Foundation
import SwiftData

extension ContentView {
    func open(_ savedTune: SavedTune) {
        cancelActiveTuneWork()
        _ = try? reusableAuthorizedValidationRecords(
            savedTune: savedTune,
            savedTuneID: savedTune.id
        )
        if let tune = savedTune.tuneResult {
            let displayTune = TuneResultBoundarySanitizer().sanitize(tune)
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
    ) throws -> TuneResult {
        guard let savedTune = try savedTune(for: savedTuneID) else {
            throw ContentWorkflowError.missingSavedTune
        }
        let persistedTune = TuneResultBoundarySanitizer().sanitize(tune)
        do {
            try savedTune.update(
                with: persistedTune,
                playerNotes: playerNotes,
                thumbnailData: thumbnailData
            )
            try modelContext.save()
            return persistedTune
        } catch {
            modelContext.rollback()
            throw error
        }
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

    func delete(
        _ savedTune: SavedTune,
        completion: GarageRemovalCommitCallback? = nil
    ) {
        tuneWorkflow.cancelAdjustment(for: savedTune.id)
        let savedTuneID = savedTune.id
        modelContext.delete(savedTune)

        do {
            try modelContext.save()
            _ = try? ValidationDraftStore().purge(
                savedTuneID: savedTuneID
            )
            _ = try? ValidationLocalObservationStore().purge(
                savedTuneID: savedTuneID
            )
            completion?(.committed(savedTuneID: savedTuneID))
        } catch {
            modelContext.rollback()
            let message =
                "Could not delete this tune: \(error.localizedDescription)"
            errorMessage = message
            completion?(.rolledBack(
                savedTuneID: savedTuneID,
                message: message
            ))
        }
    }

    func commitGarageRemoval(
        savedTuneID: UUID,
        completion: GarageRemovalCommitCallback? = nil
    ) {
        do {
            guard let tune = try savedTune(for: savedTuneID) else {
                throw ContentWorkflowError.missingSavedTune
            }
            delete(tune, completion: completion)
        } catch {
            let message = "Could not delete this tune: \(error.localizedDescription)"
            errorMessage = message
            completion?(.rolledBack(
                savedTuneID: savedTuneID,
                message: message
            ))
        }
    }

    func retry(_ recovery: ErrorRecovery) {
        clearError()

        switch recovery {
        case .generate(let session):
            startGeneration(session)
        }
    }

    func clearError() {
        errorMessage = nil
        errorRecovery = nil
    }

    func openBetaValidationMission(_ mission: BetaValidationMission) {
        rootSheet = nil
        do {
            let currentBoard = BetaValidationMissionPlanner().makeBoard(
                savedTunes: savedTunes
            )
            guard currentBoard.missions.contains(mission) else {
                throw ContentWorkflowError.staleBetaMission
            }

            cancelActiveTuneWork()
            switch mission.destination {
            case .manualEntry(let game):
                step = .manualEntry(
                    ManualEntryDraft(game: game),
                    thumbnailData: nil
                )
            case .savedTune(let savedTuneID, let kind):
                guard let savedTune = try savedTune(for: savedTuneID),
                      let storedTune = savedTune.tuneResult else {
                    throw ContentWorkflowError.missingSavedTune
                }
                let tune = TuneResultBoundarySanitizer().sanitize(storedTune)
                switch kind {
                case .recordFH5Research:
                    step = .fh5ResearchCapture(
                        tune,
                        savedTuneID: savedTuneID,
                        thumbnailData: savedTune.thumbnailData,
                        playerNotes: savedTune.playerNotes
                    )
                case .runFH5Experiment:
                    let researchRecords = savedTune
                        .fh5ResearchObservationRecords(matching: tune)
                    guard case .success(let researchRecord) =
                        FH5ControlledExperimentFactory().eligibility(
                            tune: tune,
                            savedTune: tune,
                            isStreaming: false,
                            researchRecords: researchRecords
                        ) else {
                        throw ContentWorkflowError.staleBetaMission
                    }
                    let reviewInputs = savedTune
                        .fh5ResearchReviewEntries(matching: tune)
                        .map { FH5ResearchReviewInput(entry: $0) }
                    let candidateTrialAvailable = (try?
                        FH5CandidateTrialCoordinator().generate(
                            tune: tune,
                            savedTune: tune,
                            isStreaming: false,
                            researchRecords: researchRecords,
                            reviewInputs: reviewInputs,
                            input: .controller,
                            surface: .dry
                        )
                    ) != nil
                    step = .fh5ControlledExperimentCapture(
                        tune,
                        savedTuneID: savedTuneID,
                        researchRecord: researchRecord,
                        candidateTrialAvailable: candidateTrialAvailable,
                        thumbnailData: savedTune.thumbnailData,
                        playerNotes: savedTune.playerNotes
                    )
                case .verifyTireRanges:
                    step = .tirePressureCapture(
                        tune,
                        savedTuneID: savedTuneID,
                        thumbnailData: savedTune.thumbnailData,
                        playerNotes: savedTune.playerNotes
                    )
                case .verifyTuneMenu:
                    step = .fh6TuneMenuCapture(
                        tune,
                        savedTuneID: savedTuneID,
                        thumbnailData: savedTune.thumbnailData,
                        playerNotes: savedTune.playerNotes
                    )
                case .verifyUpgradeParts:
                    step = .upgradePartCapture(
                        tune,
                        savedTuneID: savedTuneID,
                        thumbnailData: savedTune.thumbnailData,
                        playerNotes: savedTune.playerNotes
                    )
                case .recordTestDrive:
                    step = .recordTestDrive(
                        tune,
                        savedTuneID: savedTuneID,
                        thumbnailData: savedTune.thumbnailData,
                        playerNotes: savedTune.playerNotes
                    )
                case .runFH6CommunityReferenceTrial:
                    openFH6CommunityReferenceTrial(
                        savedTuneID: savedTuneID,
                        requiresNoCurrentTrial: true
                    )
                case .startFH5Plan, .startFH6Tune:
                    throw ContentWorkflowError.staleBetaMission
                }
            }
        } catch {
            errorMessage = "Could not open this beta mission: \(error.localizedDescription)"
        }
    }

    func cancelActiveTuneWork() {
        tuneWorkflow.cancelActiveTuneWork()
    }

    func makeTuneProvider(
        mode: TuneProviderMode? = nil
    ) -> any TuneProvider {
        CapabilityProjectingTuneProvider(base: CompositeTuneProvider(
            configuration: TuneProviderConfiguration(
                mode: mode ?? tuneProviderMode
            ),
            remoteProvider: TuneAPIClient(keychainStore: keychainStore),
            onDeviceProvider: FoundationModelTuneProvider(),
            localProvider: LocalSampleTuneProvider()
        ))
    }

    func cancelGenerationSession() {
        guard let session = tuneWorkflow.activeGenerationSession else { return }
        tuneWorkflow.cancelGeneration()
        restoreGenerationReturnContext(session.returnContext)
    }

    func resumeNewTuneDraft() {
        guard newTuneSession.isMeaningful else { return }
        restoreGenerationReturnContext(.newTune(newTuneSession))
    }

    func restoreGenerationReturnContext(
        _ context: TuneGenerationReturnContext
    ) {
        switch context {
        case .newTune(let draft):
            newTuneSession = draft
            switch draft.stage {
            case .source:
                step = .newTune
            case .manual(let manualDraft, let thumbnailData):
                step = .manualEntry(
                    manualDraft,
                    thumbnailData: thumbnailData
                )
            case .ocr(let ocrDraft):
                step = .ocrReview(ocrDraft)
            case .discipline(let car, let origin, let thumbnailData, _):
                step = .discipline(
                    car,
                    origin: origin,
                    thumbnailData: thumbnailData
                )
            }
        case .savedEdit(let retune):
            step = .editSavedTuneDraft(retune)
        }
    }

    func makeProviderDisclosure(
        mode: TuneProviderMode
    ) -> TuneProviderDisclosure {
        let onDevice: TuneProviderCapability =
            OnDeviceModelAvailability.current().isAvailable
            ? .ready
            : .unavailable(.modelNotReady)
        let api: TuneProviderCapability
        switch keychainStore.apiKeyStatus() {
        case .configured:
            api = .storedOnDeviceNotTested
        case .missing:
            api = .setupRequired(.apiKey)
        case .readFailed:
            api = .unavailable(.credentialStatusUnavailable)
        }
        return TuneProviderDisclosure(
            preferredMode: mode,
            capabilities: TuneProviderCapabilities(
                onDeviceModel: onDevice,
                anthropicAPI: api
            )
        )
    }
}
