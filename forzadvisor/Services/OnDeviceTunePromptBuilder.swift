//
//  OnDeviceTunePromptBuilder.swift
//  forzadvisor
//
//  Builds the compact prompt sent to Apple Foundation Models. The 4k context
//  window is treated as a hard budget, so this never includes OCR text,
//  screenshots, long formula references, or remote-system-prompt material.
//

import Foundation

struct OnDeviceTunePromptBuilder {
    static let maximumPromptCharacters = 2_400

    func prompt(for request: TuneRequest, baseline: TuneResult) throws -> String {
        let car = request.car
        let prompt = [
            "Task: refine a \(car.game.title) tune from compact baseline values.",
            "Return only the guided structure. Keep notes under 90 chars each.",
            "Use tune-menu order. Stay near baseline; clamp to sane \(car.game.shortTitle) ranges.",
            "Car: \(carLine(car)); mode=\(request.discipline.apiValue).",
            "Baseline: \(baselineLine(baseline)).",
            "Rules: psi15-40 fd2.5-5.5 camber-5..0 toe-2..2 caster3-8 arb1-65 spring100-2000 ride2-12 damp1-20 aero0-600 brake0-200 diff0-100.",
            "Diff: use accel/decel for RWD; front_* for FWD; front_*, rear_*, center_balance_rear_pct for AWD."
        ].joined(separator: "\n")

        guard prompt.count <= Self.maximumPromptCharacters else {
            throw OnDeviceTuneError.promptTooLarge(prompt.count)
        }

        return prompt
    }

    private func carLine(_ car: CarInput) -> String {
        [
            car.year.map { "yr=\($0)" },
            "make=\(short(car.make))",
            "model=\(short(car.model))",
            "wt=\(car.weightPounds)",
            "front=\(format(car.frontWeightPercent))",
            "pi=\(car.performanceClass.rawValue)\(car.performanceIndex)",
            "dt=\(car.drivetrain.rawValue)",
            car.peakHorsepower.map { "hp=\($0)" },
            car.peakTorqueFootPounds.map { "tq=\($0)" }
        ]
        .compactMap { $0 }
        .joined(separator: " ")
    }

    private func baselineLine(_ tune: TuneResult) -> String {
        [
            compactSection(tune, "Tires", [("Front pressure", "tF"), ("Rear pressure", "tR")]),
            compactSection(tune, "Gearing", [("Final drive", "fd")]),
            compactSection(tune, "Alignment", [("Front camber", "cF"), ("Rear camber", "cR"), ("Front toe", "toeF"), ("Rear toe", "toeR"), ("Caster", "cas")]),
            compactSection(tune, "Antiroll Bars", [("Front", "arbF"), ("Rear", "arbR")]),
            compactSection(tune, "Springs", [("Front rate", "sprF"), ("Rear rate", "sprR"), ("Front ride height", "hF"), ("Rear ride height", "hR")]),
            compactSection(tune, "Damping", [("Front rebound", "rebF"), ("Rear rebound", "rebR"), ("Front bump", "bumpF"), ("Rear bump", "bumpR")]),
            compactSection(tune, "Aero", [("Front", "aeroF"), ("Rear", "aeroR")]),
            compactSection(tune, "Brakes", [("Balance", "brBal"), ("Pressure", "brPress")]),
            compactSection(tune, "Differential", [("Accel", "diffA"), ("Decel", "diffD"), ("Front accel", "fdiffA"), ("Front decel", "fdiffD"), ("Rear accel", "rdiffA"), ("Rear decel", "rdiffD"), ("Center balance", "ctr")])
        ]
        .filter { !$0.isEmpty }
        .joined(separator: "; ")
    }

    private func compactSection(
        _ tune: TuneResult,
        _ title: String,
        _ lines: [(label: String, key: String)]
    ) -> String {
        let pairs = lines.compactMap { line -> String? in
            guard let value = tune.section(title)?.number(line.label) else { return nil }
            return "\(line.key)=\(format(value))"
        }
        return pairs.joined(separator: " ")
    }

    private func short(_ value: String) -> String {
        let trimmed = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
        return String(trimmed.prefix(28))
    }

    private func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(2)))
    }
}

enum OnDeviceTuneError: LocalizedError {
    case unavailable(OnDeviceModelAvailability)
    case promptTooLarge(Int)
    case noCompleteResponse

    var errorDescription: String? {
        switch self {
        case .unavailable(let availability):
            "On-device generation is unavailable: \(availability.title)."
        case .promptTooLarge(let count):
            "The on-device prompt is too large (\(count) characters)."
        case .noCompleteResponse:
            "The on-device model did not finish a complete tune."
        }
    }
}
