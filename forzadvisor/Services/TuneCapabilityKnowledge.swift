//
//  TuneCapabilityKnowledge.swift
//  forzadvisor
//
//  Versioned global unlock knowledge. Per-car profiles remain authoritative.
//

import Foundation

struct TuneUnlockRule: Codable, Equatable, Sendable {
    var setting: TuneSetting
    var stockAvailable: Bool
    var requirement: TuneRequirementGroup?
    var supportedDrivetrains: [Drivetrain]
}

struct TuneCapabilityKnowledge: Codable, Equatable, Sendable {
    var game: ForzaGame
    var evidence: TuneEvidence
    var rules: [TuneUnlockRule]

    static func defaults(for game: ForzaGame) -> TuneCapabilityKnowledge {
        let evidence = switch game {
        case .fh5:
            TuneEvidence(
                confidence: .high,
                source: "forzadvisor.fh5.global-upgrade-unlocks",
                version: "2026.07.1",
                usagePermission: .permitted
            )
        case .fh6:
            TuneEvidence(
                confidence: .medium,
                source: "forzadvisor.fh6.global-upgrade-unlocks",
                version: "2026.07.1",
                usagePermission: .permitted
            )
        }

        return TuneCapabilityKnowledge(game: game, evidence: evidence, rules: defaultRules)
    }

    private static var defaultRules: [TuneUnlockRule] {
        let fullTransmissions: [TunePartID] = [.raceTransmission, .driftTransmission]
        let adjustableSuspensions: [TunePartID] = [
            .raceSuspension,
            .rallySuspension,
            .offroadSuspension,
            .driftSuspension
        ]
        let fullDifferentials: [TunePartID] = [
            .raceDifferential,
            .rallyDifferential,
            .offroadDifferential,
            .driftDifferential
        ]

        return [
            stock(.tirePressure),
            anyOf(.finalDrive, [.sportTransmission] + fullTransmissions),
            anyOf(.gearRatios, fullTransmissions),
            anyOf(.alignment, adjustableSuspensions),
            anyOf(.frontARB, [.raceFrontAntirollBar]),
            anyOf(.rearARB, [.raceRearAntirollBar]),
            anyOf(.springRates, adjustableSuspensions),
            anyOf(.rideHeight, adjustableSuspensions),
            anyOf(.damping, adjustableSuspensions),
            anyOf(.frontAero, [.raceFrontBumper]),
            anyOf(.rearAero, [.raceRearWing]),
            anyOf(.brakes, [.raceBrakes]),
            anyOf(.differentialAcceleration, [.sportDifferential] + fullDifferentials),
            anyOf(.differentialDeceleration, fullDifferentials),
            anyOf(.differentialCenter, fullDifferentials, drivetrains: [.awd])
        ]
    }

    private static func stock(_ setting: TuneSetting) -> TuneUnlockRule {
        TuneUnlockRule(
            setting: setting,
            stockAvailable: true,
            requirement: nil,
            supportedDrivetrains: Drivetrain.allCases
        )
    }

    private static func anyOf(
        _ setting: TuneSetting,
        _ partIDs: [TunePartID],
        drivetrains: [Drivetrain] = Drivetrain.allCases
    ) -> TuneUnlockRule {
        TuneUnlockRule(
            setting: setting,
            stockAvailable: false,
            requirement: TuneRequirementGroup(kind: .anyOf, partIDs: partIDs),
            supportedDrivetrains: drivetrains
        )
    }
}
