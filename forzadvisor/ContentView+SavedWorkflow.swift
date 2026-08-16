//
//  Root workflow actions split by bounded ownership.
//

import Foundation
import SwiftData

extension ContentView {
    func open(_ savedTune: SavedTune) {
        cancelActiveTuneWork()
        do {
            _ = try reusableAuthorizedValidationRecords(
                savedTune: savedTune,
                savedTuneID: savedTune.id
            )
        } catch {
            errorMessage = "Evidence privacy reconciliation failed safely: \(error.localizedDescription)"
            return
        }
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
        var cleanupFingerprints = Set<String>()
        var cleanupPreparationFailures: [Error] = []
        do {
            cleanupFingerprints.formUnion(
                try savedTune.allFirstPartyValidationRecords()
                    .map(\.contentFingerprint)
            )
        } catch {
            cleanupPreparationFailures.append(error)
        }
        do {
            cleanupFingerprints.formUnion(
                try ValidationLocalObservationStore()
                    .observations(savedTuneID: savedTuneID)
                    .map(\.observationFingerprint)
            )
        } catch {
            cleanupPreparationFailures.append(error)
        }
        var fingerprintsReferencedByOtherTunes = Set<String>()
        for otherTune in savedTunes where otherTune.id != savedTuneID {
            do {
                fingerprintsReferencedByOtherTunes.formUnion(
                    try otherTune.allFirstPartyValidationRecords()
                        .map(\.contentFingerprint)
                )
                fingerprintsReferencedByOtherTunes.formUnion(
                    try ValidationLocalObservationStore()
                        .observations(savedTuneID: otherTune.id)
                        .map(\.observationFingerprint)
                )
            } catch {
                cleanupPreparationFailures.append(error)
            }
        }
        cleanupFingerprints.subtract(fingerprintsReferencedByOtherTunes)
        modelContext.delete(savedTune)

        do {
            try modelContext.save()
            completion?(.committed(savedTuneID: savedTuneID))
            var cleanupFailures = cleanupPreparationFailures
            do {
                try ValidationEvidencePurgeCoordinator().scheduleAndRun(
                    ValidationTunePurgeTask(
                        savedTuneID: savedTuneID,
                        authorizationFingerprints: cleanupFingerprints
                    )
                )
            } catch {
                cleanupFailures.append(error)
            }
            if let first = cleanupFailures.first {
                errorMessage = ValidationEvidenceTransactionError(
                    primary: first,
                    recoveryFailures: Array(cleanupFailures.dropFirst())
                ).errorDescription.map {
                    "Tune deleted, but private cleanup is pending and will retry next launch: \($0)"
                }
            }
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

    func retryGeneration(_ session: TuneGenerationSession) {
        startGeneration(session)
    }

    func clearError() {
        errorMessage = nil
    }

    func changeGenerationDiscipline(
        _ session: TuneGenerationSession
    ) {
        restoreGenerationReturnContext(
            TuneGenerationFailureRecovery(session: session)
                .changeDisciplineContext
        )
    }

    func backFromGenerationFailure(_ session: TuneGenerationSession) {
        if let mission = session.validationMissionReturnContext {
            if case .newTune(let draft) = session.returnContext {
                newTuneSession = draft
            }
            if returnToValidationMission(
                .draftPreserved,
                expected: mission
            ) {
                return
            }
        }
        let recovery = TuneGenerationFailureRecovery(session: session)
        switch recovery.backTarget {
        case .source(let origin, let thumbnailData):
            if case .newTune(let draft) = session.returnContext {
                newTuneSession = draft
            }
            step = origin.previousStep(thumbnailData: thumbnailData)
        case .savedEdit(let retune):
            step = .editSavedTuneDraft(retune)
        }
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
            validationMissionReturnContext = .init(mission: mission)
            validationMissionOutcomeMessage = nil
            switch mission.destination {
            case .manualEntry(let game):
                let draft = ManualEntryDraft(game: game)
                newTuneSession.stage = .manual(
                    draft,
                    thumbnailData: nil
                )
                step = .manualEntry(
                    draft,
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
        } catch ContentWorkflowError.staleBetaMission {
            validationMissionReturnContext = nil
            validationMissionOutcomeMessage =
                ValidationMissionReturnOutcome.stale.message
            step = .home
            rootSheet = .betaMissions
        } catch {
            validationMissionReturnContext = nil
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
