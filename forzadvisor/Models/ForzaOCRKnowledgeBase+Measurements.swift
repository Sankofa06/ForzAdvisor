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
        guard let completeWindow = windows.last,
              let completeMeasurement = windows.lazy.compactMap({
                  firstMeasurement(in: $0.rawText, kind: kind)
              }).first,
              measurementIsUnambiguous(
                completeMeasurement.sourceValue,
                completeMeasurement.sourceUnit,
                in: completeWindow,
                kind: kind
              ) else {
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
        let primary = window.candidateGroups.compactMap(\.first)
        guard primary.count == window.candidateGroups.count,
              let value = Double(sourceValue),
              let signature = measurementObservationSignature(primary, kind: kind) else {
            return false
        }
        let reading = "\(sourceUnit.rawValue):\(value)"
        guard signature.joined().contains(reading),
              signature.joined().allSatisfy({ $0 == reading || $0 == "unrelated" }) else {
            return false
        }
        for (index, group) in window.candidateGroups.enumerated() {
            for alternative in group.dropFirst() {
                var fragments = primary
                fragments[index] = alternative
                // Preserve each original observation's field ownership. An
                // alternative cannot move a number into another field or rely
                // on a duplicate reading elsewhere to hide missing evidence.
                guard measurementObservationSignature(fragments, kind: kind) == signature else {
                    return false
                }
            }
        }
        return true
    }

    func measurementObservationSignature(
        _ fragments: [String],
        kind: MeasurementKind
    ) -> [[String]]? {
        let normalized = fragments.map { normalize($0) }
        let text = normalized.joined(separator: " ") as NSString
        let number = #"[0-9]{2,4}(?:\.[0-9]+)?"#
        let otherLabel = kind == .horsepower ? "torque" : "(?:power|horsepower)"
        let units = #"(?:hp|bhp|kw|ft[- ]?lb|lb[- ]?ft|nm|ps|cv)\b"#
        // An explicit other-field label owns its unresolved numeric reading.
        // It may be absent, unitless, malformed, or have incompatible units;
        // none of those conditions supplies a reading for the current field.
        let otherField = #"\b"# + otherLabel + #"\b(?:\s*[:=]?\s*[\d.,'’+−-]+(?:\s+\d+)*(?:\s*"#
            + units + #"(?:\s*/\s*"# + units + #")*)?)?"#
        // Measurement fragments must be consumed completely. Explicit other
        // fields own their values; separate screenshot context is recognized
        // below only at original observation boundaries.
        let fields = [
            otherField,
            #"(?:(?:power|horsepower)\s*[:=]?\s*)?"# + number + #"\s*(?:hp|bhp|kw)\b"#,
            #"(?:torque\s*[:=]?\s*)?"# + number + #"\s*(?:ft[- ]?lb|lb[- ]?ft|nm)\b"#,
            #"(?:front(?:\s+weight)?|(?:weight\s+)?distribution|balance)\s*[:=]?\s*\d{2}(?:\.\d+)?\s*%"#,
            #"\d{2}(?:\.\d+)?\s*%\s*front\b"#,
            #"(?:weight|curb(?:\s+weight)?|mass)\s*[:=]?\s*(?:\d{1,2},\d{3}|\d{3,5})(?:\s*(?:lbs?|pounds|kg))?\b"#,
            #"(?:(?:class|pi)\s*[:=]?\s*)?(?:s1|s2|r|x|d|c|b|a)\s*-?\s*\d{3}\b"#,
            #"(?:class|pi)\s*[:=]?\s*(?:(?:s1|s2|r|x|d|c|b|a)|\d{3})\b"#,
            #"(?:drivetrain\s*[:=]?\s*)?(?:awd|rwd|fwd|4wd|(?:all|rear|front)[ -]?wheel(?:[ -]+drive)?)\b"#,
            #"(?:speed|handling|acceleration|launch|braking|off[- ]?road)\s*[:=]?\s*(?:10(?:\.0+)?|[0-9](?:\.[0-9]+)?)\b"#
        ]
        let pattern = #"(?i)(?<![\w.,'’+−-])(?:"# + fields.joined(separator: "|") + ")"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let separators = CharacterSet.whitespacesAndNewlines.union(
            CharacterSet(charactersIn: ":=;/|,()[]")
        )
        var offset = 0
        let ranges = normalized.map { fragment -> NSRange in
            let range = NSRange(location: offset, length: (fragment as NSString).length)
            offset += range.length + 1
            return range
        }
        let contextRanges = ranges.indices.compactMap { index -> NSRange? in
            isUnrelatedScreenshotObservation(normalized[index]) ? ranges[index] : nil
        }
        let fieldRanges = regex.matches(in: text as String, range: NSRange(location: 0, length: text.length))
            .map(\.range).filter { range in
                !contextRanges.contains { NSIntersectionRange($0, range).length > 0 }
            }
        var signature = Array(repeating: [String](), count: fragments.count)
        var end = 0
        // Keep context in the stream: deleting it could join a value and unit
        // across a car heading or hide a trailing unresolved fragment.
        for range in (fieldRanges + contextRanges).sorted(by: { $0.location < $1.location }) {
            let gap = text.substring(with: NSRange(location: end, length: range.location - end))
            guard gap.unicodeScalars.allSatisfy(separators.contains) else { return nil }
            let reading = firstMeasurement(in: text.substring(with: range), kind: kind)
            let token = reading.map { "\($0.sourceUnit.rawValue):\($0.value)" } ?? "unrelated"
            for index in ranges.indices where NSIntersectionRange(ranges[index], range).length > 0 {
                signature[index].append(token)
            }
            end = NSMaxRange(range)
        }
        guard text.substring(from: end).unicodeScalars.allSatisfy(separators.contains) else { return nil }
        return signature
    }

    func isUnrelatedScreenshotObservation(_ normalizedText: String) -> Bool {
        let text = normalizedText.trimmingCharacters(in: .whitespacesAndNewlines)
        // A complete car heading supplies context for its year/model numbers.
        // Measurement labels and units, including unsupported PS/CV, must never
        // be hidden inside that context.
        let measurementMarkers = #"(?:\b(?:power|horsepower|torque)\b|(?<![a-z])(?:hp|bhp|kw|nm|ps|cv|ft[- ]?lb|lb[- ]?ft)\b)"#
        guard text.range(of: measurementMarkers, options: .regularExpression) == nil else { return false }
        let nameToken = #"[a-z0-9][a-z0-9.'’&()-]*"#
        let namedToken = #"(?=[a-z0-9.'’&()-]*[a-z])"# + nameToken
        let carHeading = #"^(?:19|20)\d{2}\s+[a-z][a-z0-9.'’&-]*\s+"#
            + nameToken + #"(?:\s+"# + namedToken + ")*$"
        if text.range(of: carHeading, options: .regularExpression) != nil { return true }
        // These titles/actions are whole observations, not permissive words
        // in the measurement grammar. "100 hp Upgrade Shop" still fails.
        return [
            "garage", "my cars", "car collection", "car mastery", "select car",
            "upgrade shop", "custom upgrade", "auto upgrade", "tune car",
            "upgrades and tuning", "upgrades & tuning", "conversion", "engine",
            "platform and handling", "tires and rims", "aero and appearance",
            "performance", "performance stats", "specifications",
            "back", "select", "apply", "install", "continue"
        ].contains(text)
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
            // Establish field ownership before validating the numeric token.
            // A malformed reading explicitly labeled for the other field must
            // not invalidate this field in a coalesced OCR observation.
            if let labelRange = Range(match.range(at: 1), in: text) {
                let label = text[labelRange].lowercased()
                switch kind {
                case .horsepower where label == "torque": continue
                case .torque where label == "power" || label == "horsepower": continue
                default: break
                }
            }
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
