//
//  FH6ValidationReview.swift
//  forzadvisor
//
//  Strict local ingestion and outcome-only review of permission-bound FH6
//  validation exports. Review reports are evidence, never tuning rules.
//

import CryptoKit
import Foundation

struct FH6ValidationReviewPermission: Codable, Equatable, Sendable {
    let submissionID: UUID
    let permissionReceiptID: UUID
    let consentVersion: String
    let canonicalExportDigest: String
    let contentFingerprint: String
    let locallyReviewedAt: Date
}

struct FH6ValidationReviewEntry: Codable, Equatable, Identifiable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let id: UUID
    let importedAt: Date
    let canonicalExportJSON: Data
    let permission: FH6ValidationReviewPermission

    var hasConsistentLocalReviewTimestamp: Bool {
        importedAt == permission.locallyReviewedAt
    }

    init(
        id: UUID = UUID(),
        importedAt: Date = .now,
        canonicalExportJSON: Data,
        permission: FH6ValidationReviewPermission
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
            throw FH6ValidationReviewError.permissionNotConfirmed
        }
        let validated = try FH6ValidationReviewIngestor().validate(canonicalExportJSON)
        return Self(
            id: id,
            importedAt: now,
            canonicalExportJSON: canonicalExportJSON,
            permission: FH6ValidationReviewPermission(
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

enum FH6ValidationReviewError: Error, LocalizedError, Equatable {
    case emptyPayload
    case payloadTooLarge
    case invalidJSON
    case nonCanonicalJSON
    case invalidStructure
    case invalidShopAvailabilityFingerprint
    case invalidContentFingerprint
    case permissionNotConfirmed
    case tuneMismatch
    case corruptStorage

    var errorDescription: String? {
        switch self {
        case .emptyPayload:
            "Paste a ForzAdvisor FH6 validation JSON export first."
        case .payloadTooLarge:
            "This validation export is larger than the supported 256 KiB limit."
        case .invalidJSON:
            "This is not a readable FH6 validation JSON export."
        case .nonCanonicalJSON:
            "This export is not the exact canonical JSON produced by ForzAdvisor."
        case .invalidStructure:
            "This export failed the FH6 validation structure and value checks."
        case .invalidShopAvailabilityFingerprint:
            "This export's upgrade-shop fingerprint does not match its contents."
        case .invalidContentFingerprint:
            "This export's content fingerprint does not match its contents."
        case .permissionNotConfirmed:
            "Confirm direct receipt and reuse permission before importing."
        case .tuneMismatch:
            "This validation session tested a different FH6 setup or tune revision."
        case .corruptStorage:
            "Stored FH6 review evidence is corrupt. The saved tune and local test drives were not changed."
        }
    }
}

struct ValidatedFH6ValidationSession: Sendable {
    let export: FirstPartyValidationExport
    let canonicalExportDigest: String
    let testedTuneFingerprint: String
}

struct FH6ValidationReviewAssociationContext: Equatable, Sendable {
    let game: ForzaGame
    let gameBuildVersion: String
    let buildCapturedAt: Date
    let vehicle: FirstPartyValidationRecord.Vehicle
    let shopParts: [FirstPartyValidationRecord.ShopPart]
    let shopAvailabilityFingerprint: String
    let discipline: DrivingDiscipline
    let ruleset: FirstPartyValidationRecord.Ruleset
    let appliedFields: [FirstPartyValidationRecord.AppliedField]
}

struct FH6ValidationReviewValueCount: Equatable, Sendable {
    let value: String
    let count: Int
}

struct FH6ValidationReviewOutcomeGroup: Equatable, Identifiable, Sendable {
    var id: String { testedTuneFingerprint }

    let testedTuneFingerprint: String
    let associationContext: FH6ValidationReviewAssociationContext
    let sessionCount: Int
    let keepCount: Int
    let adjustCount: Int
    let rejectCount: Int
    let acceptanceRate: Double
    let handlingSymptomCounts: [FH6ValidationReviewValueCount]
    let courseTypeCounts: [FH6ValidationReviewValueCount]
    let surfaceCounts: [FH6ValidationReviewValueCount]
    let inputCounts: [FH6ValidationReviewValueCount]
}

struct FH6ValidationReviewReport: Equatable, Sendable {
    let receivedCount: Int
    let verifiedUniqueSessionCount: Int
    let quarantinedCount: Int
    let invalidCount: Int
    let duplicateCount: Int
    let conflictCount: Int
    /// A receipt replay is also included in `conflictCount`.
    let receiptReplayCount: Int
    let groups: [FH6ValidationReviewOutcomeGroup]

    static let empty = Self(
        receivedCount: 0,
        verifiedUniqueSessionCount: 0,
        quarantinedCount: 0,
        invalidCount: 0,
        duplicateCount: 0,
        conflictCount: 0,
        receiptReplayCount: 0,
        groups: []
    )

    var sessionSummary: String {
        let keep = groups.reduce(0) { $0 + $1.keepCount }
        let adjust = groups.reduce(0) { $0 + $1.adjustCount }
        let reject = groups.reduce(0) { $0 + $1.rejectCount }
        return "Verified first-party sessions: \(verifiedUniqueSessionCount). "
            + "Tested tune groups: \(groups.count). "
            + "Keep: \(keep), Adjust: \(adjust), Reject: \(reject)."
    }
}

struct FH6ValidationReviewIngestor {
    static let maximumPayloadBytes = 256 * 1_024

    func validate(_ data: Data) throws -> ValidatedFH6ValidationSession {
        guard !data.isEmpty else { throw FH6ValidationReviewError.emptyPayload }
        guard data.count <= Self.maximumPayloadBytes else {
            throw FH6ValidationReviewError.payloadTooLarge
        }

        let export: FirstPartyValidationExport
        do {
            export = try Self.decoder.decode(FirstPartyValidationExport.self, from: data)
        } catch {
            throw FH6ValidationReviewError.invalidJSON
        }

        let canonical: Data
        do {
            canonical = try Self.canonicalData(for: export)
        } catch {
            throw FH6ValidationReviewError.invalidJSON
        }
        guard canonical == data else {
            throw FH6ValidationReviewError.nonCanonicalJSON
        }
        guard Self.hasValidStructure(export) else {
            throw FH6ValidationReviewError.invalidStructure
        }
        guard (try? Self.shopAvailabilityFingerprint(for: export.shopParts))
                == export.shopAvailabilityFingerprint else {
            throw FH6ValidationReviewError.invalidShopAvailabilityFingerprint
        }
        guard (try? Self.contentFingerprint(for: export)) == export.contentFingerprint else {
            throw FH6ValidationReviewError.invalidContentFingerprint
        }
        guard let testedTuneFingerprint = try? Self.testedTuneFingerprint(for: export) else {
            throw FH6ValidationReviewError.invalidStructure
        }

        return ValidatedFH6ValidationSession(
            export: export,
            canonicalExportDigest: Self.sha256(canonical),
            testedTuneFingerprint: testedTuneFingerprint
        )
    }

    func matchesSavedTune(
        _ validated: ValidatedFH6ValidationSession,
        tune: TuneResult
    ) -> Bool {
        guard let eligibleTune = try? FirstPartyValidationRecordFactory()
            .eligibility(
                for: tune,
                savedTune: tune,
                isStreaming: false
            )
            .get(),
              let localFingerprint = try? Self.testedTuneFingerprint(
                for: eligibleTune
              ) else {
            return false
        }
        return localFingerprint == validated.testedTuneFingerprint
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
            vehicle: export.vehicle,
            shopParts: export.shopParts,
            shopAvailabilityFingerprint: export.shopAvailabilityFingerprint,
            discipline: export.discipline,
            ruleset: export.ruleset,
            appliedFields: export.appliedFields
        ))
    }

    private static let expectedUnknowns = [
        "assists:not-collected", "elapsed-time:not-collected", "telemetry:not-collected",
        "weather:not-collected"
    ]

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
              export.shopParts == export.shopParts.sorted(by: {
                  $0.partID.rawValue < $1.partID.rawValue
              }),
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

    private static func testedTuneFingerprint(for tune: TuneResult) throws -> String {
        let projected = TuneOutputProjector().project(tune)
        guard projected.purpose == .numericTune,
              let snapshot = projected.request.buildSnapshot,
              snapshot.kind == .exactBuildObservation,
              snapshot.isValid,
              snapshot.matches(car: projected.request.car),
              snapshot.car.game == .fh6,
              !snapshot.car.catalogValuesModified,
              let buildVersion = snapshot.gameBuild.version,
              snapshot.gameBuild.capturedAt != nil,
              let catalog = snapshot.car.catalogReference,
              let year = snapshot.car.year,
              let horsepower = snapshot.car.peakHorsepower,
              let torque = snapshot.car.peakTorqueFootPounds,
              let tire = snapshot.tireCompound,
              let gearCount = snapshot.gearCount,
              let ruleset = projected.rulesetReference,
              let report = projected.projectionReport,
              let fields = appliedFields(in: projected, report: report),
              canonicalPublicString(buildVersion, maximumLength: 120),
              canonicalPublicString(catalog.entryID, maximumLength: 160),
              canonicalPublicString(snapshot.car.make, maximumLength: 120),
              canonicalPublicString(snapshot.car.model, maximumLength: 120),
              canonicalPublicString(tire.id, maximumLength: 160),
              canonicalPublicString(tire.displayName, maximumLength: 120),
              canonicalPublicString(ruleset.id, maximumLength: 160),
              canonicalPublicString(ruleset.algorithmVersion, maximumLength: 120),
              canonicalPublicString(ruleset.knowledgeRevision, maximumLength: 160) else {
            throw FH6ValidationReviewError.tuneMismatch
        }

        let parts = snapshot.capabilityProfile.parts.map {
            FirstPartyValidationRecord.ShopPart(
                partID: $0.partID,
                availability: $0.availability
            )
        }.sorted { $0.partID.rawValue < $1.partID.rawValue }
        let expectedPartIDs = Set(TunePartID.allCases)
        guard parts.count == expectedPartIDs.count,
              Set(parts.map(\.partID)) == expectedPartIDs,
              parts.allSatisfy({
                  $0.availability == .available || $0.availability == .unavailable
              }) else {
            throw FH6ValidationReviewError.tuneMismatch
        }

        let vehicle = FirstPartyValidationRecord.Vehicle(
            catalogID: catalog.entryID,
            year: year,
            make: snapshot.car.make,
            model: snapshot.car.model,
            performanceClass: snapshot.car.performanceClass,
            performanceIndex: snapshot.car.performanceIndex,
            drivetrain: snapshot.car.drivetrain,
            weightPounds: snapshot.car.weightPounds,
            frontWeightPercent: snapshot.car.frontWeightPercent,
            peakHorsepower: horsepower,
            peakTorqueFootPounds: torque,
            tireCompoundID: tire.id,
            tireCompoundDisplayName: tire.displayName,
            gearCount: gearCount,
            stock: true
        )
        let publicRuleset = FirstPartyValidationRecord.Ruleset(
            id: ruleset.id,
            schemaVersion: ruleset.schemaVersion,
            algorithmVersion: ruleset.algorithmVersion,
            knowledgeRevision: ruleset.knowledgeRevision,
            validationStatus: ruleset.validationStatus
        )
        let shopFingerprint = try shopAvailabilityFingerprint(for: parts)
        return try fingerprint(TestedTunePayload(
            game: snapshot.car.game,
            gameBuildVersion: buildVersion,
            vehicle: vehicle,
            shopParts: parts,
            shopAvailabilityFingerprint: shopFingerprint,
            discipline: projected.request.discipline,
            ruleset: publicRuleset,
            appliedFields: fields
        ))
    }

    private static func appliedFields(
        in tune: TuneResult,
        report: TuneProjectionReport
    ) -> [FirstPartyValidationRecord.AppliedField]? {
        let lines = tune.sections.flatMap(\.lines)
        guard lines.count == report.readyCount else { return nil }
        var seen = Set<TuneFieldID>()
        var result: [FirstPartyValidationRecord.AppliedField] = []
        for line in lines {
            guard let field = line.fieldID,
                  report.readyFieldIDs.contains(field),
                  seen.insert(field).inserted,
                  line.unit == field.expectedDisplayUnit,
                  let value = LocalizedNumberText.parse(line.value, locale: .current),
                  value.isFinite else {
                return nil
            }
            result.append(.init(field: field, value: value, unit: field.expectedUnit))
        }
        guard Set(result.map(\.field)) == report.readyFieldIDs else { return nil }
        return result.sorted { $0.field.stableID < $1.field.stableID }
    }

    private static func canonicalPublicString(
        _ value: String,
        maximumLength: Int
    ) -> Bool {
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

    private struct ContentPayload: Codable {
        let game: ForzaGame
        let gameBuildVersion: String
        let buildCapturedAt: Date
        let vehicle: FirstPartyValidationRecord.Vehicle
        let shopParts: [FirstPartyValidationRecord.ShopPart]
        let shopAvailabilityFingerprint: String
        let discipline: DrivingDiscipline
        let tuneGeneratedAt: Date
        let ruleset: FirstPartyValidationRecord.Ruleset
        let appliedFields: [FirstPartyValidationRecord.AppliedField]
        let session: FirstPartyValidationRecord.Session
        let outcome: FirstPartyValidationRecord.Outcome
    }

    private struct TestedTunePayload: Codable {
        // Capture time is administrative observation metadata. Different drivers
        // can test the same game build and exact setup at different times.
        let game: ForzaGame
        let gameBuildVersion: String
        let vehicle: FirstPartyValidationRecord.Vehicle
        let shopParts: [FirstPartyValidationRecord.ShopPart]
        let shopAvailabilityFingerprint: String
        let discipline: DrivingDiscipline
        let ruleset: FirstPartyValidationRecord.Ruleset
        let appliedFields: [FirstPartyValidationRecord.AppliedField]
    }
}

struct FH6ValidationReviewEvaluator {
    func evaluate(_ entries: [FH6ValidationReviewEntry]) -> FH6ValidationReviewReport {
        let ingestor = FH6ValidationReviewIngestor()
        var invalidCount = 0
        var quarantinedCount = 0
        var verified: [ValidatedFH6ValidationSession] = []

        for entry in entries {
            guard entry.schemaVersion == FH6ValidationReviewEntry.currentSchemaVersion,
                  let validated = try? ingestor.validate(entry.canonicalExportJSON) else {
                invalidCount += 1
                continue
            }
            guard entry.hasConsistentLocalReviewTimestamp else {
                quarantinedCount += 1
                continue
            }
            let permission = entry.permission
            guard permission.submissionID == validated.export.submissionID,
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
        let contentGroups = Dictionary(
            grouping: conflictFree,
            by: { $0.export.contentFingerprint }
        )
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

        return FH6ValidationReviewReport(
            receivedCount: entries.count,
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
        sessions: [ValidatedFH6ValidationSession]
    ) -> FH6ValidationReviewOutcomeGroup {
        let orderedSessions = sessions.sorted {
            if $0.export.buildCapturedAt != $1.export.buildCapturedAt {
                return $0.export.buildCapturedAt < $1.export.buildCapturedAt
            }
            if $0.canonicalExportDigest != $1.canonicalExportDigest {
                return $0.canonicalExportDigest < $1.canonicalExportDigest
            }
            return $0.export.submissionID.uuidString
                < $1.export.submissionID.uuidString
        }
        let first = orderedSessions[0].export
        let keepCount = orderedSessions
            .filter { $0.export.outcome.verdict == .keep }.count
        let adjustCount = orderedSessions
            .filter { $0.export.outcome.verdict == .adjust }.count
        let rejectCount = orderedSessions
            .filter { $0.export.outcome.verdict == .reject }.count
        let negativeFeedback = orderedSessions.flatMap { session in
            session.export.outcome.verdict == .keep ? [] : session.export.outcome.feedback
        }
        return FH6ValidationReviewOutcomeGroup(
            testedTuneFingerprint: fingerprint,
            associationContext: FH6ValidationReviewAssociationContext(
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
            sessionCount: orderedSessions.count,
            keepCount: keepCount,
            adjustCount: adjustCount,
            rejectCount: rejectCount,
            acceptanceRate: Double(keepCount) / Double(orderedSessions.count),
            handlingSymptomCounts: counts(negativeFeedback.map(\.rawValue)),
            courseTypeCounts: counts(
                orderedSessions.map { $0.export.session.courseType.rawValue }
            ),
            surfaceCounts: counts(
                orderedSessions.map { $0.export.session.surface.rawValue }
            ),
            inputCounts: counts(
                orderedSessions.map { $0.export.session.input.rawValue }
            )
        )
    }

    private func counts(_ values: [String]) -> [FH6ValidationReviewValueCount] {
        Dictionary(grouping: values, by: { $0 })
            .map { FH6ValidationReviewValueCount(value: $0.key, count: $0.value.count) }
            .sorted { $0.value < $1.value }
    }

    private struct SubmissionUse: Hashable {
        let canonicalExportDigest: String
        let contentFingerprint: String
    }

    private struct ReceiptUse: Hashable {
        let submissionID: UUID
        let contentFingerprint: String
    }
}
