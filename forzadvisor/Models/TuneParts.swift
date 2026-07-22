//
//  TuneParts.swift
//  forzadvisor
//
//  Stable upgrade identifiers and canonical US-English catalog terms.
//

import Foundation

enum TunePartID: String, CaseIterable, Codable, Identifiable, Sendable {
    case sportTransmission
    case raceTransmission
    case driftTransmission
    case raceSuspension
    case rallySuspension
    case offroadSuspension
    case driftSuspension
    case raceFrontAntirollBar
    case raceRearAntirollBar
    case raceFrontBumper
    case raceRearWing
    case raceBrakes
    case sportDifferential
    case raceDifferential
    case rallyDifferential
    case offroadDifferential
    case driftDifferential

    var id: String { rawValue }
}

enum TunePartCategory: String, Codable, Sendable {
    case drivetrain
    case platformAndHandling
    case aeroAndAppearance

    var label: String {
        switch self {
        case .drivetrain: "Drivetrain"
        case .platformAndHandling: "Platform and Handling"
        case .aeroAndAppearance: "Aero and Appearance"
        }
    }
}

enum TunePartSlot: String, CaseIterable, Codable, Sendable {
    case transmission
    case suspension
    case frontAntirollBar
    case rearAntirollBar
    case frontAero
    case rearAero
    case brakes
    case differential

    var label: String {
        switch self {
        case .transmission: "Transmission"
        case .suspension: "Spring and Dampers"
        case .frontAntirollBar: "Front Antiroll Bars"
        case .rearAntirollBar: "Rear Antiroll Bars"
        case .frontAero: "Front Bumper"
        case .rearAero: "Rear Wing"
        case .brakes: "Brakes"
        case .differential: "Differential"
        }
    }
}

struct TunePartDefinition: Codable, Equatable, Identifiable, Sendable {
    var id: TunePartID
    var category: TunePartCategory
    var slot: TunePartSlot
    var label: String
    var aliases: [String]
}
