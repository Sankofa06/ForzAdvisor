//
//  TuneProjection.swift
//  forzadvisor
//
//  Persisted, value-free coverage metadata for capability-gated tune output.
//

import Foundation

enum TuneProjectionContextStatus: String, Codable, Sendable {
    case exactBuild
    case capabilityOnly
    case missingSnapshot
    case invalidSnapshot
}

enum TuneProjectionStatus: String, Codable, Sendable {
    case ready
    case requiresUpgrade
    case needsPartConfirmation
    case needsConstraint
    case unavailable
    case awaitingProvider
    case providerOmitted
    case rejectedValue
}

enum TuneProjectionReason: String, Codable, Sendable {
    case missingSnapshot
    case invalidSnapshot
    case capabilityUnavailable
    case partAvailabilityUnknown
    case upgradeRequired
    case missingProductionConstraint
    case providerPending
    case providerOmitted
    case duplicateField
    case unexpectedField
    case invalidGearIndex
    case malformedValue
    case wrongDisplayUnit
    case valueOutsideConstraint
}

enum TuneProjectionDiagnosticKind: String, Codable, Sendable {
    case untypedProviderLine
    case invalidRulesetReference
}

struct TuneProjectionDiagnostic: Codable, Equatable, Sendable {
    var kind: TuneProjectionDiagnosticKind
    var sectionTitle: String?
    var lineLabel: String?
}

struct TuneFieldProjection: Codable, Equatable, Sendable {
    var field: TuneFieldID
    var status: TuneProjectionStatus
    var requiredPurchaseIDs: [TunePartID]
    var unresolvedPartIDs: [TunePartID]
    var reason: TuneProjectionReason?
}

struct TunePurchasePlanItem: Codable, Equatable, Sendable {
    var part: TunePartDefinition
    var unlocks: [TuneSetting]
    var evidence: [TuneEvidence]
}

struct TuneSettingConfirmation: Codable, Equatable, Sendable {
    var setting: TuneSetting
    var candidateParts: [TunePartDefinition]
}

struct TuneProjectionReport: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var snapshotID: UUID?
    var contextStatus: TuneProjectionContextStatus
    var capabilityResolution: TuneCapabilityResolution?
    var fields: [TuneFieldProjection]
    var purchasePlan: [TunePurchasePlanItem]
    var confirmations: [TuneSettingConfirmation]
    var diagnostics: [TuneProjectionDiagnostic]

    var readyFieldIDs: Set<TuneFieldID> {
        Set(fields.lazy.filter { $0.status == .ready }.map(\.field))
    }

    var readyCount: Int { readyFieldIDs.count }

    var unavailableCount: Int {
        fields.filter { $0.status == .unavailable }.count
    }

    var requiresInGameConfirmation: Bool {
        !confirmations.isEmpty
            || fields.contains {
                $0.status == .needsConstraint
                    || $0.status == .providerOmitted
                    || $0.status == .rejectedValue
            }
    }
}

extension TuneSetting {
    var projectionLabel: String {
        switch self {
        case .tirePressure: "Tire Pressure"
        case .finalDrive: "Final Drive"
        case .gearRatios: "Individual Gears"
        case .alignment: "Alignment"
        case .frontARB: "Front Antiroll Bar"
        case .rearARB: "Rear Antiroll Bar"
        case .springRates: "Spring Rates"
        case .rideHeight: "Ride Height"
        case .damping: "Damping"
        case .frontAero: "Front Aero"
        case .rearAero: "Rear Aero"
        case .brakes: "Brakes"
        case .differentialAcceleration: "Differential Acceleration"
        case .differentialDeceleration: "Differential Deceleration"
        case .differentialCenter: "Center Differential"
        }
    }
}

extension TuneFieldID {
    var projectionLabel: String {
        switch self {
        case .frontTirePressure: "Front tire pressure"
        case .rearTirePressure: "Rear tire pressure"
        case .finalDrive: "Final drive"
        case .gearRatio(let index): "Gear \(index)"
        case .frontCamber: "Front camber"
        case .rearCamber: "Rear camber"
        case .frontToe: "Front toe"
        case .rearToe: "Rear toe"
        case .caster: "Caster"
        case .frontARB: "Front antiroll bar"
        case .rearARB: "Rear antiroll bar"
        case .frontSpringRate: "Front spring rate"
        case .rearSpringRate: "Rear spring rate"
        case .frontRideHeight: "Front ride height"
        case .rearRideHeight: "Rear ride height"
        case .frontRebound: "Front rebound"
        case .rearRebound: "Rear rebound"
        case .frontBump: "Front bump"
        case .rearBump: "Rear bump"
        case .frontAero: "Front aero"
        case .rearAero: "Rear aero"
        case .brakeBalance: "Brake balance"
        case .brakePressure: "Brake pressure"
        case .differentialAcceleration: "Differential acceleration"
        case .differentialDeceleration: "Differential deceleration"
        case .frontDifferentialAcceleration: "Front differential acceleration"
        case .frontDifferentialDeceleration: "Front differential deceleration"
        case .rearDifferentialAcceleration: "Rear differential acceleration"
        case .rearDifferentialDeceleration: "Rear differential deceleration"
        case .differentialCenterBalance: "Center differential balance"
        }
    }

    var expectedDisplayUnit: String {
        switch expectedUnit {
        case .psi: "PSI"
        case .ratio, .scalar: ""
        case .degrees: "deg"
        case .poundsPerInch: "lb/in"
        case .inches: "in"
        case .pounds: "lb"
        case .percent: "%"
        case .percentRear: "% rear"
        }
    }

    var projectionSectionTitle: String {
        switch self {
        case .frontTirePressure, .rearTirePressure: "Tires"
        case .finalDrive, .gearRatio: "Gearing"
        case .frontCamber, .rearCamber, .frontToe, .rearToe, .caster: "Alignment"
        case .frontARB, .rearARB: "Antiroll Bars"
        case .frontSpringRate, .rearSpringRate, .frontRideHeight, .rearRideHeight: "Springs"
        case .frontRebound, .rearRebound, .frontBump, .rearBump: "Damping"
        case .frontAero, .rearAero: "Aero"
        case .brakeBalance, .brakePressure: "Brakes"
        case .differentialAcceleration,
             .differentialDeceleration,
             .frontDifferentialAcceleration,
             .frontDifferentialDeceleration,
             .rearDifferentialAcceleration,
             .rearDifferentialDeceleration,
             .differentialCenterBalance:
            "Differential"
        }
    }

    var projectionSectionSymbol: String {
        switch projectionSectionTitle {
        case "Tires": "circle.dashed"
        case "Gearing": "gearshape.2"
        case "Alignment": "arrow.left.and.right"
        case "Antiroll Bars": "arrow.up.left.and.arrow.down.right"
        case "Springs": "waveform.path.ecg"
        case "Damping": "slider.horizontal.3"
        case "Aero": "wind"
        case "Brakes": "exclamationmark.octagon"
        default: "point.3.connected.trianglepath.dotted"
        }
    }

    static func expectedFields(drivetrain: Drivetrain, gearCount: Int?) -> [TuneFieldID] {
        var fields: [TuneFieldID] = [
            .frontTirePressure, .rearTirePressure,
            .finalDrive,
            .frontCamber, .rearCamber, .frontToe, .rearToe, .caster,
            .frontARB, .rearARB,
            .frontSpringRate, .rearSpringRate,
            .frontRideHeight, .rearRideHeight,
            .frontRebound, .rearRebound, .frontBump, .rearBump,
            .frontAero, .rearAero,
            .brakeBalance, .brakePressure
        ]

        if let gearCount, gearCount > 0 {
            fields.insert(contentsOf: (1...gearCount).map(TuneFieldID.gearRatio), at: 3)
        }

        switch drivetrain {
        case .fwd:
            fields.append(contentsOf: [
                .frontDifferentialAcceleration,
                .frontDifferentialDeceleration
            ])
        case .rwd:
            fields.append(contentsOf: [
                .differentialAcceleration,
                .differentialDeceleration
            ])
        case .awd:
            fields.append(contentsOf: [
                .frontDifferentialAcceleration,
                .frontDifferentialDeceleration,
                .rearDifferentialAcceleration,
                .rearDifferentialDeceleration,
                .differentialCenterBalance
            ])
        }
        return fields
    }
}

extension TuneAdjustment {
    var affectedFields: Set<TuneFieldID> {
        switch self {
        case .moreRotation, .moreStability:
            return [
                .frontARB, .rearARB,
                .differentialAcceleration, .differentialDeceleration,
                .frontDifferentialAcceleration, .frontDifferentialDeceleration,
                .rearDifferentialAcceleration, .rearDifferentialDeceleration,
                .differentialCenterBalance
            ]
        case .softer, .stiffer:
            return [
                .frontSpringRate, .rearSpringRate,
                .frontRebound, .rearRebound, .frontBump, .rearBump
            ]
        case .moreTopSpeed, .moreAcceleration:
            return [.finalDrive, .frontAero, .rearAero]
        }
    }
}
