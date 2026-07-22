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
    @State var isShowingSettings = false
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
                        onSettings: { isShowingSettings = true }
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
                        onContinue: { input in
                            step = .discipline(
                                input,
                                origin: .ocr(draft),
                                thumbnailData: draft.thumbnailData
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
            .sheet(isPresented: $isShowingSettings) {
                SettingsView(keychainStore: keychainStore)
            }
            .tint(ForzAdvisorTheme.accent)
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
            onFeedback: { feedback in
                guard let resolvedSavedTuneID else { return }
                adjust(tune, savedTuneID: resolvedSavedTuneID, feedback: feedback)
            }
        )
    }
}
