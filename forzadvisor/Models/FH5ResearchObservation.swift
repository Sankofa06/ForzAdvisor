//
//  FH5ResearchObservation.swift
//  forzadvisor
//
//  Permission-aware, first-party observations of the untouched FH5 tuning
//  menu. These records are evidence, never generated tunes or public rulesets.
//

import CryptoKit
import Foundation

enum FH5Platform: String, CaseIterable, Codable, Identifiable, Sendable {
    case xboxOne
    case xboxSeries
    case microsoftStorePC
    case steamPC
    case playStation5

    var id: String { rawValue }

    var title: String {
        switch self {
        case .xboxOne: "Xbox One"
        case .xboxSeries: "Xbox Series X|S"
        case .microsoftStorePC: "Microsoft Store PC"
        case .steamPC: "Steam PC"
        case .playStation5: "PlayStation 5"
        }
    }
}

enum FH5TuneFieldAvailability: String, CaseIterable, Codable, Identifiable, Sendable {
    case adjustable
    case shownLocked
    case notShown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .adjustable: "Adjustable"
        case .shownLocked: "Shown locked"
        case .notShown: "Not shown"
        }
    }
}

struct FH5TuneFieldObservation: Codable, Equatable, Sendable {
    let field: TuneFieldID
    let availability: FH5TuneFieldAvailability
    let minimum: Double?
    let maximum: Double?
    let step: Double?
    let current: Double?
    let unit: TuneUnit?

    init(
        field: TuneFieldID,
        availability: FH5TuneFieldAvailability,
        minimum: Double? = nil,
        maximum: Double? = nil,
        step: Double? = nil,
        current: Double? = nil,
        unit: TuneUnit? = nil
    ) {
        self.field = field
        self.availability = availability
        self.minimum = minimum
        self.maximum = maximum
        self.step = step
        self.current = current
        self.unit = unit
    }
}

struct FH5ResearchCapture: Equatable, Sendable {
    let platform: FH5Platform
    let gameVersion: String
    let tireCompoundDisplayName: String
    let forwardGearCount: Int
    let controls: [FH5TuneFieldObservation]
    let exactUntouchedStockConfirmed: Bool
    let allSlidersRestoredConfirmed: Bool
    let personallyReadFromGameConfirmed: Bool
    let firstPartyAuthorshipConfirmed: Bool
    let localStoragePermitted: Bool
    let deidentifiedStructuredReusePermitted: Bool

    init(
        platform: FH5Platform,
        gameVersion: String,
        tireCompoundDisplayName: String,
        forwardGearCount: Int,
        controls: [FH5TuneFieldObservation],
        exactUntouchedStockConfirmed: Bool,
        allSlidersRestoredConfirmed: Bool,
        personallyReadFromGameConfirmed: Bool,
        firstPartyAuthorshipConfirmed: Bool,
        localStoragePermitted: Bool,
        deidentifiedStructuredReusePermitted: Bool = false
    ) {
        self.platform = platform
        self.gameVersion = gameVersion
        self.tireCompoundDisplayName = tireCompoundDisplayName
        self.forwardGearCount = forwardGearCount
        self.controls = controls
        self.exactUntouchedStockConfirmed = exactUntouchedStockConfirmed
        self.allSlidersRestoredConfirmed = allSlidersRestoredConfirmed
        self.personallyReadFromGameConfirmed = personallyReadFromGameConfirmed
        self.firstPartyAuthorshipConfirmed = firstPartyAuthorshipConfirmed
        self.localStoragePermitted = localStoragePermitted
        self.deidentifiedStructuredReusePermitted = deidentifiedStructuredReusePermitted
    }
}

enum FH5ResearchIssue: Error, LocalizedError, Equatable {
    case notSaved
    case streaming
    case notFH5Plan
    case numericOrProviderPayload
    case missingProjection
    case invalidProjection
    case invalidCapabilitySnapshot
    case missingCatalogIdentity
    case modifiedCatalogIdentity
    case staleSavedRevision
    case missingGameVersion
    case invalidGameVersion
    case mismatchedGameVersion(expected: String, entered: String)
    case missingTireCompound
    case invalidTireCompound
    case invalidGearCount
    case missingField(TuneFieldID)
    case duplicateField(TuneFieldID)
    case unexpectedField(TuneFieldID)
    case forbiddenNumericPayload(TuneFieldID)
    case missingAdjustablePayload(TuneFieldID)
    case nonFiniteValue(TuneFieldID)
    case invalidRange(TuneFieldID)
    case invalidStep(TuneFieldID)
    case currentOutOfRange(TuneFieldID)
    case valueOffLattice(TuneFieldID)
    case wrongUnit(TuneFieldID)
    case stockNotConfirmed
    case slidersNotRestored
    case valuesNotPersonallyRead
    case authorshipNotConfirmed
    case localStorageNotPermitted
    case invalidGeneratedSnapshot
    case invalidStoredRecord
    case reuseNotPermitted

    var errorDescription: String? {
        switch self {
        case .notSaved: "Save this FH5 build plan before opening Research Lab."
        case .streaming: "Wait for the plan to finish before recording an observation."
        case .notFH5Plan: "Research Lab accepts saved FH5 catalog plans only."
        case .numericOrProviderPayload:
            "This result contains tune, provider, or ruleset data and cannot be used for FH5 research."
        case .missingProjection: "This plan does not contain current capability coverage metadata."
        case .invalidProjection: "This plan's capability coverage no longer matches its catalog snapshot."
        case .invalidCapabilitySnapshot: "Use an unmodified capability-only catalog plan."
        case .missingCatalogIdentity: "Choose and save an FH5 car from the catalog first."
        case .modifiedCatalogIdentity: "Restore the original catalog values before recording stock evidence."
        case .staleSavedRevision: "Reopen the latest saved plan before recording evidence."
        case .missingGameVersion: "Enter the exact FH5 game version shown on this platform."
        case .invalidGameVersion: "The FH5 game version contains unsupported characters."
        case .mismatchedGameVersion(let expected, let entered):
            "This plan's verified Upgrade Lab observation uses game version \(expected), not \(entered)."
        case .missingTireCompound: "Enter the tire-compound name exactly as FH5 displays it."
        case .invalidTireCompound: "The tire-compound name contains unsupported characters."
        case .invalidGearCount: "Forward gear count must be a whole number from 1 through 10."
        case .missingField(let field): "Record one decision for \(field.projectionLabel)."
        case .duplicateField(let field): "\(field.projectionLabel) was recorded more than once."
        case .unexpectedField(let field):
            "\(field.projectionLabel) is not expected for this drivetrain and gear count."
        case .forbiddenNumericPayload(let field):
            "\(field.projectionLabel) includes values that are not allowed for its availability."
        case .missingAdjustablePayload(let field):
            "Enter minimum, maximum, step, and current for \(field.projectionLabel)."
        case .nonFiniteValue(let field): "\(field.projectionLabel) contains an invalid number."
        case .invalidRange(let field):
            "\(field.projectionLabel) minimum must be lower than its maximum."
        case .invalidStep(let field): "\(field.projectionLabel) step must be greater than zero."
        case .currentOutOfRange(let field):
            "\(field.projectionLabel) current value must be inside its observed range."
        case .valueOffLattice(let field):
            "\(field.projectionLabel) maximum and current must land on the observed slider step."
        case .wrongUnit(let field):
            "\(field.projectionLabel) must use the English-unit field shown by Research Lab."
        case .stockNotConfirmed: "Confirm that this is the exact untouched stock catalog car."
        case .slidersNotRestored:
            "Return every moved slider to its original current value before saving."
        case .valuesNotPersonallyRead:
            "Confirm that you personally read these values in FH5, not from a tune, video, post, or share code."
        case .authorshipNotConfirmed: "Confirm that this is your own first-party observation."
        case .localStorageNotPermitted:
            "Allow ForzAdvisor to keep this observation locally with the saved plan."
        case .invalidGeneratedSnapshot:
            "The observation could not create a safe detached validation snapshot."
        case .invalidStoredRecord: "This stored FH5 observation failed its integrity checks."
        case .reuseNotPermitted:
            "Enable deidentified structured reuse for this record before sharing its JSON."
        }
    }
}

struct FH5ResearchEligibility {
    func snapshot(
        for tune: TuneResult,
        savedTune: TuneResult?,
        isStreaming: Bool
    ) -> Result<VehicleBuildSnapshot, FH5ResearchIssue> {
        guard let savedTune else { return .failure(.notSaved) }
        guard !isStreaming else { return .failure(.streaming) }
        guard tune.request.car.game == .fh5,
              tune.purpose == .fh5BuildPlan,
              savedTune.request.car.game == .fh5,
              savedTune.purpose == .fh5BuildPlan else {
            return .failure(.notFH5Plan)
        }
        guard tune.sections.isEmpty,
              tune.providerInfo == nil,
              tune.rulesetReference == nil,
              savedTune.sections.isEmpty,
              savedTune.providerInfo == nil,
              savedTune.rulesetReference == nil else {
            return .failure(.numericOrProviderPayload)
        }
        guard let report = tune.projectionReport,
              savedTune.projectionReport != nil else {
            return .failure(.missingProjection)
        }
        guard let snapshot = tune.request.buildSnapshot,
              snapshot.kind == .capabilityOnly,
              snapshot.isValid,
              snapshot.matches(car: tune.request.car),
              snapshot.constraints.isEmpty,
              snapshot.tireCompound == nil,
              snapshot.gearCount == nil,
              !snapshot.capabilityProfile.parts.contains(where: { $0.availability == .installed })
        else {
            return .failure(.invalidCapabilitySnapshot)
        }
        guard tune.request.car.catalogReference != nil else {
            return .failure(.missingCatalogIdentity)
        }
        guard !tune.request.car.catalogValuesModified else {
            return .failure(.modifiedCatalogIdentity)
        }
        guard report.schemaVersion == TuneProjectionReport.currentSchemaVersion,
              report.snapshotID == snapshot.id,
              report.contextStatus == .capabilityOnly,
              report.readyCount == 0 else {
            return .failure(.invalidProjection)
        }
        guard savedTune.id == tune.id,
              savedTune.generatedAt == tune.generatedAt,
              savedTune == tune else {
            return .failure(.staleSavedRevision)
        }
        return .success(snapshot)
    }
}

struct FH5ResearchObservationRecord: Codable, Equatable, Identifiable, Sendable {
    static let currentSchemaVersion = 1
    static let currentConsentVersion = "fh5-first-party-stock-observation-v1"
    static let unknowns = [
        "display-rounding:not-characterized",
        "game-internal-physics:not-observed",
        "slider-input-acceleration:not-collected"
    ]
    static let privacyExclusions = [
        "analytics",
        "catalog-source-urls",
        "device-identifiers",
        "discipline",
        "garage-notes",
        "generated-tune-values",
        "history",
        "location",
        "ocr",
        "provider-and-ruleset",
        "raw-screenshots",
        "saved-tune-and-tune-identifiers",
        "share-destination",
        "thumbnails",
        "upgrade-lab-part-availability"
    ]

    struct Vehicle: Codable, Equatable, Sendable {
        let catalogID: String
        let catalogRevision: String
        let catalogReviewedAt: Date
        let catalogVerificationStatus: CatalogVerificationStatus
        let year: Int
        let make: String
        let model: String
        let performanceClass: PerformanceClass
        let performanceIndex: Int
        let drivetrain: Drivetrain
        let weightPounds: Int
        let frontWeightPercent: Double
        let peakHorsepower: Int
        let peakTorqueFootPounds: Int
        let stock: Bool
    }

    struct Attestations: Codable, Equatable, Sendable {
        let exactUntouchedStock: Bool
        let allSlidersRestored: Bool
        let personallyReadFromGame: Bool
        let firstPartyAuthorship: Bool
        let localStoragePermitted: Bool
        let deidentifiedStructuredReusePermitted: Bool
    }

    struct UpgradePart: Codable, Equatable, Sendable {
        let partID: TunePartID
        let availability: TunePartAvailability
    }

    var id: UUID { recordID }
    let schemaVersion: Int
    let consentVersion: String
    let recordID: UUID
    let submissionID: UUID
    let permissionReceiptID: UUID
    let capturedAt: Date
    let game: ForzaGame
    let platform: FH5Platform
    let gameVersion: String
    let unitScope: String
    let vehicle: Vehicle
    let upgradeParts: [UpgradePart]
    let tireCompoundDisplayName: String
    let forwardGearCount: Int
    let controls: [FH5TuneFieldObservation]
    let attestations: Attestations
    let unknowns: [String]
    let privacyExclusions: [String]
    let contentFingerprint: String
    let planRevisionFingerprint: String
    let internalValidationSnapshot: VehicleBuildSnapshot

    var canExport: Bool {
        attestations.deidentifiedStructuredReusePermitted
            && FH5ResearchObservationFactory().isValid(self)
    }

    func deterministicJSON() throws -> Data {
        guard FH5ResearchObservationFactory().isValid(self) else {
            throw FH5ResearchIssue.invalidStoredRecord
        }
        guard attestations.deidentifiedStructuredReusePermitted else {
            throw FH5ResearchIssue.reuseNotPermitted
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(publicExport())
    }

    var deterministicJSONString: String? {
        guard let data = try? deterministicJSON() else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func publicExport() throws -> FH5ResearchObservationExport {
        let factory = FH5ResearchObservationFactory()
        guard factory.isValid(self) else {
            throw FH5ResearchIssue.invalidStoredRecord
        }
        guard attestations.deidentifiedStructuredReusePermitted else {
            throw FH5ResearchIssue.reuseNotPermitted
        }
        return FH5ResearchObservationExport(
            schemaVersion: schemaVersion,
            consentVersion: consentVersion,
            submissionID: submissionID,
            permissionReceiptID: permissionReceiptID,
            capturedAt: capturedAt,
            game: game,
            platform: platform,
            gameVersion: gameVersion,
            unitScope: unitScope,
            vehicle: vehicle,
            tireCompoundDisplayName: tireCompoundDisplayName,
            forwardGearCount: forwardGearCount,
            controls: controls,
            attestations: attestations,
            unknowns: unknowns,
            privacyExclusions: privacyExclusions,
            contentFingerprint: try factory.publicSemanticFingerprint(for: self)
        )
    }
}

/// Explicit public JSON allow-list. Local linkage and the validation snapshot are absent.
struct FH5ResearchObservationExport: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let consentVersion: String
    let submissionID: UUID
    let permissionReceiptID: UUID
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
    let contentFingerprint: String
}

struct FH5ResearchObservationFactory {
    static let provenanceSource = "forzadvisor.local.first-party-fh5-observation"
    static let provenanceVersion = "fh5-research-v1"
    static let unitScope = "English units (TuneUnit v1)"

    func make(
        tune: TuneResult,
        savedTune: TuneResult?,
        isStreaming: Bool,
        capture: FH5ResearchCapture,
        recordID: UUID = UUID(),
        submissionID: UUID = UUID(),
        permissionReceiptID: UUID = UUID(),
        capturedAt: Date = .now,
        snapshotID: UUID = UUID()
    ) throws -> FH5ResearchObservationRecord {
        let base = try FH5ResearchEligibility().snapshot(
            for: tune,
            savedTune: savedTune,
            isStreaming: isStreaming
        ).get()
        let requiredGameVersion = verifiedUpgradeGameVersion(in: base)
        let validation = validationIssues(
            capture: capture,
            drivetrain: base.car.drivetrain,
            requiredGameVersion: requiredGameVersion
        )
        guard validation.isEmpty else { throw validation[0] }
        guard let reference = base.car.catalogReference,
              let year = base.car.year,
              let horsepower = base.car.peakHorsepower,
              let torque = base.car.peakTorqueFootPounds,
              let build = canonicalString(capture.gameVersion, maximumLength: 120),
              let compound = canonicalString(capture.tireCompoundDisplayName, maximumLength: 120),
              let catalogID = canonicalString(reference.entryID, maximumLength: 160),
              let catalogRevision = canonicalString(reference.revision, maximumLength: 160),
              let make = canonicalString(base.car.make, maximumLength: 120),
              let model = canonicalString(base.car.model, maximumLength: 160) else {
            throw FH5ResearchIssue.invalidStoredRecord
        }

        let controls = canonicalControls(
            capture.controls,
            drivetrain: base.car.drivetrain,
            gearCount: capture.forwardGearCount
        )
        let vehicle = FH5ResearchObservationRecord.Vehicle(
            catalogID: catalogID,
            catalogRevision: catalogRevision,
            catalogReviewedAt: reference.reviewedAt,
            catalogVerificationStatus: reference.verificationStatus,
            year: year,
            make: make,
            model: model,
            performanceClass: base.car.performanceClass,
            performanceIndex: base.car.performanceIndex,
            drivetrain: base.car.drivetrain,
            weightPounds: base.car.weightPounds,
            frontWeightPercent: base.car.frontWeightPercent,
            peakHorsepower: horsepower,
            peakTorqueFootPounds: torque,
            stock: true
        )
        let upgradeParts = verifiedUpgradeParts(in: base) ?? []
        let attestations = FH5ResearchObservationRecord.Attestations(
            exactUntouchedStock: true,
            allSlidersRestored: true,
            personallyReadFromGame: true,
            firstPartyAuthorship: true,
            localStoragePermitted: true,
            deidentifiedStructuredReusePermitted: capture.deidentifiedStructuredReusePermitted
        )
        let validationSnapshot = try detachedSnapshot(
            from: base,
            build: build,
            tireCompound: compound,
            gearCount: capture.forwardGearCount,
            controls: controls,
            vehicle: vehicle,
            upgradeParts: upgradeParts,
            capturedAt: capturedAt,
            snapshotID: snapshotID
        )
        guard let planRevisionFingerprint = planRevisionFingerprint(for: tune) else {
            throw FH5ResearchIssue.invalidStoredRecord
        }
        let fingerprint = try hash(ContentPayload(
            schemaVersion: FH5ResearchObservationRecord.currentSchemaVersion,
            consentVersion: FH5ResearchObservationRecord.currentConsentVersion,
            capturedAt: capturedAt,
            game: .fh5,
            platform: capture.platform,
            gameVersion: build,
            unitScope: Self.unitScope,
            vehicle: vehicle,
            upgradeParts: upgradeParts,
            tireCompoundDisplayName: compound,
            forwardGearCount: capture.forwardGearCount,
            controls: controls,
            attestations: attestations,
            unknowns: FH5ResearchObservationRecord.unknowns,
            privacyExclusions: FH5ResearchObservationRecord.privacyExclusions
        ))
        let record = FH5ResearchObservationRecord(
            schemaVersion: FH5ResearchObservationRecord.currentSchemaVersion,
            consentVersion: FH5ResearchObservationRecord.currentConsentVersion,
            recordID: recordID,
            submissionID: submissionID,
            permissionReceiptID: permissionReceiptID,
            capturedAt: capturedAt,
            game: .fh5,
            platform: capture.platform,
            gameVersion: build,
            unitScope: Self.unitScope,
            vehicle: vehicle,
            upgradeParts: upgradeParts,
            tireCompoundDisplayName: compound,
            forwardGearCount: capture.forwardGearCount,
            controls: controls,
            attestations: attestations,
            unknowns: FH5ResearchObservationRecord.unknowns,
            privacyExclusions: FH5ResearchObservationRecord.privacyExclusions,
            contentFingerprint: fingerprint,
            planRevisionFingerprint: planRevisionFingerprint,
            internalValidationSnapshot: validationSnapshot
        )
        guard isValid(record) else { throw FH5ResearchIssue.invalidStoredRecord }
        return record
    }

    func validationIssues(
        capture: FH5ResearchCapture,
        drivetrain: Drivetrain,
        requiredGameVersion: String? = nil
    ) -> [FH5ResearchIssue] {
        var issues: [FH5ResearchIssue] = []
        let build = capture.gameVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        if build.isEmpty {
            issues.append(.missingGameVersion)
        } else if canonicalString(capture.gameVersion, maximumLength: 120) == nil {
            issues.append(.invalidGameVersion)
        } else if let requiredGameVersion,
                  build != requiredGameVersion {
            issues.append(.mismatchedGameVersion(
                expected: requiredGameVersion,
                entered: build
            ))
        }
        let compound = capture.tireCompoundDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if compound.isEmpty {
            issues.append(.missingTireCompound)
        } else if canonicalString(capture.tireCompoundDisplayName, maximumLength: 120) == nil {
            issues.append(.invalidTireCompound)
        }
        guard (1...10).contains(capture.forwardGearCount) else {
            issues.append(.invalidGearCount)
            return issues + attestationIssues(capture)
        }

        let expected = TuneFieldID.expectedFields(
            drivetrain: drivetrain,
            gearCount: capture.forwardGearCount
        )
        let expectedSet = Set(expected)
        let groups = Dictionary(grouping: capture.controls, by: \.field)
        for field in expected {
            switch groups[field]?.count ?? 0 {
            case 0: issues.append(.missingField(field))
            case 1:
                if let observation = groups[field]?.first {
                    issues.append(contentsOf: payloadIssues(observation))
                }
            default: issues.append(.duplicateField(field))
            }
        }
        for field in groups.keys where !expectedSet.contains(field) {
            issues.append(.unexpectedField(field))
        }
        return issues + attestationIssues(capture)
    }

    func isValid(_ record: FH5ResearchObservationRecord) -> Bool {
        guard record.schemaVersion == FH5ResearchObservationRecord.currentSchemaVersion,
              record.consentVersion == FH5ResearchObservationRecord.currentConsentVersion,
              record.game == .fh5,
              record.unitScope == Self.unitScope,
              record.vehicle.stock,
              record.attestations.exactUntouchedStock,
              record.attestations.allSlidersRestored,
              record.attestations.personallyReadFromGame,
              record.attestations.firstPartyAuthorship,
              record.attestations.localStoragePermitted,
              record.unknowns == FH5ResearchObservationRecord.unknowns,
              record.privacyExclusions == FH5ResearchObservationRecord.privacyExclusions,
              canonicalString(record.gameVersion, maximumLength: 120) == record.gameVersion,
              canonicalString(record.tireCompoundDisplayName, maximumLength: 120)
                == record.tireCompoundDisplayName,
              canonicalString(record.vehicle.catalogID, maximumLength: 160)
                == record.vehicle.catalogID,
              canonicalString(record.vehicle.catalogRevision, maximumLength: 160)
                == record.vehicle.catalogRevision,
              canonicalString(record.vehicle.make, maximumLength: 120) == record.vehicle.make,
              canonicalString(record.vehicle.model, maximumLength: 160) == record.vehicle.model,
              record.vehicle.year > 0,
              record.vehicle.peakHorsepower > 0,
              record.vehicle.peakTorqueFootPounds > 0,
              isCanonicalUpgradeParts(record.upgradeParts),
              isSHA256Fingerprint(record.planRevisionFingerprint),
              (1...10).contains(record.forwardGearCount),
              record.controls == canonicalControls(
                record.controls,
                drivetrain: record.vehicle.drivetrain,
                gearCount: record.forwardGearCount
              ),
              validationIssues(
                capture: validationCapture(from: record),
                drivetrain: record.vehicle.drivetrain
              ).isEmpty,
              validDetachedSnapshot(record.internalValidationSnapshot, for: record)
        else {
            return false
        }
        let payload = ContentPayload(
            schemaVersion: record.schemaVersion,
            consentVersion: record.consentVersion,
            capturedAt: record.capturedAt,
            game: record.game,
            platform: record.platform,
            gameVersion: record.gameVersion,
            unitScope: record.unitScope,
            vehicle: record.vehicle,
            upgradeParts: record.upgradeParts,
            tireCompoundDisplayName: record.tireCompoundDisplayName,
            forwardGearCount: record.forwardGearCount,
            controls: record.controls,
            attestations: record.attestations,
            unknowns: record.unknowns,
            privacyExclusions: record.privacyExclusions
        )
        return (try? hash(payload)) == record.contentFingerprint
    }

    func verifiedUpgradeGameVersion(in snapshot: VehicleBuildSnapshot) -> String? {
        guard verifiedUpgradeParts(in: snapshot) != nil else { return nil }
        return canonicalString(snapshot.gameBuild.version ?? "", maximumLength: 120)
    }

    func planRevisionFingerprint(for tune: TuneResult) -> String? {
        guard tune.request.car.game == .fh5,
              tune.purpose == .fh5BuildPlan,
              tune.sections.isEmpty,
              tune.providerInfo == nil,
              tune.rulesetReference == nil,
              tune.request.car.catalogReference != nil,
              !tune.request.car.catalogValuesModified,
              tune.request.buildSnapshot?.isValid == true else {
            return nil
        }
        return try? hash(tune)
    }

    func publicSemanticFingerprint(
        for record: FH5ResearchObservationRecord
    ) throws -> String {
        try publicSemanticFingerprint(
            schemaVersion: record.schemaVersion,
            consentVersion: record.consentVersion,
            submissionID: record.submissionID,
            permissionReceiptID: record.permissionReceiptID,
            capturedAt: record.capturedAt,
            game: record.game,
            platform: record.platform,
            gameVersion: record.gameVersion,
            unitScope: record.unitScope,
            vehicle: record.vehicle,
            tireCompoundDisplayName: record.tireCompoundDisplayName,
            forwardGearCount: record.forwardGearCount,
            controls: record.controls,
            attestations: record.attestations,
            unknowns: record.unknowns,
            privacyExclusions: record.privacyExclusions
        )
    }

    func publicSemanticFingerprint(
        for export: FH5ResearchObservationExport
    ) throws -> String {
        try publicSemanticFingerprint(
            schemaVersion: export.schemaVersion,
            consentVersion: export.consentVersion,
            submissionID: export.submissionID,
            permissionReceiptID: export.permissionReceiptID,
            capturedAt: export.capturedAt,
            game: export.game,
            platform: export.platform,
            gameVersion: export.gameVersion,
            unitScope: export.unitScope,
            vehicle: export.vehicle,
            tireCompoundDisplayName: export.tireCompoundDisplayName,
            forwardGearCount: export.forwardGearCount,
            controls: export.controls,
            attestations: export.attestations,
            unknowns: export.unknowns,
            privacyExclusions: export.privacyExclusions
        )
    }

    private func publicSemanticFingerprint(
        schemaVersion: Int,
        consentVersion: String,
        submissionID: UUID,
        permissionReceiptID: UUID,
        capturedAt: Date,
        game: ForzaGame,
        platform: FH5Platform,
        gameVersion: String,
        unitScope: String,
        vehicle: FH5ResearchObservationRecord.Vehicle,
        tireCompoundDisplayName: String,
        forwardGearCount: Int,
        controls: [FH5TuneFieldObservation],
        attestations: FH5ResearchObservationRecord.Attestations,
        unknowns: [String],
        privacyExclusions: [String]
    ) throws -> String {
        try hash(PublicSemanticPayload(
            schemaVersion: schemaVersion,
            consentVersion: consentVersion,
            submissionID: submissionID,
            permissionReceiptID: permissionReceiptID,
            capturedAt: capturedAt,
            game: game,
            platform: platform,
            gameVersion: gameVersion,
            unitScope: unitScope,
            vehicle: vehicle,
            tireCompoundDisplayName: tireCompoundDisplayName,
            forwardGearCount: forwardGearCount,
            controls: controls,
            attestations: attestations,
            unknowns: unknowns,
            privacyExclusions: privacyExclusions
        ))
    }

    func matches(_ record: FH5ResearchObservationRecord, tune: TuneResult) -> Bool {
        guard isValid(record),
              record.game == .fh5,
              planRevisionFingerprint(for: tune) == record.planRevisionFingerprint,
              let reference = tune.request.car.catalogReference,
              !tune.request.car.catalogValuesModified else {
            return false
        }
        let car = tune.request.car
        return car.game == .fh5
            && reference.entryID == record.vehicle.catalogID
            && reference.revision == record.vehicle.catalogRevision
            && reference.reviewedAt == record.vehicle.catalogReviewedAt
            && reference.verificationStatus == record.vehicle.catalogVerificationStatus
            && car.year == record.vehicle.year
            && canonicalString(car.make, maximumLength: 120) == record.vehicle.make
            && canonicalString(car.model, maximumLength: 160) == record.vehicle.model
            && car.performanceClass == record.vehicle.performanceClass
            && car.performanceIndex == record.vehicle.performanceIndex
            && car.drivetrain == record.vehicle.drivetrain
            && car.weightPounds == record.vehicle.weightPounds
            && car.frontWeightPercent == record.vehicle.frontWeightPercent
            && car.peakHorsepower == record.vehicle.peakHorsepower
            && car.peakTorqueFootPounds == record.vehicle.peakTorqueFootPounds
    }

    private func detachedSnapshot(
        from base: VehicleBuildSnapshot,
        build: String,
        tireCompound: String,
        gearCount: Int,
        controls: [FH5TuneFieldObservation],
        vehicle: FH5ResearchObservationRecord.Vehicle,
        upgradeParts: [FH5ResearchObservationRecord.UpgradePart],
        capturedAt: Date,
        snapshotID: UUID
    ) throws -> VehicleBuildSnapshot {
        let evidenceID = "fh5-research.\(snapshotID.uuidString.lowercased())"
        let provenance = TuneDataProvenance(
            id: evidenceID,
            game: .fh5,
            gameBuildVersion: build,
            scope: .exactVehicleBuild,
            source: Self.provenanceSource,
            version: Self.provenanceVersion,
            capturedAt: capturedAt,
            confidence: .medium,
            usagePermission: .permitted
        )
        let expected = TuneFieldID.expectedFields(
            drivetrain: base.car.drivetrain,
            gearCount: gearCount
        )
        let byField = Dictionary(uniqueKeysWithValues: controls.map { ($0.field, $0) })
        let constraints = expected.compactMap { field -> TuneFieldConstraint? in
            guard let item = byField[field],
                  item.availability == .adjustable,
                  let minimum = item.minimum,
                  let maximum = item.maximum,
                  let step = item.step,
                  let current = item.current,
                  let unit = item.unit else {
                return nil
            }
            return TuneFieldConstraint(
                field: field,
                minimum: minimum,
                maximum: maximum,
                step: step,
                defaultValue: nil,
                currentValue: current,
                unit: unit,
                scope: .exactVehicleBuild,
                verification: .provisional,
                evidenceIDs: [evidenceID]
            )
        }
        let groupedBySetting = Dictionary(grouping: expected, by: \.setting)
        let evidence = TuneEvidence(
            confidence: .medium,
            source: Self.provenanceSource,
            version: build,
            usagePermission: .permitted
        )
        let stockSettings = groupedBySetting.keys
            .filter { setting in
                let fields = groupedBySetting[setting] ?? []
                return !fields.isEmpty && fields.allSatisfy {
                    byField[$0]?.availability == .adjustable
                }
            }
            .sorted { $0.rawValue < $1.rawValue }
            .map { StockAdjustableSetting(setting: $0, evidence: evidence) }

        let car = detachedCar(for: vehicle)
        let profile = TuneVehicleCapabilityProfile(
            vehicle: TuneVehicleIdentity(
                game: .fh5,
                catalogID: vehicle.catalogID,
                year: vehicle.year,
                make: vehicle.make,
                model: vehicle.model
            ),
            drivetrain: vehicle.drivetrain,
            parts: upgradeParts.map {
                TuneVehiclePart(
                    partID: $0.partID,
                    availability: $0.availability,
                    evidence: upgradeEvidence(build: build)
                )
            },
            stockAdjustableSettings: stockSettings
        )

        let snapshot = VehicleBuildSnapshot(
            schemaVersion: VehicleBuildSnapshot.currentSchemaVersion,
            id: snapshotID,
            kind: .exactBuildObservation,
            capturedAt: capturedAt,
            gameBuild: GameBuildReference(game: .fh5, version: build, capturedAt: capturedAt),
            car: car,
            capabilityProfile: profile,
            tireCompound: TireCompoundReference(
                id: "fh5-stock-tire:\(tireCompound.lowercased())",
                displayName: tireCompound,
                evidenceIDs: [evidenceID]
            ),
            gearCount: gearCount,
            constraints: constraints,
            evidenceSources: [provenance]
        )
        guard snapshot.isValid,
              snapshot.constraints.allSatisfy({ $0.verification == .provisional }) else {
            throw FH5ResearchIssue.invalidGeneratedSnapshot
        }
        return snapshot
    }

    private func verifiedUpgradeParts(
        in snapshot: VehicleBuildSnapshot
    ) -> [FH5ResearchObservationRecord.UpgradePart]? {
        guard let build = canonicalString(
            snapshot.gameBuild.version ?? "",
            maximumLength: 120
        ) else {
            return nil
        }
        let parts = snapshot.capabilityProfile.parts
        let expected = Set(TunePartID.allCases)
        guard parts.count == expected.count,
              Set(parts.map(\.partID)) == expected,
              parts.allSatisfy({
                ($0.availability == .available || $0.availability == .unavailable)
                    && $0.evidence.source == UpgradePartCapture.provenanceSource
                    && normalized($0.evidence.version) == build
                    && $0.evidence.confidence == .medium
                    && $0.evidence.usagePermission == .permitted
              }) else {
            return nil
        }
        let byID = Dictionary(uniqueKeysWithValues: parts.map { ($0.partID, $0) })
        return TunePartID.allCases.map {
            FH5ResearchObservationRecord.UpgradePart(
                partID: $0,
                availability: byID[$0]!.availability
            )
        }
    }

    private func validDetachedSnapshot(
        _ snapshot: VehicleBuildSnapshot,
        for record: FH5ResearchObservationRecord
    ) -> Bool {
        let evidenceID = "fh5-research.\(snapshot.id.uuidString.lowercased())"
        let expected = TuneFieldID.expectedFields(
            drivetrain: record.vehicle.drivetrain,
            gearCount: record.forwardGearCount
        )
        let byField = Dictionary(uniqueKeysWithValues: record.controls.map { ($0.field, $0) })
        let expectedConstraints = expected.compactMap { field -> TuneFieldConstraint? in
            guard let item = byField[field],
                  item.availability == .adjustable,
                  let minimum = item.minimum,
                  let maximum = item.maximum,
                  let step = item.step,
                  let current = item.current,
                  let unit = item.unit else {
                return nil
            }
            return TuneFieldConstraint(
                field: field,
                minimum: minimum,
                maximum: maximum,
                step: step,
                defaultValue: nil,
                currentValue: current,
                unit: unit,
                scope: .exactVehicleBuild,
                verification: .provisional,
                evidenceIDs: [evidenceID]
            )
        }
        let expectedSettings = Dictionary(grouping: expected, by: \.setting).keys
            .filter { setting in
                let fields = Dictionary(grouping: expected, by: \.setting)[setting] ?? []
                return !fields.isEmpty && fields.allSatisfy {
                    byField[$0]?.availability == .adjustable
                }
            }
            .sorted { $0.rawValue < $1.rawValue }
            .map {
                StockAdjustableSetting(
                    setting: $0,
                    evidence: researchEvidence(build: record.gameVersion)
                )
            }
        let expectedParts = record.upgradeParts.map {
            TuneVehiclePart(
                partID: $0.partID,
                availability: $0.availability,
                evidence: upgradeEvidence(build: record.gameVersion)
            )
        }
        let expectedProvenance = TuneDataProvenance(
            id: evidenceID,
            game: .fh5,
            gameBuildVersion: record.gameVersion,
            scope: .exactVehicleBuild,
            source: Self.provenanceSource,
            version: Self.provenanceVersion,
            capturedAt: record.capturedAt,
            confidence: .medium,
            usagePermission: .permitted
        )
        let expectedTire = TireCompoundReference(
            id: "fh5-stock-tire:\(record.tireCompoundDisplayName.lowercased())",
            displayName: record.tireCompoundDisplayName,
            evidenceIDs: [evidenceID]
        )
        let expectedVehicle = TuneVehicleIdentity(
            game: .fh5,
            catalogID: record.vehicle.catalogID,
            year: record.vehicle.year,
            make: record.vehicle.make,
            model: record.vehicle.model
        )
        return snapshot.kind == .exactBuildObservation
            && snapshot.isValid
            && snapshot.schemaVersion == VehicleBuildSnapshot.currentSchemaVersion
            && snapshot.capturedAt == record.capturedAt
            && snapshot.gameBuild == GameBuildReference(
                game: .fh5,
                version: record.gameVersion,
                capturedAt: record.capturedAt
            )
            && snapshot.car == detachedCar(for: record.vehicle)
            && snapshot.capabilityProfile.vehicle == expectedVehicle
            && snapshot.capabilityProfile.drivetrain == record.vehicle.drivetrain
            && snapshot.capabilityProfile.parts == expectedParts
            && snapshot.capabilityProfile.stockAdjustableSettings == expectedSettings
            && snapshot.gearCount == record.forwardGearCount
            && snapshot.tireCompound == expectedTire
            && snapshot.constraints == expectedConstraints
            && snapshot.evidenceSources == [expectedProvenance]
    }

    private func validationCapture(
        from record: FH5ResearchObservationRecord
    ) -> FH5ResearchCapture {
        FH5ResearchCapture(
            platform: record.platform,
            gameVersion: record.gameVersion,
            tireCompoundDisplayName: record.tireCompoundDisplayName,
            forwardGearCount: record.forwardGearCount,
            controls: record.controls,
            exactUntouchedStockConfirmed: record.attestations.exactUntouchedStock,
            allSlidersRestoredConfirmed: record.attestations.allSlidersRestored,
            personallyReadFromGameConfirmed: record.attestations.personallyReadFromGame,
            firstPartyAuthorshipConfirmed: record.attestations.firstPartyAuthorship,
            localStoragePermitted: record.attestations.localStoragePermitted,
            deidentifiedStructuredReusePermitted:
                record.attestations.deidentifiedStructuredReusePermitted
        )
    }

    private func payloadIssues(_ observation: FH5TuneFieldObservation) -> [FH5ResearchIssue] {
        let field = observation.field
        switch observation.availability {
        case .adjustable:
            guard let minimum = observation.minimum,
                  let maximum = observation.maximum,
                  let step = observation.step,
                  let current = observation.current,
                  let unit = observation.unit else {
                return [.missingAdjustablePayload(field)]
            }
            guard [minimum, maximum, step, current].allSatisfy(\.isFinite) else {
                return [.nonFiniteValue(field)]
            }
            var issues: [FH5ResearchIssue] = []
            if minimum >= maximum { issues.append(.invalidRange(field)) }
            if step <= 0 { issues.append(.invalidStep(field)) }
            if unit != field.expectedUnit { issues.append(.wrongUnit(field)) }
            if current < minimum || current > maximum {
                issues.append(.currentOutOfRange(field))
            }
            if step > 0, minimum < maximum,
               (!isOnLattice(maximum, minimum: minimum, step: step)
                || !isOnLattice(current, minimum: minimum, step: step)) {
                issues.append(.valueOffLattice(field))
            }
            return issues
        case .shownLocked:
            guard observation.minimum == nil,
                  observation.maximum == nil,
                  observation.step == nil else {
                return [.forbiddenNumericPayload(field)]
            }
            if let current = observation.current {
                guard current.isFinite else { return [.nonFiniteValue(field)] }
                guard observation.unit == field.expectedUnit else {
                    return [.wrongUnit(field)]
                }
            } else if observation.unit != nil {
                return [.forbiddenNumericPayload(field)]
            }
            return []
        case .notShown:
            guard observation.minimum == nil,
                  observation.maximum == nil,
                  observation.step == nil,
                  observation.current == nil,
                  observation.unit == nil else {
                return [.forbiddenNumericPayload(field)]
            }
            return []
        }
    }

    private func attestationIssues(_ capture: FH5ResearchCapture) -> [FH5ResearchIssue] {
        var issues: [FH5ResearchIssue] = []
        if !capture.exactUntouchedStockConfirmed { issues.append(.stockNotConfirmed) }
        if !capture.allSlidersRestoredConfirmed { issues.append(.slidersNotRestored) }
        if !capture.personallyReadFromGameConfirmed { issues.append(.valuesNotPersonallyRead) }
        if !capture.firstPartyAuthorshipConfirmed { issues.append(.authorshipNotConfirmed) }
        if !capture.localStoragePermitted { issues.append(.localStorageNotPermitted) }
        return issues
    }

    private func canonicalControls(
        _ controls: [FH5TuneFieldObservation],
        drivetrain: Drivetrain,
        gearCount: Int
    ) -> [FH5TuneFieldObservation] {
        let order = Dictionary(uniqueKeysWithValues: TuneFieldID.expectedFields(
            drivetrain: drivetrain,
            gearCount: gearCount
        ).enumerated().map { ($0.element, $0.offset) })
        return controls.sorted {
            let lhs = order[$0.field] ?? Int.max
            let rhs = order[$1.field] ?? Int.max
            if lhs == rhs { return $0.field.stableID < $1.field.stableID }
            return lhs < rhs
        }
    }

    private func detachedCar(
        for vehicle: FH5ResearchObservationRecord.Vehicle
    ) -> CarInput {
        CarInput(
            game: .fh5,
            year: vehicle.year,
            make: vehicle.make,
            model: vehicle.model,
            weightPounds: vehicle.weightPounds,
            frontWeightPercent: vehicle.frontWeightPercent,
            performanceIndex: vehicle.performanceIndex,
            performanceClass: vehicle.performanceClass,
            drivetrain: vehicle.drivetrain,
            peakHorsepower: vehicle.peakHorsepower,
            peakTorqueFootPounds: vehicle.peakTorqueFootPounds,
            catalogReference: CatalogCarReference(
                entryID: vehicle.catalogID,
                revision: vehicle.catalogRevision,
                reviewedAt: vehicle.catalogReviewedAt,
                verificationStatus: vehicle.catalogVerificationStatus,
                sources: []
            )
        )
    }

    private func researchEvidence(build: String) -> TuneEvidence {
        TuneEvidence(
            confidence: .medium,
            source: Self.provenanceSource,
            version: build,
            usagePermission: .permitted
        )
    }

    private func upgradeEvidence(build: String) -> TuneEvidence {
        TuneEvidence(
            confidence: .medium,
            source: UpgradePartCapture.provenanceSource,
            version: build,
            usagePermission: .permitted
        )
    }

    private func isCanonicalUpgradeParts(
        _ parts: [FH5ResearchObservationRecord.UpgradePart]
    ) -> Bool {
        guard !parts.isEmpty else { return true }
        return parts.map(\.partID) == TunePartID.allCases
            && parts.allSatisfy {
                $0.availability == .available || $0.availability == .unavailable
            }
    }

    private func isSHA256Fingerprint(_ value: String) -> Bool {
        value.count == 64
            && value.unicodeScalars.allSatisfy {
                (48...57).contains($0.value) || (97...102).contains($0.value)
            }
    }

    private func isOnLattice(_ value: Double, minimum: Double, step: Double) -> Bool {
        guard value.isFinite, minimum.isFinite, step.isFinite, step > 0 else { return false }
        let quotient = (value - minimum) / step
        return abs(quotient - quotient.rounded()) <= 1e-8
    }

    private func canonicalString(_ value: String, maximumLength: Int) -> String? {
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
        let canonical = value.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard (1...maximumLength).contains(canonical.count) else { return nil }
        return canonical
    }

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func hash<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        let digest = SHA256.hash(data: try encoder.encode(value))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private struct ContentPayload: Codable {
        let schemaVersion: Int
        let consentVersion: String
        let capturedAt: Date
        let game: ForzaGame
        let platform: FH5Platform
        let gameVersion: String
        let unitScope: String
        let vehicle: FH5ResearchObservationRecord.Vehicle
        let upgradeParts: [FH5ResearchObservationRecord.UpgradePart]
        let tireCompoundDisplayName: String
        let forwardGearCount: Int
        let controls: [FH5TuneFieldObservation]
        let attestations: FH5ResearchObservationRecord.Attestations
        let unknowns: [String]
        let privacyExclusions: [String]
    }

    private struct PublicSemanticPayload: Codable {
        let schemaVersion: Int
        let consentVersion: String
        let submissionID: UUID
        let permissionReceiptID: UUID
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
    }
}
