//
//  TuningDomain.swift
//  forzadvisor
//
//  Core value types shared by manual entry, tune generation, tune display, and
//  future SwiftData/API boundaries.
//

import Foundation

enum PerformanceClass: String, CaseIterable, Codable, Identifiable {
    case c = "C"
    case b = "B"
    case a = "A"
    case s1 = "S1"
    case s2 = "S2"
    case x = "X"

    var id: String { rawValue }
}

enum Drivetrain: String, CaseIterable, Codable, Identifiable {
    case fwd = "FWD"
    case rwd = "RWD"
    case awd = "AWD"

    var id: String { rawValue }
}

enum DrivingDiscipline: String, CaseIterable, Codable, Identifiable {
    case road
    case touge
    case drift
    case dirt
    case crossCountry
    case drag

    var id: String { rawValue }

    var title: String {
        switch self {
        case .road: "Road"
        case .touge: "Touge"
        case .drift: "Drift"
        case .dirt: "Dirt/Rally"
        case .crossCountry: "Cross-Country"
        case .drag: "Drag"
        }
    }

    var symbolName: String {
        switch self {
        case .road: "road.lanes"
        case .touge: "mountain.2"
        case .drift: "arrow.triangle.2.circlepath"
        case .dirt: "cloud.dust"
        case .crossCountry: "suv.side"
        case .drag: "flag.checkered"
        }
    }

    var summary: String {
        switch self {
        case .road: "Balanced grip and predictable braking"
        case .touge: "Fast rotation for technical descents"
        case .drift: "Loose rear with recoverable angle"
        case .dirt: "Compliance for mixed loose surfaces"
        case .crossCountry: "Travel and stability for rough terrain"
        case .drag: "Launch grip and high-speed pull"
        }
    }
}

struct CarInput: Codable, Equatable {
    var year: Int?
    var make: String
    var model: String
    var weightPounds: Int
    var frontWeightPercent: Double
    var performanceIndex: Int
    var performanceClass: PerformanceClass
    var drivetrain: Drivetrain
    var peakHorsepower: Int?
    var peakTorqueFootPounds: Int?

    var displayName: String {
        let name = [make, model]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        guard let year else { return name.isEmpty ? "Untitled car" : name }
        return name.isEmpty ? "\(year) car" : "\(year) \(name)"
    }

    var validationIssues: [ValidationIssue] {
        var issues: [ValidationIssue] = []
        if make.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.missingName)
        }
        if !(1500...7000).contains(weightPounds) {
            issues.append(.invalidWeight)
        }
        if !(30...70).contains(frontWeightPercent) {
            issues.append(.invalidFrontWeight)
        }
        if !(100...999).contains(performanceIndex) {
            issues.append(.invalidPerformanceIndex)
        }
        return issues
    }

    var isValid: Bool {
        validationIssues.isEmpty
    }
}

enum ValidationIssue: Identifiable, Equatable {
    case missingName
    case invalidWeight
    case invalidFrontWeight
    case invalidPerformanceIndex

    var id: String { message }

    var message: String {
        switch self {
        case .missingName: "Add at least a make or model."
        case .invalidWeight: "Weight should be between 1,500 and 7,000 lb."
        case .invalidFrontWeight: "Front weight should be between 30% and 70%."
        case .invalidPerformanceIndex: "PI should be between 100 and 999."
        }
    }
}

struct TuneRequest: Codable, Equatable {
    var car: CarInput
    var discipline: DrivingDiscipline
}

struct TuneResult: Identifiable, Codable, Equatable {
    var id = UUID()
    var request: TuneRequest
    var sections: [TuneSection]
    var notes: TuneNotes
    var generatedAt: Date = .now
}

struct TuneSection: Identifiable, Codable, Equatable {
    var id: String { title }
    var title: String
    var symbolName: String
    var lines: [TuneLine]
}

struct TuneLine: Identifiable, Codable, Equatable {
    var id: String { "\(label)-\(value)-\(unit)" }
    var label: String
    var value: String
    var unit: String
    var detail: String?

    var copyText: String {
        unit.isEmpty ? "\(label): \(value)" : "\(label): \(value) \(unit)"
    }
}

struct TuneNotes: Codable, Equatable {
    var bias: String
    var ifPushesWide: String
    var ifSnapsOnLift: String
    var retuneTrigger: String
}

enum TuneAdjustment: String, CaseIterable, Identifiable {
    case moreRotation
    case moreStability
    case softer
    case stiffer
    case moreTopSpeed
    case moreAcceleration

    var id: String { rawValue }

    var title: String {
        switch self {
        case .moreRotation: "More rotation"
        case .moreStability: "More stability"
        case .softer: "Softer"
        case .stiffer: "Stiffer"
        case .moreTopSpeed: "More top speed"
        case .moreAcceleration: "More acceleration"
        }
    }

    var symbolName: String {
        switch self {
        case .moreRotation: "arrow.triangle.2.circlepath"
        case .moreStability: "shield"
        case .softer: "arrow.down.forward.and.arrow.up.backward"
        case .stiffer: "arrow.up.backward.and.arrow.down.forward"
        case .moreTopSpeed: "speedometer"
        case .moreAcceleration: "bolt"
        }
    }
}

enum TuneFeedback: String, CaseIterable, Identifiable {
    case pushesWide
    case oversteersOnExit
    case snapsOnLift
    case wheelspinOnLaunch
    case bouncyOverBumps
    case feelsFloaty
    case runsOutOfGear
    case needsMorePull

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pushesWide: "Pushes wide"
        case .oversteersOnExit: "Oversteers on exit"
        case .snapsOnLift: "Snaps on lift"
        case .wheelspinOnLaunch: "Wheelspin on launch"
        case .bouncyOverBumps: "Bouncy over bumps"
        case .feelsFloaty: "Feels floaty"
        case .runsOutOfGear: "Runs out of gear"
        case .needsMorePull: "Needs more pull"
        }
    }

    var prompt: String {
        switch self {
        case .pushesWide: "Car will not rotate into or through the corner."
        case .oversteersOnExit: "Rear steps out when throttle comes in."
        case .snapsOnLift: "Rear rotates too sharply when lifting or braking."
        case .wheelspinOnLaunch: "Too much slip before the car hooks up."
        case .bouncyOverBumps: "The car skips, hops, or loses contact."
        case .feelsFloaty: "Body motion is slow and unsettled."
        case .runsOutOfGear: "Hits limiter or needs more top speed."
        case .needsMorePull: "Acceleration feels lazy out of corners."
        }
    }

    var symbolName: String {
        switch self {
        case .pushesWide: "arrow.turn.up.right"
        case .oversteersOnExit: "arrow.triangle.2.circlepath"
        case .snapsOnLift: "exclamationmark.triangle"
        case .wheelspinOnLaunch: "flag.checkered"
        case .bouncyOverBumps: "waveform.path.ecg"
        case .feelsFloaty: "slider.horizontal.3"
        case .runsOutOfGear: "speedometer"
        case .needsMorePull: "bolt"
        }
    }

    var adjustment: TuneAdjustment {
        switch self {
        case .pushesWide: .moreRotation
        case .oversteersOnExit, .snapsOnLift, .wheelspinOnLaunch: .moreStability
        case .bouncyOverBumps: .softer
        case .feelsFloaty: .stiffer
        case .runsOutOfGear: .moreTopSpeed
        case .needsMorePull: .moreAcceleration
        }
    }

    var rationale: String {
        switch self {
        case .pushesWide: "Adds rotation by softening front roll resistance and freeing the rear to turn."
        case .oversteersOnExit: "Adds stability by calming rear rotation and reducing aggressive diff lock."
        case .snapsOnLift: "Stabilizes lift-off behavior with more decel lock and a calmer rear balance."
        case .wheelspinOnLaunch: "Tames launch slip by adding stability before chasing more acceleration."
        case .bouncyOverBumps: "Softens springs and damping so the tires stay in contact over rough surfaces."
        case .feelsFloaty: "Adds spring and damping support so body motion settles faster."
        case .runsOutOfGear: "Lowers the final drive and trims drag so the car has more room up top."
        case .needsMorePull: "Shortens gearing and adds grip-biased support for stronger corner exit pull."
        }
    }
}

struct TuneAdjustmentResult: Equatable {
    var tune: TuneResult
    var changes: [TuneAdjustmentChange]
}

struct TuneAdjustmentChange: Identifiable, Equatable {
    var sectionTitle: String
    var lineLabel: String
    var oldValue: String
    var newValue: String
    var unit: String
    var rationale: String? = nil

    var id: String {
        "\(sectionTitle)-\(lineLabel)-\(oldValue)-\(newValue)-\(unit)-\(rationale ?? "")"
    }
}

enum SampleTuningData {
    static let starterCar = CarInput(
        year: 2019,
        make: "Toyota",
        model: "Supra",
        weightPounds: 3340,
        frontWeightPercent: 53,
        performanceIndex: 750,
        performanceClass: .s1,
        drivetrain: .rwd,
        peakHorsepower: 480,
        peakTorqueFootPounds: 410
    )
}
