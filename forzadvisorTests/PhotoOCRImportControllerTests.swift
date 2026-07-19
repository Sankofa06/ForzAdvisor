//
//  PhotoOCRImportControllerTests.swift
//  forzadvisorTests
//
//  Unit coverage for photo OCR task coordination without PhotosUI or Vision.
//

import UIKit
import XCTest
@testable import forzadvisor

@MainActor
final class PhotoOCRImportControllerTests: XCTestCase {
    func testCancelSuppressesDelayedOCRDraft() async {
        let ocrService = QueuedOCRService()
        let controller = PhotoOCRImportController(ocrService: ocrService)
        var deliveredDrafts: [OCRConfirmationDraft] = []

        controller.processCapturedPhoto(
            sampleImage(),
            failureMessage: "failed"
        ) { draft in
            deliveredDrafts.append(draft)
        }

        await waitUntil(ocrService.startedCount == 1)
        XCTAssertTrue(controller.isProcessingPhoto)

        controller.cancelPhotoImport()
        ocrService.complete(at: 0, with: draft(year: 2001))
        await settleMainActorWork()

        XCTAssertTrue(deliveredDrafts.isEmpty)
        XCTAssertFalse(controller.isProcessingPhoto)
        XCTAssertNil(controller.errorMessage)
    }

    func testLatestOCRImportWinsWhenPriorImportCompletesLate() async {
        let ocrService = QueuedOCRService()
        let controller = PhotoOCRImportController(ocrService: ocrService)
        var deliveredDrafts: [OCRConfirmationDraft] = []

        controller.processCapturedPhoto(
            sampleImage(),
            failureMessage: "first failed"
        ) { draft in
            deliveredDrafts.append(draft)
        }
        await waitUntil(ocrService.startedCount == 1)

        controller.processCapturedPhoto(
            sampleImage(),
            failureMessage: "second failed"
        ) { draft in
            deliveredDrafts.append(draft)
        }
        await waitUntil(ocrService.startedCount == 2)

        ocrService.complete(at: 0, with: draft(year: 2001))
        await settleMainActorWork()
        XCTAssertTrue(deliveredDrafts.isEmpty)
        XCTAssertTrue(controller.isProcessingPhoto)

        ocrService.complete(at: 1, with: draft(year: 2002))
        await waitUntil(deliveredDrafts.count == 1)

        XCTAssertEqual(deliveredDrafts.first?.year, 2002)
        XCTAssertFalse(controller.isProcessingPhoto)
        XCTAssertNil(controller.errorMessage)
    }

    func testCurrentOCRFailureShowsRetryState() async {
        let ocrService = QueuedOCRService()
        let controller = PhotoOCRImportController(ocrService: ocrService)
        var deliveredDrafts: [OCRConfirmationDraft] = []

        controller.processCapturedPhoto(
            sampleImage(),
            failureMessage: "Could not read that photo."
        ) { draft in
            deliveredDrafts.append(draft)
        }
        await waitUntil(ocrService.startedCount == 1)

        ocrService.fail(at: 0, with: TestOCRError())
        await waitUntil(controller.errorMessage != nil)

        XCTAssertTrue(deliveredDrafts.isEmpty)
        XCTAssertEqual(controller.errorMessage, "Could not read that photo.")
        XCTAssertNotNil(controller.lastFailedImage)
        XCTAssertFalse(controller.isProcessingPhoto)
    }

    private func draft(year: Int) -> OCRConfirmationDraft {
        var draft = OCRConfirmationDraft()
        draft.year = year
        return draft
    }

    private func sampleImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 24, height: 24))
        return renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 24, height: 24))
        }
    }

    private func waitUntil(
        _ condition: @autoclosure @escaping @MainActor () -> Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        for _ in 0..<100 {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Timed out waiting for condition.", file: file, line: line)
    }

    private func settleMainActorWork() async {
        try? await Task.sleep(for: .milliseconds(30))
    }
}

@MainActor
private final class QueuedOCRService: CarInputOCRService {
    private var continuations: [CheckedContinuation<OCRConfirmationDraft, Error>] = []

    var startedCount: Int {
        continuations.count
    }

    func confirmationDraft(from image: CGImage) async throws -> OCRConfirmationDraft {
        try await withCheckedThrowingContinuation { continuation in
            continuations.append(continuation)
        }
    }

    func complete(at index: Int, with draft: OCRConfirmationDraft) {
        continuations[index].resume(returning: draft)
    }

    func fail(at index: Int, with error: Error) {
        continuations[index].resume(throwing: error)
    }
}

private struct TestOCRError: Error {}
