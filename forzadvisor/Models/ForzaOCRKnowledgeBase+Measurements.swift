import Foundation

extension ForzaOCRKnowledgeBase {
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
                  let measurement = firstMeasurement(in: window.rawText, kind: kind),
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
}
