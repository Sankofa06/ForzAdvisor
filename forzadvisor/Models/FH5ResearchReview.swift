//
//  FH5ResearchReview.swift
//  forzadvisor
//
//  Strict local ingestion and comparison of permission-bound FH5 Research
//  exports. Review reports are raw evidence and never tuning rules.
//

import CryptoKit
import Foundation

struct FH5ResearchReviewPermission: Codable, Equatable, Sendable {
    let submissionID: UUID
    let permissionReceiptID: UUID
    let consentVersion: String
    let canonicalExportDigest: String
    let contentFingerprint: String
    let locallyReviewedAt: Date
}

struct FH5ResearchReviewEntry: Codable, Equatable, Identifiable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let id: UUID
    let importedAt: Date
    let canonicalExportJSON: Data
    let permission: FH5ResearchReviewPermission

    var hasConsistentLocalReviewTimestamp: Bool {
        importedAt == permission.locallyReviewedAt
    }

    init(
        id: UUID = UUID(),
        importedAt: Date = .now,
        canonicalExportJSON: Data,
        permission: FH5ResearchReviewPermission
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.id = id
        self.importedAt = importedAt
        self.canonicalExportJSON = canonicalExportJSON
        self.permission = permission
    }

    static func locallyReviewed(
        canonicalExportJSON: Data,
        reviewerConfirmedDirectReceiptAndReusePermission: Bool,
        id: UUID = UUID(),
        now: Date = .now
    ) throws -> Self {
        guard reviewerConfirmedDirectReceiptAndReusePermission else {
            throw FH5ResearchReviewError.permissionNotConfirmed
        }
        let validated = try FH5ResearchReviewIngestor().validate(canonicalExportJSON)
        return Self(
            id: id,
            importedAt: now,
            canonicalExportJSON: canonicalExportJSON,
            permission: FH5ResearchReviewPermission(
                submissionID: validated.export.submissionID,
                permissionReceiptID: validated.export.permissionReceiptID,
                consentVersion: validated.export.consentVersion,
                canonicalExportDigest: validated.canonicalExportDigest,
                contentFingerprint: validated.export.contentFingerprint,
                locallyReviewedAt: now
            )
        )
    }
}

struct FH5ResearchReviewInput: Sendable {
    let exportJSON: Data
    let permission: FH5ResearchReviewPermission?

    init(
        exportJSON: Data,
        permission: FH5ResearchReviewPermission?
    ) {
        self.exportJSON = exportJSON
        self.permission = permission
    }

    init(entry: FH5ResearchReviewEntry) {
        self.init(
            exportJSON: entry.canonicalExportJSON,
            permission: entry.permission
        )
    }
}

enum FH5ResearchReviewError: Error, LocalizedError, Equatable {
    case emptyPayload
    case payloadTooLarge
    case invalidJSON
    case nonCanonicalJSON
    case invalidStructure
    case invalidContentFingerprint
    case permissionNotConfirmed
    case planMismatch
    case corruptStorage

    var errorDescription: String? {
        switch self {
        case .emptyPayload:
            "Paste a ForzAdvisor FH5 Research JSON export first."
        case .payloadTooLarge:
            "This research export is larger than the supported 256 KiB limit."
        case .invalidJSON:
            "This is not a readable FH5 Research JSON export."
        case .nonCanonicalJSON:
            "This export is not the exact canonical JSON produced by ForzAdvisor."
        case .invalidStructure:
            "This export failed the FH5 Research structure and value checks."
        case .invalidContentFingerprint:
            "This export's content fingerprint does not match its contents."
        case .permissionNotConfirmed:
            "Confirm direct receipt and reuse permission before importing."
        case .planMismatch:
            "This observation belongs to a different FH5 catalog car or plan revision."
        case .corruptStorage:
            "Stored FH5 review evidence is corrupt. The saved plan and local observations were not changed."
        }
    }
}

struct ValidatedFH5ResearchObservation: Sendable {
    let export: FH5ResearchObservationExport
    let canonicalExportDigest: String
    let reviewSessionFingerprint: String
    let associationFingerprint: String
    let measurementFingerprint: String
}

struct FH5ResearchReviewAssociation: Equatable, Sendable {
    let platform: FH5Platform
    let gameVersion: String
    let vehicle: FH5ResearchObservationRecord.Vehicle
    let tireCompoundDisplayName: String
    let forwardGearCount: Int
}

enum FH5ResearchReplicationStatus: String, Codable, Sendable {
    case insufficient
    case replicated
    case conflicted

    var title: String {
        switch self {
        case .insufficient: "One raw observation"
        case .replicated: "Replicated raw observations"
        case .conflicted: "Conflicting raw observations"
        }
    }
}

struct FH5ResearchReviewGroup: Equatable, Identifiable, Sendable {
    var id: String { associationFingerprint }
    let associationFingerprint: String
    let association: FH5ResearchReviewAssociation
    let observationCount: Int
    let measurementVariantCount: Int
    let measurementFingerprint: String?
    let status: FH5ResearchReplicationStatus
}

struct FH5ResearchReviewReport: Equatable, Sendable {
    let receivedCount: Int
    let verifiedUniqueObservationCount: Int
    let invalidCount: Int
    let quarantinedCount: Int
    let duplicateCount: Int
    let administrativeConflictCount: Int
    let receiptReplayCount: Int
    let groups: [FH5ResearchReviewGroup]

    static let empty = Self(
        receivedCount: 0,
        verifiedUniqueObservationCount: 0,
        invalidCount: 0,
        quarantinedCount: 0,
        duplicateCount: 0,
        administrativeConflictCount: 0,
        receiptReplayCount: 0,
        groups: []
    )
}

struct FH5ResearchReviewIngestor {
    static let maximumPayloadBytes = 256 * 1_024

    func validate(_ data: Data) throws -> ValidatedFH5ResearchObservation {
        guard !data.isEmpty else { throw FH5ResearchReviewError.emptyPayload }
        guard data.count <= Self.maximumPayloadBytes else {
            throw FH5ResearchReviewError.payloadTooLarge
        }

        let export: FH5ResearchObservationExport
        do {
            export = try Self.decoder.decode(FH5ResearchObservationExport.self, from: data)
        } catch {
            throw FH5ResearchReviewError.invalidJSON
        }
        let canonical: Data
        do {
            canonical = try Self.canonicalData(for: export)
        } catch {
            throw FH5ResearchReviewError.invalidJSON
        }
        guard canonical == data else {
            throw FH5ResearchReviewError.nonCanonicalJSON
        }
        guard Self.hasValidStructure(export) else {
            throw FH5ResearchReviewError.invalidStructure
        }
        guard (try? FH5ResearchObservationFactory().publicSemanticFingerprint(for: export))
                == export.contentFingerprint else {
            throw FH5ResearchReviewError.invalidContentFingerprint
        }

        do {
            return ValidatedFH5ResearchObservation(
                export: export,
                canonicalExportDigest: Self.sha256(canonical),
                reviewSessionFingerprint: try Self.fingerprint(
                    ReviewSessionPayload(export: export)
                ),
                associationFingerprint: try Self.fingerprint(
                    AssociationPayload(export: export)
                ),
                measurementFingerprint: try Self.fingerprint(export.controls)
            )
        } catch {
            throw FH5ResearchReviewError.invalidStructure
        }
    }

    func measurementFingerprint(
        for controls: [FH5TuneFieldObservation]
    ) -> String? {
        try? Self.fingerprint(controls)
    }

    func matchesSavedPlan(
        _ validated: ValidatedFH5ResearchObservation,
        tune: TuneResult
    ) -> Bool {
        let export = validated.export
        let car = tune.request.car
        guard car.game == .fh5,
              tune.purpose == .fh5BuildPlan,
              tune.sections.isEmpty,
              tune.providerInfo == nil,
              tune.rulesetReference == nil,
              !car.catalogValuesModified,
              let reference = car.catalogReference else {
            return false
        }
        return reference.entryID == export.vehicle.catalogID
            && reference.revision == export.vehicle.catalogRevision
            && reference.reviewedAt == export.vehicle.catalogReviewedAt
            && reference.verificationStatus == export.vehicle.catalogVerificationStatus
            && car.year == export.vehicle.year
            && car.make == export.vehicle.make
            && car.model == export.vehicle.model
            && car.performanceClass == export.vehicle.performanceClass
            && car.performanceIndex == export.vehicle.performanceIndex
            && car.drivetrain == export.vehicle.drivetrain
            && car.weightPounds == export.vehicle.weightPounds
            && car.frontWeightPercent == export.vehicle.frontWeightPercent
            && car.peakHorsepower == export.vehicle.peakHorsepower
            && car.peakTorqueFootPounds == export.vehicle.peakTorqueFootPounds
            && export.vehicle.stock
    }

    static func canonicalData(for export: FH5ResearchObservationExport) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(export)
    }

    private static func hasValidStructure(_ export: FH5ResearchObservationExport) -> Bool {
        guard export.schemaVersion == FH5ResearchObservationRecord.currentSchemaVersion,
              export.consentVersion == FH5ResearchObservationRecord.currentConsentVersion,
              export.game == .fh5,
              export.unitScope == FH5ResearchObservationFactory.unitScope,
              export.vehicle.stock,
              export.vehicle.year > 0,
              (1_500...7_000).contains(export.vehicle.weightPounds),
              export.vehicle.frontWeightPercent.isFinite,
              (30...70).contains(export.vehicle.frontWeightPercent),
              export.vehicle.peakHorsepower > 0,
              export.vehicle.peakTorqueFootPounds > 0,
              export.game.performanceIndexRange(for: export.vehicle.performanceClass)?
                .contains(export.vehicle.performanceIndex) == true,
              export.capturedAt.timeIntervalSinceReferenceDate.isFinite,
              export.vehicle.catalogReviewedAt.timeIntervalSinceReferenceDate.isFinite,
              canonicalString(export.gameVersion, maximumLength: 120),
              canonicalString(export.tireCompoundDisplayName, maximumLength: 120),
              canonicalString(export.vehicle.catalogID, maximumLength: 160),
              canonicalString(export.vehicle.catalogRevision, maximumLength: 160),
              canonicalString(export.vehicle.make, maximumLength: 120),
              canonicalString(export.vehicle.model, maximumLength: 160),
              export.attestations.exactUntouchedStock,
              export.attestations.allSlidersRestored,
              export.attestations.personallyReadFromGame,
              export.attestations.firstPartyAuthorship,
              export.attestations.localStoragePermitted,
              export.attestations.deidentifiedStructuredReusePermitted,
              export.unknowns == FH5ResearchObservationRecord.unknowns,
              export.privacyExclusions == FH5ResearchObservationRecord.privacyExclusions,
              export.controls.map(\.field) == TuneFieldID.expectedFields(
                drivetrain: export.vehicle.drivetrain,
                gearCount: export.forwardGearCount
              ) else {
            return false
        }

        let capture = FH5ResearchCapture(
            platform: export.platform,
            gameVersion: export.gameVersion,
            tireCompoundDisplayName: export.tireCompoundDisplayName,
            forwardGearCount: export.forwardGearCount,
            controls: export.controls,
            exactUntouchedStockConfirmed: export.attestations.exactUntouchedStock,
            allSlidersRestoredConfirmed: export.attestations.allSlidersRestored,
            personallyReadFromGameConfirmed: export.attestations.personallyReadFromGame,
            firstPartyAuthorshipConfirmed: export.attestations.firstPartyAuthorship,
            localStoragePermitted: export.attestations.localStoragePermitted,
            deidentifiedStructuredReusePermitted:
                export.attestations.deidentifiedStructuredReusePermitted
        )
        return FH5ResearchObservationFactory().validationIssues(
            capture: capture,
            drivetrain: export.vehicle.drivetrain
        ).isEmpty
    }

    private static func canonicalString(_ value: String, maximumLength: Int) -> Bool {
        let forbiddenFormatScalars = CharacterSet(charactersIn:
            "\u{061C}\u{200B}\u{200C}\u{200D}\u{200E}\u{200F}\u{202A}\u{202B}\u{202C}\u{202D}\u{202E}\u{2060}\u{2061}\u{2062}\u{2063}\u{2064}\u{2066}\u{2067}\u{2068}\u{2069}\u{FEFF}"
        )
        let forbidden = CharacterSet.controlCharacters
            .union(.illegalCharacters)
            .union(.newlines)
            .union(forbiddenFormatScalars)
        guard !value.unicodeScalars.contains(where: {
            forbidden.contains($0) || $0.properties.generalCategory == .format
        }) else {
            return false
        }
        let canonical = value.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return canonical == value && (1...maximumLength).contains(canonical.count)
    }

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private static func fingerprint<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return sha256(try encoder.encode(value))
    }

    private static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private struct ReviewSessionPayload: Codable {
        let schemaVersion: Int
        let consentVersion: String
        let capturedAt: Date
        let game: ForzaGame
        let platform: FH5Platform
        let gameVersion: String
        let unitScope: String
        let vehicle: FH5ResearchObservationRecord.Vehicle
        let tireCompoundDisplayName: String
        let forwardGearCount: Int
        let controls: [FH5TuneFieldObservation]
        let attestations: FH5ResearchObservationRecord.Attestations
        let unknowns: [String]
        let privacyExclusions: [String]

        init(export: FH5ResearchObservationExport) {
            schemaVersion = export.schemaVersion
            consentVersion = export.consentVersion
            capturedAt = export.capturedAt
            game = export.game
            platform = export.platform
            gameVersion = export.gameVersion
            unitScope = export.unitScope
            vehicle = export.vehicle
            tireCompoundDisplayName = export.tireCompoundDisplayName
            forwardGearCount = export.forwardGearCount
            controls = export.controls
            attestations = export.attestations
            unknowns = export.unknowns
            privacyExclusions = export.privacyExclusions
        }
    }

    private struct AssociationPayload: Codable {
        let game: ForzaGame
        let platform: FH5Platform
        let gameVersion: String
        let unitScope: String
        let vehicle: FH5ResearchObservationRecord.Vehicle
        let tireCompoundDisplayName: String
        let forwardGearCount: Int

        init(export: FH5ResearchObservationExport) {
            game = export.game
            platform = export.platform
            gameVersion = export.gameVersion
            unitScope = export.unitScope
            vehicle = export.vehicle
            tireCompoundDisplayName = export.tireCompoundDisplayName
            forwardGearCount = export.forwardGearCount
        }
    }
}

struct FH5ResearchReviewEvaluator {
    func evaluate(_ inputs: [FH5ResearchReviewInput]) -> FH5ResearchReviewReport {
        let ingestor = FH5ResearchReviewIngestor()
        var invalidCount = 0
        var quarantinedCount = 0
        var verified: [ValidatedFH5ResearchObservation] = []

        for input in inputs {
            guard let validated = try? ingestor.validate(input.exportJSON) else {
                invalidCount += 1
                continue
            }
            guard let permission = input.permission,
                  permission.submissionID == validated.export.submissionID,
                  permission.permissionReceiptID == validated.export.permissionReceiptID,
                  permission.consentVersion == validated.export.consentVersion,
                  permission.canonicalExportDigest == validated.canonicalExportDigest,
                  permission.contentFingerprint == validated.export.contentFingerprint else {
                quarantinedCount += 1
                continue
            }
            verified.append(validated)
        }

        let conflictingSubmissionIDs = Set(
            Dictionary(grouping: verified, by: { $0.export.submissionID })
                .filter { _, observations in
                    Set(observations.map {
                        "\($0.canonicalExportDigest):\($0.export.contentFingerprint)"
                    }).count > 1
                }
                .map(\.key)
        )
        let replayedReceiptIDs = Set(
            Dictionary(grouping: verified, by: { $0.export.permissionReceiptID })
                .filter { _, observations in
                    Set(observations.map {
                        "\($0.export.submissionID.uuidString):\($0.export.contentFingerprint)"
                    }).count > 1
                }
                .map(\.key)
        )
        let conflicted = verified.filter {
            conflictingSubmissionIDs.contains($0.export.submissionID)
                || replayedReceiptIDs.contains($0.export.permissionReceiptID)
        }
        let clean = verified.filter {
            !conflictingSubmissionIDs.contains($0.export.submissionID)
                && !replayedReceiptIDs.contains($0.export.permissionReceiptID)
        }

        let sessionGroups = Dictionary(grouping: clean, by: \.reviewSessionFingerprint)
        let duplicateCount = sessionGroups.values.reduce(0) {
            $0 + max(0, $1.count - 1)
        }
        let accepted = sessionGroups.values.compactMap { observations in
            observations.min {
                if $0.canonicalExportDigest != $1.canonicalExportDigest {
                    return $0.canonicalExportDigest < $1.canonicalExportDigest
                }
                return $0.export.submissionID.uuidString < $1.export.submissionID.uuidString
            }
        }

        let groups = Dictionary(grouping: accepted, by: \.associationFingerprint)
            .map { fingerprint, observations in
                makeGroup(fingerprint: fingerprint, observations: observations)
            }
            .sorted { $0.associationFingerprint < $1.associationFingerprint }

        return FH5ResearchReviewReport(
            receivedCount: inputs.count,
            verifiedUniqueObservationCount: accepted.count,
            invalidCount: invalidCount,
            quarantinedCount: quarantinedCount,
            duplicateCount: duplicateCount,
            administrativeConflictCount: conflicted.count,
            receiptReplayCount: conflicted.filter {
                replayedReceiptIDs.contains($0.export.permissionReceiptID)
            }.count,
            groups: groups
        )
    }

    private func makeGroup(
        fingerprint: String,
        observations: [ValidatedFH5ResearchObservation]
    ) -> FH5ResearchReviewGroup {
        let first = observations[0]
        let variants = Set(observations.map(\.measurementFingerprint)).count
        let status: FH5ResearchReplicationStatus
        if variants > 1 {
            status = .conflicted
        } else if observations.count >= 2 {
            status = .replicated
        } else {
            status = .insufficient
        }
        return FH5ResearchReviewGroup(
            associationFingerprint: fingerprint,
            association: FH5ResearchReviewAssociation(
                platform: first.export.platform,
                gameVersion: first.export.gameVersion,
                vehicle: first.export.vehicle,
                tireCompoundDisplayName: first.export.tireCompoundDisplayName,
                forwardGearCount: first.export.forwardGearCount
            ),
            observationCount: observations.count,
            measurementVariantCount: variants,
            measurementFingerprint: variants == 1
                ? first.measurementFingerprint
                : nil,
            status: status
        )
    }
}
