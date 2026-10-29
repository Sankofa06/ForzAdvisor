//
//  NewTuneStartView.swift
//  forzadvisor
//
//  Starts a tune from camera capture, photo-library OCR, or manual entry, then
//  hands OCR results to OCRConfirmationView before tune generation.
//

import PhotosUI
import SwiftUI
import UIKit

typealias OCRDraftReadyHandler = @MainActor (OCRConfirmationDraft) -> Void

struct NewTuneStartView: View {
    let draftSession: TuneDraftSession?
    let onResume: () -> Void
    let onCancel: () -> Void
    let onManualEntry: () -> Void
    let onDraftReady: OCRDraftReadyHandler

    @State private var selectedItem: PhotosPickerItem?
    @State private var isShowingCamera = false
    @State private var isShowingPhotoPicker = false
    @State private var isShowingReplacementChoice = false
    @State private var pendingSource: NewTuneSource?
    @StateObject private var photoImport: PhotoOCRImportController

    init(
        draftSession: TuneDraftSession? = nil,
        onResume: @escaping () -> Void = {},
        onCancel: @escaping () -> Void,
        onManualEntry: @escaping () -> Void,
        onDraftReady: @escaping OCRDraftReadyHandler,
        ocrService: any CarInputOCRService = VisionCarInputOCRService()
    ) {
        self.draftSession = draftSession
        self.onResume = onResume
        self.onCancel = onCancel
        self.onManualEntry = onManualEntry
        self.onDraftReady = onDraftReady
        self._photoImport = StateObject(wrappedValue: PhotoOCRImportController(ocrService: ocrService))
    }

    var body: some View {
        List {
            Section {
                ForzAdvisorWorkflowProgress(step: .source)
                ForzAdvisorScreenHeader(
                    title: "New Tune",
                    subtitle: "Choose how to add your car. You can check and edit every value before tuning.",
                    systemImage: "camera.metering.matrix",
                    tint: ForzAdvisorTheme.warmAccent
                )
            }
            .listRowBackground(ForzAdvisorTheme.heroRowBackground)

            importStatusSection

            Section("Start") {
                if draftSession?.isMeaningful == true {
                    Button(action: onResume) {
                        Label("Resume New Tune", systemImage: "arrow.uturn.forward.circle.fill")
                            .frame(maxWidth: .infinity, minHeight: ForzAdvisorTheme.minimumTouchTarget, alignment: .leading)
                    }
                        .buttonStyle(ForzAdvisorActionButtonStyle(kind: .secondary))
                        .accessibilityHint("Continue the car details you already entered.")
                        .accessibilityIdentifier("resumeNewTuneButton")
                }
                Button {
                    request(.camera)
                } label: {
                    PrimaryStartCard(
                        title: "Take Photo",
                        subtitle: "Photograph the performance screen. Reading stays on this device.",
                        systemImage: "camera"
                    )
                }
                .buttonStyle(ForzAdvisorActionButtonStyle(kind: .primary))
                .accessibilityElement(children: .combine)
                .accessibilityHint("Opens the camera to photograph your car’s performance screen.")
                .disabled(photoImport.isProcessingPhoto)
                .accessibilityIdentifier("takePhotoPrimaryButton")
                .forzAdvisorRowBackground()

                Button {
                    request(.screenshot)
                } label: {
                    StartRow(
                        title: "Import Screenshot",
                        subtitle: "Choose a saved image. Reading stays on this device.",
                        systemImage: "photo.badge.plus"
                    )
                }
                .buttonStyle(.plain)
                .disabled(photoImport.isProcessingPhoto)
                .accessibilityIdentifier("importScreenshotButton")
                .forzAdvisorRowBackground()

                Button { request(.manual) } label: {
                    StartRow(
                        title: "Enter Manually",
                        subtitle: "Type the values shown on your car’s performance screen.",
                        systemImage: "keyboard"
                    )
                }
                .accessibilityIdentifier("manualEntryButton")
                .buttonStyle(.plain)
                .forzAdvisorRowBackground()
            }

            CaptureGuideSection()
        }
        .navigationTitle("Tune Source")
        .forzAdvisorScreenChrome()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if photoImport.isProcessingPhoto {
                    Button("Cancel OCR") {
                        photoImport.cancelPhotoImport()
                        selectedItem = nil
                    }
                } else {
                    Button("Close", action: onCancel)
                }
            }
        }
        .photosPicker(
            isPresented: $isShowingPhotoPicker,
            selection: $selectedItem,
            matching: .images
        )
        .confirmationDialog(
            "Replace your current New Tune draft?",
            isPresented: $isShowingReplacementChoice,
            titleVisibility: .visible
        ) {
            Button("Resume Current Draft", action: onResume)
            Button("Replace Draft", role: .destructive, action: performPendingSource)
            Button("Cancel", role: .cancel) { pendingSource = nil }
        } message: {
            Text("Replacing starts from a new photo, screenshot, or manual form. Close keeps the current draft available to resume.")
        }
        .onChange(of: selectedItem) { _, newItem in
            guard let newItem else { return }
            processPhoto(newItem)
        }
        .fullScreenCover(isPresented: $isShowingCamera) {
            CameraCaptureView(
                onCancel: { isShowingCamera = false },
                onUseManualEntry: {
                    isShowingCamera = false
                    startManualEntry()
                },
                onPhotoCaptured: { image in
                    isShowingCamera = false
                    processCapturedPhoto(image)
                }
            )
        }
        .onDisappear {
            photoImport.cancelPhotoImport()
            selectedItem = nil
        }
    }

    private func processPhoto(_ item: PhotosPickerItem) {
        photoImport.processPhotoData(
            loadData: {
                try await item.loadTransferable(type: Data.self)
            },
            failureMessage: "Could not read that screenshot. Try another photo or enter the values manually.",
            onFinish: { selectedItem = nil },
            onDraftReady: { draft in
                onDraftReady(draft)
            }
        )
    }

    private func processCapturedPhoto(_ image: UIImage) {
        photoImport.processCapturedPhoto(
            image,
            failureMessage: "Could not read that photo. Try another capture, import a screenshot, or enter the values manually.",
            onDraftReady: { draft in
                onDraftReady(draft)
            }
        )
    }

    private func startManualEntry() {
        photoImport.cancelPhotoImport()
        selectedItem = nil
        onManualEntry()
    }

    @ViewBuilder
    private var importStatusSection: some View {
        if photoImport.isProcessingPhoto {
            Section("Photo OCR") {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Reading image on this device")
                        .foregroundStyle(.secondary)
                }
                Button("Cancel OCR") {
                    photoImport.cancelPhotoImport()
                    selectedItem = nil
                }
            }
            .forzAdvisorRowBackground()
        } else if let errorMessage = photoImport.errorMessage {
            Section("Photo OCR needs attention") {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(ForzAdvisorTheme.warning)
                if let lastFailedImage = photoImport.lastFailedImage {
                    Button("Retry OCR") { processCapturedPhoto(lastFailedImage) }
                }
                Button("Enter Manually") { request(.manual) }
            }
            .forzAdvisorRowBackground()
        }
    }

    private func request(_ source: NewTuneSource) {
        guard draftSession?.isMeaningful == true else {
            perform(source)
            return
        }
        pendingSource = source
        isShowingReplacementChoice = true
    }

    private func performPendingSource() {
        guard let pendingSource else { return }
        self.pendingSource = nil
        perform(pendingSource)
    }

    private func perform(_ source: NewTuneSource) {
        switch source {
        case .camera: isShowingCamera = true
        case .screenshot: isShowingPhotoPicker = true
        case .manual: startManualEntry()
        }
    }
}

private enum NewTuneSource {
    case camera
    case screenshot
    case manual
}
