//
//  OCRConfirmation.swift
//  forzadvisor
//
//  Confirmation draft types shared by Vision OCR, future photo capture, and
//  the editable confirmation screen before a tune request is generated.
//

import CoreGraphics
import Foundation

enum OCRInputField: String, CaseIterable, Identifiable, Sendable {
    case weightPounds
    case frontWeightPercent
    case performanceIndex
    case performanceClass
    case drivetrain
    case horsepower
    case torque

    var id: String { rawValue }

    var title: String {
        switch self {
        case .weightPounds: "Weight"
        case .frontWeightPercent: "Front weight"
        case .performanceIndex: "PI"
        case .performanceClass: "Class"
        case .drivetrain: "Drivetrain"
        case .horsepower: "Horsepower"
        case .torque: "Torque"
        }
    }
}

struct OCRTextObservation: Equatable, Sendable {
    var text: String
    var confidence: Double
    var boundingBox: CGRect?
    var candidates: [String]

    init(
        text: String,
        confidence: Double,
        boundingBox: CGRect? = nil,
        candidates: [String] = []
    ) {
        self.text = text
        self.confidence = confidence
        self.boundingBox = boundingBox
        self.candidates = ([text] + candidates).deduplicated()
    }
}

struct OCRFieldEvidence: Equatable, Sendable {
    static let reviewThreshold = 0.6

    var rawText: String?
    var confidence: Double
    var candidates: [String] = []
    var boundingBox: CGRect?

    var needsReview: Bool {
        rawText == nil || confidence < Self.reviewThreshold
    }

    var confidencePercentText: String {
        confidence.formatted(.percent.precision(.fractionLength(0)))
    }

    static var missing: OCRFieldEvidence {
        OCRFieldEvidence(rawText: nil, confidence: 0)
    }
}

struct OCRFieldCandidate: Identifiable, Equatable, Sendable {
    var field: OCRInputField
    var value: String
    var confidence: Double
    var rawText: String

    var id: String {
        "\(field.rawValue)-\(value)-\(rawText)-\(confidence)"
    }
}

protocol OCRCorrectionProvider {
    func correctedDraft(
        from draft: OCRConfirmationDraft,
        observations: [OCRTextObservation]
    ) async throws -> OCRConfirmationDraft
}

struct OCRConfirmationDraft: Equatable, Sendable {
    var game: ForzaGame = .fh6
    var year: Int?
    var make = ""
    var model = ""
    var weightPounds: Int?
    var frontWeightPercent: Double?
    var performanceIndex: Int?
    var performanceClass: PerformanceClass?
    var drivetrain: Drivetrain?
    var peakHorsepower: Int?
    var peakTorqueFootPounds: Int?
    var thumbnailData: Data?
    var fieldCandidates: [OCRInputField: [OCRFieldCandidate]] = [:]
    var evidence: [OCRInputField: OCRFieldEvidence] = [:]

    static let requiredFields: [OCRInputField] = [
        .weightPounds,
        .frontWeightPercent,
        .performanceIndex,
        .performanceClass,
        .drivetrain
    ]

    var fieldsNeedingReview: [OCRInputField] {
        Self.requiredFields.filter { evidence(for: $0).needsReview }
    }

    func evidence(for field: OCRInputField) -> OCRFieldEvidence {
        evidence[field] ?? .missing
    }

    func candidates(for field: OCRInputField) -> [OCRFieldCandidate] {
        fieldCandidates[field] ?? []
    }

    func manualEntryFallback() -> ManualEntryDraft {
        ManualEntryDraft(
            game: game,
            year: year,
            make: make,
            model: model,
            weightPounds: weightPounds,
            frontWeightPercent: frontWeightPercent,
            performanceIndex: performanceIndex,
            performanceClass: performanceClass,
            drivetrain: drivetrain,
            peakHorsepower: peakHorsepower,
            peakTorqueFootPounds: peakTorqueFootPounds
        )
    }

    func confirmedCarInput() -> CarInput? {
        guard
            let weightPounds,
            let frontWeightPercent,
            let performanceIndex,
            let performanceClass,
            let drivetrain
        else {
            return nil
        }

        let car = CarInput(
            game: game,
            year: year,
            make: make,
            model: model,
            weightPounds: weightPounds,
            frontWeightPercent: frontWeightPercent,
            performanceIndex: performanceIndex,
            performanceClass: performanceClass,
            drivetrain: drivetrain,
            peakHorsepower: peakHorsepower,
            peakTorqueFootPounds: peakTorqueFootPounds
        )

        return car.isValid ? car : nil
    }
}

enum OCRTextParser {
    static func confirmationDraft(from observations: [OCRTextObservation]) -> OCRConfirmationDraft {
        ForzaOCRKnowledgeBase().confirmationDraft(from: observations)
    }
}

private extension Array where Element == String {
    func deduplicated() -> [String] {
        var seen = Set<String>()
        return filter { seen.insert($0).inserted }
    }
}
