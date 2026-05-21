//
//  TuneProvider.swift
//  forzadvisor
//
//  Defines the tune generation boundary. LocalSampleTuneProvider gives the UI a
//  deterministic, offline implementation until the API client is introduced.
//

import Foundation

protocol TuneProvider {
    func generateTune(for request: TuneRequest) async throws -> TuneResult
    func adjustTune(previous tune: TuneResult, adjustment: TuneAdjustment) async throws -> TuneAdjustmentResult
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
        let frontWeightRatio = car.frontWeightPercent / 100
        let rearWeightRatio = 1 - frontWeightRatio
        let classBias = classBias(for: car.performanceClass)
        let disciplineBias = disciplineBias(for: request.discipline)
        let drivetrainBias = drivetrainBias(for: car.drivetrain)

        let frontTire = clamp(27 + classBias.tire + disciplineBias.frontTire, 24, 34)
        let rearTire = clamp(27 + classBias.tire + disciplineBias.rearTire + drivetrainBias.rearTire, 24, 34)
        let finalDrive = clamp(3.2 + classBias.gearing + disciplineBias.gearing, 2.5, 5.5)
        let frontCamber = clamp(-1.6 - classBias.camber - disciplineBias.camber, -4.5, -0.5)
        let rearCamber = clamp(frontCamber + 0.8 + drivetrainBias.rearCamber, -3.5, -0.3)
        let caster = clamp(5.2 + disciplineBias.caster, 4.5, 7)

        let frontSpring = springRate(weight: car.weightPounds, ratio: frontWeightRatio, classBias: classBias.spring)
        let rearSpring = springRate(weight: car.weightPounds, ratio: rearWeightRatio, classBias: classBias.spring)
        let frontArb = clamp(18 + (frontWeightRatio * 20) + disciplineBias.frontArb, 10, 65)
        let rearArb = clamp(18 + (rearWeightRatio * 20) + disciplineBias.rearArb + drivetrainBias.rearArb, 8, 65)
        let frontRebound = clamp(frontSpring / 85 + disciplineBias.damping, 3, 13)
        let rearRebound = clamp(rearSpring / 85 + disciplineBias.damping + drivetrainBias.rearDamping, 3, 13)

        let sections = [
            TuneSection(title: "Tires", symbolName: "circle.dashed", lines: [
                line("Front pressure", frontTire, "PSI"),
                line("Rear pressure", rearTire, "PSI")
            ]),
            TuneSection(title: "Gearing", symbolName: "gearshape.2", lines: [
                line("Final drive", finalDrive, "", digits: 2),
                TuneLine(label: "Individual gears", value: "Stock baseline", unit: "", detail: "Adjust after top-speed telemetry.")
            ]),
            TuneSection(title: "Alignment", symbolName: "arrow.left.and.right", lines: [
                line("Front camber", frontCamber, "deg"),
                line("Rear camber", rearCamber, "deg"),
                line("Front toe", disciplineBias.frontToe, "deg"),
                line("Rear toe", disciplineBias.rearToe, "deg"),
                line("Caster", caster, "deg")
            ]),
            TuneSection(title: "Antiroll Bars", symbolName: "arrow.up.left.and.arrow.down.right", lines: [
                line("Front", frontArb, ""),
                line("Rear", rearArb, "")
            ]),
            TuneSection(title: "Springs", symbolName: "waveform.path.ecg", lines: [
                line("Front rate", frontSpring, "lb/in", digits: 0),
                line("Rear rate", rearSpring, "lb/in", digits: 0),
                line("Front ride height", disciplineBias.rideHeight, "in"),
                line("Rear ride height", disciplineBias.rideHeight + disciplineBias.rake, "in")
            ]),
            TuneSection(title: "Damping", symbolName: "slider.horizontal.3", lines: [
                line("Front rebound", frontRebound, ""),
                line("Rear rebound", rearRebound, ""),
                line("Front bump", frontRebound * 0.62, ""),
                line("Rear bump", rearRebound * 0.62, "")
            ]),
            TuneSection(title: "Aero", symbolName: "wind", lines: aeroLines(for: request.discipline, classBias: classBias)),
            TuneSection(title: "Brakes", symbolName: "exclamationmark.octagon", lines: [
                line("Balance", 50 + disciplineBias.brakeBalance, "%", digits: 0),
                line("Pressure", 100 + disciplineBias.brakePressure, "%", digits: 0)
            ]),
            TuneSection(title: "Differential", symbolName: "point.3.connected.trianglepath.dotted", lines: diffLines(for: car.drivetrain, discipline: request.discipline))
        ]

        return TuneResult(
            request: request,
            sections: sections,
            notes: TuneNotes(
                bias: "\(request.discipline.title) baseline with \(biasSummary(for: car.drivetrain, discipline: request.discipline)).",
                ifPushesWide: "Soften front ARB by 2 or add 0.1 rear toe-out.",
                ifSnapsOnLift: "Lower rear rebound by 0.4 and reduce rear diff decel by 5%.",
                retuneTrigger: "Re-tune if weight distribution shifts more than 2%."
            )
        )
    }

    private func springRate(weight: Int, ratio: Double, classBias: Double) -> Double {
        clamp((Double(weight) * ratio * 0.32) + classBias, 220, 1_200)
    }

    private func aeroLines(for discipline: DrivingDiscipline, classBias: ClassBias) -> [TuneLine] {
        switch discipline {
        case .drag:
            return [TuneLine(label: "Aero", value: "Minimum usable", unit: "", detail: "Reduce drag unless launch stability suffers.")]
        case .dirt, .crossCountry:
            return [
                line("Front", 110 + classBias.aero, "lb", digits: 0),
                line("Rear", 140 + classBias.aero, "lb", digits: 0)
            ]
        default:
            return [
                line("Front", 160 + classBias.aero, "lb", digits: 0),
                line("Rear", 190 + classBias.aero, "lb", digits: 0)
            ]
        }
    }

    private func diffLines(for drivetrain: Drivetrain, discipline: DrivingDiscipline) -> [TuneLine] {
        switch drivetrain {
        case .fwd:
            return [
                line("Front accel", discipline == .drag ? 65 : 35, "%", digits: 0),
                line("Front decel", 12, "%", digits: 0)
            ]
        case .rwd:
            return [
                line("Accel", discipline == .drift ? 82 : 55, "%", digits: 0),
                line("Decel", discipline == .drift ? 48 : 30, "%", digits: 0)
            ]
        case .awd:
            return [
                line("Front accel", 22, "%", digits: 0),
                line("Front decel", 8, "%", digits: 0),
                line("Rear accel", discipline == .drag ? 72 : 58, "%", digits: 0),
                line("Rear decel", 24, "%", digits: 0),
                line("Center balance", discipline == .dirt ? 62 : 70, "% rear", digits: 0)
            ]
        }
    }

    private func line(_ label: String, _ value: Double, _ unit: String, digits: Int = 1) -> TuneLine {
        TuneLine(label: label, value: value.formatted(.number.precision(.fractionLength(digits))), unit: unit)
    }

    private func line(_ label: String, _ value: Int, _ unit: String, digits: Int = 0) -> TuneLine {
        line(label, Double(value), unit, digits: digits)
    }

    private func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        min(max(value, lower), upper)
    }

    private func classBias(for performanceClass: PerformanceClass) -> ClassBias {
        switch performanceClass {
        case .c: ClassBias(tire: -1, gearing: -0.2, camber: 0, spring: -20, aero: -40)
        case .b: ClassBias(tire: -0.5, gearing: -0.1, camber: 0.1, spring: 0, aero: -20)
        case .a: ClassBias(tire: 0, gearing: 0, camber: 0.2, spring: 35, aero: 0)
        case .s1: ClassBias(tire: 0.5, gearing: 0.15, camber: 0.4, spring: 80, aero: 25)
        case .s2: ClassBias(tire: 1, gearing: 0.25, camber: 0.65, spring: 140, aero: 55)
        case .x: ClassBias(tire: 1.5, gearing: 0.35, camber: 0.8, spring: 190, aero: 80)
        }
    }

    private func disciplineBias(for discipline: DrivingDiscipline) -> DisciplineBias {
        switch discipline {
        case .road:
            DisciplineBias(frontTire: 0, rearTire: 0, gearing: 0, camber: 0, caster: 0.1, frontToe: 0, rearToe: 0, frontArb: 0, rearArb: 0, damping: 0, rideHeight: 4.6, rake: 0.1, brakeBalance: 0, brakePressure: 0)
        case .touge:
            DisciplineBias(frontTire: -0.4, rearTire: -0.1, gearing: 0.15, camber: 0.25, caster: 0.4, frontToe: -0.1, rearToe: 0.1, frontArb: -1, rearArb: 4, damping: 0.3, rideHeight: 4.5, rake: 0.2, brakeBalance: 1, brakePressure: 4)
        case .drift:
            DisciplineBias(frontTire: 2, rearTire: 4, gearing: 0.3, camber: 0.9, caster: 0.8, frontToe: -0.3, rearToe: 0.2, frontArb: 5, rearArb: 9, damping: 0.5, rideHeight: 4.9, rake: 0, brakeBalance: -2, brakePressure: 8)
        case .dirt:
            DisciplineBias(frontTire: -2, rearTire: -2, gearing: 0.2, camber: -0.2, caster: -0.2, frontToe: 0, rearToe: 0, frontArb: -6, rearArb: -4, damping: -0.8, rideHeight: 6.2, rake: 0.2, brakeBalance: 2, brakePressure: -5)
        case .crossCountry:
            DisciplineBias(frontTire: -2.5, rearTire: -2.5, gearing: 0.1, camber: -0.3, caster: -0.3, frontToe: 0, rearToe: 0, frontArb: -8, rearArb: -6, damping: -1, rideHeight: 7, rake: 0.3, brakeBalance: 3, brakePressure: -8)
        case .drag:
            DisciplineBias(frontTire: 2, rearTire: -3, gearing: -0.4, camber: -0.8, caster: -0.4, frontToe: 0, rearToe: 0, frontArb: -4, rearArb: 2, damping: -0.2, rideHeight: 4.8, rake: -0.1, brakeBalance: 0, brakePressure: 0)
        }
    }

    private func drivetrainBias(for drivetrain: Drivetrain) -> DrivetrainBias {
        switch drivetrain {
        case .fwd: DrivetrainBias(rearTire: -0.5, rearArb: 5, rearDamping: 0.2, rearCamber: 0.2)
        case .rwd: DrivetrainBias(rearTire: 0, rearArb: 1, rearDamping: 0, rearCamber: 0)
        case .awd: DrivetrainBias(rearTire: -0.2, rearArb: 3, rearDamping: 0.1, rearCamber: 0.1)
        }
    }

    private func biasSummary(for drivetrain: Drivetrain, discipline: DrivingDiscipline) -> String {
        if discipline == .drift { return "rear-biased oversteer" }
        if discipline == .drag { return "straight-line traction" }
        return drivetrain == .awd ? "stable rotation" : "light rotation"
    }

}

private struct ClassBias {
    var tire: Double
    var gearing: Double
    var camber: Double
    var spring: Double
    var aero: Double
}

private struct DisciplineBias {
    var frontTire: Double
    var rearTire: Double
    var gearing: Double
    var camber: Double
    var caster: Double
    var frontToe: Double
    var rearToe: Double
    var frontArb: Double
    var rearArb: Double
    var damping: Double
    var rideHeight: Double
    var rake: Double
    var brakeBalance: Double
    var brakePressure: Double
}

private struct DrivetrainBias {
    var rearTire: Double
    var rearArb: Double
    var rearDamping: Double
    var rearCamber: Double
}
