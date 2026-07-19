//
//  TuningKnowledgeBase.swift
//  forzadvisor
//
//  Source-backed offline tuning heuristics used by LocalSampleTuneProvider.
//  Forza.guide is treated as the FH6 primary source; Reddit is used to
//  corroborate community baselines and identify FH5-era disagreements.
//

import Foundation

enum TuningKnowledgeBase {
    static func tirePressures(for request: TuneRequest) -> TirePressureBaseline {
        let car = request.car

        switch request.discipline {
        case .drag:
            return TirePressureBaseline(
                frontPsi: 40,
                rearPsi: 16,
                detail: "Drag baseline: high front pressure, minimum rear pressure; refine after launch tests."
            )
        case .drift:
            return TirePressureBaseline(
                frontPsi: 28,
                rearPsi: 22,
                detail: "Drift baseline keeps the front stock-ish and starts the rear low for easier rotation."
            )
        case .dirt, .crossCountry:
            let weightAdjustment = clamp((Double(car.weightPounds) - 3_200) / 1_500, -0.6, 1.2)
            let base = request.discipline == .dirt ? 18.5 : 19.5
            return TirePressureBaseline(
                frontPsi: clamp(base + weightAdjustment, 15.5, 21),
                rearPsi: clamp(base + weightAdjustment - 0.2, 15.5, 21),
                detail: "Off-road/rally baseline uses the low-pressure contact-patch range."
            )
        case .road, .touge:
            let base = roadTireBase(for: car.performanceClass)
            let weightAdjustment = clamp((Double(car.weightPounds) - 3_200) / 1_200, -0.8, 1.5)
            let frontAxleAdjustment = clamp((car.frontWeightPercent - 50) / 10 * 0.3, -0.5, 0.7)
            let rearAxleAdjustment = -frontAxleAdjustment * 0.5
            let tougeAdjustment = request.discipline == .touge ? -0.2 : 0

            return TirePressureBaseline(
                frontPsi: clamp(base + weightAdjustment + frontAxleAdjustment + tougeAdjustment, 24, 33),
                rearPsi: clamp(base + weightAdjustment + rearAxleAdjustment + tougeAdjustment, 24, 33),
                detail: "Class-inferred compound pressure; lower the hot axle if telemetry shows center heat."
            )
        }
    }

    static func alignment(for request: TuneRequest) -> AlignmentBaseline {
        let car = request.car

        if request.discipline == .drag {
            return AlignmentBaseline(
                frontCamber: -0.3,
                rearCamber: 0.2,
                frontToe: 0,
                rearToe: 0,
                caster: 7
            )
        }

        if request.discipline == .drift {
            return AlignmentBaseline(
                frontCamber: -5,
                rearCamber: -1,
                frontToe: 1,
                rearToe: -0.1,
                caster: 7
            )
        }

        let classExtra = classCamberExtra(for: car.performanceClass)
        let frontBase: Double
        let rearBase: Double
        let caster: Double

        switch request.discipline {
        case .road:
            frontBase = -0.9
            rearBase = -0.5
            caster = 6.8
        case .touge:
            frontBase = -1.2
            rearBase = -0.7
            caster = 7
        case .dirt:
            frontBase = -0.7
            rearBase = -0.5
            caster = 5.8
        case .crossCountry:
            frontBase = -0.6
            rearBase = -0.4
            caster = 5.5
        case .drag, .drift:
            fatalError("Handled above.")
        }

        let frontToe = request.discipline == .touge ? 0.1 : 0
        let rearToe = request.discipline == .touge && car.drivetrain == .rwd ? -0.1 : 0

        return AlignmentBaseline(
            frontCamber: clamp(frontBase + classExtra, -2.0, -0.3),
            rearCamber: clamp(rearBase + (classExtra * 0.45), -1.4, -0.2),
            frontToe: frontToe,
            rearToe: rearToe,
            caster: caster
        )
    }

    static func antirollBars(for request: TuneRequest) -> FrontRearBaseline {
        let car = request.car

        switch request.discipline {
        case .drag:
            return FrontRearBaseline(front: 58, rear: 58)
        case .drift:
            return FrontRearBaseline(front: 8, rear: 8)
        case .dirt:
            return FrontRearBaseline(front: 8, rear: 9)
        case .crossCountry:
            return FrontRearBaseline(front: 11, rear: 13)
        case .road, .touge:
            let stiffness = classARBBase(for: car.performanceClass)
                + clamp((Double(car.weightPounds) - 3_200) / 500, -3, 6)
            var front: Double
            var rear: Double

            switch car.drivetrain {
            case .fwd:
                front = stiffness * 0.55
                rear = stiffness * 0.95
            case .rwd:
                front = stiffness * 0.85
                rear = stiffness * 0.75
            case .awd:
                front = stiffness * 0.60
                rear = stiffness
            }

            if request.discipline == .touge {
                front -= 3
                rear += 4
            }

            return FrontRearBaseline(
                front: clamp(front, 1, 65),
                rear: clamp(rear, 1, 65)
            )
        }
    }

    static func springs(for request: TuneRequest) -> SpringBaseline {
        let car = request.car
        let frontRatio = car.frontWeightPercent / 100
        let rearRatio = 1 - frontRatio

        if request.discipline == .drift {
            let rate = clamp(Double(car.weightPounds) * 0.12, 320, 520)
            return SpringBaseline(frontRate: rate, rearRate: rate)
        }

        let factor = springFactor(for: request.discipline)
        let classBonus = springClassBonus(for: car.performanceClass, discipline: request.discipline)
        let front = Double(car.weightPounds) * frontRatio * factor + classBonus
        var rear = Double(car.weightPounds) * rearRatio * factor + classBonus

        if car.drivetrain == .rwd && (request.discipline == .road || request.discipline == .touge) {
            rear += 20
        }

        let bounds = springBounds(for: request.discipline)
        return SpringBaseline(
            frontRate: clamp(front, bounds.lowerBound, bounds.upperBound),
            rearRate: clamp(rear, bounds.lowerBound, bounds.upperBound)
        )
    }

    static func rideHeight(for request: TuneRequest) -> FrontRearBaseline {
        let heavyAdjustment = Double(request.car.weightPounds) > 4_000 ? 0.2 : 0

        switch request.discipline {
        case .road:
            return FrontRearBaseline(front: 4.3 + heavyAdjustment, rear: 4.4 + heavyAdjustment)
        case .touge:
            return FrontRearBaseline(front: 4.4 + heavyAdjustment, rear: 4.6 + heavyAdjustment)
        case .drift:
            return FrontRearBaseline(front: 4.4, rear: 4.4)
        case .dirt:
            return FrontRearBaseline(front: 6.3 + heavyAdjustment, rear: 6.5 + heavyAdjustment)
        case .crossCountry:
            return FrontRearBaseline(front: 7.0 + heavyAdjustment, rear: 7.3 + heavyAdjustment)
        case .drag:
            return FrontRearBaseline(front: 7.2, rear: 7.2)
        }
    }

    static func damping(for request: TuneRequest, springs: SpringBaseline) -> DampingBaseline {
        let car = request.car

        switch request.discipline {
        case .drag:
            return DampingBaseline(frontRebound: 3.5, rearRebound: 9, frontBump: 8.5, rearBump: 3.2)
        case .drift:
            return DampingBaseline(frontRebound: 4, rearRebound: 4, frontBump: 4, rearBump: 4)
        case .dirt:
            return DampingBaseline(frontRebound: 5.5, rearRebound: 5, frontBump: 1, rearBump: 1)
        case .crossCountry:
            return DampingBaseline(frontRebound: 5.8, rearRebound: 5.4, frontBump: 2, rearBump: 1.8)
        case .road, .touge:
            let frontWeight = Double(car.weightPounds) * (car.frontWeightPercent / 100)
            let rearWeight = Double(car.weightPounds) - frontWeight
            let classExtra = dampingClassExtra(for: car.performanceClass)
            let springSplit = clamp((springs.rearRate - springs.frontRate) / 250, -0.6, 0.6)
            let tougeExtra = request.discipline == .touge ? 0.2 : 0

            let frontBump = clamp(4.4 + (frontWeight / 200 * 0.1) + classExtra + tougeExtra, 4.4, 7.2)
            let rearBump = clamp(4.4 + (rearWeight / 200 * 0.1) + classExtra + springSplit + tougeExtra, 4.2, 7.2)

            return DampingBaseline(
                frontRebound: clamp(frontBump / 0.4, 10, 18),
                rearRebound: clamp(rearBump / 0.4, 10, 18),
                frontBump: frontBump,
                rearBump: rearBump
            )
        }
    }

    static func aero(for request: TuneRequest) -> FrontRearBaseline {
        let car = request.car

        switch request.discipline {
        case .drag:
            return FrontRearBaseline(front: 0, rear: 0)
        case .drift:
            return FrontRearBaseline(front: 90, rear: 0)
        case .dirt:
            return FrontRearBaseline(front: 100 + classAeroBonus(for: car.performanceClass) * 0.4, rear: 125 + classAeroBonus(for: car.performanceClass) * 0.4)
        case .crossCountry:
            return FrontRearBaseline(front: 90 + classAeroBonus(for: car.performanceClass) * 0.3, rear: 115 + classAeroBonus(for: car.performanceClass) * 0.3)
        case .road, .touge:
            let base = 135 + classAeroBonus(for: car.performanceClass)
            let hp = Double(car.peakHorsepower ?? estimatedHorsepower(for: car.performanceClass))
            let powerBonus = hp >= 800 ? 30.0 : (hp >= 400 ? 15.0 : 0)
            let tougeFront = request.discipline == .touge ? 20.0 : 0
            let tougeRear = request.discipline == .touge ? 10.0 : 0

            return FrontRearBaseline(
                front: clamp(base + powerBonus + tougeFront, 0, 500),
                rear: clamp(base + 35 + powerBonus + tougeRear, 0, 500)
            )
        }
    }

    static func brakes(for request: TuneRequest) -> BrakeBaseline {
        let car = request.car
        let heavyPressure = car.weightPounds > 4_000 ? 5.0 : 0
        let classPressure = car.performanceClass == .s2 || car.performanceClass == .x ? 5.0 : 0

        switch request.discipline {
        case .road:
            return BrakeBaseline(balancePercent: 53, pressurePercent: 100 + heavyPressure + classPressure)
        case .touge:
            return BrakeBaseline(balancePercent: 47, pressurePercent: 100 + heavyPressure)
        case .drift:
            return BrakeBaseline(balancePercent: 70, pressurePercent: 100)
        case .dirt:
            return BrakeBaseline(balancePercent: 48, pressurePercent: 95 + heavyPressure)
        case .crossCountry:
            return BrakeBaseline(balancePercent: 52, pressurePercent: 95 + heavyPressure)
        case .drag:
            return BrakeBaseline(balancePercent: 50, pressurePercent: 100)
        }
    }

}
