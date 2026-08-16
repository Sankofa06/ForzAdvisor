import Foundation

enum WorkflowStep {
    case home
    case newTune
    case ocrReview(OCRConfirmationDraft)
    case manualEntry(ManualEntryDraft, thumbnailData: Data?)
    case discipline(CarInput, origin: InputOrigin, thumbnailData: Data?)
    case loading(
        TuneRequest,
        thumbnailData: Data?,
        savedTuneID: UUID?,
        playerNotes: String,
        partialTune: TuneResult?
    )
    case generationFailed(TuneGenerationSession)
    case result(
        TuneResult,
        savedTuneID: UUID?,
        adjustmentChanges: [TuneAdjustmentChange],
        thumbnailData: Data?,
        playerNotes: String
    )
    case fh6TuneMenuCapture(
        TuneResult,
        savedTuneID: UUID?,
        thumbnailData: Data?,
        playerNotes: String
    )
    case tirePressureCapture(
        TuneResult,
        savedTuneID: UUID?,
        thumbnailData: Data?,
        playerNotes: String
    )
    case upgradePartCapture(
        TuneResult,
        savedTuneID: UUID?,
        thumbnailData: Data?,
        playerNotes: String
    )
    case fh5ResearchCapture(
        TuneResult,
        savedTuneID: UUID,
        thumbnailData: Data?,
        playerNotes: String
    )
    case fh5ControlledExperimentCapture(
        TuneResult,
        savedTuneID: UUID,
        researchRecord: FH5ResearchObservationRecord,
        candidateTrialAvailable: Bool,
        thumbnailData: Data?,
        playerNotes: String
    )
    case recordTestDrive(
        TuneResult,
        savedTuneID: UUID,
        thumbnailData: Data?,
        playerNotes: String
    )
    case fh6CommunityReferenceTrialCapture(
        TuneResult,
        savedTuneID: UUID,
        thumbnailData: Data?,
        playerNotes: String
    )
    case editSavedTune(
        TuneResult,
        savedTuneID: UUID,
        playerNotes: String,
        thumbnailData: Data?
    )
    case editSavedTuneDraft(SavedTuneRetuneSession)
}

enum InputOrigin: Equatable, Sendable {
    case manual(CarInput)
    case ocr(OCRConfirmationDraft)
    // Compatibility-only source metadata for existing saved/catalog fixtures.
    // Root navigation no longer exposes bundled-catalog routes.
    case catalog(
        CatalogCarSelection,
        reusedUpgradeSnapshot: VehicleBuildSnapshot? = nil
    )

    func previousStep(thumbnailData: Data?) -> WorkflowStep {
        switch self {
        case .manual(let input):
            .manualEntry(
                ManualEntryDraft(car: input),
                thumbnailData: thumbnailData
            )
        case .ocr(let draft):
            .ocrReview(draft)
        case .catalog(let selection, _):
            .manualEntry(
                ManualEntryDraft(car: selection.carInput),
                thumbnailData: thumbnailData
            )
        }
    }

    func buildSnapshot(
        matching input: CarInput,
        capturedAt: Date = .now
    ) -> VehicleBuildSnapshot? {
        guard case .catalog(
            let selection,
            let reusedUpgradeSnapshot
        ) = self, input == selection.carInput else {
            return nil
        }
        if let reusedUpgradeSnapshot,
           CatalogUpgradeEvidenceReuseResolver().isValidReuseSnapshot(
                reusedUpgradeSnapshot,
                for: selection
           ) {
            return reusedUpgradeSnapshot
        }
        return selection.capabilityOnlyBuildSnapshot(capturedAt: capturedAt)
    }

    func resolvedBuildSnapshot(
        matching input: CarInput,
        preserving snapshot: VehicleBuildSnapshot?,
        capturedAt: Date = .now
    ) -> VehicleBuildSnapshot? {
        if snapshot?.isValid == true,
           snapshot?.matches(car: input) == true {
            return snapshot
        }
        return buildSnapshot(matching: input, capturedAt: capturedAt)
    }
}

struct ActiveTuneAdjustment {
    let id: UUID
    let savedTuneID: UUID
    let feedback: TuneFeedback
}
