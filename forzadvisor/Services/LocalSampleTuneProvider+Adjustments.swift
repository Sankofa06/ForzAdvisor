//
//  LocalSampleTuneProvider+Adjustments.swift
//  forzadvisor
//
//  Offline feel-adjustment helpers for the sample tune provider. These mutate
//  generated tune lines and return the diff rows shown in TuneResultView.
//

import Foundation

extension LocalSampleTuneProvider {
    func rotationChanges(
        in tune: inout TuneResult,
        drivetrain: Drivetrain,
        direction: RotationAdjustmentDirection
    ) -> [TuneAdjustmentChange] {
        var changes: [TuneAdjustmentChange] = []

        switch drivetrain {
        case .fwd:
            changes.appendChange(adjustLine(in: &tune, sectionTitle: "Differential", lineLabel: "Front accel", delta: direction.frontAccelDelta, lower: 5, upper: 100, digits: 0))
            changes.appendChange(adjustLine(in: &tune, sectionTitle: "Differential", lineLabel: "Front decel", delta: direction.frontDecelDelta, lower: 0, upper: 100, digits: 0))
        case .rwd:
            changes.appendChange(adjustLine(in: &tune, sectionTitle: "Differential", lineLabel: "Accel", delta: direction.accelDelta, lower: 5, upper: 100, digits: 0))
            changes.appendChange(adjustLine(in: &tune, sectionTitle: "Differential", lineLabel: "Decel", delta: direction.decelDelta, lower: 0, upper: 100, digits: 0))
        case .awd:
            changes.appendChange(adjustLine(in: &tune, sectionTitle: "Differential", lineLabel: "Front accel", delta: direction.frontAccelDelta, lower: 5, upper: 100, digits: 0))
            changes.appendChange(adjustLine(in: &tune, sectionTitle: "Differential", lineLabel: "Front decel", delta: direction.frontDecelDelta, lower: 0, upper: 100, digits: 0))
            changes.appendChange(adjustLine(in: &tune, sectionTitle: "Differential", lineLabel: "Rear accel", delta: direction.accelDelta, lower: 5, upper: 100, digits: 0))
            changes.appendChange(adjustLine(in: &tune, sectionTitle: "Differential", lineLabel: "Rear decel", delta: direction.decelDelta, lower: 0, upper: 100, digits: 0))
            changes.appendChange(adjustLine(in: &tune, sectionTitle: "Differential", lineLabel: "Center balance", delta: direction.centerBalanceDelta, lower: 40, upper: 85, digits: 0))
        }

        return changes
    }

    func dampingChanges(in tune: inout TuneResult, delta: Double) -> [TuneAdjustmentChange] {
        [
            adjustLine(in: &tune, sectionTitle: "Damping", lineLabel: "Front rebound", delta: delta, lower: 1, upper: 20, digits: 1),
            adjustLine(in: &tune, sectionTitle: "Damping", lineLabel: "Rear rebound", delta: delta, lower: 1, upper: 20, digits: 1),
            adjustLine(in: &tune, sectionTitle: "Damping", lineLabel: "Front bump", delta: delta, lower: 1, upper: 20, digits: 1),
            adjustLine(in: &tune, sectionTitle: "Damping", lineLabel: "Rear bump", delta: delta, lower: 1, upper: 20, digits: 1)
        ].compactMap { $0 }
    }

    func aeroChanges(in tune: inout TuneResult, delta: Double) -> [TuneAdjustmentChange] {
        [
            adjustLine(in: &tune, sectionTitle: "Aero", lineLabel: "Front", delta: delta, lower: 0, upper: 500, digits: 0),
            adjustLine(in: &tune, sectionTitle: "Aero", lineLabel: "Rear", delta: delta, lower: 0, upper: 500, digits: 0)
        ].compactMap { $0 }
    }

    func adjustLine(
        in tune: inout TuneResult,
        sectionTitle: String,
        lineLabel: String,
        delta: Double,
        lower: Double,
        upper: Double,
        digits: Int
    ) -> TuneAdjustmentChange? {
        guard let sectionIndex = tune.sections.firstIndex(where: { $0.title == sectionTitle }),
              let lineIndex = tune.sections[sectionIndex].lines.firstIndex(where: { $0.label == lineLabel }),
              let oldValue = numericValue(from: tune.sections[sectionIndex].lines[lineIndex].value)
        else {
            return nil
        }

        let newValue = min(max(oldValue + delta, lower), upper)
        guard abs(newValue - oldValue) > 0.0001 else { return nil }

        let oldLine = tune.sections[sectionIndex].lines[lineIndex]
        let newValueText = formatted(newValue, digits: digits)
        tune.sections[sectionIndex].lines[lineIndex].value = newValueText

        return TuneAdjustmentChange(
            sectionTitle: sectionTitle,
            lineLabel: lineLabel,
            oldValue: oldLine.value,
            newValue: newValueText,
            unit: oldLine.unit,
            rationale: rationale(for: sectionTitle, lineLabel: lineLabel, delta: newValue - oldValue)
        )
    }

    func numericValue(from text: String) -> Double? {
        Double(text.replacingOccurrences(of: ",", with: ""))
    }

    func formatted(_ value: Double, digits: Int) -> String {
        value.formatted(.number.precision(.fractionLength(digits)))
    }

    private func rationale(for sectionTitle: String, lineLabel: String, delta: Double) -> String {
        switch sectionTitle {
        case "Antiroll Bars":
            if lineLabel == "Front" {
                return delta < 0 ? "Less front roll stiffness helps the nose bite and rotate." : "More front roll stiffness calms turn-in and reduces sudden rotation."
            }
            return delta > 0 ? "More rear roll stiffness helps the car rotate." : "Less rear roll stiffness makes the rear end more settled."
        case "Differential":
            if lineLabel.localizedCaseInsensitiveContains("center") {
                return delta > 0 ? "More rear bias makes AWD feel more agile." : "Less rear bias makes AWD more planted."
            }
            if lineLabel.localizedCaseInsensitiveContains("decel") {
                return delta > 0 ? "More decel lock steadies lift-off and braking rotation." : "Less decel lock lets the car rotate more freely off throttle."
            }
            return delta > 0 ? "More accel lock improves drive off the corner." : "Less accel lock reduces power-on push or snap."
        case "Springs":
            return delta > 0 ? "A stiffer spring rate adds support and faster response." : "A softer spring rate improves compliance and grip over bumps."
        case "Damping":
            return delta > 0 ? "More damping settles body motion faster." : "Less damping lets the suspension absorb rough surfaces."
        case "Gearing":
            return delta > 0 ? "A shorter final drive improves acceleration." : "A taller final drive gives more top-speed headroom."
        case "Aero":
            return delta > 0 ? "More downforce adds high-speed grip." : "Less downforce reduces drag for speed."
        default:
            return "Adjusted this value to match the selected driving feedback."
        }
    }
}

enum RotationAdjustmentDirection {
    case moreRotation
    case moreStability

    var accelDelta: Double {
        switch self {
        case .moreRotation: 5
        case .moreStability: -5
        }
    }

    var decelDelta: Double {
        switch self {
        case .moreRotation: -5
        case .moreStability: 5
        }
    }

    var frontAccelDelta: Double {
        switch self {
        case .moreRotation: -3
        case .moreStability: 3
        }
    }

    var frontDecelDelta: Double {
        switch self {
        case .moreRotation: -2
        case .moreStability: 2
        }
    }

    var centerBalanceDelta: Double {
        switch self {
        case .moreRotation: 3
        case .moreStability: -3
        }
    }
}

extension Array where Element == TuneAdjustmentChange {
    mutating func appendChange(_ change: TuneAdjustmentChange?) {
        guard let change else { return }
        append(change)
    }
}
