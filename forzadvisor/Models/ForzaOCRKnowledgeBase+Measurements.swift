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
        // The complete capture must support one reading before a narrower
        // window can supply its confidence/evidence. Discarding a conflicting
        // aggregate must never leave an apparently safe adjacent pair behind.
        let originalWindows = windows.filter { $0.candidateGroups.count == 1 }
        guard let completeWindow = windows.last,
              let completeMeasurement = firstMeasurement(in: completeWindow.rawText, kind: kind),
              measurementIsUnambiguous(
                completeMeasurement.sourceValue,
                completeMeasurement.sourceUnit,
                in: completeWindow,
                kind: kind
              ),
              ambiguousMeasurementCandidates(in: originalWindows, kind: kind).isEmpty else {
            return []
        }
        let candidates: [ParsedCandidate<Int>] = windows.compactMap { window in
            guard containsAny(kind.fieldAliases, in: window.normalizedText),
                  let measurement = firstMeasurement(in: window.rawText, kind: kind),
                  measurementIsUnambiguous(
                    measurement.sourceValue,
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
        return measurementValuesAreUnambiguous(candidates) ? candidates : []
    }

    func measurementValuesAreUnambiguous<Value>(
        _ candidates: [ParsedCandidate<Value>]
    ) -> Bool {
        let readings = Set(candidates.compactMap { candidate -> String? in
            guard let sourceValue = candidate.sourceValue,
                  let value = Double(sourceValue),
                  let sourceUnit = candidate.sourceUnit else {
                return nil
            }
            return "\(sourceUnit.rawValue):\(value)"
        })
        return readings.count <= 1
    }

    func hasConflictingMeasurementReadings(
        in windows: [ObservationWindow],
        kind: MeasurementKind
    ) -> Bool {
        let readings = Set(windows.compactMap { window -> String? in
            guard containsAny(kind.fieldAliases, in: window.normalizedText),
                  let measurement = firstMeasurement(in: window.rawText, kind: kind) else {
                return nil
            }
            return "\(measurement.sourceUnit.rawValue):\(measurement.value)"
        })
        return readings.count > 1
    }

    func measurementIsUnambiguous(
        _ sourceValue: String,
        _ sourceUnit: OCRMeasurementUnit,
        in window: ObservationWindow,
        kind: MeasurementKind
    ) -> Bool {
        window.candidateGroups.allSatisfy { group in
            guard let primary = group.first else { return true }
            guard firstMeasurement(in: primary, kind: kind) != nil else {
                let primaryText = primary.trimmingCharacters(in: .whitespacesAndNewlines)
                if let unit = kind.sourceUnit(for: primaryText),
                   kind.convertedValue(1, sourceUnit: unit) != nil {
                    return unit == sourceUnit && group.allSatisfy {
                        kind.sourceUnit(for: $0.trimmingCharacters(in: .whitespacesAndNewlines)) == unit
                    }
                }
                if let value = Double(primaryText), value == Double(sourceValue) {
                    return group.allSatisfy {
                        Double($0.trimmingCharacters(in: .whitespacesAndNewlines)) == value
                    }
                }
                // Other fields in a combined window do not become alternatives
                // for this measurement. Preserve split field-label ambiguity.
                guard containsAny(kind.fieldAliases, in: normalize(primary)) else {
                    return true
                }
                let labelPattern = switch kind {
                case .horsepower: #"^\s*(?:power|horsepower)\s*[:=]?\s*$"#
                case .torque: #"^\s*torque\s*[:=]?\s*$"#
                }
                return group.allSatisfy {
                    normalize($0).range(of: labelPattern, options: .regularExpression) != nil
                }
            }
            return group.allSatisfy { candidateText in
                guard isUnambiguousMeasurementObservation(candidateText),
                      let alternative = firstMeasurement(in: candidateText, kind: kind) else {
                    return false
                }
                return alternative.sourceUnit == sourceUnit
                    && alternative.value == Double(sourceValue)
            }
        }
    }

    func isUnambiguousMeasurementObservation(_ text: String) -> Bool {
        // A measurement observation may include both power and torque, but an
        // extra number without a recognized unit is an unresolved alternative.
        // Apply this to original observation groups, never the combined window.
        let pattern = #"(?i)[\d.,'’+−-]+(?:\s+\d+)*\s*(?:hp|bhp|kw|ft[- ]?lb|lb[- ]?ft|nm)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return false
        }
        let remaining = regex.stringByReplacingMatches(
            in: text,
            range: NSRange(text.startIndex..<text.endIndex, in: text),
            withTemplate: ""
        ).replacingOccurrences(
            of: #"(?i)\b(?:power|horsepower|torque)\b"#,
            with: "",
            options: .regularExpression
        )
        // Leftover unit markers or unrecognized text can qualify the same value
        // (for example hp/kW). Only field labels and separators may remain.
        let separators = CharacterSet.whitespacesAndNewlines.union(
            CharacterSet(charactersIn: ":=;/|,()[]-")
        )
        return remaining.unicodeScalars.allSatisfy(separators.contains)
    }

    func ambiguousMeasurementCandidates(
        in windows: [ObservationWindow],
        kind: MeasurementKind
    ) -> [ParsedCandidate<String>] {
        let hasConflictingReadings = hasConflictingMeasurementReadings(
            in: windows,
            kind: kind
        )
        return windows.compactMap { window in
            guard containsAny(kind.fieldAliases, in: window.normalizedText),
                  let sourceValue = firstCapture(in: window.rawText, pattern: kind.ambiguousPattern),
                  Double(sourceValue)?.isFinite == true else {
                return nil
            }
            if let measurement = firstMeasurement(in: window.rawText, kind: kind),
               !hasConflictingReadings,
               measurementIsUnambiguous(
                   measurement.sourceValue,
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
        let pattern = #"(?i)(?<![\w.,'’+−-])(?:(power|horsepower|torque)\s*[:=]?\s*)?([\d.,'’+−-]+(?:\s+\d+)*)\s*("# + kind.unitsPattern + #")\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        var reading: (value: Double, sourceValue: String, sourceUnit: OCRMeasurementUnit)?
        for match in regex.matches(in: text, range: range) {
            guard let valueRange = Range(match.range(at: 2), in: text),
                  let unitRange = Range(match.range(at: 3), in: text),
                  text[valueRange].range(
                    of: #"^[0-9]{2,4}(?:\.[0-9]+)?$"#,
                    options: .regularExpression
                  ) != nil,
                  let value = Double(text[valueRange]),
                  let sourceUnit = kind.sourceUnit(for: String(text[unitRange])) else {
                return nil
            }
            if let labelRange = Range(match.range(at: 1), in: text) {
                let label = text[labelRange].lowercased()
                switch kind {
                case .horsepower where label == "torque": continue
                case .torque where label == "power" || label == "horsepower": continue
                default: break
                }
            }
            if let reading,
               reading.value != value || reading.sourceUnit != sourceUnit {
                return nil
            }
            reading = (value, String(text[valueRange]), sourceUnit)
        }
        guard let reading else { return nil }

        // Every labeled reading must agree, including ones without a supported
        // unit. Coalesced OCR lines must not hide a second conflicting value.
        let labels = switch kind {
        case .horsepower: "power|horsepower"
        case .torque: "torque"
        }
        let labeledPattern = #"(?i)\b(?:"# + labels + #")\s*[:=]?\s*([+-]?\d+(?:\.\d+)?)"#
        guard let labeledRegex = try? NSRegularExpression(pattern: labeledPattern) else {
            return nil
        }
        for match in labeledRegex.matches(in: text, range: range) {
            guard let valueRange = Range(match.range(at: 1), in: text),
                  Double(text[valueRange]) == reading.value,
                  let unit = firstCapture(
                    in: String(text[valueRange.upperBound...]),
                    pattern: #"(?i)^\s*("# + kind.unitsPattern + #")\b"#
                  ), kind.sourceUnit(for: unit) == reading.sourceUnit else {
                return nil
            }
        }
        return reading
    }
}
