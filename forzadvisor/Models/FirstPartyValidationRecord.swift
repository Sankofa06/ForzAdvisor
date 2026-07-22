//
//  FirstPartyValidationRecord.swift
//  forzadvisor
//
//  Permission-clear, allow-listed evidence from a single first-party test-drive session.
//

import CryptoKit
import Foundation

enum ValidationSurface: String, CaseIterable, Codable, Identifiable, Sendable {
    case dry, wet, mixed
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum ValidationInput: String, CaseIterable, Codable, Identifiable, Sendable {
    case controller, wheel, keyboard
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum ValidationVerdict: String, CaseIterable, Codable, Identifiable, Sendable {
    case keep, adjust, reject
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum ValidationCourseType: String, CaseIterable, Codable, Identifiable, Sendable {
    case roadCircuit
    case streetRace
    case sprint
    case dirt
    case crossCountry
    case drag
    case testTrack

    var id: String { rawValue }

    var title: String {
        switch self {
        case .roadCircuit: "Road Circuit"
        case .streetRace: "Street Race"
        case .sprint: "Sprint"
        case .dirt: "Dirt"
        case .crossCountry: "Cross-Country"
        case .drag: "Drag"
        case .testTrack: "Test Track"
        }
    }
}

struct FirstPartyValidationCapture: Equatable, Sendable {
    var courseType: ValidationCourseType
    var surface: ValidationSurface
    var input: ValidationInput
    var runCount: Int
    var verdict: ValidationVerdict
    var feedback: Set<TuneFeedback>
    var exactSetupConfirmed: Bool
    var allExportedSettingsApplied: Bool
    var firstPartyAuthorshipConfirmed: Bool
    var deidentifiedReusePermitted: Bool
}

enum FirstPartyValidationError: LocalizedError, Equatable {
    case notSaved, streaming, legacyTune, staleSavedRevision, invalidSnapshot
    case incompleteStockContext, invalidProjection, invalidRuleset
    case invalidRunCount, missingFeedback, unexpectedFeedback
    case setupNotConfirmed, settingsNotApplied, authorshipNotConfirmed, reuseNotPermitted
    case invalidStoredRecord

    var errorDescription: String? {
        switch self {
        case .notSaved: "Save this tune before recording a test drive."
        case .streaming: "Wait for tune generation to finish."
        case .legacyTune: "Legacy tunes cannot produce accuracy evidence."
        case .staleSavedRevision: "This is not the current saved tune revision."
        case .invalidSnapshot: "The exact vehicle-build snapshot is missing, invalid, or does not match this tune."
        case .incompleteStockContext: "Complete the local stock tire and upgrade-shop verification first."
        case .invalidProjection: "The tune cannot be exported because its fresh projection is incomplete or inconsistent."
        case .invalidRuleset: "The tune does not have a valid current public ruleset reference."
        case .invalidRunCount: "Run count must be between 1 and 99."
        case .missingFeedback: "Choose at least one handling symptom for an Adjust or Reject verdict."
        case .unexpectedFeedback: "A Keep verdict cannot include adjustment or rejection symptoms."
        case .setupNotConfirmed: "Confirm that the tested car matched the verified stock setup."
        case .settingsNotApplied: "Confirm that every exported setting was applied."
        case .authorshipNotConfirmed: "Confirm that this is your own test-drive observation."
        case .reuseNotPermitted: "Allow deidentified benchmark reuse to create a validation record."
        case .invalidStoredRecord: "This validation record failed its integrity checks."
        }
    }
}

struct FirstPartyValidationRecord: Codable, Equatable, Sendable, Identifiable {
    static let currentSchemaVersion = 1
    static let currentConsentVersion = "first-party-validation-v1"

    struct Vehicle: Codable, Equatable, Sendable {
        var catalogID: String
        var year: Int
        var make: String
        var model: String
        var performanceClass: PerformanceClass
        var performanceIndex: Int
        var drivetrain: Drivetrain
        var weightPounds: Int
        var frontWeightPercent: Double
        var peakHorsepower: Int
        var peakTorqueFootPounds: Int
        var tireCompoundID: String
        var tireCompoundDisplayName: String
        var gearCount: Int
        var stock: Bool
    }

    struct ShopPart: Codable, Equatable, Sendable {
        var partID: TunePartID
        var availability: TunePartAvailability
    }

    struct Ruleset: Codable, Equatable, Sendable {
        var id: String
        var schemaVersion: Int
        var algorithmVersion: String
        var knowledgeRevision: String
        var validationStatus: TuneRulesetValidationStatus
    }

    struct AppliedField: Codable, Equatable, Sendable {
        var field: TuneFieldID
        var value: Double
        var unit: TuneUnit
    }

    struct Session: Codable, Equatable, Sendable {
        var courseType: ValidationCourseType
        var surface: ValidationSurface
        var input: ValidationInput
        var runCount: Int
    }

    struct Outcome: Codable, Equatable, Sendable {
        var verdict: ValidationVerdict
        var feedback: [TuneFeedback]
    }

    var id: UUID { recordID }
    var schemaVersion: Int
    var recordID: UUID
    var submissionID: UUID
    var createdAt: Date
    var consentVersion: String
    var permissionReceiptID: UUID
    var game: ForzaGame
    var gameBuildVersion: String
    var buildCapturedAt: Date
    var vehicle: Vehicle
    var shopParts: [ShopPart]
    var shopAvailabilityFingerprint: String
    var discipline: DrivingDiscipline
    var tuneID: UUID
    var tuneGeneratedAt: Date
    var tuneRevisionFingerprint: String
    var ruleset: Ruleset
    var appliedFields: [AppliedField]
    var session: Session
    var outcome: Outcome
    var exactSetupConfirmed: Bool
    var allExportedSettingsApplied: Bool
    var firstPartyAuthorshipConfirmed: Bool
    var deidentifiedReusePermitted: Bool
    var unknowns: [String]
    var privacyExclusions: [String]
    var contentFingerprint: String

    func deterministicJSON() throws -> Data {
        guard FirstPartyValidationRecordFactory().isValid(self) else {
            throw FirstPartyValidationError.invalidStoredRecord
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(publicExport)
    }

    var deterministicJSONString: String? {
        guard let data = try? deterministicJSON() else { return nil }
        return String(data: data, encoding: .utf8)
    }


    var publicExport: FirstPartyValidationExport {
        FirstPartyValidationExport(
            schemaVersion: schemaVersion,
            submissionID: submissionID,
            createdAt: createdAt,
            consentVersion: consentVersion,
            permissionReceiptID: permissionReceiptID,
            game: game,
            gameBuildVersion: gameBuildVersion,
            buildCapturedAt: buildCapturedAt,
            vehicle: vehicle,
            shopParts: shopParts,
            shopAvailabilityFingerprint: shopAvailabilityFingerprint,
            discipline: discipline,
            tuneGeneratedAt: tuneGeneratedAt,
            ruleset: ruleset,
            appliedFields: appliedFields,
            session: session,
            outcome: outcome,
            exactSetupConfirmed: exactSetupConfirmed,
            allExportedSettingsApplied: allExportedSettingsApplied,
            firstPartyAuthorshipConfirmed: firstPartyAuthorshipConfirmed,
            deidentifiedReusePermitted: deidentifiedReusePermitted,
            unknowns: unknowns,
            privacyExclusions: privacyExclusions,
            contentFingerprint: contentFingerprint
        )
    }
}

/// The complete, explicit public JSON allow-list. Persistence-only linkage identifiers are absent.
struct FirstPartyValidationExport: Codable, Equatable, Sendable {
    var schemaVersion: Int
    var submissionID: UUID
    var createdAt: Date
    var consentVersion: String
    var permissionReceiptID: UUID
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
    var exactSetupConfirmed: Bool
    var allExportedSettingsApplied: Bool
    var firstPartyAuthorshipConfirmed: Bool
    var deidentifiedReusePermitted: Bool
    var unknowns: [String]
    var privacyExclusions: [String]
    var contentFingerprint: String
}

struct FirstPartyValidationRecordFactory {
    var locale: Locale = .current

    private static let unknowns = [
        "assists:not-collected", "elapsed-time:not-collected", "telemetry:not-collected",
        "weather:not-collected"
    ]
    private static let exclusions = [
        "attachments", "catalog-source-urls", "device-identifiers", "garage-notes",
        "location", "provider-details", "public-attribution", "raw-build-snapshot",
        "ruleset-provenance-ids", "tune-notes"
    ]

    func eligibility(
        for tune: TuneResult,
        savedTune: TuneResult?,
        isStreaming: Bool
    ) -> Result<TuneResult, FirstPartyValidationError> {
        guard savedTune != nil else { return .failure(.notSaved) }
        guard !isStreaming else { return .failure(.streaming) }
        guard tune.projectionReport != nil else { return .failure(.legacyTune) }
        guard savedTune?.id == tune.id, savedTune?.generatedAt == tune.generatedAt else {
            return .failure(.staleSavedRevision)
        }
        guard let snapshot = tune.request.buildSnapshot,
              snapshot.kind == .exactBuildObservation,
              snapshot.isValid,
              snapshot.matches(car: tune.request.car),
              snapshot.gameBuild.hasKnownVersion,
              let buildVersion = snapshot.gameBuild.version,
              !buildVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              snapshot.car.catalogReference != nil,
              !snapshot.car.catalogValuesModified,
              snapshot.car.peakHorsepower != nil,
              snapshot.car.peakTorqueFootPounds != nil,
              snapshot.tireCompound != nil,
              snapshot.gearCount != nil else {
            return .failure(.invalidSnapshot)
        }
        guard hasPermissionClearStockCapture(snapshot) else {
            return .failure(.incompleteStockContext)
        }
        guard let ruleset = tune.rulesetReference,
              ruleset.isValid,
              matchesCurrentPublicRuleset(ruleset, snapshot: snapshot),
              hasSafeExportStrings(snapshot: snapshot, ruleset: ruleset) else {
            return .failure(.invalidRuleset)
        }

        let projected = TuneOutputProjector().project(tune)
        guard let report = projected.projectionReport,
              report.schemaVersion == TuneProjectionReport.currentSchemaVersion,
              report.snapshotID == snapshot.id,
              report.contextStatus == .exactBuild,
              report.readyCount > 0,
              validAppliedFields(in: projected, report: report) != nil else {
            return .failure(.invalidProjection)
        }
        guard let savedTune,
              let projectedRevision = revisionFingerprint(for: projected),
              let savedRevision = revisionFingerprint(for: TuneOutputProjector().project(savedTune)),
              projectedRevision == savedRevision else {
            return .failure(.staleSavedRevision)
        }
        return .success(projected)
    }

    func make(
        tune: TuneResult,
        savedTune: TuneResult?,
        isStreaming: Bool,
        capture: FirstPartyValidationCapture,
        recordID: UUID = UUID(),
        submissionID: UUID = UUID(),
        permissionReceiptID: UUID = UUID(),
        createdAt: Date = .now
    ) throws -> FirstPartyValidationRecord {
        let projected = try eligibility(for: tune, savedTune: savedTune, isStreaming: isStreaming).get()
        guard (1...99).contains(capture.runCount) else { throw FirstPartyValidationError.invalidRunCount }
        if capture.verdict != .keep && capture.feedback.isEmpty {
            throw FirstPartyValidationError.missingFeedback
        }
        if capture.verdict == .keep && !capture.feedback.isEmpty {
            throw FirstPartyValidationError.unexpectedFeedback
        }
        guard capture.exactSetupConfirmed else { throw FirstPartyValidationError.setupNotConfirmed }
        guard capture.allExportedSettingsApplied else { throw FirstPartyValidationError.settingsNotApplied }
        guard capture.firstPartyAuthorshipConfirmed else { throw FirstPartyValidationError.authorshipNotConfirmed }
        guard capture.deidentifiedReusePermitted else { throw FirstPartyValidationError.reuseNotPermitted }

        guard let snapshot = projected.request.buildSnapshot,
              let catalog = snapshot.car.catalogReference,
              let year = snapshot.car.year,
              let horsepower = snapshot.car.peakHorsepower,
              let torque = snapshot.car.peakTorqueFootPounds,
              let tire = snapshot.tireCompound,
              let gearCount = snapshot.gearCount,
              let build = snapshot.gameBuild.version,
              let buildDate = snapshot.gameBuild.capturedAt,
              let ruleset = projected.rulesetReference,
              let report = projected.projectionReport,
              let fields = validAppliedFields(in: projected, report: report) else {
            throw FirstPartyValidationError.invalidProjection
        }
        guard let canonicalBuild = canonicalPublicString(build, maximumLength: 120),
              let catalogID = canonicalPublicString(catalog.entryID, maximumLength: 160),
              let make = canonicalPublicString(snapshot.car.make, maximumLength: 120),
              let model = canonicalPublicString(snapshot.car.model, maximumLength: 120),
              let tireID = canonicalPublicString(tire.id, maximumLength: 160),
              let tireName = canonicalPublicString(tire.displayName, maximumLength: 120),
              let rulesetID = canonicalPublicString(ruleset.id, maximumLength: 160),
              let algorithm = canonicalPublicString(ruleset.algorithmVersion, maximumLength: 120),
              let knowledge = canonicalPublicString(ruleset.knowledgeRevision, maximumLength: 160) else {
            throw FirstPartyValidationError.invalidSnapshot
        }
        let parts = snapshot.capabilityProfile.parts
            .map { FirstPartyValidationRecord.ShopPart(partID: $0.partID, availability: $0.availability) }
            .sorted { $0.partID.rawValue < $1.partID.rawValue }
        let vehicle = FirstPartyValidationRecord.Vehicle(
            catalogID: catalogID, year: year, make: make, model: model,
            performanceClass: snapshot.car.performanceClass, performanceIndex: snapshot.car.performanceIndex,
            drivetrain: snapshot.car.drivetrain, weightPounds: snapshot.car.weightPounds,
            frontWeightPercent: snapshot.car.frontWeightPercent, peakHorsepower: horsepower,
            peakTorqueFootPounds: torque, tireCompoundID: tireID,
            tireCompoundDisplayName: tireName, gearCount: gearCount, stock: true
        )
        let publicRuleset = FirstPartyValidationRecord.Ruleset(
            id: rulesetID, schemaVersion: ruleset.schemaVersion,
            algorithmVersion: algorithm, knowledgeRevision: knowledge,
            validationStatus: ruleset.validationStatus
        )
        let outcome = FirstPartyValidationRecord.Outcome(
            verdict: capture.verdict,
            feedback: capture.feedback.sorted { $0.rawValue < $1.rawValue }
        )
        let session = FirstPartyValidationRecord.Session(
            courseType: capture.courseType, surface: capture.surface, input: capture.input,
            runCount: capture.runCount
        )
        let shopHash = try hash(parts)
        let revision = try hash(RevisionPayload(
            game: snapshot.car.game, gameBuildVersion: canonicalBuild,
            buildCapturedAt: buildDate, vehicle: vehicle,
            shopAvailabilityFingerprint: shopHash, discipline: projected.request.discipline,
            tuneID: projected.id, tuneGeneratedAt: projected.generatedAt, ruleset: publicRuleset,
            appliedFields: fields
        ))
        let content = try hash(ContentPayload(
            game: snapshot.car.game, gameBuildVersion: canonicalBuild, buildCapturedAt: buildDate,
            vehicle: vehicle, shopParts: parts, shopAvailabilityFingerprint: shopHash,
            discipline: projected.request.discipline, tuneGeneratedAt: projected.generatedAt,
            ruleset: publicRuleset, appliedFields: fields, session: session, outcome: outcome
        ))
        return FirstPartyValidationRecord(
            schemaVersion: FirstPartyValidationRecord.currentSchemaVersion,
            recordID: recordID, submissionID: submissionID, createdAt: createdAt,
            consentVersion: FirstPartyValidationRecord.currentConsentVersion,
            permissionReceiptID: permissionReceiptID, game: snapshot.car.game,
            gameBuildVersion: canonicalBuild, buildCapturedAt: buildDate, vehicle: vehicle,
            shopParts: parts, shopAvailabilityFingerprint: shopHash,
            discipline: projected.request.discipline, tuneID: projected.id,
            tuneGeneratedAt: projected.generatedAt, tuneRevisionFingerprint: revision,
            ruleset: publicRuleset, appliedFields: fields, session: session, outcome: outcome,
            exactSetupConfirmed: true, allExportedSettingsApplied: true,
            firstPartyAuthorshipConfirmed: true, deidentifiedReusePermitted: true,
            unknowns: Self.unknowns, privacyExclusions: Self.exclusions,
            contentFingerprint: content
        )
    }

    func revisionFingerprint(for tune: TuneResult) -> String? {
        guard let snapshot = tune.request.buildSnapshot,
              let build = snapshot.gameBuild.version,
              let year = snapshot.car.year,
              let hp = snapshot.car.peakHorsepower,
              let torque = snapshot.car.peakTorqueFootPounds,
              let tire = snapshot.tireCompound,
              let gears = snapshot.gearCount,
              let catalog = snapshot.car.catalogReference,
              let ruleset = tune.rulesetReference,
              let report = tune.projectionReport,
              let fields = validAppliedFields(in: tune, report: report) else { return nil }
        guard let canonicalBuild = canonicalPublicString(build, maximumLength: 120),
              let catalogID = canonicalPublicString(catalog.entryID, maximumLength: 160),
              let make = canonicalPublicString(snapshot.car.make, maximumLength: 120),
              let model = canonicalPublicString(snapshot.car.model, maximumLength: 120),
              let tireID = canonicalPublicString(tire.id, maximumLength: 160),
              let tireName = canonicalPublicString(tire.displayName, maximumLength: 120),
              let rulesetID = canonicalPublicString(ruleset.id, maximumLength: 160),
              let algorithm = canonicalPublicString(ruleset.algorithmVersion, maximumLength: 120),
              let knowledge = canonicalPublicString(ruleset.knowledgeRevision, maximumLength: 160) else {
            return nil
        }
        let vehicle = FirstPartyValidationRecord.Vehicle(
            catalogID: catalogID, year: year, make: make, model: model,
            performanceClass: snapshot.car.performanceClass, performanceIndex: snapshot.car.performanceIndex,
            drivetrain: snapshot.car.drivetrain, weightPounds: snapshot.car.weightPounds,
            frontWeightPercent: snapshot.car.frontWeightPercent, peakHorsepower: hp,
            peakTorqueFootPounds: torque, tireCompoundID: tireID,
            tireCompoundDisplayName: tireName, gearCount: gears, stock: true
        )
        let parts = snapshot.capabilityProfile.parts.map {
            FirstPartyValidationRecord.ShopPart(partID: $0.partID, availability: $0.availability)
        }.sorted { $0.partID.rawValue < $1.partID.rawValue }
        let publicRuleset = FirstPartyValidationRecord.Ruleset(
            id: rulesetID, schemaVersion: ruleset.schemaVersion,
            algorithmVersion: algorithm, knowledgeRevision: knowledge,
            validationStatus: ruleset.validationStatus
        )
        guard let shopHash = try? hash(parts) else { return nil }
        return try? hash(RevisionPayload(
            game: snapshot.car.game, gameBuildVersion: canonicalBuild,
            buildCapturedAt: snapshot.gameBuild.capturedAt ?? snapshot.capturedAt, vehicle: vehicle,
            shopAvailabilityFingerprint: shopHash, discipline: tune.request.discipline,
            tuneID: tune.id, tuneGeneratedAt: tune.generatedAt, ruleset: publicRuleset,
            appliedFields: fields
        ))
    }

    func isValid(_ record: FirstPartyValidationRecord) -> Bool {
        guard record.schemaVersion == FirstPartyValidationRecord.currentSchemaVersion,
              record.consentVersion == FirstPartyValidationRecord.currentConsentVersion,
              record.vehicle.stock,
              record.ruleset.validationStatus != .deprecated,
              !record.ruleset.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              record.ruleset.schemaVersion > 0,
              !record.ruleset.algorithmVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !record.ruleset.knowledgeRevision.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              record.exactSetupConfirmed,
              record.allExportedSettingsApplied,
              record.firstPartyAuthorshipConfirmed,
              record.deidentifiedReusePermitted,
              (1...99).contains(record.session.runCount),
              ((record.outcome.verdict == .keep && record.outcome.feedback.isEmpty)
                || (record.outcome.verdict != .keep && !record.outcome.feedback.isEmpty)),
              record.outcome.feedback == record.outcome.feedback.sorted(by: { $0.rawValue < $1.rawValue }),
              Set(record.outcome.feedback).count == record.outcome.feedback.count,
              record.unknowns == Self.unknowns,
              record.privacyExclusions == Self.exclusions else { return false }

        guard canonicalPublicString(record.gameBuildVersion, maximumLength: 120) == record.gameBuildVersion,
              canonicalPublicString(record.vehicle.catalogID, maximumLength: 160) == record.vehicle.catalogID,
              canonicalPublicString(record.vehicle.make, maximumLength: 120) == record.vehicle.make,
              canonicalPublicString(record.vehicle.model, maximumLength: 120) == record.vehicle.model,
              canonicalPublicString(record.vehicle.tireCompoundID, maximumLength: 160) == record.vehicle.tireCompoundID,
              canonicalPublicString(record.vehicle.tireCompoundDisplayName, maximumLength: 120) == record.vehicle.tireCompoundDisplayName,
              canonicalPublicString(record.ruleset.id, maximumLength: 160) == record.ruleset.id,
              canonicalPublicString(record.ruleset.algorithmVersion, maximumLength: 120) == record.ruleset.algorithmVersion,
              canonicalPublicString(record.ruleset.knowledgeRevision, maximumLength: 160) == record.ruleset.knowledgeRevision else {
            return false
        }

        let expectedParts = Set(TunePartID.allCases)
        guard record.shopParts.count == expectedParts.count,
              Set(record.shopParts.map(\.partID)) == expectedParts,
              record.shopParts == record.shopParts.sorted(by: { $0.partID.rawValue < $1.partID.rawValue }),
              record.shopParts.allSatisfy({ $0.availability == .available || $0.availability == .unavailable }),
              !record.appliedFields.isEmpty,
              Set(record.appliedFields.map(\.field)).count == record.appliedFields.count,
              record.appliedFields == record.appliedFields.sorted(by: { $0.field.stableID < $1.field.stableID }),
              record.appliedFields.allSatisfy({ $0.value.isFinite && $0.unit == $0.field.expectedUnit }) else {
            return false
        }

        guard let shopHash = try? hash(record.shopParts),
              shopHash == record.shopAvailabilityFingerprint else { return false }
        let revisionPayload = RevisionPayload(
            game: record.game, gameBuildVersion: record.gameBuildVersion,
            buildCapturedAt: record.buildCapturedAt, vehicle: record.vehicle,
            shopAvailabilityFingerprint: record.shopAvailabilityFingerprint,
            discipline: record.discipline, tuneID: record.tuneID,
            tuneGeneratedAt: record.tuneGeneratedAt, ruleset: record.ruleset,
            appliedFields: record.appliedFields
        )
        guard let revisionHash = try? hash(revisionPayload),
              revisionHash == record.tuneRevisionFingerprint else { return false }
        let contentPayload = ContentPayload(
            game: record.game, gameBuildVersion: record.gameBuildVersion,
            buildCapturedAt: record.buildCapturedAt, vehicle: record.vehicle,
            shopParts: record.shopParts,
            shopAvailabilityFingerprint: record.shopAvailabilityFingerprint,
            discipline: record.discipline, tuneGeneratedAt: record.tuneGeneratedAt,
            ruleset: record.ruleset, appliedFields: record.appliedFields,
            session: record.session, outcome: record.outcome
        )
        return (try? hash(contentPayload)) == record.contentFingerprint
    }

    private func hasPermissionClearStockCapture(_ snapshot: VehicleBuildSnapshot) -> Bool {
        guard let rawBuild = snapshot.gameBuild.version else { return false }
        let build = rawBuild.trimmingCharacters(in: .whitespacesAndNewlines)
        let expected = Set(TunePartID.allCases)
        let parts = snapshot.capabilityProfile.parts
        guard parts.count == expected.count, Set(parts.map(\.partID)) == expected,
              parts.allSatisfy({
                  ($0.availability == .available || $0.availability == .unavailable)
                      && $0.evidence.source == UpgradePartCapture.provenanceSource
                      && $0.evidence.version == build
                      && $0.evidence.usagePermission == .permitted
                      && $0.evidence.confidence != .low
              }) else { return false }
        let tireFields: Set<TuneFieldID> = [.frontTirePressure, .rearTirePressure]
        let tireConstraints = snapshot.constraints.filter { tireFields.contains($0.field) }
        guard tireConstraints.count == tireFields.count,
              Set(tireConstraints.map(\.field)) == tireFields,
              let tireCompound = snapshot.tireCompound else { return false }
        let tireEvidenceIDs = tireCompound.evidenceIDs.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard !tireEvidenceIDs.isEmpty,
              !tireEvidenceIDs.contains(where: \.isEmpty),
              Set(tireEvidenceIDs).count == tireEvidenceIDs.count else { return false }
        let acceptedEvidence = snapshot.evidenceSources.filter { evidence in
            tireEvidenceIDs.contains(evidence.id.trimmingCharacters(in: .whitespacesAndNewlines))
                && evidence.source == TirePressureCapture.provenanceSource
                && evidence.version == TirePressureCapture.provenanceVersion
                && evidence.game == snapshot.car.game
                && evidence.gameBuildVersion == build
                && evidence.scope == .exactVehicleBuild
                && evidence.usagePermission == .permitted
                && evidence.confidence != .low
        }
        guard Set(acceptedEvidence.map { $0.id.trimmingCharacters(in: .whitespacesAndNewlines) })
                == Set(tireEvidenceIDs) else { return false }
        return tireConstraints.allSatisfy { constraint in
            constraint.scope == .exactVehicleBuild
                && constraint.verification == .productionEligible
                && Set(constraint.evidenceIDs.map {
                    $0.trimmingCharacters(in: .whitespacesAndNewlines)
                }) == Set(tireEvidenceIDs)
        }
    }

    private func matchesCurrentPublicRuleset(
        _ ruleset: TuneRulesetReference,
        snapshot: VehicleBuildSnapshot
    ) -> Bool {
        guard ruleset.game == .fh6,
              snapshot.car.game == .fh6,
              ruleset.id == FH6LocalTirePressureRuleset.id,
              ruleset.schemaVersion == FH6LocalTirePressureRuleset.schemaVersion,
              ruleset.algorithmVersion == FH6LocalTirePressureRuleset.algorithmVersion,
              ruleset.knowledgeRevision == FH6LocalTirePressureRuleset.knowledgeRevision,
              ruleset.validationStatus == .experimental,
              let tire = snapshot.tireCompound else { return false }
        let tireIDs = tire.evidenceIDs
        return !tireIDs.isEmpty
            && tireIDs.allSatisfy {
                !$0.isEmpty && $0 == $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            && Set(tireIDs).count == tireIDs.count
            && ruleset.provenanceIDs == tireIDs.sorted()
    }

    private func validAppliedFields(
        in tune: TuneResult,
        report: TuneProjectionReport
    ) -> [FirstPartyValidationRecord.AppliedField]? {
        let lines = tune.sections.flatMap(\.lines)
        guard lines.count == report.readyCount else { return nil }
        var seen = Set<TuneFieldID>()
        var result: [FirstPartyValidationRecord.AppliedField] = []
        for line in lines {
            guard let field = line.fieldID,
                  report.readyFieldIDs.contains(field), seen.insert(field).inserted,
                  line.unit == field.expectedDisplayUnit,
                  let value = LocalizedNumberText.parse(line.value, locale: locale),
                  value.isFinite else { return nil }
            result.append(.init(field: field, value: value, unit: field.expectedUnit))
        }
        guard Set(result.map(\.field)) == report.readyFieldIDs else { return nil }
        return result.sorted { $0.field.stableID < $1.field.stableID }
    }

    private func hasSafeExportStrings(
        snapshot: VehicleBuildSnapshot,
        ruleset: TuneRulesetReference
    ) -> Bool {
        guard let build = snapshot.gameBuild.version,
              let catalog = snapshot.car.catalogReference,
              let tire = snapshot.tireCompound else { return false }
        return canonicalPublicString(build, maximumLength: 120) != nil
            && canonicalPublicString(catalog.entryID, maximumLength: 160) != nil
            && canonicalPublicString(snapshot.car.make, maximumLength: 120) != nil
            && canonicalPublicString(snapshot.car.model, maximumLength: 120) != nil
            && canonicalPublicString(tire.id, maximumLength: 160) != nil
            && canonicalPublicString(tire.displayName, maximumLength: 120) != nil
            && canonicalPublicString(ruleset.id, maximumLength: 160) != nil
            && canonicalPublicString(ruleset.algorithmVersion, maximumLength: 120) != nil
            && canonicalPublicString(ruleset.knowledgeRevision, maximumLength: 160) != nil
    }

    private func canonicalPublicString(_ value: String, maximumLength: Int) -> String? {
        let forbiddenFormatScalars = CharacterSet(charactersIn:
            "\u{061C}\u{200B}\u{200C}\u{200D}\u{200E}\u{200F}\u{202A}\u{202B}\u{202C}\u{202D}\u{202E}\u{2060}\u{2061}\u{2062}\u{2063}\u{2064}\u{2066}\u{2067}\u{2068}\u{2069}\u{FEFF}"
        )
        let forbidden = CharacterSet.controlCharacters
            .union(.illegalCharacters)
            .union(.newlines)
            .union(forbiddenFormatScalars)
        guard !value.unicodeScalars.contains(where: {
            forbidden.contains($0) || $0.properties.generalCategory == .format
        }) else { return nil }
        let canonical = value.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        guard (1...maximumLength).contains(canonical.count) else { return nil }
        return canonical
    }

    private func hash<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        let digest = SHA256.hash(data: try encoder.encode(value))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private struct RevisionPayload: Codable {
        var game: ForzaGame
        var gameBuildVersion: String
        var buildCapturedAt: Date
        var vehicle: FirstPartyValidationRecord.Vehicle
        var shopAvailabilityFingerprint: String
        var discipline: DrivingDiscipline
        var tuneID: UUID
        var tuneGeneratedAt: Date
        var ruleset: FirstPartyValidationRecord.Ruleset
        var appliedFields: [FirstPartyValidationRecord.AppliedField]
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
}
