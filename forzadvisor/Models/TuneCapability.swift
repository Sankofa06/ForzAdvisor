//
//  TuneCapability.swift
//  forzadvisor
//
//  Honest, source-attributed tune-setting and upgrade capability values.
//

import Foundation

enum TuneSetting: String, CaseIterable, Codable, Identifiable, Sendable {
    case tirePressure
    case finalDrive
    case gearRatios
    case alignment
    case frontARB
    case rearARB
    case springRates
    case rideHeight
    case damping
    case frontAero
    case rearAero
    case brakes
    case differentialAcceleration
    case differentialDeceleration
    case differentialCenter

    var id: String { rawValue }
}

enum TuneCapabilityStatus: String, Codable, Sendable {
    case stockAvailable
    case installedUpgrade
    case requiresUpgrade
    case unavailable
    case unknown
}

enum TuneEvidenceConfidence: String, Codable, Sendable {
    case high
    case medium
    case low
}

struct TuneEvidence: Codable, Equatable, Sendable {
    var confidence: TuneEvidenceConfidence
    var source: String
    var version: String
    var usagePermission: TuneDataUsagePermission

    enum CodingKeys: String, CodingKey {
        case confidence, source, version, usagePermission
    }

    init(
        confidence: TuneEvidenceConfidence,
        source: String,
        version: String,
        usagePermission: TuneDataUsagePermission = .unknown
    ) {
        self.confidence = confidence
        self.source = source
        self.version = version
        self.usagePermission = usagePermission
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        confidence = try container.decode(TuneEvidenceConfidence.self, forKey: .confidence)
        source = try container.decode(String.self, forKey: .source)
        version = try container.decode(String.self, forKey: .version)
        usagePermission = try container.decodeIfPresent(
            TuneDataUsagePermission.self,
            forKey: .usagePermission
        ) ?? .unknown
    }
}

struct TuneVehicleIdentity: Codable, Equatable, Sendable {
    var game: ForzaGame
    var catalogID: String
    var year: Int
    var make: String
    var model: String
}

enum TunePartAvailability: String, Codable, Sendable {
    case installed
    case available
    case unavailable
    case unknown
}

struct TuneVehiclePart: Codable, Equatable, Sendable {
    var partID: TunePartID
    var availability: TunePartAvailability
    var evidence: TuneEvidence
}

struct StockAdjustableSetting: Codable, Equatable, Sendable {
    var setting: TuneSetting
    var evidence: TuneEvidence
}

struct TuneVehicleCapabilityProfile: Codable, Equatable, Sendable {
    var vehicle: TuneVehicleIdentity
    var drivetrain: Drivetrain
    var parts: [TuneVehiclePart]
    var stockAdjustableSettings: [StockAdjustableSetting]
}

enum TuneRequirementKind: String, Codable, Sendable {
    case anyOf
    case allOf
}

struct TuneRequirementGroup: Codable, Equatable, Sendable {
    var kind: TuneRequirementKind
    var partIDs: [TunePartID]
}

struct TuneSettingCapability: Codable, Equatable, Sendable {
    var setting: TuneSetting
    var status: TuneCapabilityStatus
    var requirement: TuneRequirementGroup?
    var requiredPurchaseIDs: [TunePartID]
    var unresolvedPartIDs: [TunePartID]
    var evidence: [TuneEvidence]
}

struct TuneCapabilityResolution: Codable, Equatable, Sendable {
    var vehicle: TuneVehicleIdentity
    var drivetrain: Drivetrain
    var settings: [TuneSettingCapability]
    var requiredPurchases: [TunePartDefinition]
    var unresolvedConfirmations: [TunePartID]
}
