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

struct NewTuneStartView: View {
    let onCancel: () -> Void
    let onManualEntry: () -> Void
    let onDraftReady: (OCRConfirmationDraft) -> Void

    @State private var selectedItem: PhotosPickerItem?
    @State private var isShowingCamera = false
    @State private var isProcessingPhoto = false
    @State private var errorMessage: String?
    @State private var lastFailedImage: UIImage?

    private let ocrService = VisionCarInputOCRService()

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("New Tune")
                        .font(.title2.weight(.bold))
                    Text("Take or import a Forza performance screenshot, then confirm every value before tuning.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            CaptureGuideSection()

            Section("Start") {
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
                .disabled(isProcessingPhoto)

                PhotosPicker(selection: $selectedItem, matching: .images) {
                    StartRow(
                        title: "Import Screenshot",
                        subtitle: "Run on-device Vision OCR, then confirm every value.",
                        systemImage: "photo.badge.plus"
                    )
                }
                .disabled(isProcessingPhoto)

                Button(action: onManualEntry) {
                    StartRow(
                        title: "Enter Manually",
                        subtitle: "Type weight, front %, PI, class, and drivetrain.",
                        systemImage: "keyboard"
                    )
                }
                .accessibilityIdentifier("manualEntryButton")
                .buttonStyle(.plain)
            }

            if isProcessingPhoto {
                Section {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Reading image")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let errorMessage {
                Section("Photo OCR") {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    if let lastFailedImage {
                        Button("Retry OCR") {
                            processCapturedPhoto(lastFailedImage)
                        }
                    }
                    Button("Enter manually", action: onManualEntry)
                }
            }
        }
        .navigationTitle("Tune Source")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel", action: onCancel)
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
                    onManualEntry()
                },
                onPhotoCaptured: { image in
                    isShowingCamera = false
                    processCapturedPhoto(image)
                }
            )
        }
    }

    private func processPhoto(_ item: PhotosPickerItem) {
        Task {
            isProcessingPhoto = true
            errorMessage = nil
            defer {
                isProcessingPhoto = false
                selectedItem = nil
            }

            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data)
                else {
                    throw PhotoImportError.unreadableImage
                }

                lastFailedImage = image
                try await processImage(image)
                lastFailedImage = nil
            } catch {
                errorMessage = "Could not read that screenshot. Try another photo or enter the values manually."
            }
        }
    }

    private func processCapturedPhoto(_ image: UIImage) {
        Task {
            isProcessingPhoto = true
            errorMessage = nil
            defer { isProcessingPhoto = false }

            do {
                lastFailedImage = image
                try await processImage(image)
                lastFailedImage = nil
            } catch {
                errorMessage = "Could not read that photo. Try another capture, import a screenshot, or enter the values manually."
            }
        }
    }

    private func processImage(_ image: UIImage) async throws {
        guard let cgImage = cgImage(from: image) else {
            throw PhotoImportError.unreadableImage
        }

        var draft = try await ocrService.confirmationDraft(from: cgImage)
        draft.thumbnailData = thumbnailData(from: image)
        onDraftReady(draft)
    }

    private func cgImage(from image: UIImage) -> CGImage? {
        guard image.imageOrientation != .up || image.cgImage == nil else {
            return image.cgImage
        }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }.cgImage
    }

    private func thumbnailData(from image: UIImage) -> Data? {
        let maxSide: CGFloat = 480
        let largestSide = max(image.size.width, image.size.height)
        let scale = largestSide > maxSide ? maxSide / largestSide : 1
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        let thumbnail = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return thumbnail.jpegData(compressionQuality: 0.68)
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
                        Image(systemName: "checkmark.circle")
                            .foregroundStyle(.tint)
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
    }
}

private struct StartRow: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 32)

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

private enum PhotoImportError: Error {
    case unreadableImage
}
