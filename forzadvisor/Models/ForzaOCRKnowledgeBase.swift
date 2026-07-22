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
            candidates: integerCandidates(in: windows, fieldAliases: ["power", "horsepower", "hp", "kw"], units: #"hp|bhp|kw"#, range: 40...2_500),
            assign: { draft, value in draft.peakHorsepower = value }
        )
        applyBestIntegerCandidate(
            field: .torque,
            to: &draft,
            candidates: integerCandidates(in: windows, fieldAliases: ["torque", "ft lb", "ft-lb", "lb ft", "lb-ft", "nm"], units: #"ft[- ]?lb|lb[- ]?ft|nm"#, range: 40...2_500),
            assign: { draft, value in draft.peakTorqueFootPounds = value }
        )

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

    func candidate<Value>(
        value: Value,
        textValue: String,
        window: ObservationWindow,
        labelBoost _: Double
    ) -> ParsedCandidate<Value> {
        ParsedCandidate(
            value: value,
            textValue: textValue,
            confidence: window.confidence,
            rawText: window.rawText,
            candidates: window.candidates,
            boundingBox: window.boundingBox
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
