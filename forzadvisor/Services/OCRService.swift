//
//  OCRService.swift
//  forzadvisor
//
//  Vision-backed OCR boundary. Camera/photo import can call this service and
//  pass the returned confirmation draft into the editable review flow.
//

import CoreGraphics
import Foundation
import Vision

protocol CarInputOCRService {
    func confirmationDraft(from image: CGImage) async throws -> OCRConfirmationDraft
}

struct VisionCarInputOCRService: CarInputOCRService {
    func confirmationDraft(from image: CGImage) async throws -> OCRConfirmationDraft {
        let observations = try await recognizedTextObservations(from: image)
        return OCRTextParser.confirmationDraft(from: observations)
    }

    private func recognizedTextObservations(from image: CGImage) async throws -> [OCRTextObservation] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                let lines = observations.compactMap { observation -> OCRTextObservation? in
                    let candidates = observation.topCandidates(3)
                    guard let candidate = candidates.first else { return nil }
                    return OCRTextObservation(
                        text: candidate.string,
                        confidence: Double(candidate.confidence),
                        boundingBox: observation.boundingBox,
                        candidates: candidates.dropFirst().map(\.string)
                    )
                }
                continuation.resume(returning: lines)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let handler = VNImageRequestHandler(cgImage: image)
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
