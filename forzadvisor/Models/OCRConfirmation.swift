//
//  OCRConfirmation.swift
//  forzadvisor
//
//  Confirmation draft types shared by Vision OCR, future photo capture, and
//  the editable confirmation screen before a tune request is generated.
//

import CoreGraphics
import Foundation

enum OCRInputField: String, CaseIterable, Identifiable {
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

struct OCRTextObservation: Equatable {
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

struct OCRFieldEvidence: Equatable {
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

struct OCRFieldCandidate: Identifiable, Equatable {
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

struct OCRConfirmationDraft: Equatable {
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

    func manualEntryFallback(default defaultCar: CarInput = SampleTuningData.starterCar) -> CarInput {
        CarInput(
            year: year ?? defaultCar.year,
            make: make.isEmpty ? defaultCar.make : make,
            model: model.isEmpty ? defaultCar.model : model,
            weightPounds: weightPounds ?? defaultCar.weightPounds,
            frontWeightPercent: frontWeightPercent ?? defaultCar.frontWeightPercent,
            performanceIndex: performanceIndex ?? defaultCar.performanceIndex,
            performanceClass: performanceClass ?? defaultCar.performanceClass,
            drivetrain: drivetrain ?? defaultCar.drivetrain,
            peakHorsepower: peakHorsepower ?? defaultCar.peakHorsepower,
            peakTorqueFootPounds: peakTorqueFootPounds ?? defaultCar.peakTorqueFootPounds
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

private extension OCRTextParser {
    static func legacyConfirmationDraft(from observations: [OCRTextObservation]) -> OCRConfirmationDraft {
        var draft = OCRConfirmationDraft()

        if let match = bestPerformanceClassMatch(in: observations) {
            draft.performanceClass = match.value
            draft.evidence[.performanceClass] = match.evidence
        }

        if let match = bestPerformanceIndexMatch(in: observations) {
            draft.performanceIndex = match.value
            draft.evidence[.performanceIndex] = match.evidence
        }

        if let match = bestDrivetrainMatch(in: observations) {
            draft.drivetrain = match.value
            draft.evidence[.drivetrain] = match.evidence
        }

        if let match = bestIntegerMatch(in: observations, fieldWords: ["power", "hp"], unitPattern: #"hp|bhp"#) {
            draft.peakHorsepower = match.value
            draft.evidence[.horsepower] = match.evidence
        }

        if let match = bestIntegerMatch(in: observations, fieldWords: ["torque", "ft"], unitPattern: #"ft[- ]?lb|lb[- ]?ft"#) {
            draft.peakTorqueFootPounds = match.value
            draft.evidence[.torque] = match.evidence
        }

        return draft
    }
}

private extension OCRTextParser {
    struct FieldMatch<Value> {
        var value: Value
        var evidence: OCRFieldEvidence
    }

    static func bestWeightMatch(in observations: [OCRTextObservation]) -> FieldMatch<Int>? {
        observations
            .filter { $0.text.localizedCaseInsensitiveContains("weight") }
            .compactMap { observation -> FieldMatch<Int>? in
                guard let rawValue = firstCapture(in: observation.text, pattern: #"(?i)\b(\d{1,2},\d{3}|\d{3,5})\s*(lb|lbs|pounds|kg)?"#),
                      let weight = Int(rawValue.replacingOccurrences(of: ",", with: ""))
                else { return nil }

                let lowercased = observation.text.lowercased()
                let pounds = lowercased.contains("kg") ? Int((Double(weight) * 2.20462).rounded()) : weight
                return FieldMatch(value: pounds, evidence: evidence(from: observation))
            }
            .max { $0.evidence.confidence < $1.evidence.confidence }
    }

    static func bestFrontWeightMatch(in observations: [OCRTextObservation]) -> FieldMatch<Double>? {
        let patterns = [
            #"(?i)front[^0-9]*(\d{2}(?:\.\d+)?)\s*%"#,
            #"(?i)(\d{2}(?:\.\d+)?)\s*%\s*front"#
        ]

        return observations
            .filter { $0.text.localizedCaseInsensitiveContains("front") }
            .compactMap { observation -> FieldMatch<Double>? in
                guard let rawValue = patterns.compactMap({ firstCapture(in: observation.text, pattern: $0) }).first,
                      let percent = Double(rawValue)
                else { return nil }

                return FieldMatch(value: percent, evidence: evidence(from: observation))
            }
            .max { $0.evidence.confidence < $1.evidence.confidence }
    }

    static func bestPerformanceClassMatch(in observations: [OCRTextObservation]) -> FieldMatch<PerformanceClass>? {
        observations
            .compactMap { observation -> FieldMatch<PerformanceClass>? in
                guard let rawValue = firstCapture(in: observation.text, pattern: #"(?i)\b(S1|S2|X|C|B|A)\b\s*-?\s*\d{3}|\bclass[^A-Z0-9]*(S1|S2|X|C|B|A)\b"#),
                      let performanceClass = PerformanceClass(rawValue: rawValue.uppercased())
                else { return nil }

                return FieldMatch(value: performanceClass, evidence: evidence(from: observation))
            }
            .max { $0.evidence.confidence < $1.evidence.confidence }
    }

    static func bestPerformanceIndexMatch(in observations: [OCRTextObservation]) -> FieldMatch<Int>? {
        observations
            .compactMap { observation -> FieldMatch<Int>? in
                guard let rawValue = firstCapture(in: observation.text, pattern: #"(?i)\b(?:PI|S1|S2|X|C|B|A)[^0-9]*(\d{3})\b"#),
                      let performanceIndex = Int(rawValue)
                else { return nil }

                return FieldMatch(value: performanceIndex, evidence: evidence(from: observation))
            }
            .max { $0.evidence.confidence < $1.evidence.confidence }
    }

    static func bestDrivetrainMatch(in observations: [OCRTextObservation]) -> FieldMatch<Drivetrain>? {
        observations
            .compactMap { observation -> FieldMatch<Drivetrain>? in
                let text = observation.text.uppercased()
                let drivetrain: Drivetrain?

                if text.contains("AWD") || text.contains("ALL WHEEL") || text.contains("ALL-WHEEL") {
                    drivetrain = .awd
                } else if text.contains("RWD") || text.contains("REAR WHEEL") || text.contains("REAR-WHEEL") {
                    drivetrain = .rwd
                } else if text.contains("FWD") || text.contains("FRONT WHEEL") || text.contains("FRONT-WHEEL") {
                    drivetrain = .fwd
                } else {
                    drivetrain = nil
                }

                guard let drivetrain else { return nil }
                return FieldMatch(value: drivetrain, evidence: evidence(from: observation))
            }
            .max { $0.evidence.confidence < $1.evidence.confidence }
    }

    static func bestIntegerMatch(
        in observations: [OCRTextObservation],
        fieldWords: [String],
        unitPattern: String
    ) -> FieldMatch<Int>? {
        observations
            .filter { observation in
                let text = observation.text.lowercased()
                return fieldWords.contains { text.contains($0) }
            }
            .compactMap { observation -> FieldMatch<Int>? in
                let pattern = #"(?i)(\d{2,4})\s*(?:"# + unitPattern + #")"#
                guard let rawValue = firstCapture(in: observation.text, pattern: pattern),
                      let value = Int(rawValue)
                else { return nil }

                return FieldMatch(value: value, evidence: evidence(from: observation))
            }
            .max { $0.evidence.confidence < $1.evidence.confidence }
    }

    static func firstCapture(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range) else { return nil }

        for index in 1..<match.numberOfRanges {
            let captureRange = match.range(at: index)
            guard captureRange.location != NSNotFound,
                  let range = Range(captureRange, in: text)
            else { continue }
            return String(text[range])
        }

        return nil
    }

    static func evidence(from observation: OCRTextObservation) -> OCRFieldEvidence {
        OCRFieldEvidence(rawText: observation.text, confidence: observation.confidence)
    }
}
