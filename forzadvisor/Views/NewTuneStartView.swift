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
    let onCancel: () -> Void
    let onCatalog: () -> Void
    let onManualEntry: () -> Void
    let onDraftReady: OCRDraftReadyHandler

    @State private var selectedItem: PhotosPickerItem?
    @State private var isShowingCamera = false
    @StateObject private var photoImport: PhotoOCRImportController

    init(
        onCancel: @escaping () -> Void,
        onCatalog: @escaping () -> Void,
        onManualEntry: @escaping () -> Void,
        onDraftReady: @escaping OCRDraftReadyHandler,
        ocrService: any CarInputOCRService = VisionCarInputOCRService()
    ) {
        self.onCancel = onCancel
        self.onCatalog = onCatalog
        self.onManualEntry = onManualEntry
        self.onDraftReady = onDraftReady
        self._photoImport = StateObject(wrappedValue: PhotoOCRImportController(ocrService: ocrService))
    }

    var body: some View {
        List {
            Section {
                ForzAdvisorScreenHeader(
                    title: "New Tune",
                    subtitle: "Take or import a Forza performance screenshot, then confirm every value before tuning.",
                    systemImage: "camera.metering.matrix",
                    tint: ForzAdvisorTheme.warmAccent
                )
            }
            .listRowBackground(ForzAdvisorTheme.heroRowBackground)

            Section("Start") {
                Button(action: onCatalog) {
                    StartRow(
                        title: "Choose a Car",
                        subtitle: "Browse reviewed stock cars for FH5 or FH6.",
                        systemImage: "car.2"
                    )
                }
                .accessibilityIdentifier("catalogEntryButton")
                .buttonStyle(.plain)
                .forzAdvisorRowBackground()

                Button {
                    isShowingCamera = true
                } label: {
                    StartRow(
                        title: "Take Photo",
                        subtitle: "Capture the performance screen and run on-device OCR.",
                        systemImage: "camera"
                    )
                }
                .buttonStyle(.plain)
                .disabled(photoImport.isProcessingPhoto)
                .forzAdvisorRowBackground()

                PhotosPicker(selection: $selectedItem, matching: .images) {
                    StartRow(
                        title: "Import Screenshot",
                        subtitle: "Run on-device Vision OCR, then confirm every value.",
                        systemImage: "photo.badge.plus"
                    )
                }
                .disabled(photoImport.isProcessingPhoto)
                .forzAdvisorRowBackground()

                Button(action: startManualEntry) {
                    StartRow(
                        title: "Enter Manually",
                        subtitle: "Type weight, front %, PI, class, and drivetrain.",
                        systemImage: "keyboard"
                    )
                }
                .accessibilityIdentifier("manualEntryButton")
                .buttonStyle(.plain)
                .forzAdvisorRowBackground()
            }

            CaptureGuideSection()

            if photoImport.isProcessingPhoto {
                Section {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Reading image on device")
                            .foregroundStyle(.secondary)
                    }
                }
                .forzAdvisorRowBackground()
            }

            if let errorMessage = photoImport.errorMessage {
                Section("Photo OCR") {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(ForzAdvisorTheme.warning)
                    if let lastFailedImage = photoImport.lastFailedImage {
                        Button("Retry OCR") {
                            processCapturedPhoto(lastFailedImage)
                        }
                    }
                    Button("Enter manually", action: startManualEntry)
                }
                .forzAdvisorRowBackground()
            }
        }
        .navigationTitle("Tune Source")
        .forzAdvisorScreenChrome()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    photoImport.cancelPhotoImport()
                    selectedItem = nil
                    onCancel()
                }
            }
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
}

private struct CaptureGuideSection: View {
    private let fields = [
        ("Weight", "lb or kg"),
        ("Front weight", "%"),
        ("PI / Class", "A 750, S1 900"),
        ("Drivetrain", "FWD, RWD, AWD"),
        ("Power / Torque", "optional")
    ]

    var body: some View {
        Section("Capture Guide") {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(fields, id: \.0) { field, hint in
                    HStack(spacing: 10) {
                        ForzAdvisorIcon(
                            systemName: "checkmark",
                            tint: ForzAdvisorTheme.success,
                            size: 28
                        )
                        Text(field)
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(hint)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .forzAdvisorRowBackground()
    }
}

private struct StartRow: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            ForzAdvisorIcon(systemName: systemImage)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}
