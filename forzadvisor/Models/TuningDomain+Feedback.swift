//
//  TuningDomain+Feedback.swift
//  forzadvisor
//
//  Guided-refinement feedback, adjustment intents, and adjustment diff models.
//

import Foundation

enum TuneAdjustment: String, CaseIterable, Identifiable, Sendable {
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

enum TuneFeedback: String, CaseIterable, Identifiable, Sendable {
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

struct TuneAdjustmentResult: Equatable, Sendable {
    var tune: TuneResult
    var changes: [TuneAdjustmentChange]
}

struct TuneAdjustmentChange: Identifiable, Equatable, Sendable {
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
