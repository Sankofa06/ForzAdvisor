//
//  Root workflow actions split by bounded ownership.
//

import Foundation
import SwiftData

extension ContentView {
    func performCopilotAction(
        _ action: StepGuideAction
    ) -> StepGuideActionResult {
        let authoritativeSnapshot: CopilotPersistedActionSnapshot? = {
            guard case .result(
                let displayedTune,
                let savedTuneID,
                _,
                _,
                _
            ) = step,
            let savedTuneID else {
                return nil
            }
            return try? CopilotPersistedActionSnapshotResolver()
                .resolve(
                    displayedTune: displayedTune,
                    savedTuneID: savedTuneID,
                    in: modelContext
                )
        }()
        let route = CopilotWorkflowActionRouter().route(
            action,
            from: step,
            authoritativeSnapshot: authoritativeSnapshot
        )
        guard let destination = route.destination else {
            return route.result
        }
        tuneWorkflow.cancelAdjustment()
        step = destination
        return route.result
    }

    func generateTune(
        for input: CarInput,
        discipline: DrivingDiscipline,
        origin: InputOrigin,
        thumbnailData: Data?,
        saveTo savedTuneID: UUID? = nil,
        playerNotes: String = "",
        preserving buildSnapshot: VehicleBuildSnapshot? = nil,
        retuneSession: SavedTuneRetuneSession? = nil
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
        let disclosure = makeProviderDisclosure(mode: tuneProviderMode)
        let returnContext: TuneGenerationReturnContext = retuneSession.map {
            .savedEdit($0)
        } ?? .newTune(newTuneSession)
        let session = TuneGenerationSession(
            request: request,
            origin: origin,
            thumbnailData: thumbnailData,
            savedTuneID: savedTuneID,
            playerNotes: playerNotes,
            preferredProviderMode: tuneProviderMode,
            providerDisclosure: disclosure,
            returnContext: returnContext
        )
        startGeneration(session)
    }

    func startGeneration(_ session: TuneGenerationSession) {
        let request = session.request
        step = .loading(
            request,
            thumbnailData: session.thumbnailData,
            savedTuneID: session.savedTuneID,
            playerNotes: session.playerNotes,
            partialTune: nil
        )

        let provider = makeTuneProvider(mode: session.preferredProviderMode)
        tuneWorkflow.generateTune(
            session: session,
            provider: provider,
            onPartial: { partialTune in
                step = .loading(
                    request,
                    thumbnailData: session.thumbnailData,
                    savedTuneID: session.savedTuneID,
                    playerNotes: session.playerNotes,
                    partialTune: partialTune
                )
            },
            onSuccess: { tune in
                let resultTune: TuneResult
                if let savedTuneID = session.savedTuneID {
                    resultTune = try updateSavedTune(
                        savedTuneID: savedTuneID,
                        with: tune,
                        playerNotes: session.playerNotes,
                        thumbnailData: session.thumbnailData
                    )
                } else {
                    resultTune = TuneResultBoundarySanitizer().sanitize(tune)
                }
                step = .result(
                    resultTune,
                    savedTuneID: session.savedTuneID,
                    adjustmentChanges: [],
                    thumbnailData: session.thumbnailData,
                    playerNotes: session.playerNotes
                )
            },
            onFailure: { failedSession, error in
                errorMessage = error.localizedDescription
                errorRecovery = .generate(failedSession)
                restoreGenerationReturnContext(failedSession.returnContext)
            }
        )
    }

    func save(_ tune: TuneResult, playerNotes: String, thumbnailData: Data?) -> UUID? {
        if savedTunes.contains(where: { $0.id == tune.id }) {
            return tune.id
        }

        do {
            let persistedTune = TuneResultBoundarySanitizer().sanitize(tune)
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
            let retuneSession = SavedTuneRetuneSession(
                savedTuneID: savedTuneID,
                baseline: originalTune,
                draft: draft,
                thumbnailData: thumbnailData
            )
            generateTune(
                for: draft.car,
                discipline: discipline,
                origin: .manual(draft.car),
                thumbnailData: thumbnailData,
                saveTo: savedTuneID,
                playerNotes: draft.playerNotes,
                preserving: originalTune.request.buildSnapshot,
                retuneSession: retuneSession
            )
            return
        }

        let updatedTune = draft.metadataUpdatedTune(from: originalTune)

        do {
            let persistedTune = try updateSavedTune(
                savedTuneID: savedTuneID,
                with: updatedTune,
                playerNotes: draft.playerNotes,
                thumbnailData: thumbnailData
            )
            step = .result(
                persistedTune,
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
                guard try savedTune(for: savedTuneID) != nil else {
                    throw ContentWorkflowError.missingSavedTune
                }
                refinementProposals.store(TuneRefinementProposal(
                    savedTuneID: savedTuneID,
                    baseline: tune,
                    result: result,
                    feedback: feedback
                ))
                step = .result(
                    tune,
                    savedTuneID: savedTuneID,
                    adjustmentChanges: result.changes,
                    thumbnailData: try savedTune(for: savedTuneID)?.thumbnailData,
                    playerNotes: try savedTune(for: savedTuneID)?.playerNotes ?? ""
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

    func discardRefinementProposal() {
        refinementProposals.discard()
    }

    func applyRefinementProposal() {
        guard let proposal = refinementProposals.proposal else { return }
        do {
            guard let savedTune = try savedTune(for: proposal.savedTuneID),
                  let persisted = savedTune.tuneResult else {
                throw ContentWorkflowError.missingSavedTune
            }
            let applied = try refinementProposals.apply(
                currentPersistedTune: persisted,
                persist: { candidate in
                    try savedTune.update(with: candidate)
                    try modelContext.save()
                }
            )
            step = .result(
                applied.proposal.candidate,
                savedTuneID: proposal.savedTuneID,
                adjustmentChanges: applied.proposal.changes,
                thumbnailData: savedTune.thumbnailData,
                playerNotes: savedTune.playerNotes
            )
        } catch {
            modelContext.rollback()
            errorMessage = "Could not apply this refinement: \(error.localizedDescription)"
        }
    }

    func undoAppliedRefinement(now: Date = .now) {
        guard let applied = refinementProposals.applied else { return }
        do {
            guard let savedTune = try savedTune(
                for: applied.proposal.savedTuneID
            ), let persisted = savedTune.tuneResult else {
                throw ContentWorkflowError.missingSavedTune
            }
            let restored = try refinementProposals.undo(
                currentPersistedTune: persisted,
                now: now,
                persist: { baseline in
                    try savedTune.update(with: baseline)
                    try modelContext.save()
                }
            )
            step = .result(
                restored,
                savedTuneID: savedTune.id,
                adjustmentChanges: [],
                thumbnailData: savedTune.thumbnailData,
                playerNotes: savedTune.playerNotes
            )
        } catch {
            modelContext.rollback()
            errorMessage = "Could not undo this refinement: \(error.localizedDescription)"
        }
    }

}
