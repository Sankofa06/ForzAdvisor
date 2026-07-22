//
//  TunePartCatalog.swift
//  forzadvisor
//
//  Canonical terms used to match catalog data and explain exact purchases.
//

import Foundation

enum TunePartCatalog {
    nonisolated static var parts: [TunePartDefinition] {
        TunePartID.allCases.map(definition(for:))
    }

    nonisolated static func definition(for id: TunePartID) -> TunePartDefinition {
        switch id {
        case .sportTransmission:
            part(id, .drivetrain, .transmission, "Sport Transmission", ["Sport Gearbox"])
        case .raceTransmission:
            part(id, .drivetrain, .transmission, "Race Transmission", ["Race Gearbox"])
        case .driftTransmission:
            part(id, .drivetrain, .transmission, "Drift Transmission", ["Drift Gearbox"])
        case .raceSuspension:
            part(id, .platformAndHandling, .suspension, "Race Spring and Dampers", ["Race Springs and Dampers", "Race Suspension"])
        case .rallySuspension:
            part(id, .platformAndHandling, .suspension, "Rally Spring and Dampers", ["Rally Springs and Dampers", "Rally Suspension"])
        case .offroadSuspension:
            part(id, .platformAndHandling, .suspension, "Offroad Spring and Dampers", ["Offroad Springs and Dampers", "Off-Road Suspension", "Offroad Suspension"])
        case .driftSuspension:
            part(id, .platformAndHandling, .suspension, "Drift Spring and Dampers", ["Drift Springs and Dampers", "Drift Suspension"])
        case .raceFrontAntirollBar:
            part(id, .platformAndHandling, .frontAntirollBar, "Race Front Antiroll Bars", ["Race Front ARBs", "Race Front Anti-Roll Bars"])
        case .raceRearAntirollBar:
            part(id, .platformAndHandling, .rearAntirollBar, "Race Rear Antiroll Bars", ["Race Rear ARBs", "Race Rear Anti-Roll Bars"])
        case .raceFrontBumper:
            part(id, .aeroAndAppearance, .frontAero, "Race Front Bumper", ["Race Front Aero"])
        case .raceRearWing:
            part(id, .aeroAndAppearance, .rearAero, "Race Rear Wing", ["Race Rear Aero"])
        case .raceBrakes:
            part(id, .platformAndHandling, .brakes, "Race Brakes", ["Race Brake Upgrade"])
        case .sportDifferential:
            part(id, .drivetrain, .differential, "Sport Differential", ["Sport Diff"])
        case .raceDifferential:
            part(id, .drivetrain, .differential, "Race Differential", ["Race Diff"])
        case .rallyDifferential:
            part(id, .drivetrain, .differential, "Rally Differential", ["Rally Diff"])
        case .offroadDifferential:
            part(id, .drivetrain, .differential, "Offroad Differential", ["Off-Road Differential", "Offroad Diff"])
        case .driftDifferential:
            part(id, .drivetrain, .differential, "Drift Differential", ["Drift Diff"])
        }
    }

    nonisolated private static func part(
        _ id: TunePartID,
        _ category: TunePartCategory,
        _ slot: TunePartSlot,
        _ label: String,
        _ aliases: [String]
    ) -> TunePartDefinition {
        TunePartDefinition(id: id, category: category, slot: slot, label: label, aliases: aliases)
    }
}
