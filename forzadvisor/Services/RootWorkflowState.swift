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
        switch self {
        case .manual(let confirmedInput):
            guard confirmedInput == input, input.isValid else {
                return nil
            }
            return Self.userConfirmedSnapshot(
                for: input,
                source: .userConfirmedManual,
                capturedAt: capturedAt
            )
        case .ocr(let draft):
            guard draft.confirmedCarInput() == input else {
                return nil
            }
            return Self.userConfirmedSnapshot(
                for: input,
                source: .userConfirmedOCR,
                capturedAt: capturedAt
            )
        case .catalog(let selection, let reusedUpgradeSnapshot):
            guard input == selection.carInput else { return nil }
            if let reusedUpgradeSnapshot,
               CatalogUpgradeEvidenceReuseResolver().isValidReuseSnapshot(
                    reusedUpgradeSnapshot,
                    for: selection
               ) {
                return reusedUpgradeSnapshot
            }
            return selection.capabilityOnlyBuildSnapshot(
                capturedAt: capturedAt
            )
        }
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

    private static func userConfirmedSnapshot(
        for input: CarInput,
        source: VehicleInputFactsSource,
        capturedAt: Date
    ) -> VehicleBuildSnapshot {
        let resolvedSource: VehicleInputFactsSource =
            input.catalogReference == nil ? source : .reviewedCatalog
        let sourceID = input.catalogReference?.entryID
            ?? "input-source:\(source.rawValue)"
        return VehicleBuildSnapshot(
            schemaVersion: VehicleBuildSnapshot.currentSchemaVersion,
            id: UUID(),
            kind: .capabilityOnly,
            capturedAt: capturedAt,
            gameBuild: GameBuildReference(
                game: input.game,
                version: nil,
                capturedAt: nil
            ),
            car: input,
            capabilityProfile: TuneVehicleCapabilityProfile(
                vehicle: TuneVehicleIdentity(
                    game: input.game,
                    catalogID: sourceID,
                    year: input.year ?? 0,
                    make: input.make,
                    model: input.model
                ),
                drivetrain: input.drivetrain,
                parts: [],
                stockAdjustableSettings: []
            ),
            tireCompound: nil,
            gearCount: nil,
            constraints: [],
            evidenceSources: [],
            inputFactsSource: resolvedSource
        )
    }
}

struct ActiveTuneAdjustment {
    let id: UUID
    let savedTuneID: UUID
    let feedback: TuneFeedback
}
