//
//  TuningKnowledgeBase+Tables.swift
//  forzadvisor
//
//  Static class, discipline, and helper tables for the offline tuning baseline.
//

import Foundation

extension TuningKnowledgeBase {
    static func roadTireBase(for performanceClass: PerformanceClass) -> Double {
        switch performanceClass {
        case .d, .c:
            25
        case .b:
            25.5
        case .a:
            26.5
        case .s1:
            28
        case .s2:
            30
        case .r, .x:
            31
        }
    }

    static func classGearingBase(for performanceClass: PerformanceClass) -> Double {
        switch performanceClass {
        case .d, .c:
            3.35
        case .b:
            3.45
        case .a:
            3.6
        case .s1:
            3.75
        case .s2:
            3.9
        case .r, .x:
            4.05
        }
    }

    static func disciplineGearingAdjustment(for discipline: DrivingDiscipline) -> Double {
        switch discipline {
        case .road:
            0
        case .touge:
            0.15
        case .drift:
            0.2
        case .dirt:
            0.1
        case .crossCountry:
            -0.05
        case .drag:
            -0.45
        }
    }

    static func classCamberExtra(for performanceClass: PerformanceClass) -> Double {
        switch performanceClass {
        case .d, .c:
            0
        case .b:
            -0.05
        case .a:
            -0.15
        case .s1:
            -0.3
        case .s2:
            -0.45
        case .r, .x:
            -0.55
        }
    }

    static func classARBBase(for performanceClass: PerformanceClass) -> Double {
        switch performanceClass {
        case .d, .c:
            38
        case .b:
            42
        case .a:
            46
        case .s1:
            52
        case .s2:
            57
        case .r, .x:
            61
        }
    }

    static func springFactor(for discipline: DrivingDiscipline) -> Double {
        switch discipline {
        case .road:
            0.34
        case .touge:
            0.35
        case .drift:
            0.12
        case .dirt:
            0.22
        case .crossCountry:
            0.25
        case .drag:
            0.2
        }
    }

    static func springClassBonus(for performanceClass: PerformanceClass, discipline: DrivingDiscipline) -> Double {
        guard discipline != .dirt && discipline != .crossCountry && discipline != .drag else {
            return 0
        }

        return switch performanceClass {
        case .d, .c:
            -20
        case .b:
            0
        case .a:
            35
        case .s1:
            80
        case .s2:
            140
        case .r, .x:
            190
        }
    }

    static func springBounds(for discipline: DrivingDiscipline) -> ClosedRange<Double> {
        switch discipline {
        case .dirt:
            180...650
        case .crossCountry:
            200...750
        case .drag:
            180...600
        default:
            220...1_200
        }
    }

    static func dampingClassExtra(for performanceClass: PerformanceClass) -> Double {
        switch performanceClass {
        case .d, .c, .b:
            0
        case .a:
            0.1
        case .s1:
            0.25
        case .s2:
            0.4
        case .r, .x:
            0.55
        }
    }

    static func classAeroBonus(for performanceClass: PerformanceClass) -> Double {
        switch performanceClass {
        case .d, .c:
            -50
        case .b:
            -25
        case .a:
            0
        case .s1:
            35
        case .s2:
            70
        case .r, .x:
            100
        }
    }

    static func estimatedHorsepower(for performanceClass: PerformanceClass) -> Int {
        switch performanceClass {
        case .d, .c:
            220
        case .b:
            320
        case .a:
            430
        case .s1:
            600
        case .s2:
            850
        case .r, .x:
            1_000
        }
    }

    static func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        min(max(value, lower), upper)
    }
}
