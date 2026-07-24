//
//  FH5CandidateOutcomeExchange.swift
//  forzadvisor
//
//  Explicit, permission-bound exchange for experimental FH5 candidate outcomes.
//  Imported evidence is collection-only and can never authorize tune output.
//

import CryptoKit
import Foundation

enum FH5CandidateOutcomeExchangeError: Error, LocalizedError, Equatable {
    case shareConfirmationRequired
    case reuseNotPermitted
    case invalidLocalRecord
    case unregisteredCandidate
    case emptyPayload
    case payloadTooLarge
    case invalidJSON
    case nonCanonicalJSON
    case invalidStructure
    case invalidAssociationFingerprint
    case invalidContentFingerprint
    case permissionNotConfirmed
    case candidateMismatch
    case corruptStorage

    var errorDescription: String? {
        switch self {
        case .shareConfirmationRequired:
            "Confirm this one share before opening the system share sheet."
        case .reuseNotPermitted:
            "This trial was not saved with deidentified reuse permission."
        case .invalidLocalRecord:
            "This candidate trial failed its local integrity checks."
        case .unregisteredCandidate:
            "This build does not recognize the candidate algorithm and source manifest."
        case .emptyPayload:
            "Paste a ForzAdvisor FH5 Candidate Outcome JSON export first."
        case .payloadTooLarge:
            "This candidate outcome export is larger than the supported 256 KiB limit."
        case .invalidJSON:
            "This is not a readable FH5 Candidate Outcome JSON export."
        case .nonCanonicalJSON:
            "This export is not the exact canonical JSON produced by ForzAdvisor."
        case .invalidStructure:
            "This export failed the FH5 Candidate Outcome structure and value checks."
        case .invalidAssociationFingerprint:
            "This export's public candidate association fingerprint does not match its contents."
        case .invalidContentFingerprint:
            "This export's content fingerprint does not match its contents."
        case .permissionNotConfirmed:
            "Confirm direct receipt and deidentified structured reuse permission before importing."
        case .candidateMismatch:
            "This outcome tested a different car, build, measurement, context, or candidate."
        case .corruptStorage:
            "Stored FH5 Candidate Outcome review evidence is corrupt. Local trials and the saved plan were not changed."
        }
    }
}

struct FH5CandidateOutcomeAssociation: Codable, Equatable, Sendable {
    let protocolVersion: String
    let game: ForzaGame
    let algorithmID: FH5ExperimentalAlgorithmID
    let rulesetReference: TuneRulesetReference
    let sourceManifestFingerprint: String
    let outcomePolicyVersion: String
    let measurementFingerprint: String
    let context: FH5ControlledExperimentRecord.Context
    let change: FH5ControlledExperimentRecord.Change
    let targetSymptom: TuneFeedback
}

struct FH5CandidateOutcomeProtocolAttestations: Codable, Equatable, Sendable {
    let sameRouteAndConditions: Bool
    let sameAssistsAndInput: Bool
    let onlyDeclaredFieldChanged: Bool
    let sequenceCompleted: Bool
    let stockValuesRestored: Bool
    let firstPartyAuthorship: Bool
    let deidentifiedReusePermitted: Bool
}

struct FH5CandidateOutcomeExport: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1
    static let currentConsentVersion = "fh5-candidate-outcome-exchange-v1"
    static let privacyExclusions = [
        "analytics and share history",
        "attribution and tester identity",
        "device identifiers and location",
        "generated tune and provider data",
        "internal generated candidate fingerprint",
        "local record and saved tune IDs",
        "notes, screenshots, OCR, and telemetry",
        "raw Research Review exports",
        "Research Lab record ID and content fingerprint",
        "saved plan fingerprint",
        "source documents and source-manifest contents"
    ]

    let schemaVersion: Int
    let consentVersion: String
    let submissionID: UUID
    let permissionReceiptID: UUID
    let createdAt: Date
    let association: FH5CandidateOutcomeAssociation
    let associationFingerprint: String
    let outcome: FH5ExperimentOutcome
    let attestations: FH5CandidateOutcomeProtocolAttestations
    let privacyExclusions: [String]
    let contentFingerprint: String

    func deterministicJSON() throws -> Data {
        try FH5CandidateOutcomeExchange.canonicalData(for: self)
    }

    var deterministicJSONString: String? {
        guard let data = try? deterministicJSON() else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

struct FH5ValidatedCandidateOutcome: Sendable {
    let export: FH5CandidateOutcomeExport
    let canonicalExportDigest: String
    let trialSemanticFingerprint: String
    let trialSessionFingerprint: String
}

struct FH5CandidateOutcomeShareAuthorization: Equatable, Sendable {
    private(set) var isConfirmed = false

    mutating func confirm() {
        isConfirmed = true
    }

    mutating func consume() -> Bool {
        guard isConfirmed else { return false }
        isConfirmed = false
        return true
    }

    mutating func invalidate() {
        isConfirmed = false
    }
}

struct FH5CandidateOutcomeReviewPermission: Codable, Equatable, Sendable {
    let submissionID: UUID
    let permissionReceiptID: UUID
    let consentVersion: String
    let canonicalExportDigest: String
    let contentFingerprint: String
    let associationFingerprint: String
    let locallyReviewedAt: Date
}

struct FH5CandidateOutcomeReviewEntry:
    Codable, Equatable, Identifiable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let id: UUID
    let importedAt: Date
    let canonicalExportJSON: Data
    let permission: FH5CandidateOutcomeReviewPermission

    var hasConsistentLocalReviewTimestamp: Bool {
        importedAt == permission.locallyReviewedAt
    }

    init(
        id: UUID = UUID(),
        importedAt: Date = .now,
        canonicalExportJSON: Data,
        permission: FH5CandidateOutcomeReviewPermission
    ) {
        schemaVersion = Self.currentSchemaVersion
        self.id = id
        self.importedAt = importedAt
        self.canonicalExportJSON = canonicalExportJSON
        self.permission = permission
    }

    static func locallyReviewed(
        canonicalExportJSON: Data,
        expectedArtifact: FH5GeneratedCandidateArtifact,
        reviewerConfirmedDirectReceiptAndReusePermission: Bool,
        id: UUID = UUID(),
        now: Date = .now
    ) throws -> Self {
        guard reviewerConfirmedDirectReceiptAndReusePermission else {
            throw FH5CandidateOutcomeExchangeError.permissionNotConfirmed
        }
        let exchange = FH5CandidateOutcomeExchange()
        let validated = try exchange.validate(canonicalExportJSON)
        guard try exchange.matches(
            validated,
            locallyRegeneratedArtifact: expectedArtifact
        ) else {
            throw FH5CandidateOutcomeExchangeError.candidateMismatch
        }
        return Self(
            id: id,
            importedAt: now,
            canonicalExportJSON: canonicalExportJSON,
            permission: FH5CandidateOutcomeReviewPermission(
                submissionID: validated.export.submissionID,
                permissionReceiptID:
                    validated.export.permissionReceiptID,
                consentVersion: validated.export.consentVersion,
                canonicalExportDigest:
                    validated.canonicalExportDigest,
                contentFingerprint:
                    validated.export.contentFingerprint,
                associationFingerprint:
                    validated.export.associationFingerprint,
                locallyReviewedAt: now
            )
        )
    }
}

struct FH5CandidateOutcomeCollectionReport: Equatable, Sendable {
    let receivedCount: Int
    let localCount: Int
    let reviewedCount: Int
    let verifiedUniqueSessionCount: Int
    let variantPreferredCount: Int
    let noClearDifferenceCount: Int
    let baselinePreferredCount: Int
    let inconclusiveCount: Int
    let distinctUTCDayCount: Int
    let duplicateCount: Int
    let conflictCount: Int
    let receiptReplayCount: Int
    let semanticReplayCount: Int
    let quarantinedCount: Int

    static let empty = Self(
        receivedCount: 0,
        localCount: 0,
        reviewedCount: 0,
        verifiedUniqueSessionCount: 0,
        variantPreferredCount: 0,
        noClearDifferenceCount: 0,
        baselinePreferredCount: 0,
        inconclusiveCount: 0,
        distinctUTCDayCount: 0,
        duplicateCount: 0,
        conflictCount: 0,
        receiptReplayCount: 0,
        semanticReplayCount: 0,
        quarantinedCount: 0
    )

    var summary: String {
        "Permission-bound sessions: \(verifiedUniqueSessionCount) "
            + "(\(localCount) local, \(reviewedCount) reviewed) across "
            + "\(distinctUTCDayCount) UTC day\(distinctUTCDayCount == 1 ? "" : "s"). "
            + "Variant preferred: \(variantPreferredCount); no clear difference: "
            + "\(noClearDifferenceCount); baseline preferred: "
            + "\(baselinePreferredCount); inconclusive: \(inconclusiveCount)."
    }
}

struct FH5CandidateOutcomeExchange {
    static let maximumPayloadBytes = 256 * 1_024

    private let registry =
        FH5TrustedNumericRulesetRegistry.experimentalCandidateCollection

    func makeExport(
        from record: FH5ControlledExperimentRecord,
        explicitShareConfirmed: Bool
    ) throws -> FH5CandidateOutcomeExport {
        guard explicitShareConfirmed else {
            throw FH5CandidateOutcomeExchangeError
                .shareConfirmationRequired
        }
        guard FH5ControlledExperimentFactory().isValid(record),
              record.schemaVersion
                == FH5ControlledExperimentRecord
                    .candidateBoundSchemaVersion,
              let binding = record.candidateBinding else {
            throw FH5CandidateOutcomeExchangeError.invalidLocalRecord
        }
        guard record.attestations.deidentifiedReusePermitted else {
            throw FH5CandidateOutcomeExchangeError.reuseNotPermitted
        }
        guard let registration = registry.registration(
            for: binding.algorithmID
        ), binding.isValid(for: registration) else {
            throw FH5CandidateOutcomeExchangeError.unregisteredCandidate
        }
        let association = association(
            binding: binding,
            protocolVersion: record.protocolVersion,
            game: record.game,
            measurementFingerprint: record.measurementFingerprint,
            context: record.context,
            change: record.change,
            targetSymptom: record.targetSymptom
        )
        let associationFingerprint = try Self.fingerprint(association)
        let attestations = publicAttestations(record.attestations)
        var export = FH5CandidateOutcomeExport(
            schemaVersion:
                FH5CandidateOutcomeExport.currentSchemaVersion,
            consentVersion:
                FH5CandidateOutcomeExport.currentConsentVersion,
            submissionID: record.submissionID,
            permissionReceiptID: record.permissionReceiptID,
            createdAt: record.createdAt,
            association: association,
            associationFingerprint: associationFingerprint,
            outcome: record.outcome,
            attestations: attestations,
            privacyExclusions:
                FH5CandidateOutcomeExport.privacyExclusions,
            contentFingerprint: ""
        )
        export = FH5CandidateOutcomeExport(
            schemaVersion: export.schemaVersion,
            consentVersion: export.consentVersion,
            submissionID: export.submissionID,
            permissionReceiptID: export.permissionReceiptID,
            createdAt: export.createdAt,
            association: export.association,
            associationFingerprint: export.associationFingerprint,
            outcome: export.outcome,
            attestations: export.attestations,
            privacyExclusions: export.privacyExclusions,
            contentFingerprint: try Self.contentFingerprint(export)
        )
        guard try isValid(export) else {
            throw FH5CandidateOutcomeExchangeError.invalidLocalRecord
        }
        return export
    }

    func validate(_ data: Data) throws -> FH5ValidatedCandidateOutcome {
        guard !data.isEmpty else {
            throw FH5CandidateOutcomeExchangeError.emptyPayload
        }
        guard data.count <= Self.maximumPayloadBytes else {
            throw FH5CandidateOutcomeExchangeError.payloadTooLarge
        }
        let export: FH5CandidateOutcomeExport
        do {
            export = try Self.decoder.decode(
                FH5CandidateOutcomeExport.self,
                from: data
            )
        } catch {
            throw FH5CandidateOutcomeExchangeError.invalidJSON
        }
        guard (try? Self.canonicalData(for: export)) == data else {
            throw FH5CandidateOutcomeExchangeError.nonCanonicalJSON
        }
        guard hasValidStructure(export) else {
            throw FH5CandidateOutcomeExchangeError.invalidStructure
        }
        guard (try? Self.fingerprint(export.association))
                == export.associationFingerprint else {
            throw FH5CandidateOutcomeExchangeError
                .invalidAssociationFingerprint
        }
        guard (try? Self.contentFingerprint(export))
                == export.contentFingerprint else {
            throw FH5CandidateOutcomeExchangeError
                .invalidContentFingerprint
        }
        guard let registration = registry.registration(
            for: export.association.algorithmID
        ), registration.isValid,
              registration.reference
                == export.association.rulesetReference,
              registration.sourceManifestFingerprint
                == export.association.sourceManifestFingerprint,
              registration.outcomeThreshold.policyVersion
                == export.association.outcomePolicyVersion else {
            throw FH5CandidateOutcomeExchangeError
                .unregisteredCandidate
        }
        return FH5ValidatedCandidateOutcome(
            export: export,
            canonicalExportDigest: Self.sha256(data),
            trialSemanticFingerprint:
                try Self.trialSemanticFingerprint(export),
            trialSessionFingerprint:
                try Self.trialSessionFingerprint(export)
        )
    }

    func association(
        for artifact: FH5GeneratedCandidateArtifact
    ) -> FH5CandidateOutcomeAssociation {
        association(
            binding: artifact.candidateBinding,
            protocolVersion: artifact.protocolVersion,
            game: artifact.game,
            measurementFingerprint: artifact.measurementFingerprint,
            context: artifact.context,
            change: artifact.change,
            targetSymptom: artifact.targetSymptom
        )
    }

    func associationFingerprint(
        for artifact: FH5GeneratedCandidateArtifact
    ) throws -> String {
        try Self.fingerprint(association(for: artifact))
    }

    func associationFingerprint(
        for association: FH5CandidateOutcomeAssociation
    ) throws -> String {
        try Self.fingerprint(association)
    }

    func matches(
        _ validated: FH5ValidatedCandidateOutcome,
        locallyRegeneratedArtifact artifact:
            FH5GeneratedCandidateArtifact
    ) throws -> Bool {
        let localAssociation = association(for: artifact)
        let localFingerprint = try Self.fingerprint(
            localAssociation
        )
        return localAssociation == validated.export.association
            && localFingerprint
                == validated.export.associationFingerprint
    }

    func canShare(
        _ record: FH5ControlledExperimentRecord,
        currentArtifact artifact: FH5GeneratedCandidateArtifact
    ) -> Bool {
        guard record.schemaVersion
                == FH5ControlledExperimentRecord
                    .candidateBoundSchemaVersion,
              record.candidateBinding == artifact.candidateBinding,
              let export = try? makeExport(
                from: record,
                explicitShareConfirmed: true
              ),
              let localFingerprint = try? associationFingerprint(
                for: artifact
              ) else {
            return false
        }
        return export.association == association(for: artifact)
            && export.associationFingerprint == localFingerprint
    }

    func prepareShare(
        from record: FH5ControlledExperimentRecord,
        currentArtifact artifact: FH5GeneratedCandidateArtifact,
        authorization: inout FH5CandidateOutcomeShareAuthorization
    ) throws -> FH5CandidateOutcomeExport {
        guard canShare(record, currentArtifact: artifact) else {
            authorization.invalidate()
            throw FH5CandidateOutcomeExchangeError.candidateMismatch
        }
        guard authorization.consume() else {
            throw FH5CandidateOutcomeExchangeError
                .shareConfirmationRequired
        }
        return try makeExport(
            from: record,
            explicitShareConfirmed: true
        )
    }

    func isValidReviewEntry(
        _ entry: FH5CandidateOutcomeReviewEntry
    ) -> Bool {
        guard entry.schemaVersion
                == FH5CandidateOutcomeReviewEntry
                    .currentSchemaVersion,
              entry.hasConsistentLocalReviewTimestamp,
              let validated = try? validate(
                entry.canonicalExportJSON
              ) else {
            return false
        }
        let permission = entry.permission
        return permission.submissionID
                == validated.export.submissionID
            && permission.permissionReceiptID
                == validated.export.permissionReceiptID
            && permission.consentVersion
                == validated.export.consentVersion
            && permission.canonicalExportDigest
                == validated.canonicalExportDigest
            && permission.contentFingerprint
                == validated.export.contentFingerprint
            && permission.associationFingerprint
                == validated.export.associationFingerprint
    }

    static func canonicalData(
        for export: FH5CandidateOutcomeExport
    ) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .prettyPrinted, .sortedKeys, .withoutEscapingSlashes
        ]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(export)
    }

    private func association(
        binding: FH5RulesetCandidateBinding,
        protocolVersion: String,
        game: ForzaGame,
        measurementFingerprint: String,
        context: FH5ControlledExperimentRecord.Context,
        change: FH5ControlledExperimentRecord.Change,
        targetSymptom: TuneFeedback
    ) -> FH5CandidateOutcomeAssociation {
        FH5CandidateOutcomeAssociation(
            protocolVersion: protocolVersion,
            game: game,
            algorithmID: binding.algorithmID,
            rulesetReference: binding.rulesetReference,
            sourceManifestFingerprint:
                binding.sourceManifestFingerprint,
            outcomePolicyVersion: binding.outcomePolicyVersion,
            measurementFingerprint: measurementFingerprint,
            context: context,
            change: change,
            targetSymptom: targetSymptom
        )
    }

    private func publicAttestations(
        _ value: FH5ControlledExperimentRecord.Attestations
    ) -> FH5CandidateOutcomeProtocolAttestations {
        FH5CandidateOutcomeProtocolAttestations(
            sameRouteAndConditions:
                value.sameRouteAndConditions,
            sameAssistsAndInput: value.sameAssistsAndInput,
            onlyDeclaredFieldChanged:
                value.onlyDeclaredFieldChanged,
            sequenceCompleted: value.sequenceCompleted,
            stockValuesRestored: value.stockValuesRestored,
            firstPartyAuthorship: value.firstPartyAuthorship,
            deidentifiedReusePermitted:
                value.deidentifiedReusePermitted
        )
    }

    private func isValid(
        _ export: FH5CandidateOutcomeExport
    ) throws -> Bool {
        let associationFingerprint = try Self.fingerprint(
            export.association
        )
        let contentFingerprint = try Self.contentFingerprint(
            export
        )
        return hasValidStructure(export)
            && associationFingerprint
                == export.associationFingerprint
            && contentFingerprint
                == export.contentFingerprint
    }

    private func hasValidStructure(
        _ export: FH5CandidateOutcomeExport
    ) -> Bool {
        let association = export.association
        let attestations = export.attestations
        guard export.schemaVersion
                == FH5CandidateOutcomeExport.currentSchemaVersion,
              export.consentVersion
                == FH5CandidateOutcomeExport.currentConsentVersion,
              export.privacyExclusions
                == FH5CandidateOutcomeExport.privacyExclusions,
              association.protocolVersion
                == FH5ControlledExperimentRecord
                    .currentProtocolVersion,
              association.game == .fh5,
              Self.isSHA256Fingerprint(
                association.sourceManifestFingerprint
              ),
              Self.isSHA256Fingerprint(
                association.measurementFingerprint
              ),
              Self.isSHA256Fingerprint(
                export.associationFingerprint
              ),
              Self.isSHA256Fingerprint(export.contentFingerprint),
              association.rulesetReference.isValid,
              association.rulesetReference.game == .fh5,
              association.rulesetReference.id
                == association.algorithmID.rawValue,
              association.rulesetReference.validationStatus
                == .experimental,
              association.context.route
                == FH5ControlledExperimentRecord.route,
              association.context.sequence
                == FH5ControlledExperimentRecord.sequence,
              (1...10).contains(
                association.context.forwardGearCount
              ),
              association.context.vehicle.stock,
              association.context.vehicle.year > 0,
              association.context.vehicle.weightPounds > 0,
              association.context.vehicle.frontWeightPercent
                .isFinite,
              (0...100).contains(
                association.context.vehicle
                    .frontWeightPercent
              ),
              association.context.vehicle.peakHorsepower > 0,
              association.context.vehicle
                .peakTorqueFootPounds > 0,
              association.game.performanceIndexRange(
                for: association.context.vehicle
                    .performanceClass
              )?.contains(
                association.context.vehicle.performanceIndex
              ) == true,
              association.change.field.expectedUnit
                == association.change.unit,
              association.change.minimum.isFinite,
              association.change.maximum.isFinite,
              association.change.step.isFinite,
              association.change.baselineValue.isFinite,
              association.change.candidateValue.isFinite,
              association.change.minimum
                < association.change.maximum,
              association.change.step > 0,
              association.change.baselineValue
                >= association.change.minimum,
              association.change.baselineValue
                <= association.change.maximum,
              association.change.candidateValue
                >= association.change.minimum,
              association.change.candidateValue
                <= association.change.maximum,
              Self.isOnLattice(
                association.change.baselineValue,
                minimum: association.change.minimum,
                step: association.change.step
              ),
              Self.isOnLattice(
                association.change.candidateValue,
                minimum: association.change.minimum,
                step: association.change.step
              ),
              abs(
                abs(
                    association.change.candidateValue
                        - association.change.baselineValue
                ) - association.change.step
              ) <= max(1e-9, association.change.step * 1e-7),
              attestations.sameRouteAndConditions,
              attestations.sameAssistsAndInput,
              attestations.onlyDeclaredFieldChanged,
              attestations.sequenceCompleted,
              attestations.stockValuesRestored,
              attestations.firstPartyAuthorship,
              attestations.deidentifiedReusePermitted,
              association.algorithmID
                == .cleanRoomDirectionalV1,
              association.targetSymptom == .pushesWide,
              association.change.field
                == .frontTirePressure,
              abs(
                association.change.candidateValue
                    - (
                        association.change.baselineValue
                            - association.change.step
                    )
              ) <= max(
                1e-9,
                association.change.step * 1e-7
              ) else {
            return false
        }
        return canonicalPublicString(
            association.context.gameVersion,
            maximumLength: 120
        ) && canonicalPublicString(
            association.context.tireCompoundDisplayName,
            maximumLength: 120
        ) && canonicalPublicString(
            association.context.vehicle.catalogID,
            maximumLength: 160
        ) && canonicalPublicString(
            association.context.vehicle.catalogRevision,
            maximumLength: 160
        ) && canonicalPublicString(
            association.context.vehicle.make,
            maximumLength: 120
        ) && canonicalPublicString(
            association.context.vehicle.model,
            maximumLength: 160
        )
    }

    private static func contentFingerprint(
        _ export: FH5CandidateOutcomeExport
    ) throws -> String {
        try fingerprint(ContentPayload(
            schemaVersion: export.schemaVersion,
            consentVersion: export.consentVersion,
            submissionID: export.submissionID,
            permissionReceiptID: export.permissionReceiptID,
            createdAt: export.createdAt,
            association: export.association,
            associationFingerprint:
                export.associationFingerprint,
            outcome: export.outcome,
            attestations: export.attestations,
            privacyExclusions: export.privacyExclusions
        ))
    }

    private static func trialSemanticFingerprint(
        _ export: FH5CandidateOutcomeExport
    ) throws -> String {
        try fingerprint(TrialSemanticPayload(
            associationFingerprint:
                export.associationFingerprint,
            createdAt: export.createdAt,
            outcome: export.outcome,
            attestations: export.attestations
        ))
    }

    private static func trialSessionFingerprint(
        _ export: FH5CandidateOutcomeExport
    ) throws -> String {
        try fingerprint(TrialSessionPayload(
            associationFingerprint:
                export.associationFingerprint,
            createdAt: export.createdAt,
            attestations: export.attestations
        ))
    }

    private static func fingerprint<T: Encodable>(
        _ value: T
    ) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .sortedKeys, .withoutEscapingSlashes
        ]
        encoder.dateEncodingStrategy = .iso8601
        return sha256(try encoder.encode(value))
    }

    private static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private static func isSHA256Fingerprint(
        _ value: String
    ) -> Bool {
        value.count == 64
            && value.unicodeScalars.allSatisfy {
                (48...57).contains($0.value)
                    || (97...102).contains($0.value)
            }
    }

    private static func isOnLattice(
        _ value: Double,
        minimum: Double,
        step: Double
    ) -> Bool {
        let position = (value - minimum) / step
        return abs(position - position.rounded())
            <= max(1e-7, abs(position) * 1e-9)
    }

    private func canonicalPublicString(
        _ value: String,
        maximumLength: Int
    ) -> Bool {
        let forbidden = CharacterSet.controlCharacters
            .union(.illegalCharacters)
            .union(.newlines)
        guard !value.unicodeScalars.contains(where: {
            forbidden.contains($0)
                || $0.properties.generalCategory == .format
        }) else {
            return false
        }
        let canonical = value
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        return canonical == value
            && (1...maximumLength).contains(canonical.count)
    }

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private struct ContentPayload: Codable {
        let schemaVersion: Int
        let consentVersion: String
        let submissionID: UUID
        let permissionReceiptID: UUID
        let createdAt: Date
        let association: FH5CandidateOutcomeAssociation
        let associationFingerprint: String
        let outcome: FH5ExperimentOutcome
        let attestations: FH5CandidateOutcomeProtocolAttestations
        let privacyExclusions: [String]
    }

    private struct TrialSemanticPayload: Codable {
        let associationFingerprint: String
        let createdAt: Date
        let outcome: FH5ExperimentOutcome
        let attestations: FH5CandidateOutcomeProtocolAttestations
    }

    private struct TrialSessionPayload: Codable {
        let associationFingerprint: String
        let createdAt: Date
        let attestations: FH5CandidateOutcomeProtocolAttestations
    }
}

struct FH5CandidateOutcomeCollectionEvaluator {
    private struct Evidence {
        enum Provenance: Int {
            case local
            case reviewed
        }

        let submissionID: UUID
        let sourceReceiptID: UUID
        let associationFingerprint: String
        let trialSemanticFingerprint: String
        let trialSessionFingerprint: String
        let canonicalDigest: String
        let createdAt: Date
        let outcome: FH5ExperimentOutcome
        let provenance: Provenance
    }

    func evaluate(
        localRecords: [FH5ControlledExperimentRecord],
        reviewedEntries: [FH5CandidateOutcomeReviewEntry],
        matchingAssociationFingerprint: String
    ) -> FH5CandidateOutcomeCollectionReport {
        let exchange = FH5CandidateOutcomeExchange()
        var evidence: [Evidence] = []

        for record in localRecords {
            guard let export = try? exchange.makeExport(
                from: record,
                explicitShareConfirmed: true
            ), let data = try? export.deterministicJSON(),
                  let validated = try? exchange.validate(data) else {
                continue
            }
            evidence.append(Evidence(
                submissionID: export.submissionID,
                sourceReceiptID: export.permissionReceiptID,
                associationFingerprint:
                    export.associationFingerprint,
                trialSemanticFingerprint:
                    validated.trialSemanticFingerprint,
                trialSessionFingerprint:
                    validated.trialSessionFingerprint,
                canonicalDigest:
                    validated.canonicalExportDigest,
                createdAt: export.createdAt,
                outcome: export.outcome,
                provenance: .local
            ))
        }

        for entry in reviewedEntries {
            guard exchange.isValidReviewEntry(entry),
                  let validated = try? exchange.validate(
                    entry.canonicalExportJSON
              ) else {
                continue
            }
            evidence.append(Evidence(
                submissionID: validated.export.submissionID,
                sourceReceiptID:
                    validated.export.permissionReceiptID,
                associationFingerprint:
                    validated.export.associationFingerprint,
                trialSemanticFingerprint:
                    validated.trialSemanticFingerprint,
                trialSessionFingerprint:
                    validated.trialSessionFingerprint,
                canonicalDigest:
                    validated.canonicalExportDigest,
                createdAt: validated.export.createdAt,
                outcome: validated.export.outcome,
                provenance: .reviewed
            ))
        }

        evidence = evidence.filter {
            $0.associationFingerprint
                == matchingAssociationFingerprint
        }

        let submissionConflicts = Set(
            Dictionary(grouping: evidence, by: \.submissionID)
                .filter { _, values in
                    Set(values.map(\.trialSemanticFingerprint))
                        .count > 1
                }.map(\.key)
        )
        let replayedReceipts = Set(
            Dictionary(grouping: evidence, by: \.sourceReceiptID)
                .filter { _, values in
                    Set(values.map {
                        "\($0.submissionID.uuidString)|"
                            + $0.trialSemanticFingerprint + "|"
                            + $0.associationFingerprint
                    }).count > 1
                }.map(\.key)
        )
        let replayedSessions = Set(
            Dictionary(
                grouping: evidence,
                by: \.trialSessionFingerprint
            ).filter { _, values in
                Set(values.map {
                    "\($0.submissionID.uuidString)|"
                        + $0.sourceReceiptID.uuidString
                }).count > 1
            }.map(\.key)
        )
        let quarantined = evidence.filter {
            submissionConflicts.contains($0.submissionID)
                || replayedReceipts.contains($0.sourceReceiptID)
                || replayedSessions.contains(
                    $0.trialSessionFingerprint
                )
        }
        let conflictFree = evidence.filter {
            !submissionConflicts.contains($0.submissionID)
                && !replayedReceipts.contains($0.sourceReceiptID)
                && !replayedSessions.contains(
                    $0.trialSessionFingerprint
                )
        }
        let digestGroups = Dictionary(
            grouping: conflictFree,
            by: \.canonicalDigest
        )
        let unique = digestGroups.values.compactMap { group in
            group.sorted(by: evidenceSort).first
        }.sorted(by: evidenceSort)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let days = Set(unique.map {
            calendar.dateComponents(
                [.year, .month, .day],
                from: $0.createdAt
            )
        })
        return FH5CandidateOutcomeCollectionReport(
            receivedCount: evidence.count,
            localCount: unique.count {
                $0.provenance == .local
            },
            reviewedCount: unique.count {
                $0.provenance == .reviewed
            },
            verifiedUniqueSessionCount: unique.count,
            variantPreferredCount: unique.count {
                $0.outcome == .variantPreferred
            },
            noClearDifferenceCount: unique.count {
                $0.outcome == .noClearDifference
            },
            baselinePreferredCount: unique.count {
                $0.outcome == .baselinePreferred
            },
            inconclusiveCount: unique.count {
                $0.outcome == .inconclusive
            },
            distinctUTCDayCount: days.count,
            duplicateCount: digestGroups.values.reduce(0) {
                $0 + max(0, $1.count - 1)
            },
            conflictCount: evidence.count {
                submissionConflicts.contains($0.submissionID)
            },
            receiptReplayCount: evidence.count {
                replayedReceipts.contains($0.sourceReceiptID)
            },
            semanticReplayCount: evidence.count {
                replayedSessions.contains(
                    $0.trialSessionFingerprint
                )
            },
            quarantinedCount: quarantined.count
        )
    }

    private func evidenceSort(
        _ lhs: Evidence,
        _ rhs: Evidence
    ) -> Bool {
        if lhs.provenance != rhs.provenance {
            return lhs.provenance.rawValue
                < rhs.provenance.rawValue
        }
        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt < rhs.createdAt
        }
        if lhs.submissionID != rhs.submissionID {
            return lhs.submissionID.uuidString
                < rhs.submissionID.uuidString
        }
        return lhs.canonicalDigest < rhs.canonicalDigest
    }
}
