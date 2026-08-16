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

    static var missing: OCRFieldEvidence {
        OCRFieldEvidence(rawText: nil, confidence: 0)
    }
}

enum OCRFieldReviewState: String, Equatable, Sendable {
    case needsCheck = "Needs Check"
    case confirmed = "Confirmed"
    case corrected = "Corrected"
}

enum OCRConfirmationUnresolvedField: Hashable, Sendable {
    case identity
    case weightPounds
    case frontWeightPercent
    case performanceIndex
    case performanceClass
    case drivetrain

    var title: String {
        switch self {
        case .identity: "Make or model"
        case .weightPounds: "Weight"
        case .frontWeightPercent: "Front weight"
        case .performanceIndex: "PI"
        case .performanceClass: "Class"
        case .drivetrain: "Drivetrain"
        }
    }

    var inputField: OCRInputField? {
        switch self {
        case .identity: nil
        case .weightPounds: .weightPounds
        case .frontWeightPercent: .frontWeightPercent
        case .performanceIndex: .performanceIndex
        case .performanceClass: .performanceClass
        case .drivetrain: .drivetrain
        }
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
    var reviewStates: [OCRInputField: OCRFieldReviewState] = [:]

    static let requiredFields: [OCRInputField] = [
        .weightPounds,
        .frontWeightPercent,
        .performanceIndex,
        .performanceClass,
        .drivetrain
    ]

    var fieldsNeedingReview: [OCRInputField] {
        Self.requiredFields.filter { reviewState(for: $0) == .needsCheck }
    }

    var firstUnresolvedField: OCRConfirmationUnresolvedField? {
        if make.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .identity
        }
        if weightPounds.map({ !(1500...7000).contains($0) }) ?? true { return .weightPounds }
        if frontWeightPercent.map({ !(30...70).contains($0) }) ?? true { return .frontWeightPercent }
        if performanceIndex.map({ !(100...999).contains($0) }) ?? true { return .performanceIndex }
        guard let performanceClass else { return .performanceClass }
        if game.performanceIndexRange(for: performanceClass) == nil { return .performanceClass }
        if let performanceIndex,
           let range = game.performanceIndexRange(for: performanceClass),
           !range.contains(performanceIndex) { return .performanceIndex }
        if drivetrain == nil { return .drivetrain }
        if requiresFieldReview, let field = fieldsNeedingReview.first {
            return field.unresolvedField
        }
        return nil
    }

    private var requiresFieldReview: Bool {
        !evidence.isEmpty || thumbnailData != nil
    }

    func evidence(for field: OCRInputField) -> OCRFieldEvidence {
        evidence[field] ?? .missing
    }

    func candidates(for field: OCRInputField) -> [OCRFieldCandidate] {
        fieldCandidates[field] ?? []
    }

    func reviewState(for field: OCRInputField) -> OCRFieldReviewState {
        reviewStates[field] ?? (evidence(for: field).needsReview ? .needsCheck : .confirmed)
    }

    mutating func confirm(_ field: OCRInputField) {
        reviewStates[field] = .confirmed
    }

    mutating func markCorrected(_ field: OCRInputField) {
        reviewStates[field] = .corrected
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
        guard firstUnresolvedField == nil else { return nil }
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

extension OCRInputField {
    var unresolvedField: OCRConfirmationUnresolvedField {
        switch self {
        case .weightPounds: .weightPounds
        case .frontWeightPercent: .frontWeightPercent
        case .performanceIndex: .performanceIndex
        case .performanceClass: .performanceClass
        case .drivetrain: .drivetrain
        case .horsepower, .torque: .identity
        }
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
