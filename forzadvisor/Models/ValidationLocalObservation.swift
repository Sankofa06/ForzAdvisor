import Foundation

/// Factual local evidence only. Authorization, consent, authorship, attestations,
/// permission receipts, and export JSON are intentionally absent.
struct ValidationLocalObservation: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1
    static let reusableFieldLabels = [
        "Game and exact build version",
        "Vehicle specification and observed shop availability",
        "Discipline and generated settings",
        "Course type, surface, input, and run count",
        "Outcome verdict and selected symptoms",
        "Ruleset and observation fingerprints",
        "Capture time and declared unknowns"
    ]

    let schemaVersion: Int
    let capturedAt: Date
    let game: ForzaGame
    let gameBuildVersion: String
    let buildCapturedAt: Date
    let vehicle: FirstPartyValidationRecord.Vehicle
    let shopParts: [FirstPartyValidationRecord.ShopPart]
    let shopAvailabilityFingerprint: String
    let discipline: DrivingDiscipline
    let tuneID: UUID
    let tuneGeneratedAt: Date
    let tuneRevisionFingerprint: String
    let ruleset: FirstPartyValidationRecord.Ruleset
    let appliedFields: [FirstPartyValidationRecord.AppliedField]
    let session: FirstPartyValidationRecord.Session
    let outcome: FirstPartyValidationRecord.Outcome
    let unknowns: [String]
    let privacyExclusions: [String]
    let observationFingerprint: String

    init(record: FirstPartyValidationRecord) throws {
        guard FirstPartyValidationRecordFactory()
            .isValidLocalObservation(record) else {
            throw FirstPartyValidationError.invalidStoredRecord
        }
        schemaVersion = Self.currentSchemaVersion
        capturedAt = record.createdAt
        game = record.game
        gameBuildVersion = record.gameBuildVersion
        buildCapturedAt = record.buildCapturedAt
        vehicle = record.vehicle
        shopParts = record.shopParts
        shopAvailabilityFingerprint = record.shopAvailabilityFingerprint
        discipline = record.discipline
        tuneID = record.tuneID
        tuneGeneratedAt = record.tuneGeneratedAt
        tuneRevisionFingerprint = record.tuneRevisionFingerprint
        ruleset = record.ruleset
        appliedFields = record.appliedFields
        session = record.session
        outcome = record.outcome
        unknowns = record.unknowns
        privacyExclusions = record.privacyExclusions
        observationFingerprint = record.contentFingerprint
    }

    func reusableRecord(
        authorization: ValidationEvidenceAuthorizationEnvelope,
        recordID: UUID = UUID(),
        submissionID: UUID = UUID()
    ) throws -> FirstPartyValidationRecord {
        guard schemaVersion == Self.currentSchemaVersion,
              authorization.allowsReuse(of: observationFingerprint),
              let receiptID = authorization.authorizationID else {
            throw ValidationEvidenceExportError.invalidAuthorization
        }
        let record = FirstPartyValidationRecord(
            schemaVersion: FirstPartyValidationRecord.currentSchemaVersion,
            recordID: recordID,
            submissionID: submissionID,
            createdAt: capturedAt,
            consentVersion: FirstPartyValidationRecord.currentConsentVersion,
            permissionReceiptID: receiptID,
            game: game,
            gameBuildVersion: gameBuildVersion,
            buildCapturedAt: buildCapturedAt,
            vehicle: vehicle,
            shopParts: shopParts,
            shopAvailabilityFingerprint: shopAvailabilityFingerprint,
            discipline: discipline,
            tuneID: tuneID,
            tuneGeneratedAt: tuneGeneratedAt,
            tuneRevisionFingerprint: tuneRevisionFingerprint,
            ruleset: ruleset,
            appliedFields: appliedFields,
            session: session,
            outcome: outcome,
            exactSetupConfirmed: true,
            allExportedSettingsApplied: true,
            firstPartyAuthorshipConfirmed: true,
            deidentifiedReusePermitted: true,
            unknowns: unknowns,
            privacyExclusions: privacyExclusions,
            contentFingerprint: observationFingerprint
        )
        guard FirstPartyValidationRecordFactory().isValid(record) else {
            throw FirstPartyValidationError.invalidStoredRecord
        }
        return record
    }
}
