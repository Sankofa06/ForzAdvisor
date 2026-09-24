//
//  ForzaOCRKnowledgeBase.swift
//  forzadvisor
//
//  Field-aware parser for Forza performance screenshots. It repairs common OCR
//  label mistakes, pairs nearby labels and values, and returns editable drafts.
//

import CoreGraphics
import Foundation

struct ForzaOCRKnowledgeBase {
    func confirmationDraft(from observations: [OCRTextObservation]) -> OCRConfirmationDraft {
        let windows = observationWindows(from: observations)
        var draft = OCRConfirmationDraft()

        applyBestIntegerCandidate(
            field: .weightPounds,
            to: &draft,
            candidates: weightCandidates(in: windows),
            assign: { draft, value in draft.weightPounds = value }
        )
        applyBestDoubleCandidate(
            field: .frontWeightPercent,
            to: &draft,
            candidates: frontWeightCandidates(in: windows),
            assign: { draft, value in draft.frontWeightPercent = value }
        )
        applyBestIntegerCandidate(
            field: .performanceIndex,
            to: &draft,
            candidates: performanceIndexCandidates(in: windows),
            assign: { draft, value in draft.performanceIndex = value }
        )
        applyBestClassCandidate(to: &draft, candidates: performanceClassCandidates(in: windows))
        applyBestDrivetrainCandidate(to: &draft, candidates: drivetrainCandidates(in: windows))
        applyBestIntegerCandidate(
            field: .horsepower,
            to: &draft,
            candidates: measurementCandidates(in: windows, kind: .horsepower),
            assign: { draft, value in draft.peakHorsepower = value }
        )
        if draft.evidence[.horsepower] == nil,
           let candidate = bestCandidate(ambiguousMeasurementCandidates(in: windows, kind: .horsepower)) {
            draft.evidence[.horsepower] = evidence(from: candidate)
        }
        applyBestIntegerCandidate(
            field: .torque,
            to: &draft,
            candidates: measurementCandidates(in: windows, kind: .torque),
            assign: { draft, value in draft.peakTorqueFootPounds = value }
        )
        if draft.evidence[.torque] == nil,
           let candidate = bestCandidate(ambiguousMeasurementCandidates(in: windows, kind: .torque)) {
            draft.evidence[.torque] = evidence(from: candidate)
        }

        return draft
    }
}

extension ForzaOCRKnowledgeBase {
    struct ObservationWindow {
        var rawText: String
        var normalizedText: String
        var confidence: Double
        var boundingBox: CGRect?
        var candidates: [String]
    }

    struct ParsedCandidate<Value> {
        var value: Value
        var textValue: String
        var confidence: Double
        var rawText: String
        var candidates: [String]
        var boundingBox: CGRect?
        var sourceValue: String? = nil
        var sourceUnit: OCRMeasurementUnit? = nil
        var normalizedValue: String? = nil
    }

    func observationWindows(from observations: [OCRTextObservation]) -> [ObservationWindow] {
        let sorted = observations.enumerated().sorted { lhs, rhs in
            guard let leftBox = lhs.element.boundingBox, let rightBox = rhs.element.boundingBox else {
                return lhs.offset < rhs.offset
            }
            if abs(leftBox.midY - rightBox.midY) > 0.035 {
                return leftBox.midY > rightBox.midY
            }
            return leftBox.minX < rightBox.minX
        }.map(\.element)

        var windows: [ObservationWindow] = sorted.map(window(from:))

        for index in sorted.indices {
            guard index + 1 < sorted.endIndex else { continue }
            let first = sorted[index]
            let second = sorted[index + 1]
            let joined = "\(first.text) \(second.text)"
            windows.append(ObservationWindow(
                rawText: joined,
                normalizedText: normalize(joined),
                confidence: min(first.confidence, second.confidence),
                boundingBox: first.boundingBox?.union(second.boundingBox ?? first.boundingBox ?? .zero),
                candidates: (first.candidates + second.candidates + [joined]).deduplicated()
            ))
        }

        let allText = sorted.map(\.text).joined(separator: " ")
        if !allText.isEmpty {
            windows.append(ObservationWindow(
                rawText: allText,
                normalizedText: normalize(allText),
                confidence: sorted.map(\.confidence).min() ?? 0,
                boundingBox: nil,
                candidates: sorted.flatMap(\.candidates).deduplicated()
            ))
        }

        return windows
    }

    func window(from observation: OCRTextObservation) -> ObservationWindow {
        ObservationWindow(
            rawText: observation.text,
            normalizedText: normalize(observation.text),
            confidence: observation.confidence,
            boundingBox: observation.boundingBox,
            candidates: observation.candidates
        )
    }

    func normalize(_ text: String) -> String {
        var repaired = text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()

        let replacements = [
            "wait": "weight",
            "weignt": "weight",
            "weiglit": "weight",
            "we1ght": "weight",
            "fr0nt": "front",
            "font": "front",
            "pl ": "pi ",
            "p1 ": "pi ",
            " l ": " 1 ",
            "horse power": "horsepower",
            "allwheel": "all wheel",
            "rearwheel": "rear wheel",
            "frontwheel": "front wheel"
        ]

        for (bad, good) in replacements {
            repaired = repaired.replacingOccurrences(of: bad, with: good)
        }

        return repaired
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(of: "–", with: "-")
    }

    func containsAny(_ aliases: [String], in text: String) -> Bool {
        aliases.contains { text.contains($0) }
    }

    func weightCandidates(in windows: [ObservationWindow]) -> [ParsedCandidate<Int>] {
        windows.compactMap { window in
            guard containsAny(["weight", "curb", "mass"], in: window.normalizedText) else { return nil }
            let patterns = [
                #"(?i)\b(\d{1,2},\d{3}|\d{3,5})\s*(lb|lbs|pounds|kg)\b"#,
                #"(?i)\bweight[^0-9]*(\d{1,2},\d{3}|\d{3,5})\b"#
            ]

            guard let rawValue = firstCapture(in: window.rawText, patterns: patterns),
                  let parsed = Int(rawValue.replacingOccurrences(of: ",", with: ""))
            else { return nil }

            let pounds = window.normalizedText.contains("kg")
                ? Int((Double(parsed) * 2.20462).rounded())
                : parsed
            guard (1_500...7_000).contains(pounds) else { return nil }

            return candidate(value: pounds, textValue: "\(pounds)", window: window, labelBoost: 0.12)
        }
    }

    func frontWeightCandidates(in windows: [ObservationWindow]) -> [ParsedCandidate<Double>] {
        windows.compactMap { window in
            guard containsAny(["front", "distribution", "balance"], in: window.normalizedText) else { return nil }
            let patterns = [
                #"(?i)\bfront[^0-9]*(\d{2}(?:\.\d+)?)\s*%"#,
                #"(?i)\b(\d{2}(?:\.\d+)?)\s*%\s*front\b"#,
                #"(?i)\bweight[^0-9]*(\d{2}(?:\.\d+)?)\s*%"#
            ]

            guard let rawValue = firstCapture(in: window.rawText, patterns: patterns),
                  let percent = Double(rawValue),
                  (30...70).contains(percent)
            else { return nil }

            return candidate(value: percent, textValue: rawValue, window: window, labelBoost: 0.14)
        }
    }

    func performanceClassCandidates(in windows: [ObservationWindow]) -> [ParsedCandidate<PerformanceClass>] {
        windows.compactMap { window in
            let patterns = [
                #"(?i)\b(S1|S2|R|X|D|C|B|A)\s*-?\s*\d{3}\b"#,
                #"(?i)\bclass[^A-Z0-9]*(S1|S2|R|X|D|C|B|A)\b"#,
                #"(?i)\bpi[^A-Z0-9]*(S1|S2|R|X|D|C|B|A)\b"#
            ]

            guard let rawValue = firstCapture(in: window.rawText, patterns: patterns),
                  let performanceClass = PerformanceClass(rawValue: rawValue.uppercased())
            else { return nil }

            return candidate(value: performanceClass, textValue: performanceClass.rawValue, window: window, labelBoost: 0.1)
        }
    }

    func performanceIndexCandidates(in windows: [ObservationWindow]) -> [ParsedCandidate<Int>] {
        windows.compactMap { window in
            let patterns = [
                #"(?i)\b(?:PI|P1|PL|S1|S2|R|X|D|C|B|A)[^0-9]*(\d{3})\b"#,
                #"(?i)\bclass[^0-9]*(\d{3})\b"#
            ]

            guard let rawValue = firstCapture(in: window.rawText, patterns: patterns),
                  let performanceIndex = Int(rawValue),
                  (100...999).contains(performanceIndex)
            else { return nil }

            return candidate(value: performanceIndex, textValue: rawValue, window: window, labelBoost: 0.1)
        }
    }

    func drivetrainCandidates(in windows: [ObservationWindow]) -> [ParsedCandidate<Drivetrain>] {
        windows.compactMap { window in
            let text = window.normalizedText
            let drivetrain: Drivetrain?

            if containsAny(["awd", "all wheel", "all-wheel", "4wd"], in: text) {
                drivetrain = .awd
            } else if containsAny(["rwd", "rear wheel", "rear-wheel"], in: text) {
                drivetrain = .rwd
            } else if containsAny(["fwd", "front wheel", "front-wheel"], in: text) {
                drivetrain = .fwd
            } else {
                drivetrain = nil
            }

            guard let drivetrain else { return nil }
            return candidate(value: drivetrain, textValue: drivetrain.rawValue, window: window, labelBoost: 0.1)
        }
    }

    func integerCandidates(
        in windows: [ObservationWindow],
        fieldAliases: [String],
        units: String,
        range: ClosedRange<Int>
    ) -> [ParsedCandidate<Int>] {
        windows.compactMap { window in
            guard containsAny(fieldAliases, in: window.normalizedText) else { return nil }
            let patterns = [
                #"(?i)\b(\d{2,4})\s*(?:"# + units + #")\b"#,
                #"(?i)(?:"# + fieldAliases.map(NSRegularExpression.escapedPattern(for:)).joined(separator: "|") + #")[^0-9]*(\d{2,4})\b"#
            ]

            guard let rawValue = firstCapture(in: window.rawText, patterns: patterns),
                  let value = Int(rawValue),
                  range.contains(value)
            else { return nil }

            return candidate(value: value, textValue: rawValue, window: window, labelBoost: 0.08)
        }
    }

    enum MeasurementKind {
        case horsepower
        case torque

        var fieldAliases: [String] {
            switch self {
            case .horsepower: ["power", "horsepower", "hp", "kw"]
            case .torque: ["torque", "ft lb", "ft-lb", "lb ft", "lb-ft", "nm"]
            }
        }

        var unitsPattern: String {
            switch self {
            case .horsepower: #"hp|bhp|kw"#
            case .torque: #"ft[- ]?lb|lb[- ]?ft|nm"#
            }
        }

        var ambiguousPattern: String {
            switch self {
            case .horsepower:
                #"(?i)\b(?:power|horsepower|hp|kw)\b[^0-9]*(\d{2,4}(?:\.\d+)?)\b"#
            case .torque:
                #"(?i)\b(?:torque|ft[- ]?lb|lb[- ]?ft|nm)\b[^0-9]*(\d{2,4}(?:\.\d+)?)\b"#
            }
        }

        func sourceUnit(for unit: String) -> OCRMeasurementUnit? {
            switch unit.lowercased().replacingOccurrences(of: " ", with: "") {
            case "hp", "bhp": return .horsepower
            case "kw": return .kilowatts
            case "ft-lb", "ftlb", "lb-ft", "lbft": return .poundFeet
            case "nm": return .newtonMeters
            default: return nil
            }
        }

        func convertedValue(_ value: Double, sourceUnit: OCRMeasurementUnit) -> Double? {
            switch (self, sourceUnit) {
            case (.horsepower, .horsepower):
                return value
            case (.horsepower, .kilowatts):
                return value * 1.34102209
            case (.torque, .poundFeet):
                return value
            case (.torque, .newtonMeters):
                return value * 0.7375621493
            default:
                return nil
            }
        }
    }

    func measurementCandidates(
        in windows: [ObservationWindow],
        kind: MeasurementKind
    ) -> [ParsedCandidate<Int>] {
        windows.compactMap { window in
            guard containsAny(kind.fieldAliases, in: window.normalizedText),
                  let measurement = firstMeasurement(
                    in: window.rawText,
                    kind: kind
                  ),
                  measurementUnitIsUnambiguous(
                    measurement.sourceUnit,
                    in: window,
                    kind: kind
                  ) else { return nil }

            guard let converted = kind.convertedValue(
                measurement.value,
                sourceUnit: measurement.sourceUnit
            ), converted.isFinite,
               (40.0...2_500.0).contains(converted) else { return nil }
            let normalizedValue = Int(converted.rounded())
            guard (40...2_500).contains(normalizedValue) else { return nil }

            return candidate(
                value: normalizedValue,
                textValue: "\(normalizedValue)",
                window: window,
                labelBoost: 0.08,
                sourceValue: measurement.sourceValue,
                sourceUnit: measurement.sourceUnit,
                normalizedValue: "\(normalizedValue)"
            )
        }
    }

    func measurementUnitIsUnambiguous(
        _ sourceUnit: OCRMeasurementUnit,
        in window: ObservationWindow,
        kind: MeasurementKind
    ) -> Bool {
        window.candidates.allSatisfy { candidateText in
            guard firstCapture(in: candidateText, pattern: kind.ambiguousPattern) != nil else {
                return true
            }
            return firstMeasurement(in: candidateText, kind: kind)?.sourceUnit == sourceUnit
        }
    }

    func ambiguousMeasurementCandidates(
        in windows: [ObservationWindow],
        kind: MeasurementKind
    ) -> [ParsedCandidate<String>] {
        windows.compactMap { window in
            guard containsAny(kind.fieldAliases, in: window.normalizedText),
                  let sourceValue = firstCapture(in: window.rawText, pattern: kind.ambiguousPattern),
                  Double(sourceValue)?.isFinite == true else {
                return nil
            }
            if let measurement = firstMeasurement(in: window.rawText, kind: kind),
               measurementUnitIsUnambiguous(
                   measurement.sourceUnit,
                   in: window,
                   kind: kind
               ) {
                return nil
            }

            return candidate(
                value: sourceValue,
                textValue: sourceValue,
                window: window,
                labelBoost: 0.08,
                sourceValue: sourceValue,
                sourceUnit: .ambiguous
            )
        }
    }

    func firstMeasurement(
        in text: String,
        kind: MeasurementKind
    ) -> (value: Double, sourceValue: String, sourceUnit: OCRMeasurementUnit)? {
        let pattern = #"(?i)(\d{2,4}(?:\.\d+)?)\s*("# + kind.unitsPattern + #")\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let valueRange = Range(match.range(at: 1), in: text),
              let unitRange = Range(match.range(at: 2), in: text),
              let value = Double(text[valueRange]),
              let sourceUnit = kind.sourceUnit(for: String(text[unitRange])) else {
            return nil
        }
        return (value, String(text[valueRange]), sourceUnit)
    }

    func candidate<Value>(
        value: Value,
        textValue: String,
        window: ObservationWindow,
        labelBoost _: Double,
        sourceValue: String? = nil,
        sourceUnit: OCRMeasurementUnit? = nil,
        normalizedValue: String? = nil
    ) -> ParsedCandidate<Value> {
        ParsedCandidate(
            value: value,
            textValue: textValue,
            confidence: window.confidence,
            rawText: window.rawText,
            candidates: window.candidates,
            boundingBox: window.boundingBox,
            sourceValue: sourceValue,
            sourceUnit: sourceUnit,
            normalizedValue: normalizedValue
        )
    }

    func firstCapture(in text: String, patterns: [String]) -> String? {
        patterns.compactMap { firstCapture(in: text, pattern: $0) }.first
    }

    func firstCapture(in text: String, pattern: String) -> String? {
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
}

private extension Array where Element == String {
    func deduplicated() -> [String] {
        var seen = Set<String>()
        return filter { seen.insert($0).inserted }
    }
}
