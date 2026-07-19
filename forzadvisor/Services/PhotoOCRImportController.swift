//
//  PhotoOCRImportController.swift
//  forzadvisor
//
//  Testable task coordinator for photo and screenshot OCR import.
//

import Combine
import UIKit

enum PhotoImportError: Error {
    case unreadableImage
}

@MainActor
final class PhotoOCRImportController: ObservableObject {
    @Published private(set) var isProcessingPhoto = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var lastFailedImage: UIImage?

    private let ocrService: any CarInputOCRService
    private var activePhotoImportID: UUID?
    private var photoTask: Task<Void, Never>?

    init(ocrService: any CarInputOCRService) {
        self.ocrService = ocrService
    }

    func processPhotoData(
        loadData: @escaping () async throws -> Data?,
        failureMessage: String,
        onFinish: @escaping @MainActor () -> Void = {},
        onDraftReady: @escaping @MainActor (OCRConfirmationDraft) -> Void
    ) {
        let importID = beginPhotoImport()
        photoTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.finishPhotoImport(importID, onFinish: onFinish)
            }

            do {
                try Task.checkCancellation()
                guard let data = try await loadData(),
                      let image = UIImage(data: data)
                else {
                    throw PhotoImportError.unreadableImage
                }

                self.lastFailedImage = image
                let draft = try await self.confirmationDraft(from: image)
                guard self.isCurrentPhotoImport(importID) else { return }
                self.lastFailedImage = nil
                onDraftReady(draft)
            } catch {
                guard self.isCurrentPhotoImport(importID), !(error is CancellationError) else { return }
                self.errorMessage = failureMessage
            }
        }
    }

    func processCapturedPhoto(
        _ image: UIImage,
        failureMessage: String,
        onDraftReady: @escaping @MainActor (OCRConfirmationDraft) -> Void
    ) {
        let importID = beginPhotoImport()
        photoTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.finishPhotoImport(importID)
            }

            do {
                try Task.checkCancellation()
                self.lastFailedImage = image
                let draft = try await self.confirmationDraft(from: image)
                guard self.isCurrentPhotoImport(importID) else { return }
                self.lastFailedImage = nil
                onDraftReady(draft)
            } catch {
                guard self.isCurrentPhotoImport(importID), !(error is CancellationError) else { return }
                self.errorMessage = failureMessage
            }
        }
    }

    func cancelPhotoImport() {
        photoTask?.cancel()
        photoTask = nil
        activePhotoImportID = nil
        isProcessingPhoto = false
    }

    private func beginPhotoImport() -> UUID {
        photoTask?.cancel()
        let importID = UUID()
        activePhotoImportID = importID
        isProcessingPhoto = true
        errorMessage = nil
        return importID
    }

    private func finishPhotoImport(
        _ importID: UUID,
        onFinish: @escaping @MainActor () -> Void = {}
    ) {
        guard isCurrentPhotoImport(importID) else { return }
        isProcessingPhoto = false
        activePhotoImportID = nil
        photoTask = nil
        onFinish()
    }

    private func isCurrentPhotoImport(_ importID: UUID) -> Bool {
        activePhotoImportID == importID && !Task.isCancelled
    }

    private func confirmationDraft(from image: UIImage) async throws -> OCRConfirmationDraft {
        guard let cgImage = cgImage(from: image) else {
            throw PhotoImportError.unreadableImage
        }

        var draft = try await ocrService.confirmationDraft(from: cgImage)
        try Task.checkCancellation()
        draft.thumbnailData = thumbnailData(from: image)
        return draft
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
