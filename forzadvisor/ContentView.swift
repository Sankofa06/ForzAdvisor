//
//  ContentView.swift
//  forzadvisor
//
//  Root SwiftUI coordinator for garage, photo/manual input, OCR review,
//  discipline selection, tune generation, saved edits, and feel adjustments.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) var modelContext
    @Query(sort: \SavedTune.updatedAt, order: .reverse) var savedTunes: [SavedTune]
    @AppStorage("tuneProviderMode") var tuneProviderMode = TuneProviderMode.offlineFormula

    @State var step: WorkflowStep = .home
    @State var errorMessage: String?
    @State var errorRecovery: ErrorRecovery?
    @State var rootSheet: RootSheet?
    @State var catalogResult = BundledCarCatalog.load()
    @State var firstSavedSetupCopilotHandoff =
        FirstSavedSetupCopilotHandoffState()
    @StateObject var tuneWorkflow = TuneWorkflowController()

    let keychainStore = KeychainStore()

    init() {}

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .home:
                    let missionBoard = betaValidationMissionBoard
                    GarageHomeView(
                        savedTunes: savedTunes,
                        onNewTune: {
                            cancelActiveTuneWork()
                            step = .newTune
                        },
                        onOpenTune: { savedTune in
                            firstSavedSetupCopilotHandoff.consume()
                            open(savedTune)
                        },
                        onDeleteTune: delete,
                        betaMissionCount:
                            missionBoard.progress.availableMissionCount,
                        onBetaMissions: { rootSheet = .betaMissions },
                        onEmptyGarageFirstWin:
                            emptyGarageFirstWinAction(for: missionBoard),
                        onSettings: { rootSheet = .settings }
                    )
                case .newTune:
                    NewTuneStartView(
                        onCancel: { step = .home },
                        onCatalog: { step = .catalogPicker() },
                        onManualEntry: {
                            step = .manualEntry(.empty, thumbnailData: nil)
                        },
                        onDraftReady: { draft in
                            step = .ocrReview(draft)
                        }
                    )
                case .catalogPicker(let initialGame):
                    CarCatalogPickerView(
                        catalogResult: catalogResult,
                        initialGame: initialGame,
                        onBack: { step = .newTune },
                        onManualEntry: { game in
                            step = .manualEntry(
                                ManualEntryDraft(game: game),
                                thumbnailData: nil
                            )
                        },
                        onSelect: { selection in
                            step = .catalogReview(selection)
                        }
                    )
                case .catalogReview(let selection):
                    let reuseOffer =
                        catalogUpgradeEvidenceReuseOffer(
                            for: selection
                        )
                    CarCatalogReviewView(
                        selection: selection,
                        upgradeReuseOffer: reuseOffer,
                        onBack: {
                            step = .catalogPicker(initialGame: selection.entry.game)
                        },
                        onUseCar: {
                            step = .discipline(
                                selection.carInput,
                                origin: .catalog(
                                    selection,
                                    reusedUpgradeSnapshot: nil
                                ),
                                thumbnailData: nil
                            )
                        },
                        onReuseVerifiedParts:
                            reuseOffer.map { displayedOffer in
                                {
                                    guard let currentOffer =
                                            catalogUpgradeEvidenceReuseOffer(
                                                for: selection
                                            ),
                                          currentOffer
                                            == displayedOffer,
                                          let snapshot =
                                            currentOffer.makeSnapshot(
                                                for: selection
                                            ) else {
                                        errorRecovery = nil
                                        errorMessage =
                                            "Previously verified upgrade evidence changed or is no longer eligible. Review the car again or continue without reuse."
                                        return
                                    }
                                    step = .discipline(
                                        selection.carInput,
                                        origin: .catalog(
                                            selection,
                                            reusedUpgradeSnapshot:
                                                snapshot
                                        ),
                                        thumbnailData: nil
                                    )
                                }
                            },
                        onEditValues: {
                            step = .catalogEdit(selection)
                        }
                    )
                case .catalogEdit(let selection):
                    ManualEntryView(
                        draft: ManualEntryDraft(car: selection.carInput),
                        onCancel: { step = .catalogReview(selection) },
                        onContinue: { input in
                            step = .discipline(
                                input,
                                origin: .manual(input),
                                thumbnailData: nil
                            )
                        }
                    )
                case .ocrReview(let draft):
                    OCRConfirmationView(
                        draft: draft,
                        onBack: { step = .newTune },
                        onUseManualEntry: { draft in
                            step = .manualEntry(draft.manualEntryFallback(), thumbnailData: draft.thumbnailData)
                        },
                        onContinue: { input, confirmedDraft in
                            step = .discipline(
                                input,
                                origin: .ocr(confirmedDraft),
                                thumbnailData: confirmedDraft.thumbnailData
                            )
                        }
                    )
                case .manualEntry(let draft, let thumbnailData):
                    ManualEntryView(
                        draft: draft,
                        onCancel: { step = .newTune },
                        onContinue: { input in
                            step = .discipline(
                                input,
                                origin: .manual(input),
                                thumbnailData: thumbnailData
                            )
                        }
                    )
                case .discipline(let input, let origin, let thumbnailData):
                    DisciplinePickerView(
                        car: input,
                        onBack: { step = origin.previousStep(thumbnailData: thumbnailData) },
                        onSelect: { discipline in
                            generateTune(
                                for: input,
                                discipline: discipline,
                                origin: origin,
                                thumbnailData: thumbnailData
                            )
                        }
                    )
                case .loading(let request, let thumbnailData, let savedTuneID, let playerNotes, let partialTune):
                    if let partialTune {
                        resultView(
                            tune: partialTune,
                            savedTuneID: savedTuneID,
                            adjustmentChanges: [],
                            thumbnailData: thumbnailData,
                            playerNotes: playerNotes,
                            isStreaming: true
                        )
                    } else {
                        TuneLoadingView(request: request)
                            .overlay(alignment: .bottom) {
                                if thumbnailData != nil {
                                    Label("Screenshot saved with this tune", systemImage: "photo")
                                        .font(.caption.weight(.semibold))
                                        .padding(.bottom, 24)
                                        .foregroundStyle(.secondary)
                                }
                            }
                    }
                case .result(let tune, let savedTuneID, let adjustmentChanges, let thumbnailData, let playerNotes):
                    resultView(
                        tune: tune,
                        savedTuneID: savedTuneID,
                        adjustmentChanges: adjustmentChanges,
                        thumbnailData: thumbnailData,
                        playerNotes: playerNotes
                    )
                case .fh6TuneMenuCapture(let tune, let savedTuneID, let thumbnailData, let playerNotes):
                    if let snapshot = tune.request.buildSnapshot {
                        FH6TuneMenuCaptureView(
                            tune: tune,
                            snapshot: snapshot,
                            onBack: {
                                step = .result(
                                    tune,
                                    savedTuneID: savedTuneID,
                                    adjustmentChanges: [],
                                    thumbnailData: thumbnailData,
                                    playerNotes: playerNotes
                                )
                            },
                            onSubmit: { capture in
                                applyFH6TuneMenuCapture(
                                    capture,
                                    to: tune,
                                    savedTuneID: savedTuneID,
                                    thumbnailData: thumbnailData,
                                    playerNotes: playerNotes
                                )
                            }
                        )
                    } else {
                        ContentUnavailableView(
                            "Build snapshot unavailable",
                            systemImage: "exclamationmark.triangle",
                            description: Text("Return to the tune and select an untouched FH6 catalog car.")
                        )
                    }
                case .tirePressureCapture(let tune, let savedTuneID, let thumbnailData, let playerNotes):
                    if let snapshot = tune.request.buildSnapshot {
                        TirePressureCaptureView(
                            tune: tune,
                            snapshot: snapshot,
                            onBack: {
                                step = .result(
                                    tune,
                                    savedTuneID: savedTuneID,
                                    adjustmentChanges: [],
                                    thumbnailData: thumbnailData,
                                    playerNotes: playerNotes
                                )
                            },
                            onSubmit: { capture in
                                applyTirePressureCapture(
                                    capture,
                                    to: tune,
                                    savedTuneID: savedTuneID,
                                    thumbnailData: thumbnailData,
                                    playerNotes: playerNotes
                                )
                            }
                        )
                    } else {
                        ContentUnavailableView(
                            "Build snapshot unavailable",
                            systemImage: "exclamationmark.triangle",
                            description: Text("Return to the tune and select a verified catalog car.")
                        )
                    }
                case .upgradePartCapture(let tune, let savedTuneID, let thumbnailData, let playerNotes):
                    if let snapshot = tune.request.buildSnapshot {
                        UpgradePartCaptureView(
                            tune: tune,
                            snapshot: snapshot,
                            onBack: {
                                step = .result(
                                    tune,
                                    savedTuneID: savedTuneID,
                                    adjustmentChanges: [],
                                    thumbnailData: thumbnailData,
                                    playerNotes: playerNotes
                                )
                            },
                            onSubmit: { capture in
                                applyUpgradePartCapture(
                                    capture,
                                    to: tune,
                                    savedTuneID: savedTuneID,
                                    thumbnailData: thumbnailData,
                                    playerNotes: playerNotes
                                )
                            }
                        )
                    } else {
                        ContentUnavailableView(
                            "Build snapshot unavailable",
                            systemImage: "exclamationmark.triangle",
                            description: Text("Return to the tune and select a verified catalog car.")
                        )
                    }
                case .fh5ResearchCapture(let tune, let savedTuneID, let thumbnailData, let playerNotes):
                    if let snapshot = tune.request.buildSnapshot {
                        FH5ResearchCaptureView(
                            tune: tune,
                            snapshot: snapshot,
                            onBack: {
                                step = .result(
                                    tune,
                                    savedTuneID: savedTuneID,
                                    adjustmentChanges: [],
                                    thumbnailData: thumbnailData,
                                    playerNotes: playerNotes
                                )
                            },
                            onSubmit: { capture in
                                recordFH5ResearchObservation(
                                    capture,
                                    for: tune,
                                    savedTuneID: savedTuneID,
                                    thumbnailData: thumbnailData,
                                    playerNotes: playerNotes
                                )
                            }
                        )
                    } else {
                        ContentUnavailableView(
                            "Catalog snapshot unavailable",
                            systemImage: "exclamationmark.triangle",
                            description: Text("Return to the saved FH5 plan and choose an untouched catalog car.")
                        )
                    }
                case .fh5ControlledExperimentCapture(
                    let tune,
                    let savedTuneID,
                    let researchRecord,
                    let candidateTrialAvailable,
                    let thumbnailData,
                    let playerNotes
                ):
                    if candidateTrialAvailable {
                        FH5CandidateTrialCaptureView(
                            tune: tune,
                            researchRecord: researchRecord,
                            onBack: {
                                step = .result(
                                    tune,
                                    savedTuneID: savedTuneID,
                                    adjustmentChanges: [],
                                    thumbnailData: thumbnailData,
                                    playerNotes: playerNotes
                                )
                            },
                            onLockCandidate: { input, surface in
                                try makeFH5CandidateTrialArtifact(
                                    for: tune,
                                    savedTuneID: savedTuneID,
                                    input: input,
                                    surface: surface
                                )
                            },
                            onSubmit: { submission in
                                recordFH5CandidateTrial(
                                    submission,
                                    for: tune,
                                    savedTuneID: savedTuneID,
                                    thumbnailData: thumbnailData,
                                    playerNotes: playerNotes
                                )
                            }
                        )
                    } else {
                        FH5ControlledExperimentCaptureView(
                            tune: tune,
                            researchRecord: researchRecord,
                            onBack: {
                                step = .result(
                                    tune,
                                    savedTuneID: savedTuneID,
                                    adjustmentChanges: [],
                                    thumbnailData: thumbnailData,
                                    playerNotes: playerNotes
                                )
                            },
                            onSubmit: { capture in
                                recordFH5ControlledExperiment(
                                    capture,
                                    for: tune,
                                    savedTuneID: savedTuneID,
                                    thumbnailData: thumbnailData,
                                    playerNotes: playerNotes
                                )
                            }
                        )
                    }
                case .recordTestDrive(let tune, let savedTuneID, let thumbnailData, let playerNotes):
                    FirstPartyValidationCaptureView(
                        tune: tune,
                        onBack: {
                            step = .result(
                                tune,
                                savedTuneID: savedTuneID,
                                adjustmentChanges: [],
                                thumbnailData: thumbnailData,
                                playerNotes: playerNotes
                            )
                        },
                        onSubmit: { capture in
                            recordTestDrive(
                                capture,
                                for: tune,
                                savedTuneID: savedTuneID,
                                thumbnailData: thumbnailData,
                                playerNotes: playerNotes
                            )
                        }
                    )
                case .fh6CommunityReferenceTrialCapture(
                    let tune,
                    let savedTuneID,
                    let thumbnailData,
                    let playerNotes
                ):
                    FH6CommunityReferenceTrialCaptureView(
                        tune: tune,
                        onBack: {
                            step = .result(
                                tune,
                                savedTuneID: savedTuneID,
                                adjustmentChanges: [],
                                thumbnailData: thumbnailData,
                                playerNotes: playerNotes
                            )
                        },
                        onSubmit: { capture in
                            recordFH6CommunityReferenceTrial(
                                capture,
                                for: tune,
                                savedTuneID: savedTuneID,
                                thumbnailData: thumbnailData,
                                playerNotes: playerNotes
                            )
                        }
                    )
                case .editSavedTune(let tune, let savedTuneID, let playerNotes, let thumbnailData):
                    SavedTuneEditView(
                        draft: SavedTuneEditDraft(tune: tune, playerNotes: playerNotes),
                        onCancel: {
                            step = .result(
                                tune,
                                savedTuneID: savedTuneID,
                                adjustmentChanges: [],
                                thumbnailData: thumbnailData,
                                playerNotes: playerNotes
                            )
                        },
                        onSave: { draft in
                            saveEditedTune(
                                originalTune: tune,
                                savedTuneID: savedTuneID,
                                draft: draft,
                                thumbnailData: thumbnailData,
                                shouldRetune: false
                            )
                        },
                        onSaveAndRetune: { draft in
                            saveEditedTune(
                                originalTune: tune,
                                savedTuneID: savedTuneID,
                                draft: draft,
                                thumbnailData: thumbnailData,
                                shouldRetune: true
                            )
                        }
                    )
                }
            }
            .alert("Tune update failed", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { clearError() } }
            )) {
                if let errorRecovery {
                    Button("Retry") {
                        retry(errorRecovery)
                    }
                }
                Button("OK", role: .cancel) {
                    clearError()
                }
            } message: {
                Text(errorMessage ?? "Try again from the discipline picker.")
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        firstSavedSetupCopilotHandoff
                            .prepareForCopilotPresentation()
                        rootSheet = .copilot
                    } label: {
                        Image(systemName: "sparkles")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel("Open contextual Copilot")
                    .accessibilityHint("Shows guidance for the current workflow step")
                    .accessibilityIdentifier("copilotButton")
                }
            }
            .sheet(item: $rootSheet) { sheet in
                switch sheet {
                case .settings:
                    SettingsView(keychainStore: keychainStore)
                case .copilot:
                    CopilotSheet(
                        context: copilotContext,
                        onAction: performCopilotAction,
                        onClose: { rootSheet = nil }
                    )
                case .betaMissions:
                    BetaValidationMissionsView(
                        board: betaValidationMissionBoard,
                        onSelect: openBetaValidationMission
                    )
                }
            }
            .tint(ForzAdvisorTheme.accent)
        }
    }

    private var copilotContext: CopilotContext {
        let sequence = currentCopilotAccuracySequence
        return CopilotContextFactory().make(
            step: step,
            savedTuneCount: savedTunes.count,
            catalogCarCount: catalogCarCount,
            fh5ResearchLabEligible: currentFH5ResearchLabEligible,
            fh5ObservationRecorded: currentFH5ObservationRecorded,
            fh5CandidateTrialAvailable:
                currentFH5CandidateTrialAvailable,
            workflowActionsPermitted:
                sequence.hasAuthoritativeSnapshot,
            fh6RecordTestDriveEligible:
                sequence.action == .openRecordTestDrive,
            fh6CommunityReferenceTrialEligible:
                sequence.action
                    == .openFH6CommunityReferenceTrial
        )
    }

    private func catalogUpgradeEvidenceReuseOffer(
        for selection: CatalogCarSelection
    ) -> CatalogUpgradeEvidenceReuseOffer? {
        CatalogUpgradeEvidenceReuseResolver().offer(
            for: selection,
            savedTunes: savedTunes.compactMap(\.tuneResult)
        )
    }

    private var currentCopilotAccuracySequence: (
        hasAuthoritativeSnapshot: Bool,
        action: CopilotAction?
    ) {
        guard case .result(
            let displayedTune,
            let savedTuneID,
            _,
            _,
            _
        ) = step,
        let savedTuneID,
        let snapshot =
            try? CopilotPersistedActionSnapshotResolver()
                .resolve(
                    displayedTune: displayedTune,
                    savedTuneID: savedTuneID,
                    in: modelContext
                ) else {
            return (false, nil)
        }
        return (
            true,
            CopilotWorkflowActionRouter()
                .authoritativeAction(
                    for: snapshot,
                    savedTuneID: savedTuneID
                )
        )
    }

    private var currentFH5ResearchLabEligible: Bool {
        guard case .result(let tune, let savedTuneID, _, _, _) = step,
              let savedTune = resolvedSavedTune(for: tune, savedTuneID: savedTuneID) else {
            return false
        }
        return CopilotContextFactory().fh5ResearchLabEligibility(
            for: tune,
            persistedTune: savedTune.tuneResult,
            isStreaming: false
        )
    }

    private var currentFH5ObservationRecorded: Bool {
        guard case .result(let tune, let savedTuneID, _, _, _) = step,
              let savedTune = resolvedSavedTune(for: tune, savedTuneID: savedTuneID) else {
            return false
        }
        return !savedTune.fh5ResearchObservationRecords(matching: tune).isEmpty
    }

    private var currentFH5CandidateTrialAvailable: Bool {
        guard case .result(let tune, let savedTuneID, _, _, _) = step,
              let savedTune = resolvedSavedTune(
                for: tune,
                savedTuneID: savedTuneID
              ),
              let persistedTune = savedTune.tuneResult else {
            return false
        }
        let researchRecords = savedTune
            .fh5ResearchObservationRecords(matching: persistedTune)
        let reviewInputs = savedTune
            .fh5ResearchReviewEntries(matching: persistedTune)
            .map { FH5ResearchReviewInput(entry: $0) }
        return (try? FH5CandidateTrialCoordinator().generate(
            tune: tune,
            savedTune: persistedTune,
            isStreaming: false,
            researchRecords: researchRecords,
            reviewInputs: reviewInputs,
            input: .controller,
            surface: .dry
        )) != nil
    }

    private var catalogCarCount: Int {
        guard case .success(let snapshot) = catalogResult else { return 0 }
        return snapshot.entries.count
    }

    private var betaValidationMissionBoard: BetaValidationMissionBoard {
        BetaValidationMissionPlanner().makeBoard(savedTunes: savedTunes)
    }

    private func emptyGarageFirstWinAction(
        for board: BetaValidationMissionBoard
    ) -> (() -> Void)? {
        guard savedTunes.isEmpty,
              board.emptyGarageFirstWinMission != nil else {
            return nil
        }
        return {
            guard savedTunes.isEmpty,
                  let mission =
                    betaValidationMissionBoard.emptyGarageFirstWinMission else {
                return
            }
            openBetaValidationMission(mission)
        }
    }

    @ViewBuilder
    private func resultView(
        tune: TuneResult,
        savedTuneID: UUID?,
        adjustmentChanges: [TuneAdjustmentChange],
        thumbnailData: Data?,
        playerNotes: String,
        isStreaming: Bool = false
    ) -> some View {
        let resolvedSavedTune = resolvedSavedTune(for: tune, savedTuneID: savedTuneID)
        let resolvedSavedTuneID = isStreaming ? savedTuneID : (resolvedSavedTune?.id ?? savedTuneID)
        let resolvedThumbnailData = resolvedSavedTune?.thumbnailData ?? thumbnailData
        let resolvedPlayerNotes = resolvedSavedTune?.playerNotes ?? playerNotes
        let persistedTune = resolvedSavedTune?.tuneResult
        let validationEligibility = FirstPartyValidationRecordFactory().eligibility(
            for: tune,
            savedTune: persistedTune,
            isStreaming: isStreaming
        )
        let latestValidationRecord = resolvedSavedTune?
            .validationRecords(matching: tune)
            .last
        let validationReviewState: (
            entries: [FH6ValidationReviewEntry],
            loadError: String?
        ) = {
            guard let resolvedSavedTune else { return ([], nil) }
            do {
                return (
                    try resolvedSavedTune.fh6ValidationReviewEntries(
                        matching: tune
                    ),
                    nil
                )
            } catch {
                return ([], error.localizedDescription)
            }
        }()
        let communityTrialEligibility =
            FH6CommunityReferenceTrialFactory().eligibility(
                for: tune,
                savedTune: persistedTune,
                isStreaming: isStreaming
            )
        let communityTrialState: (
            records: [FH6CommunityReferenceTrialRecord],
            loadError: String?
        ) = {
            guard let resolvedSavedTune else { return ([], nil) }
            do {
                return (
                    try resolvedSavedTune
                        .fh6CommunityReferenceTrialRecords(
                            matching: tune
                        ),
                    nil
                )
            } catch {
                return ([], error.localizedDescription)
            }
        }()
        let accuracyEvidenceChain:
            FH6AccuracyEvidenceChainAssessment? = {
            guard tune.request.car.game == .fh6 else {
                return nil
            }
            guard let resolvedSavedTune else {
                return FH6AccuracyEvidenceChainPolicy().assess(
                    tune: tune,
                    savedTune: nil,
                    isStreaming: isStreaming,
                    validationRecords: [],
                    communityComparisonRecords: []
                )
            }
            return try? resolvedSavedTune
                .fh6AccuracyEvidenceChain(matching: tune)
        }()
        let communityOutcomeReviewState: (
            entries: [FH6CommunityOutcomeReviewEntry],
            report: FH6CommunityOutcomeCollectionReport,
            loadError: String?
        ) = {
            guard let resolvedSavedTune else {
                return ([], .empty, nil)
            }
            do {
                return (
                    try resolvedSavedTune
                        .allFH6CommunityOutcomeReviewEntries(),
                    try resolvedSavedTune
                        .fh6CommunityOutcomeCollectionReport(
                            matching: tune
                        ),
                    nil
                )
            } catch {
                return ([], .empty, error.localizedDescription)
            }
        }()
        let independentValidationReviewPacketState: (
            canPrepare: Bool,
            preparedInputStateFingerprint: String?
        ) = {
            guard let resolvedSavedTune,
                  let persistedTune,
                  validationEligibility.isSuccess,
                  let firstPartyTestDrives =
                    try? resolvedSavedTune
                        .allFirstPartyValidationRecords(),
                  let localCommunityOutcomes =
                    try? resolvedSavedTune
                        .allFH6CommunityReferenceTrialRecords(),
                  let reviewedCommunityOutcomes =
                    try? resolvedSavedTune
                        .allFH6CommunityOutcomeReviewEntries() else {
                return (false, nil)
            }
            let exporter =
                FH6IndependentValidationReviewPacketExporter()
            let preparedInputStateFingerprint =
                try? exporter.preparedInputStateFingerprint(
                    candidate: tune,
                    persistedCandidate: persistedTune,
                    isStreaming: isStreaming,
                    firstPartyTestDrives: firstPartyTestDrives,
                    localCommunityOutcomes:
                        localCommunityOutcomes,
                    reviewedCommunityOutcomes:
                        reviewedCommunityOutcomes
                )
            let canPrepare = (
                try? exporter.makeArtifact(
                    candidate: tune,
                    persistedCandidate: persistedTune,
                    isStreaming: isStreaming,
                    firstPartyTestDrives: firstPartyTestDrives,
                    localCommunityOutcomes:
                        localCommunityOutcomes,
                    reviewedCommunityOutcomes:
                        reviewedCommunityOutcomes
                )
            ) != nil
            return (
                canPrepare,
                preparedInputStateFingerprint
            )
        }()
        let independentValidationReceiverCandidateFingerprint:
            String? = {
            guard resolvedSavedTuneID != nil else {
                return nil
            }
            return FH6IndependentValidationReviewReceiverEligibility()
                .candidateRevisionFingerprint(
                    candidate: tune,
                    persistedCandidate: persistedTune,
                    isStreaming: isStreaming
                )
        }()
        let validateIndependentValidationReviewPacket:
            ((Data) throws ->
                FH6IndependentValidationReviewPacket)? = {
            guard independentValidationReceiverCandidateFingerprint
                    != nil,
                  let resolvedSavedTuneID else {
                return nil
            }
            return { data in
                try validateFH6IndependentValidationReviewPacket(
                    data: data,
                    displayedTune: tune,
                    savedTuneID: resolvedSavedTuneID
                )
            }
        }()
        let researchEligibility = FH5ResearchEligibility().snapshot(
            for: tune,
            savedTune: persistedTune,
            isStreaming: isStreaming
        )
        let researchRecords = resolvedSavedTune?
            .fh5ResearchObservationRecords(matching: tune) ?? []
        let latestResearchRecord = researchRecords.last
        let researchReviewEntries = resolvedSavedTune?
            .fh5ResearchReviewEntries(matching: tune) ?? []
        let researchReviewReport = resolvedSavedTune?
            .fh5ResearchReviewReport(matching: tune) ?? .empty
        let experimentRecords = resolvedSavedTune?
            .fh5ControlledExperimentRecords(
                matching: tune,
                researchRecord: latestResearchRecord
            ) ?? []
        let latestExperimentRecord = experimentRecords.last
        let experimentEligibility = FH5ControlledExperimentFactory().eligibility(
            tune: tune,
            savedTune: persistedTune,
            isStreaming: isStreaming,
            researchRecords: researchRecords
        )
        let candidateTrialArtifact = try? FH5CandidateTrialCoordinator()
            .generate(
                tune: tune,
                savedTune: persistedTune,
                isStreaming: isStreaming,
                researchRecords: researchRecords,
                reviewInputs: researchReviewEntries.map {
                    FH5ResearchReviewInput(entry: $0)
                },
                input:
                    latestExperimentRecord?.candidateBinding == nil
                    ? .controller
                    : latestExperimentRecord?.context.input
                        ?? .controller,
                surface:
                    latestExperimentRecord?.candidateBinding == nil
                    ? .dry
                    : latestExperimentRecord?.context.surface
                        ?? .dry
            )
        let candidateOutcomeReviewState: (
            entries: [FH5CandidateOutcomeReviewEntry],
            report: FH5CandidateOutcomeCollectionReport,
            loadError: String?
        ) = {
            guard let resolvedSavedTune,
                  let candidateTrialArtifact else {
                return ([], .empty, nil)
            }
            do {
                return (
                    try resolvedSavedTune
                        .allFH5CandidateOutcomeReviewEntries(),
                    try resolvedSavedTune
                        .fh5CandidateOutcomeCollectionReport(
                            matching: candidateTrialArtifact
                        ),
                    nil
                )
            } catch {
                return ([], .empty, error.localizedDescription)
            }
        }()
        let candidateOutcomeReport: FH5ControlledOutcomePolicyReport? = {
            guard let binding =
                    latestExperimentRecord?.candidateBinding else {
                return nil
            }
            return FH5ControlledOutcomeEvaluator().evaluate(
                records: experimentRecords,
                tune: tune,
                researchRecord: latestResearchRecord,
                candidateBinding: binding,
                registry: .experimentalCandidateCollection
            )
        }()
        let controlledOutcomeReport = FH5ControlledExperimentFactory()
            .outcomePolicyReport(
                records: experimentRecords,
                tune: tune,
                researchRecord: latestResearchRecord
            )
        let fh5NumericReadiness = tune.request.car.game == .fh5
            ? FH5NumericReadinessPolicy().assess(
                tune: tune,
                researchRecords: researchRecords,
                reviewReport: researchReviewReport,
                controlledOutcomeReport: controlledOutcomeReport
            )
            : nil

        TuneResultView(
            tune: tune,
            isSaved: resolvedSavedTuneID != nil,
            isStreaming: isStreaming,
            playerNotes: resolvedPlayerNotes,
            thumbnailData: resolvedThumbnailData,
            adjustmentChanges: adjustmentChanges,
            activeFeedback: tuneWorkflow.activeFeedback(for: resolvedSavedTuneID),
            showsFirstSavedSetupCopilotHandoff:
                firstSavedSetupCopilotHandoff.isPresented(
                    for: resolvedSavedTuneID
                ),
            onContinueFirstSavedSetupWithCopilot: {
                firstSavedSetupCopilotHandoff
                    .prepareForCopilotPresentation()
                rootSheet = .copilot
            },
            onDismissFirstSavedSetupCopilotHandoff: {
                firstSavedSetupCopilotHandoff.consume()
            },
            onDone: {
                firstSavedSetupCopilotHandoff.consume()
                cancelActiveTuneWork()
                step = .home
            },
            onSave: {
                let wasGarageEmpty = savedTunes.isEmpty
                if let savedTuneID = save(
                    tune,
                    playerNotes: resolvedPlayerNotes,
                    thumbnailData: resolvedThumbnailData
                ) {
                    firstSavedSetupCopilotHandoff.recordSaveResult(
                        savedTuneID: savedTuneID,
                        wasGarageEmpty: wasGarageEmpty
                    )
                    step = .result(
                        tune,
                        savedTuneID: savedTuneID,
                        adjustmentChanges: [],
                        thumbnailData: resolvedThumbnailData,
                        playerNotes: resolvedPlayerNotes
                    )
                }
            },
            onEdit: {
                guard let resolvedSavedTuneID else { return }
                tuneWorkflow.cancelAdjustment()
                step = .editSavedTune(
                    tune,
                    savedTuneID: resolvedSavedTuneID,
                    playerNotes: resolvedPlayerNotes,
                    thumbnailData: resolvedThumbnailData
                )
            },
            onVerifyTuneMenu: eligibleFH6TuneMenuCaptureSnapshot(for: tune) == nil ? nil : {
                tuneWorkflow.cancelAdjustment()
                step = .fh6TuneMenuCapture(
                    tune,
                    savedTuneID: resolvedSavedTuneID,
                    thumbnailData: resolvedThumbnailData,
                    playerNotes: resolvedPlayerNotes
                )
            },
            onVerifyTirePressures:
                eligibleFH6TuneMenuCaptureSnapshot(for: tune) != nil
                || eligibleTireCaptureSnapshot(for: tune) == nil
                ? nil : {
                tuneWorkflow.cancelAdjustment()
                step = .tirePressureCapture(
                    tune,
                    savedTuneID: resolvedSavedTuneID,
                    thumbnailData: resolvedThumbnailData,
                    playerNotes: resolvedPlayerNotes
                )
            },
            onVerifyUpgradeParts: eligibleUpgradeCaptureSnapshot(for: tune) == nil ? nil : {
                tuneWorkflow.cancelAdjustment()
                step = .upgradePartCapture(
                    tune,
                    savedTuneID: resolvedSavedTuneID,
                    thumbnailData: resolvedThumbnailData,
                    playerNotes: resolvedPlayerNotes
                )
            },
            latestFH5ResearchRecord: latestResearchRecord,
            fh5NumericReadiness: fh5NumericReadiness,
            onOpenFH5Research: researchEligibility.isSuccess && resolvedSavedTuneID != nil ? {
                guard let resolvedSavedTuneID else { return }
                tuneWorkflow.cancelAdjustment()
                step = .fh5ResearchCapture(
                    tune,
                    savedTuneID: resolvedSavedTuneID,
                    thumbnailData: resolvedThumbnailData,
                    playerNotes: resolvedPlayerNotes
                )
            } : nil,
            onDeleteFH5ResearchRecord: { record in
                guard let resolvedSavedTuneID else { return }
                deleteFH5ResearchObservationRecord(record, savedTuneID: resolvedSavedTuneID)
            },
            fh5ResearchReviewEntries: researchReviewEntries,
            onImportFH5ResearchReviewEntry:
                tune.request.car.game == .fh5 && resolvedSavedTuneID != nil
                ? { entry in
                    guard let resolvedSavedTuneID else {
                        return ContentWorkflowError.missingSavedTune.localizedDescription
                    }
                    return importFH5ResearchReviewEntry(
                        entry,
                        savedTuneID: resolvedSavedTuneID
                    )
                }
                : nil,
            onDeleteFH5ResearchReviewEntry: { entry in
                guard let resolvedSavedTuneID else { return }
                deleteFH5ResearchReviewEntry(
                    entry,
                    savedTuneID: resolvedSavedTuneID
                )
            },
            latestFH5ControlledExperimentRecord: latestExperimentRecord,
            fh5CandidateTrialAvailable: candidateTrialArtifact != nil,
            fh5CandidateOutcomeReport: candidateOutcomeReport,
            fh5CandidateTrialArtifact: candidateTrialArtifact,
            fh5CandidateOutcomeReviewEntries:
                candidateOutcomeReviewState.entries,
            fh5CandidateOutcomeCollectionReport:
                candidateOutcomeReviewState.report,
            fh5CandidateOutcomeReviewLoadError:
                candidateOutcomeReviewState.loadError,
            onImportFH5CandidateOutcomeReviewEntry:
                resolvedSavedTuneID != nil
                    && candidateTrialArtifact != nil
                ? { entry in
                    guard let resolvedSavedTuneID else {
                        return ContentWorkflowError
                            .missingSavedTune.localizedDescription
                    }
                    return importFH5CandidateOutcomeReviewEntry(
                        entry,
                        savedTuneID: resolvedSavedTuneID
                    )
                }
                : nil,
            onDeleteFH5CandidateOutcomeReviewEntry: {
                entry in
                guard let resolvedSavedTuneID else { return }
                deleteFH5CandidateOutcomeReviewEntry(
                    entry,
                    savedTuneID: resolvedSavedTuneID
                )
            },
            onOpenFH5ControlledExperiment:
                experimentEligibility.isSuccess && resolvedSavedTuneID != nil
                ? {
                    guard let resolvedSavedTuneID,
                          case .success(let researchRecord) = experimentEligibility else {
                        return
                    }
                    tuneWorkflow.cancelAdjustment()
                    step = .fh5ControlledExperimentCapture(
                        tune,
                        savedTuneID: resolvedSavedTuneID,
                        researchRecord: researchRecord,
                        candidateTrialAvailable:
                            candidateTrialArtifact != nil,
                        thumbnailData: resolvedThumbnailData,
                        playerNotes: resolvedPlayerNotes
                    )
                }
                : nil,
            onDeleteFH5ControlledExperimentRecord: { record in
                guard let resolvedSavedTuneID else { return }
                deleteFH5ControlledExperimentRecord(
                    record,
                    savedTuneID: resolvedSavedTuneID
                )
            },
            latestValidationRecord: latestValidationRecord,
            onRecordTestDrive: validationEligibility.isSuccess && resolvedSavedTuneID != nil ? {
                guard let resolvedSavedTuneID else { return }
                tuneWorkflow.cancelAdjustment()
                step = .recordTestDrive(
                    tune,
                    savedTuneID: resolvedSavedTuneID,
                    thumbnailData: resolvedThumbnailData,
                    playerNotes: resolvedPlayerNotes
                )
            } : nil,
            onDeleteValidationRecord: { record in
                guard let resolvedSavedTuneID else { return }
                deleteValidationRecord(record, savedTuneID: resolvedSavedTuneID)
            },
            fh6ValidationReviewEntries: validationReviewState.entries,
            fh6ValidationReviewLoadError: validationReviewState.loadError,
            onImportFH6ValidationReviewEntry:
                validationEligibility.isSuccess && resolvedSavedTuneID != nil
                ? { entry in
                    guard let resolvedSavedTuneID else {
                        return ContentWorkflowError.missingSavedTune
                            .localizedDescription
                    }
                    return importFH6ValidationReviewEntry(
                        entry,
                        savedTuneID: resolvedSavedTuneID
                    )
                }
                : nil,
            onDeleteFH6ValidationReviewEntry: { entry in
                guard let resolvedSavedTuneID else { return }
                deleteFH6ValidationReviewEntry(
                    entry,
                    savedTuneID: resolvedSavedTuneID
                )
            },
            onPrepareFH6IndependentValidationReviewPacket:
                independentValidationReviewPacketState.canPrepare
                    && resolvedSavedTuneID != nil
                ? {
                    guard let resolvedSavedTuneID else {
                        throw ContentWorkflowError.missingSavedTune
                    }
                    return try prepareFH6IndependentValidationReviewPacket(
                        displayedTune: tune,
                        savedTuneID: resolvedSavedTuneID
                    )
                }
                : nil,
            fh6IndependentValidationPreparedInputStateFingerprint:
                independentValidationReviewPacketState
                    .preparedInputStateFingerprint,
            onValidateFH6IndependentValidationReviewPacket:
                validateIndependentValidationReviewPacket,
            fh6IndependentValidationReceiverCandidateFingerprint:
                independentValidationReceiverCandidateFingerprint,
            fh6CommunityReferenceTrialRecords:
                communityTrialState.records,
            fh6AccuracyEvidenceChain:
                accuracyEvidenceChain,
            fh6CommunityReferenceTrialLoadError:
                communityTrialState.loadError,
            onRunFH6CommunityReferenceTrial:
                communityTrialEligibility.isSuccess
                    && accuracyEvidenceChain?
                        .permitsCommunityComparison == true
                    && resolvedSavedTuneID != nil
                ? {
                    guard let resolvedSavedTuneID else { return }
                    openFH6CommunityReferenceTrial(
                        savedTuneID: resolvedSavedTuneID,
                        requiresNoCurrentTrial: false
                    )
                }
                : nil,
            onDeleteFH6CommunityReferenceTrialRecord: { record in
                guard let resolvedSavedTuneID else { return }
                deleteFH6CommunityReferenceTrialRecord(
                    record,
                    savedTuneID: resolvedSavedTuneID
                )
            },
            fh6CommunityOutcomeReviewEntries:
                communityOutcomeReviewState.entries,
            fh6CommunityOutcomeCollectionReport:
                communityOutcomeReviewState.report,
            fh6CommunityOutcomeReviewLoadError:
                communityOutcomeReviewState.loadError,
            onImportFH6CommunityOutcomeReviewEntry:
                communityTrialEligibility.isSuccess
                    && resolvedSavedTuneID != nil
                ? { entry in
                    guard let resolvedSavedTuneID else {
                        return ContentWorkflowError
                            .missingSavedTune.localizedDescription
                    }
                    return importFH6CommunityOutcomeReviewEntry(
                        entry,
                        savedTuneID: resolvedSavedTuneID
                    )
                }
                : nil,
            onValidateFH6CommunityOutcomeReviewJSON:
                communityTrialEligibility.isSuccess
                    && resolvedSavedTuneID != nil
                ? { data in
                    guard let resolvedSavedTuneID else {
                        return ContentWorkflowError
                            .missingSavedTune.localizedDescription
                    }
                    return validateFH6CommunityOutcomeReviewJSON(
                        data,
                        displayedTune: tune,
                        savedTuneID: resolvedSavedTuneID
                    )
                }
                : nil,
            onDeleteFH6CommunityOutcomeReviewEntry: { entry in
                guard let resolvedSavedTuneID else { return }
                deleteFH6CommunityOutcomeReviewEntry(
                    entry,
                    savedTuneID: resolvedSavedTuneID
                )
            },
            onFeedback: { feedback in
                guard let resolvedSavedTuneID else { return }
                adjust(tune, savedTuneID: resolvedSavedTuneID, feedback: feedback)
            }
        )
    }
}

private extension Result {
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}

enum RootSheet: String, CaseIterable, Identifiable {
    case settings
    case copilot
    case betaMissions

    var id: String { rawValue }
}
