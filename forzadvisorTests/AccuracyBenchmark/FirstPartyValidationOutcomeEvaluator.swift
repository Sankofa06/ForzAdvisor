//
//  FirstPartyValidationOutcomeEvaluator.swift
//  forzadvisorTests
//
//  Test-target-only ingestion for app-generated first-party validation exports.
//  These sessions are outcome evidence, not independent reference tunes.
//

import CryptoKit
import Foundation
@testable import forzadvisor

struct VerifiedFirstPartyPermission: Equatable, Sendable {
    // This value must come from an external permission-verification boundary.
    // Its hashes bind that decision to bytes; they are not authentication.
    var submissionID: UUID
    var permissionReceiptID: UUID
    var consentVersion: String
    var canonicalExportDigest: String
    var contentFingerprint: String
}

struct FirstPartyValidationIngestionInput: Sendable {
    var exportJSON: Data
    var verifiedPermission: VerifiedFirstPartyPermission?
}

enum FirstPartyValidationIngestionError: Error, Equatable {
    case emptyPayload
    case payloadTooLarge
    case invalidJSON
    case nonCanonicalJSON
    case invalidStructure
    case invalidShopAvailabilityFingerprint
    case invalidContentFingerprint
}

struct ValidatedFirstPartyValidationSession: Sendable {
    var export: FirstPartyValidationExport
    var canonicalExportDigest: String
    var testedTuneFingerprint: String
}

struct FirstPartyValidationAssociationContext: Equatable, Sendable {
    var game: ForzaGame
    var gameBuildVersion: String
    var buildCapturedAt: Date
    var vehicle: FirstPartyValidationRecord.Vehicle
    var shopParts: [FirstPartyValidationRecord.ShopPart]
    var shopAvailabilityFingerprint: String
    var discipline: DrivingDiscipline
    var ruleset: FirstPartyValidationRecord.Ruleset
    var appliedFields: [FirstPartyValidationRecord.AppliedField]
}

struct FirstPartyValidationValueCount: Equatable, Sendable {
    var value: String
    var count: Int
}

struct FirstPartyValidationOutcomeGroup: Equatable, Sendable {
    var testedTuneFingerprint: String
    var associationContext: FirstPartyValidationAssociationContext
    var sessionCount: Int
    var keepCount: Int
    var adjustCount: Int
    var rejectCount: Int
    var acceptanceRate: Double
    var handlingSymptomCounts: [FirstPartyValidationValueCount]
    var courseTypeCounts: [FirstPartyValidationValueCount]
    var surfaceCounts: [FirstPartyValidationValueCount]
    var inputCounts: [FirstPartyValidationValueCount]
}

struct FirstPartyValidationOutcomeReport: Equatable, Sendable {
    var receivedCount: Int
    var verifiedUniqueSessionCount: Int
    var quarantinedCount: Int
    var invalidCount: Int
    var duplicateCount: Int
    var conflictCount: Int
    /// A receipt replay is also included in `conflictCount`.
    var receiptReplayCount: Int
    var groups: [FirstPartyValidationOutcomeGroup]

    var sessionSummary: String {
        let keep = groups.reduce(0) { $0 + $1.keepCount }
        let adjust = groups.reduce(0) { $0 + $1.adjustCount }
        let reject = groups.reduce(0) { $0 + $1.rejectCount }
        return "Verified first-party sessions: \(verifiedUniqueSessionCount). "
            + "Tested tune groups: \(groups.count). "
            + "Keep: \(keep), Adjust: \(adjust), Reject: \(reject)."
    }
}

struct FirstPartyValidationIngestor {
    static let maximumPayloadBytes = 256 * 1_024

    func validate(_ data: Data) throws -> ValidatedFirstPartyValidationSession {
        guard !data.isEmpty else { throw FirstPartyValidationIngestionError.emptyPayload }
        guard data.count <= Self.maximumPayloadBytes else {
            throw FirstPartyValidationIngestionError.payloadTooLarge
        }

        let export: FirstPartyValidationExport
        do {
            export = try Self.decoder().decode(FirstPartyValidationExport.self, from: data)
        } catch {
            throw FirstPartyValidationIngestionError.invalidJSON
        }

        let canonical: Data
        do {
            canonical = try Self.canonicalData(for: export)
        } catch {
            throw FirstPartyValidationIngestionError.invalidJSON
        }
        guard canonical == data else {
            throw FirstPartyValidationIngestionError.nonCanonicalJSON
        }
        guard Self.hasValidStructure(export) else {
            throw FirstPartyValidationIngestionError.invalidStructure
        }
        guard (try? Self.shopAvailabilityFingerprint(for: export.shopParts))
                == export.shopAvailabilityFingerprint else {
            throw FirstPartyValidationIngestionError.invalidShopAvailabilityFingerprint
        }
        guard (try? Self.contentFingerprint(for: export)) == export.contentFingerprint else {
            throw FirstPartyValidationIngestionError.invalidContentFingerprint
        }
        guard let testedTuneFingerprint = try? Self.testedTuneFingerprint(for: export) else {
            throw FirstPartyValidationIngestionError.invalidStructure
        }

        return ValidatedFirstPartyValidationSession(
            export: export,
            canonicalExportDigest: Self.sha256(canonical),
            testedTuneFingerprint: testedTuneFingerprint
        )
    }

    static func canonicalData(for export: FirstPartyValidationExport) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(export)
    }

    static func shopAvailabilityFingerprint(
        for parts: [FirstPartyValidationRecord.ShopPart]
    ) throws -> String {
        try fingerprint(parts)
    }

    static func contentFingerprint(for export: FirstPartyValidationExport) throws -> String {
        try fingerprint(ContentPayload(
            game: export.game,
            gameBuildVersion: export.gameBuildVersion,
            buildCapturedAt: export.buildCapturedAt,
            vehicle: export.vehicle,
            shopParts: export.shopParts,
            shopAvailabilityFingerprint: export.shopAvailabilityFingerprint,
            discipline: export.discipline,
            tuneGeneratedAt: export.tuneGeneratedAt,
            ruleset: export.ruleset,
            appliedFields: export.appliedFields,
            session: export.session,
            outcome: export.outcome
        ))
    }

    static func testedTuneFingerprint(for export: FirstPartyValidationExport) throws -> String {
        try fingerprint(TestedTunePayload(
            game: export.game,
            gameBuildVersion: export.gameBuildVersion,
            buildCapturedAt: export.buildCapturedAt,
            vehicle: export.vehicle,
            shopParts: export.shopParts,
            shopAvailabilityFingerprint: export.shopAvailabilityFingerprint,
            discipline: export.discipline,
            ruleset: export.ruleset,
            appliedFields: export.appliedFields
        ))
    }

    static func canonicalExportDigest(for data: Data) -> String {
        // Corruption/deduplication identifier only. This digest grants no permission.
        sha256(data)
    }

    private static let expectedUnknowns = [
        "assists:not-collected", "elapsed-time:not-collected", "telemetry:not-collected",
        "weather:not-collected"
    ]

    // Frozen to the v1 producer payload.
    private static let expectedPrivacyExclusions = [
        "attachments", "catalog-source-urls", "device-identifiers", "garage-notes",
        "location", "provider-details", "public-attribution", "raw-build-snapshot",
        "ruleset-provenance-ids", "tune-notes"
    ]

    private static func hasValidStructure(_ export: FirstPartyValidationExport) -> Bool {
        guard export.schemaVersion == FirstPartyValidationRecord.currentSchemaVersion,
              export.consentVersion == FirstPartyValidationRecord.currentConsentVersion,
              export.game == .fh6,
              export.exactSetupConfirmed,
              export.allExportedSettingsApplied,
              export.firstPartyAuthorshipConfirmed,
              export.deidentifiedReusePermitted,
              export.vehicle.stock,
              export.unknowns == expectedUnknowns,
              export.privacyExclusions == expectedPrivacyExclusions,
              (1...99).contains(export.session.runCount) else {
            return false
        }

        guard canonicalPublicString(export.gameBuildVersion, maximumLength: 120),
              canonicalPublicString(export.vehicle.catalogID, maximumLength: 160),
              canonicalPublicString(export.vehicle.make, maximumLength: 120),
              canonicalPublicString(export.vehicle.model, maximumLength: 120),
              canonicalPublicString(export.vehicle.tireCompoundID, maximumLength: 160),
              canonicalPublicString(export.vehicle.tireCompoundDisplayName, maximumLength: 120),
              canonicalPublicString(export.ruleset.id, maximumLength: 160),
              canonicalPublicString(export.ruleset.algorithmVersion, maximumLength: 120),
              canonicalPublicString(export.ruleset.knowledgeRevision, maximumLength: 160) else {
            return false
        }

        let vehicle = export.vehicle
        guard vehicle.year > 0,
              (1_500...7_000).contains(vehicle.weightPounds),
              vehicle.frontWeightPercent.isFinite,
              (30...70).contains(vehicle.frontWeightPercent),
              vehicle.peakHorsepower > 0,
              vehicle.peakTorqueFootPounds > 0,
              (1...10).contains(vehicle.gearCount),
              export.game.performanceIndexRange(for: vehicle.performanceClass)?
                .contains(vehicle.performanceIndex) == true else {
            return false
        }

        let ruleset = export.ruleset
        guard ruleset.id == FH6LocalTirePressureRuleset.id,
              ruleset.schemaVersion == FH6LocalTirePressureRuleset.schemaVersion,
              ruleset.algorithmVersion == FH6LocalTirePressureRuleset.algorithmVersion,
              ruleset.knowledgeRevision == FH6LocalTirePressureRuleset.knowledgeRevision,
              ruleset.validationStatus == .experimental else {
            return false
        }

        let expectedPartIDs = Set(TunePartID.allCases)
        guard export.shopParts.count == expectedPartIDs.count,
              Set(export.shopParts.map(\.partID)) == expectedPartIDs,
              export.shopParts == export.shopParts.sorted(by: { $0.partID.rawValue < $1.partID.rawValue }),
              export.shopParts.allSatisfy({
                  $0.availability == .available || $0.availability == .unavailable
              }) else {
            return false
        }

        let fields = export.appliedFields
        guard !fields.isEmpty,
              Set(fields.map(\.field)).count == fields.count,
              fields == fields.sorted(by: { $0.field.stableID < $1.field.stableID }),
              fields.allSatisfy({ field in
                  guard field.value.isFinite, field.unit == field.field.expectedUnit else {
                      return false
                  }
                  guard let gearIndex = field.field.gearIndex else { return true }
                  return (1...vehicle.gearCount).contains(gearIndex)
              }) else {
            return false
        }

        let feedback = export.outcome.feedback
        return ((export.outcome.verdict == .keep && feedback.isEmpty)
                || (export.outcome.verdict != .keep && !feedback.isEmpty))
            && feedback == feedback.sorted(by: { $0.rawValue < $1.rawValue })
            && Set(feedback).count == feedback.count
    }

    private static func canonicalPublicString(_ value: String, maximumLength: Int) -> Bool {
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
        let canonical = value.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        return canonical == value && (1...maximumLength).contains(canonical.count)
    }

    private static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private static func fingerprint<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return sha256(try encoder.encode(value))
    }

    private static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private struct ContentPayload: Codable {
        var game: ForzaGame
        var gameBuildVersion: String
        var buildCapturedAt: Date
        var vehicle: FirstPartyValidationRecord.Vehicle
        var shopParts: [FirstPartyValidationRecord.ShopPart]
        var shopAvailabilityFingerprint: String
        var discipline: DrivingDiscipline
        var tuneGeneratedAt: Date
        var ruleset: FirstPartyValidationRecord.Ruleset
        var appliedFields: [FirstPartyValidationRecord.AppliedField]
        var session: FirstPartyValidationRecord.Session
        var outcome: FirstPartyValidationRecord.Outcome
    }

    private struct TestedTunePayload: Codable {
        var game: ForzaGame
        var gameBuildVersion: String
        var buildCapturedAt: Date
        var vehicle: FirstPartyValidationRecord.Vehicle
        var shopParts: [FirstPartyValidationRecord.ShopPart]
        var shopAvailabilityFingerprint: String
        var discipline: DrivingDiscipline
        var ruleset: FirstPartyValidationRecord.Ruleset
        var appliedFields: [FirstPartyValidationRecord.AppliedField]
    }
}

struct FirstPartyValidationOutcomeEvaluator {
    func evaluate(_ inputs: [FirstPartyValidationIngestionInput]) -> FirstPartyValidationOutcomeReport {
        let ingestor = FirstPartyValidationIngestor()
        var invalidCount = 0
        var quarantinedCount = 0
        var verified: [ValidatedFirstPartyValidationSession] = []

        for input in inputs {
            guard let validated = try? ingestor.validate(input.exportJSON) else {
                invalidCount += 1
                continue
            }
            guard let permission = input.verifiedPermission,
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
                .filter { _, sessions in
                    Set(sessions.map {
                        SubmissionUse(
                            canonicalExportDigest: $0.canonicalExportDigest,
                            contentFingerprint: $0.export.contentFingerprint
                        )
                    }).count > 1
                }
                .map(\.key)
        )
        let replayedReceiptIDs = Set(
            Dictionary(grouping: verified, by: { $0.export.permissionReceiptID })
                .filter { _, sessions in
                    Set(sessions.map {
                        ReceiptUse(
                            submissionID: $0.export.submissionID,
                            contentFingerprint: $0.export.contentFingerprint
                        )
                    }).count > 1
                }
                .map(\.key)
        )
        let conflicted = verified.filter {
            conflictingSubmissionIDs.contains($0.export.submissionID)
                || replayedReceiptIDs.contains($0.export.permissionReceiptID)
        }
        let conflictFree = verified.filter {
            !conflictingSubmissionIDs.contains($0.export.submissionID)
                && !replayedReceiptIDs.contains($0.export.permissionReceiptID)
        }
        let contentGroups = Dictionary(grouping: conflictFree, by: { $0.export.contentFingerprint })
        let duplicateCount = contentGroups.values.reduce(0) { total, sessions in
            total + max(0, sessions.count - 1)
        }
        let accepted = contentGroups.values.compactMap { sessions in
            sessions.min {
                if $0.canonicalExportDigest != $1.canonicalExportDigest {
                    return $0.canonicalExportDigest < $1.canonicalExportDigest
                }
                return $0.export.submissionID.uuidString < $1.export.submissionID.uuidString
            }
        }

        let groups = Dictionary(grouping: accepted, by: \.testedTuneFingerprint)
            .map { fingerprint, sessions in
                makeGroup(fingerprint: fingerprint, sessions: sessions)
            }
            .sorted { $0.testedTuneFingerprint < $1.testedTuneFingerprint }

        return FirstPartyValidationOutcomeReport(
            receivedCount: inputs.count,
            verifiedUniqueSessionCount: accepted.count,
            quarantinedCount: quarantinedCount,
            invalidCount: invalidCount,
            duplicateCount: duplicateCount,
            conflictCount: conflicted.count,
            receiptReplayCount: verified.filter {
                replayedReceiptIDs.contains($0.export.permissionReceiptID)
            }.count,
            groups: groups
        )
    }

    private func makeGroup(
        fingerprint: String,
        sessions: [ValidatedFirstPartyValidationSession]
    ) -> FirstPartyValidationOutcomeGroup {
        let first = sessions[0].export
        let keepCount = sessions.filter { $0.export.outcome.verdict == .keep }.count
        let adjustCount = sessions.filter { $0.export.outcome.verdict == .adjust }.count
        let rejectCount = sessions.filter { $0.export.outcome.verdict == .reject }.count
        let negativeFeedback = sessions.flatMap { session in
            session.export.outcome.verdict == .keep ? [] : session.export.outcome.feedback
        }
        return FirstPartyValidationOutcomeGroup(
            testedTuneFingerprint: fingerprint,
            associationContext: FirstPartyValidationAssociationContext(
                game: first.game,
                gameBuildVersion: first.gameBuildVersion,
                buildCapturedAt: first.buildCapturedAt,
                vehicle: first.vehicle,
                shopParts: first.shopParts,
                shopAvailabilityFingerprint: first.shopAvailabilityFingerprint,
                discipline: first.discipline,
                ruleset: first.ruleset,
                appliedFields: first.appliedFields
            ),
            sessionCount: sessions.count,
            keepCount: keepCount,
            adjustCount: adjustCount,
            rejectCount: rejectCount,
            acceptanceRate: Double(keepCount) / Double(sessions.count),
            handlingSymptomCounts: counts(negativeFeedback.map(\.rawValue)),
            courseTypeCounts: counts(sessions.map { $0.export.session.courseType.rawValue }),
            surfaceCounts: counts(sessions.map { $0.export.session.surface.rawValue }),
            inputCounts: counts(sessions.map { $0.export.session.input.rawValue })
        )
    }

    private func counts(_ values: [String]) -> [FirstPartyValidationValueCount] {
        Dictionary(grouping: values, by: { $0 })
            .map { FirstPartyValidationValueCount(value: $0.key, count: $0.value.count) }
            .sorted { $0.value < $1.value }
    }

    private struct SubmissionUse: Hashable {
        var canonicalExportDigest: String
        var contentFingerprint: String
    }

    private struct ReceiptUse: Hashable {
        var submissionID: UUID
        var contentFingerprint: String
    }
}
