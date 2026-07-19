//
//  TuningKnowledgeBase+Driveline.swift
//  forzadvisor
//
//  Driveline and differential formulas for the offline tuning baseline.
//

import Foundation

extension TuningKnowledgeBase {
    static func finalDrive(for request: TuneRequest) -> Double {
        let car = request.car
        let horsepower = Double(car.peakHorsepower ?? estimatedHorsepower(for: car.performanceClass))
        let powerAdjustment = clamp((horsepower - 500) / 500 * -0.35, -0.45, 0.25)
        let drivetrainAdjustment = car.drivetrain == .awd ? 0.05 : 0

        return clamp(
            classGearingBase(for: car.performanceClass)
                + disciplineGearingAdjustment(for: request.discipline)
                + powerAdjustment
                + drivetrainAdjustment,
            2.5,
            5.5
        )
    }

    static func differential(for request: TuneRequest) -> DifferentialBaseline {
        let car = request.car

        switch car.drivetrain {
        case .fwd:
            if request.discipline == .drag {
                return DifferentialBaseline(frontAccel: 85, frontDecel: 0)
            }
            return DifferentialBaseline(frontAccel: 85, frontDecel: 5)
        case .rwd:
            switch request.discipline {
            case .drag:
                return DifferentialBaseline(accel: 85, decel: 0)
            case .drift:
                return DifferentialBaseline(accel: 100, decel: 10)
            case .dirt, .crossCountry:
                return DifferentialBaseline(accel: 60, decel: 10)
            case .touge:
                return DifferentialBaseline(accel: 58, decel: 12)
            case .road:
                return DifferentialBaseline(accel: 55, decel: 15)
            }
        case .awd:
            switch request.discipline {
            case .drag:
                return DifferentialBaseline(frontAccel: 85, frontDecel: 0, rearAccel: 85, rearDecel: 0, centerBalance: 75)
            case .drift:
                return DifferentialBaseline(frontAccel: 85, frontDecel: 0, rearAccel: 100, rearDecel: 10, centerBalance: 80)
            case .dirt:
                return DifferentialBaseline(frontAccel: 85, frontDecel: 5, rearAccel: 88, rearDecel: 5, centerBalance: 65)
            case .crossCountry:
                return DifferentialBaseline(frontAccel: 85, frontDecel: 5, rearAccel: 82, rearDecel: 8, centerBalance: 60)
            case .touge:
                return DifferentialBaseline(frontAccel: 85, frontDecel: 5, rearAccel: 58, rearDecel: 12, centerBalance: 78)
            case .road:
                return DifferentialBaseline(frontAccel: 85, frontDecel: 5, rearAccel: 55, rearDecel: 15, centerBalance: 75)
            }
        }
    }
}
