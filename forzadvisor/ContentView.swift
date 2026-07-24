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
    @StateObject var tuneWorkflow = TuneWorkflowController()

    let keychainStore = KeychainStore()

    init() {}

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .home:
                    GarageHomeView(
                        savedTunes: savedTunes,
                        onNewTune: {
                            cancelActiveTuneWork()
                            step = .newTune
                        },
                        onOpenTune: open,
                        onDeleteTune: delete,
                        betaMissionCount:
                            betaValidationMissionBoard.progress.availableMissionCount,
                        onBetaMissions: { rootSheet = .betaMissions },
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
                        onManualEntry: {
                            step = .manualEntry(.empty, thumbnailData: nil)
                        },
                        onSelect: { selection in
                            step = .catalogReview(selection)
                        }
                    )
                case .catalogReview(let selection):
                    CarCatalogReviewView(
                        selection: selection,
                        onBack: {
                            step = .catalogPicker(initialGame: selection.entry.game)
                        },
                        onUseCar: {
                            step = .discipline(
                                selection.carInput,
                                origin: .catalog(selection),
                                thumbnailData: nil
                            )
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
        CopilotContextFactory().make(
            step: step,
            savedTuneCount: savedTunes.count,
            catalogCarCount: catalogCarCount,
            fh5ResearchLabEligible: currentFH5ResearchLabEligible,
            fh5ObservationRecorded: currentFH5ObservationRecorded,
            fh5CandidateTrialAvailable:
                currentFH5CandidateTrialAvailable
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
            onDone: {
                cancelActiveTuneWork()
                step = .home
            },
            onSave: {
                if let savedTuneID = save(
                    tune,
                    playerNotes: resolvedPlayerNotes,
                    thumbnailData: resolvedThumbnailData
                ) {
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
