//
//  TuneAccuracy.swift
//  forzadvisor
//
//  Stable, source-attributed build and field constraints used to decide
//  whether a generated tune value is safe to surface.
//

import Foundation

enum TuneFieldID: Hashable, Sendable {
    case frontTirePressure
    case rearTirePressure
    case finalDrive
    case gearRatio(Int)
    case frontCamber
    case rearCamber
    case frontToe
    case rearToe
    case caster
    case frontARB
    case rearARB
    case frontSpringRate
    case rearSpringRate
    case frontRideHeight
    case rearRideHeight
    case frontRebound
    case rearRebound
    case frontBump
    case rearBump
    case frontAero
    case rearAero
    case brakeBalance
    case brakePressure
    case differentialAcceleration
    case differentialDeceleration
    case frontDifferentialAcceleration
    case frontDifferentialDeceleration
    case rearDifferentialAcceleration
    case rearDifferentialDeceleration
    case differentialCenterBalance

    var setting: TuneSetting {
        switch self {
        case .frontTirePressure, .rearTirePressure: .tirePressure
        case .finalDrive: .finalDrive
        case .gearRatio: .gearRatios
        case .frontCamber, .rearCamber, .frontToe, .rearToe, .caster: .alignment
        case .frontARB: .frontARB
        case .rearARB: .rearARB
        case .frontSpringRate, .rearSpringRate: .springRates
        case .frontRideHeight, .rearRideHeight: .rideHeight
        case .frontRebound, .rearRebound, .frontBump, .rearBump: .damping
        case .frontAero: .frontAero
        case .rearAero: .rearAero
        case .brakeBalance, .brakePressure: .brakes
        case .differentialAcceleration,
             .frontDifferentialAcceleration,
             .rearDifferentialAcceleration:
            .differentialAcceleration
        case .differentialDeceleration,
             .frontDifferentialDeceleration,
             .rearDifferentialDeceleration:
            .differentialDeceleration
        case .differentialCenterBalance: .differentialCenter
        }
    }

    var expectedUnit: TuneUnit {
        switch self {
        case .frontTirePressure, .rearTirePressure: .psi
        case .finalDrive, .gearRatio: .ratio
        case .frontCamber, .rearCamber, .frontToe, .rearToe, .caster: .degrees
        case .frontARB, .rearARB, .frontRebound, .rearRebound, .frontBump, .rearBump: .scalar
        case .frontSpringRate, .rearSpringRate: .poundsPerInch
        case .frontRideHeight, .rearRideHeight: .inches
        case .frontAero, .rearAero: .pounds
        case .brakeBalance,
             .brakePressure,
             .differentialAcceleration,
             .differentialDeceleration,
             .frontDifferentialAcceleration,
             .frontDifferentialDeceleration,
             .rearDifferentialAcceleration,
             .rearDifferentialDeceleration:
            .percent
        case .differentialCenterBalance: .percentRear
        }
    }

    var gearIndex: Int? {
        guard case .gearRatio(let index) = self else { return nil }
        return index
    }

    private var stableValue: String {
        switch self {
        case .frontTirePressure: "frontTirePressure"
        case .rearTirePressure: "rearTirePressure"
        case .finalDrive: "finalDrive"
        case .gearRatio(let index): "gearRatio.\(index)"
        case .frontCamber: "frontCamber"
        case .rearCamber: "rearCamber"
        case .frontToe: "frontToe"
        case .rearToe: "rearToe"
        case .caster: "caster"
        case .frontARB: "frontARB"
        case .rearARB: "rearARB"
        case .frontSpringRate: "frontSpringRate"
        case .rearSpringRate: "rearSpringRate"
        case .frontRideHeight: "frontRideHeight"
        case .rearRideHeight: "rearRideHeight"
        case .frontRebound: "frontRebound"
        case .rearRebound: "rearRebound"
        case .frontBump: "frontBump"
        case .rearBump: "rearBump"
        case .frontAero: "frontAero"
        case .rearAero: "rearAero"
        case .brakeBalance: "brakeBalance"
        case .brakePressure: "brakePressure"
        case .differentialAcceleration: "differentialAcceleration"
        case .differentialDeceleration: "differentialDeceleration"
        case .frontDifferentialAcceleration: "frontDifferentialAcceleration"
        case .frontDifferentialDeceleration: "frontDifferentialDeceleration"
        case .rearDifferentialAcceleration: "rearDifferentialAcceleration"
        case .rearDifferentialDeceleration: "rearDifferentialDeceleration"
        case .differentialCenterBalance: "differentialCenterBalance"
        }
    }

    var stableID: String { stableValue }
}

extension TuneFieldID: Codable {
    private static let fixedValues: [String: TuneFieldID] = [
        "frontTirePressure": .frontTirePressure,
        "rearTirePressure": .rearTirePressure,
        "finalDrive": .finalDrive,
        "frontCamber": .frontCamber,
        "rearCamber": .rearCamber,
        "frontToe": .frontToe,
        "rearToe": .rearToe,
        "caster": .caster,
        "frontARB": .frontARB,
        "rearARB": .rearARB,
        "frontSpringRate": .frontSpringRate,
        "rearSpringRate": .rearSpringRate,
        "frontRideHeight": .frontRideHeight,
        "rearRideHeight": .rearRideHeight,
        "frontRebound": .frontRebound,
        "rearRebound": .rearRebound,
        "frontBump": .frontBump,
        "rearBump": .rearBump,
        "frontAero": .frontAero,
        "rearAero": .rearAero,
        "brakeBalance": .brakeBalance,
        "brakePressure": .brakePressure,
        "differentialAcceleration": .differentialAcceleration,
        "differentialDeceleration": .differentialDeceleration,
        "frontDifferentialAcceleration": .frontDifferentialAcceleration,
        "frontDifferentialDeceleration": .frontDifferentialDeceleration,
        "rearDifferentialAcceleration": .rearDifferentialAcceleration,
        "rearDifferentialDeceleration": .rearDifferentialDeceleration,
        "differentialCenterBalance": .differentialCenterBalance
    ]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)

        if let fixed = Self.fixedValues[value] {
            self = fixed
            return
        }

        let prefix = "gearRatio."
        guard value.hasPrefix(prefix),
              let index = Int(value.dropFirst(prefix.count)),
              index > 0 else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown or invalid tune field ID: \(value)"
            )
        }
        self = .gearRatio(index)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if case .gearRatio(let index) = self {
            guard index > 0 else {
                throw EncodingError.invalidValue(
                    index,
                    EncodingError.Context(
                        codingPath: encoder.codingPath,
                        debugDescription: "Gear ratio indices must be positive."
                    )
                )
            }
        }
        try container.encode(stableValue)
    }
}

enum TuneUnit: String, Codable, Sendable {
    case psi
    case ratio
    case degrees
    case scalar
    case poundsPerInch
    case inches
    case pounds
    case percent
    case percentRear
}

enum TuneConstraintScope: String, Codable, Sendable {
    case gameGlobal
    case exactVehicleBuild
}

enum TuneConstraintVerification: String, Codable, Sendable {
    case productionEligible
    case provisional
}

enum TuneFieldConstraintIssue: Equatable, Sendable {
    case nonFiniteValue
    case invertedRange
    case invalidStep
    case wrongUnit(expected: TuneUnit, actual: TuneUnit)
    case defaultOutOfRange
    case currentOutOfRange
    case defaultOffStep
    case currentOffStep
    case missingEvidence
    case duplicateEvidenceID(String)
}

struct TuneFieldConstraint: Codable, Equatable, Sendable {
    var field: TuneFieldID
    var minimum: Double
    var maximum: Double
    var step: Double
    var defaultValue: Double?
    var currentValue: Double?
    var unit: TuneUnit
    var scope: TuneConstraintScope
    var verification: TuneConstraintVerification
    var evidenceIDs: [String]

    var validationIssues: [TuneFieldConstraintIssue] {
        var issues: [TuneFieldConstraintIssue] = []
        let values = [minimum, maximum, step] + [defaultValue, currentValue].compactMap { $0 }
        if values.contains(where: { !$0.isFinite }) {
            issues.append(.nonFiniteValue)
        }
        if minimum > maximum {
            issues.append(.invertedRange)
        }
        if !step.isFinite || step <= 0 {
            issues.append(.invalidStep)
        }
        if unit != field.expectedUnit {
            issues.append(.wrongUnit(expected: field.expectedUnit, actual: unit))
        }
        if let defaultValue, !contains(defaultValue) {
            issues.append(.defaultOutOfRange)
        } else if let defaultValue, !isOnStep(defaultValue) {
            issues.append(.defaultOffStep)
        }
        if let currentValue, !contains(currentValue) {
            issues.append(.currentOutOfRange)
        } else if let currentValue, !isOnStep(currentValue) {
            issues.append(.currentOffStep)
        }

        let normalizedEvidence = evidenceIDs.map { Self.normalized($0) }
        if normalizedEvidence.isEmpty || normalizedEvidence.contains(where: \.isEmpty) {
            issues.append(.missingEvidence)
        }
        var seen = Set<String>()
        for id in normalizedEvidence where !seen.insert(id).inserted {
            issues.append(.duplicateEvidenceID(id))
        }
        return issues
    }

    func accepts(_ value: Double, tolerance: Double = 1e-8) -> Bool {
        validationIssues.isEmpty && contains(value, tolerance: tolerance) && isOnStep(value, tolerance: tolerance)
    }

    private func contains(_ value: Double, tolerance: Double = 1e-8) -> Bool {
        value.isFinite && value >= minimum - tolerance && value <= maximum + tolerance
    }

    private func isOnStep(_ value: Double, tolerance: Double = 1e-8) -> Bool {
        guard value.isFinite, minimum.isFinite, step.isFinite, step > 0 else { return false }
        let quotient = (value - minimum) / step
        return abs(quotient - quotient.rounded()) <= tolerance
    }

    private static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct GameBuildReference: Codable, Equatable, Sendable {
    var game: ForzaGame
    var version: String?
    var capturedAt: Date?

    var hasKnownVersion: Bool {
        version?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && capturedAt != nil
    }
}

enum VehicleBuildSnapshotKind: String, Codable, Sendable {
    case capabilityOnly
    case exactBuildObservation
}

enum TuneDataUsagePermission: String, Codable, Sendable {
    case permitted
    case unknown
    case prohibited
}

struct TuneDataProvenance: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var game: ForzaGame
    var gameBuildVersion: String?
    var scope: TuneConstraintScope
    var source: String
    var version: String
    var capturedAt: Date
    var confidence: TuneEvidenceConfidence
    var usagePermission: TuneDataUsagePermission

    enum CodingKeys: String, CodingKey {
        case id, game, gameBuildVersion, scope, source, version, capturedAt, confidence, usagePermission
    }

    init(
        id: String,
        game: ForzaGame,
        gameBuildVersion: String?,
        scope: TuneConstraintScope,
        source: String,
        version: String,
        capturedAt: Date,
        confidence: TuneEvidenceConfidence,
        usagePermission: TuneDataUsagePermission = .unknown
    ) {
        self.id = id
        self.game = game
        self.gameBuildVersion = gameBuildVersion
        self.scope = scope
        self.source = source
        self.version = version
        self.capturedAt = capturedAt
        self.confidence = confidence
        self.usagePermission = usagePermission
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        game = try container.decode(ForzaGame.self, forKey: .game)
        gameBuildVersion = try container.decodeIfPresent(String.self, forKey: .gameBuildVersion)
        scope = try container.decode(TuneConstraintScope.self, forKey: .scope)
        source = try container.decode(String.self, forKey: .source)
        version = try container.decode(String.self, forKey: .version)
        capturedAt = try container.decode(Date.self, forKey: .capturedAt)
        confidence = try container.decode(TuneEvidenceConfidence.self, forKey: .confidence)
        usagePermission = try container.decodeIfPresent(
            TuneDataUsagePermission.self,
            forKey: .usagePermission
        ) ?? .unknown
    }
}

struct TireCompoundReference: Codable, Equatable, Sendable {
    var id: String
    var displayName: String
    var evidenceIDs: [String]
}

enum VehicleBuildSnapshotIssue: Equatable, Sendable {
    case unsupportedSchema(Int)
    case invalidGameBuild
    case incompleteGameBuildReference
    case exactBuildObservationRequiresVersion
    case exactConstraintRequiresKnownBuild(TuneFieldID)
    case exactEvidenceRequiresKnownBuild(String)
    case capabilityOnlyContainsExactBuildData
    case invalidCar
    case incompleteVehicleIdentity
    case invalidVehicleStatistics
    case gameMismatch
    case drivetrainMismatch
    case vehicleIdentityMismatch
    case catalogIdentityMismatch
    case invalidGearCount(Int)
    case gearIndexWithoutCount(Int)
    case gearIndexExceedsCount(index: Int, count: Int)
    case duplicateField(TuneFieldID)
    case invalidConstraint(TuneFieldID)
    case invalidEvidence(String)
    case duplicateEvidenceID(String)
    case danglingEvidenceID(String)
    case evidenceScopeMismatch(String)
    case invalidTireCompound
    case duplicatePartID(TunePartID)
    case invalidPartEvidence(TunePartID)
    case duplicateStockAdjustableSetting(TuneSetting)
    case invalidStockAdjustableEvidence(TuneSetting)
}

struct VehicleBuildSnapshot: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var id: UUID
    var kind: VehicleBuildSnapshotKind
    var capturedAt: Date
    var gameBuild: GameBuildReference
    var car: CarInput
    var capabilityProfile: TuneVehicleCapabilityProfile
    var tireCompound: TireCompoundReference?
    var gearCount: Int?
    var constraints: [TuneFieldConstraint]
    var evidenceSources: [TuneDataProvenance]

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case id
        case kind
        case capturedAt
        case gameBuild
        case car
        case capabilityProfile
        case tireCompound
        case gearCount
        case constraints
        case evidenceSources
    }

    init(
        schemaVersion: Int,
        id: UUID,
        kind: VehicleBuildSnapshotKind,
        capturedAt: Date,
        gameBuild: GameBuildReference,
        car: CarInput,
        capabilityProfile: TuneVehicleCapabilityProfile,
        tireCompound: TireCompoundReference?,
        gearCount: Int?,
        constraints: [TuneFieldConstraint],
        evidenceSources: [TuneDataProvenance]
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.kind = kind
        self.capturedAt = capturedAt
        self.gameBuild = gameBuild
        self.car = car
        self.capabilityProfile = capabilityProfile
        self.tireCompound = tireCompound
        self.gearCount = gearCount
        self.constraints = constraints
        self.evidenceSources = evidenceSources
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        id = try container.decode(UUID.self, forKey: .id)
        kind = try container.decodeIfPresent(VehicleBuildSnapshotKind.self, forKey: .kind) ?? .capabilityOnly
        capturedAt = try container.decode(Date.self, forKey: .capturedAt)
        gameBuild = try container.decode(GameBuildReference.self, forKey: .gameBuild)
        car = try container.decode(CarInput.self, forKey: .car)
        capabilityProfile = try container.decode(TuneVehicleCapabilityProfile.self, forKey: .capabilityProfile)
        tireCompound = try container.decodeIfPresent(TireCompoundReference.self, forKey: .tireCompound)
        gearCount = try container.decodeIfPresent(Int.self, forKey: .gearCount)
        constraints = try container.decode([TuneFieldConstraint].self, forKey: .constraints)
        evidenceSources = try container.decode([TuneDataProvenance].self, forKey: .evidenceSources)
    }

    var validationIssues: [VehicleBuildSnapshotIssue] {
        var issues: [VehicleBuildSnapshotIssue] = []
        if schemaVersion != Self.currentSchemaVersion {
            issues.append(.unsupportedSchema(schemaVersion))
        }
        let hasVersion = normalized(gameBuild.version ?? "").isEmpty == false
        let hasBuildCaptureDate = gameBuild.capturedAt != nil
        if hasVersion != hasBuildCaptureDate {
            issues.append(.incompleteGameBuildReference)
        }
        if kind == .exactBuildObservation && !gameBuild.hasKnownVersion {
            issues.append(.exactBuildObservationRequiresVersion)
        }
        if gameBuild.version.map({ normalized($0) })?.isEmpty == true {
            issues.append(.invalidGameBuild)
        }
        if !car.isValid {
            issues.append(.invalidCar)
        }
        if car.year == nil
            || normalized(car.make).isEmpty
            || normalized(car.model).isEmpty {
            issues.append(.incompleteVehicleIdentity)
        }
        if (car.year ?? 0) <= 0
            || car.peakHorsepower.map({ $0 <= 0 }) == true
            || car.peakTorqueFootPounds.map({ $0 <= 0 }) == true {
            issues.append(.invalidVehicleStatistics)
        }
        if gameBuild.game != car.game || capabilityProfile.vehicle.game != car.game {
            issues.append(.gameMismatch)
        }
        if capabilityProfile.drivetrain != car.drivetrain {
            issues.append(.drivetrainMismatch)
        }
        if car.year != capabilityProfile.vehicle.year
            || normalized(car.make) != normalized(capabilityProfile.vehicle.make)
            || normalized(car.model) != normalized(capabilityProfile.vehicle.model) {
            issues.append(.vehicleIdentityMismatch)
        }
        if let entryID = car.catalogReference?.entryID,
           entryID != capabilityProfile.vehicle.catalogID {
            issues.append(.catalogIdentityMismatch)
        }
        if let gearCount, !(1...10).contains(gearCount) {
            issues.append(.invalidGearCount(gearCount))
        }
        if kind == .capabilityOnly {
            if gearCount != nil
                || tireCompound != nil
                || capabilityProfile.parts.contains(where: { $0.availability == .installed }) {
                issues.append(.capabilityOnlyContainsExactBuildData)
            }
        }

        var seenPartIDs = Set<TunePartID>()
        for part in capabilityProfile.parts {
            if !seenPartIDs.insert(part.partID).inserted {
                issues.append(.duplicatePartID(part.partID))
            }
            if normalized(part.evidence.source).isEmpty
                || normalized(part.evidence.version).isEmpty
                || part.evidence.confidence == .low
                || part.evidence.usagePermission != .permitted {
                issues.append(.invalidPartEvidence(part.partID))
            }
        }

        var seenStockSettings = Set<TuneSetting>()
        for setting in capabilityProfile.stockAdjustableSettings {
            if !seenStockSettings.insert(setting.setting).inserted {
                issues.append(.duplicateStockAdjustableSetting(setting.setting))
            }
            if normalized(setting.evidence.source).isEmpty
                || normalized(setting.evidence.version).isEmpty
                || setting.evidence.confidence == .low
                || setting.evidence.usagePermission != .permitted {
                issues.append(.invalidStockAdjustableEvidence(setting.setting))
            }
        }

        var seenFields = Set<TuneFieldID>()
        for constraint in constraints {
            if !seenFields.insert(constraint.field).inserted {
                issues.append(.duplicateField(constraint.field))
            }
            if !constraint.validationIssues.isEmpty {
                issues.append(.invalidConstraint(constraint.field))
            }
            if let index = constraint.field.gearIndex {
                guard let gearCount else {
                    issues.append(.gearIndexWithoutCount(index))
                    continue
                }
                if index > gearCount {
                    issues.append(.gearIndexExceedsCount(index: index, count: gearCount))
                }
            }
            if constraint.scope == .exactVehicleBuild {
                if kind != .exactBuildObservation {
                    issues.append(.capabilityOnlyContainsExactBuildData)
                }
                if !gameBuild.hasKnownVersion {
                    issues.append(.exactConstraintRequiresKnownBuild(constraint.field))
                }
            }
        }

        var evidenceByID: [String: TuneDataProvenance] = [:]
        for evidence in evidenceSources {
            let id = normalized(evidence.id)
            if id.isEmpty
                || normalized(evidence.source).isEmpty
                || normalized(evidence.version).isEmpty
                || evidence.confidence == .low
                || evidence.usagePermission != .permitted
                || (evidence.scope == .exactVehicleBuild
                    && normalized(evidence.gameBuildVersion ?? "").isEmpty) {
                issues.append(.invalidEvidence(id))
            }
            if evidenceByID.updateValue(evidence, forKey: id) != nil {
                issues.append(.duplicateEvidenceID(id))
            }
            if evidence.game != car.game {
                issues.append(.evidenceScopeMismatch(id))
            }
            switch evidence.scope {
            case .exactVehicleBuild:
                if kind != .exactBuildObservation {
                    issues.append(.capabilityOnlyContainsExactBuildData)
                }
                if !gameBuild.hasKnownVersion {
                    issues.append(.exactEvidenceRequiresKnownBuild(id))
                } else if evidence.gameBuildVersion != gameBuild.version {
                    issues.append(.evidenceScopeMismatch(id))
                }
            case .gameGlobal:
                if let evidenceBuild = evidence.gameBuildVersion,
                   evidenceBuild != gameBuild.version {
                    issues.append(.evidenceScopeMismatch(id))
                }
            }
        }

        for constraint in constraints {
            for id in constraint.evidenceIDs.map({ normalized($0) }) where evidenceByID[id] == nil {
                issues.append(.danglingEvidenceID(id))
            }
            for id in constraint.evidenceIDs.map({ normalized($0) }) {
                if let evidence = evidenceByID[id], evidence.scope != constraint.scope {
                    issues.append(.evidenceScopeMismatch(id))
                }
            }
        }

        if let tireCompound {
            if normalized(tireCompound.id).isEmpty
                || normalized(tireCompound.displayName).isEmpty
                || tireCompound.evidenceIDs.isEmpty {
                issues.append(.invalidTireCompound)
            }
            for id in tireCompound.evidenceIDs.map({ normalized($0) }) where evidenceByID[id] == nil {
                issues.append(.danglingEvidenceID(id))
            }
            var seenTireEvidence = Set<String>()
            for id in tireCompound.evidenceIDs.map({ normalized($0) })
                where !seenTireEvidence.insert(id).inserted {
                issues.append(.duplicateEvidenceID(id))
            }
        }

        return issues
    }

    var isValid: Bool { validationIssues.isEmpty }

    func matches(car other: CarInput) -> Bool {
        car.game == other.game
            && car.year == other.year
            && normalized(car.make) == normalized(other.make)
            && normalized(car.model) == normalized(other.model)
            && car.weightPounds == other.weightPounds
            && car.frontWeightPercent == other.frontWeightPercent
            && car.performanceIndex == other.performanceIndex
            && car.performanceClass == other.performanceClass
            && car.drivetrain == other.drivetrain
            && car.peakHorsepower == other.peakHorsepower
            && car.peakTorqueFootPounds == other.peakTorqueFootPounds
            && car.catalogReference?.entryID == other.catalogReference?.entryID
    }

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum TuneRulesetValidationStatus: String, Codable, Sendable {
    case experimental
    case validated
    case deprecated
}

enum TuneRulesetDescriptorIssue: Equatable, Sendable {
    case invalidID
    case invalidSchemaVersion
    case invalidAlgorithmVersion
    case invalidKnowledgeRevision
    case missingProvenance
    case duplicateProvenanceID(String)
}

struct TuneRulesetDescriptor: Codable, Equatable, Sendable {
    var id: String
    var game: ForzaGame
    var schemaVersion: Int
    var algorithmVersion: String
    var knowledgeRevision: String
    var validationStatus: TuneRulesetValidationStatus
    var provenanceIDs: [String]

    var validationIssues: [TuneRulesetDescriptorIssue] {
        var issues: [TuneRulesetDescriptorIssue] = []
        if normalized(id).isEmpty { issues.append(.invalidID) }
        if schemaVersion <= 0 { issues.append(.invalidSchemaVersion) }
        if normalized(algorithmVersion).isEmpty { issues.append(.invalidAlgorithmVersion) }
        if normalized(knowledgeRevision).isEmpty { issues.append(.invalidKnowledgeRevision) }
        let ids = provenanceIDs.map { normalized($0) }
        if ids.isEmpty || ids.contains(where: \.isEmpty) {
            issues.append(.missingProvenance)
        }
        var seen = Set<String>()
        for id in ids where !seen.insert(id).inserted {
            issues.append(.duplicateProvenanceID(id))
        }
        return issues
    }

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct TuneRulesetReference: Codable, Equatable, Sendable {
    let id: String
    let game: ForzaGame
    let schemaVersion: Int
    let algorithmVersion: String
    let knowledgeRevision: String
    let validationStatus: TuneRulesetValidationStatus
    let provenanceIDs: [String]

    var validationIssues: [TuneRulesetDescriptorIssue] {
        descriptor.validationIssues
    }

    var isValid: Bool { validationIssues.isEmpty }

    var trustedValidationStatus: TuneRulesetValidationStatus? {
        isValid ? validationStatus : nil
    }

    init?(descriptor: TuneRulesetDescriptor) {
        guard descriptor.validationIssues.isEmpty else { return nil }
        id = descriptor.id
        game = descriptor.game
        schemaVersion = descriptor.schemaVersion
        algorithmVersion = descriptor.algorithmVersion
        knowledgeRevision = descriptor.knowledgeRevision
        validationStatus = descriptor.validationStatus
        provenanceIDs = descriptor.provenanceIDs
    }

    private var descriptor: TuneRulesetDescriptor {
        TuneRulesetDescriptor(
            id: id,
            game: game,
            schemaVersion: schemaVersion,
            algorithmVersion: algorithmVersion,
            knowledgeRevision: knowledgeRevision,
            validationStatus: validationStatus,
            provenanceIDs: provenanceIDs
        )
    }
}
