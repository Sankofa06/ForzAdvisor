//
//  TuneProvider.swift
//  forzadvisor
//
//  Defines the tune generation boundary. LocalSampleTuneProvider gives the UI a
//  deterministic, offline implementation until the API client is introduced.
//

import Foundation

typealias TuneProgressHandler = @MainActor (TuneResult) -> Void

protocol TuneProvider {
    func generateTune(for request: TuneRequest) async throws -> TuneResult
    func generateTune(for request: TuneRequest, onPartial: TuneProgressHandler?) async throws -> TuneResult
    func adjustTune(previous tune: TuneResult, adjustment: TuneAdjustment) async throws -> TuneAdjustmentResult
}

extension TuneProvider {
    func generateTune(for request: TuneRequest, onPartial: TuneProgressHandler?) async throws -> TuneResult {
        try await generateTune(for: request)
    }
}

struct LocalSampleTuneProvider: TuneProvider {
    func generateTune(for request: TuneRequest) async throws -> TuneResult {
        try await Task.sleep(for: .milliseconds(250))
        return makeTune(for: request)
    }

    func adjustTune(previous tune: TuneResult, adjustment: TuneAdjustment) async throws -> TuneAdjustmentResult {
        try await Task.sleep(for: .milliseconds(150))

        var adjustedTune = tune
        var changes: [TuneAdjustmentChange] = []

        switch adjustment {
        case .moreRotation:
            changes.appendChange(adjustLine(in: &adjustedTune, sectionTitle: "Antiroll Bars", lineLabel: "Front", delta: -2, lower: 8, upper: 65, digits: 1))
            changes.appendChange(adjustLine(in: &adjustedTune, sectionTitle: "Antiroll Bars", lineLabel: "Rear", delta: 2, lower: 8, upper: 65, digits: 1))
            changes.append(contentsOf: rotationChanges(in: &adjustedTune, drivetrain: tune.request.car.drivetrain, direction: .moreRotation))
        case .moreStability:
            changes.appendChange(adjustLine(in: &adjustedTune, sectionTitle: "Antiroll Bars", lineLabel: "Front", delta: 2, lower: 8, upper: 65, digits: 1))
            changes.appendChange(adjustLine(in: &adjustedTune, sectionTitle: "Antiroll Bars", lineLabel: "Rear", delta: -2, lower: 8, upper: 65, digits: 1))
            changes.append(contentsOf: rotationChanges(in: &adjustedTune, drivetrain: tune.request.car.drivetrain, direction: .moreStability))
        case .softer:
            changes.appendChange(adjustLine(in: &adjustedTune, sectionTitle: "Springs", lineLabel: "Front rate", delta: -25, lower: 180, upper: 1_200, digits: 0))
            changes.appendChange(adjustLine(in: &adjustedTune, sectionTitle: "Springs", lineLabel: "Rear rate", delta: -25, lower: 180, upper: 1_200, digits: 0))
            changes.append(contentsOf: dampingChanges(in: &adjustedTune, delta: -0.3))
        case .stiffer:
            changes.appendChange(adjustLine(in: &adjustedTune, sectionTitle: "Springs", lineLabel: "Front rate", delta: 25, lower: 180, upper: 1_200, digits: 0))
            changes.appendChange(adjustLine(in: &adjustedTune, sectionTitle: "Springs", lineLabel: "Rear rate", delta: 25, lower: 180, upper: 1_200, digits: 0))
            changes.append(contentsOf: dampingChanges(in: &adjustedTune, delta: 0.3))
        case .moreTopSpeed:
            changes.appendChange(adjustLine(in: &adjustedTune, sectionTitle: "Gearing", lineLabel: "Final drive", delta: -0.15, lower: 2.5, upper: 5.5, digits: 2))
            changes.append(contentsOf: aeroChanges(in: &adjustedTune, delta: -10))
        case .moreAcceleration:
            changes.appendChange(adjustLine(in: &adjustedTune, sectionTitle: "Gearing", lineLabel: "Final drive", delta: 0.15, lower: 2.5, upper: 5.5, digits: 2))
            changes.append(contentsOf: aeroChanges(in: &adjustedTune, delta: 10))
        }

        return TuneAdjustmentResult(tune: adjustedTune, changes: changes)
    }

    private func makeTune(for request: TuneRequest) -> TuneResult {
        let car = request.car
        let tires = TuningKnowledgeBase.tirePressures(for: request)
        let finalDrive = TuningKnowledgeBase.finalDrive(for: request)
        let alignment = TuningKnowledgeBase.alignment(for: request)
        let antirollBars = TuningKnowledgeBase.antirollBars(for: request)
        let springs = TuningKnowledgeBase.springs(for: request)
        let rideHeight = TuningKnowledgeBase.rideHeight(for: request)
        let damping = TuningKnowledgeBase.damping(for: request, springs: springs)
        let aero = TuningKnowledgeBase.aero(for: request)
        let brakes = TuningKnowledgeBase.brakes(for: request)
        let differential = TuningKnowledgeBase.differential(for: request)

        let sections = [
            TuneSection(title: "Tires", symbolName: "circle.dashed", lines: [
                line("Front pressure", tires.frontPsi, "PSI", detail: tires.detail),
                line("Rear pressure", tires.rearPsi, "PSI", detail: tires.detail)
            ]),
            TuneSection(title: "Gearing", symbolName: "gearshape.2", lines: [
                line("Final drive", finalDrive, "", digits: 2),
                TuneLine(label: "Individual gears", value: "Stock baseline", unit: "", detail: "Scale final drive first; only adjust gears after limiter checks.")
            ]),
            TuneSection(title: "Alignment", symbolName: "arrow.left.and.right", lines: [
                line("Front camber", alignment.frontCamber, "deg"),
                line("Rear camber", alignment.rearCamber, "deg"),
                line("Front toe", alignment.frontToe, "deg"),
                line("Rear toe", alignment.rearToe, "deg"),
                line("Caster", alignment.caster, "deg")
            ]),
            TuneSection(title: "Antiroll Bars", symbolName: "arrow.up.left.and.arrow.down.right", lines: [
                line("Front", antirollBars.front, ""),
                line("Rear", antirollBars.rear, "")
            ]),
            TuneSection(title: "Springs", symbolName: "waveform.path.ecg", lines: [
                line("Front rate", springs.frontRate, "lb/in", digits: 0),
                line("Rear rate", springs.rearRate, "lb/in", digits: 0),
                line("Front ride height", rideHeight.front, "in"),
                line("Rear ride height", rideHeight.rear, "in")
            ]),
            TuneSection(title: "Damping", symbolName: "slider.horizontal.3", lines: [
                line("Front rebound", damping.frontRebound, "", detail: "Road baseline keeps bump near 40% of rebound; off-road and drag are exceptions."),
                line("Rear rebound", damping.rearRebound, "", detail: "Match the stiffer spring end with slightly more damping."),
                line("Front bump", damping.frontBump, ""),
                line("Rear bump", damping.rearBump, "")
            ]),
            TuneSection(title: "Aero", symbolName: "wind", lines: [
                line("Front", aero.front, "lb", digits: 0, detail: aeroDetail(for: request.discipline)),
                line("Rear", aero.rear, "lb", digits: 0, detail: aeroDetail(for: request.discipline))
            ]),
            TuneSection(title: "Brakes", symbolName: "exclamationmark.octagon", lines: [
                line("Balance", brakes.balancePercent, "%", digits: 0, detail: brakeDetail(for: request.discipline)),
                line("Pressure", brakes.pressurePercent, "%", digits: 0)
            ]),
            TuneSection(title: "Differential", symbolName: "point.3.connected.trianglepath.dotted", lines: diffLines(for: differential))
        ]

        return TuneResult(
            request: request,
            sections: sections,
            notes: TuneNotes(
                bias: "\(request.discipline.title) \(sourceSummary(for: car.drivetrain, discipline: request.discipline)).",
                ifPushesWide: "Soften front ARB first; if it happens on exit, reduce diff accel 2-5%.",
                ifSnapsOnLift: "Increase diff decel 2-5%, then soften rear ARB or rear spring if needed.",
                retuneTrigger: "Re-tune if weight distribution shifts more than 2%."
            )
        )
    }

    private func diffLines(for differential: DifferentialBaseline) -> [TuneLine] {
        [
            line("Accel", differential.accel, "%", digits: 0),
            line("Decel", differential.decel, "%", digits: 0),
            line("Front accel", differential.frontAccel, "%", digits: 0),
            line("Front decel", differential.frontDecel, "%", digits: 0),
            line("Rear accel", differential.rearAccel, "%", digits: 0),
            line("Rear decel", differential.rearDecel, "%", digits: 0),
            line("Center balance", differential.centerBalance, "% rear", digits: 0)
        ].compactMap { $0 }
    }

    private func aeroDetail(for discipline: DrivingDiscipline) -> String? {
        switch discipline {
        case .drag:
            return "Run minimum or remove aero when the build allows it."
        case .drift:
            return "Front aero is optional grip; rear aero is usually unnecessary."
        default:
            return "Increase front for high-speed push; increase rear for high-speed looseness."
        }
    }

    private func brakeDetail(for discipline: DrivingDiscipline) -> String? {
        switch discipline {
        case .touge:
            return "FH6 uses normal brake direction; this starts rotation-first for trail braking."
        case .drift:
            return "Forward bias keeps the rear calmer during mid-drift braking."
        default:
            return "Tune 1-2% at a time after suspension and diff feel right."
        }
    }

    private func sourceSummary(for drivetrain: Drivetrain, discipline: DrivingDiscipline) -> String {
        if discipline == .drift {
            return "baseline: soft, locked RWD-style drift setup."
        }
        if discipline == .drag {
            return "baseline: launch-first setup with tall gearing and minimum aero."
        }
        if discipline == .dirt || discipline == .crossCountry {
            return "baseline: soft off-road compliance with looser AWD center behavior."
        }
        return drivetrain == .awd
            ? "baseline: FH6 tarmac setup with rear-biased AWD rotation."
            : "baseline: FH6 tarmac setup with conservative diff lock."
    }

    private func line(_ label: String, _ value: Double, _ unit: String, digits: Int = 1, detail: String? = nil) -> TuneLine {
        TuneLine(label: label, value: value.formatted(.number.precision(.fractionLength(digits))), unit: unit, detail: detail)
    }

    private func line(_ label: String, _ value: Double?, _ unit: String, digits: Int = 1) -> TuneLine? {
        guard let value else { return nil }
        return line(label, value, unit, digits: digits, detail: nil)
    }

}
