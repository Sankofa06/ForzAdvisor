//
//  StockCatalogContribution.swift
//  forzadvisor
//
//  First-party stock facts collected for later human catalog review.
//  Contributions never mutate the bundled catalog or activate tuning output.
//

import CryptoKit
import Foundation

enum StockContributionPlatform: String, CaseIterable, Codable, Identifiable, Sendable {
    case xboxSeries = "Xbox Series X|S"
    case xboxOne = "Xbox One"
    case windowsPC = "Windows PC"
    case cloudGaming = "Xbox Cloud Gaming"

    var id: String { rawValue }
}

enum StockContributionObservationScreen:
    String, CaseIterable, Codable, Identifiable, Sendable {
    case garage = "Garage"
    case carCollection = "Car Collection"
    case autoshow = "Autoshow"
    case upgrades = "Upgrades"
    case telemetry = "Telemetry"

    var id: String { rawValue }
}

struct StockCatalogFieldAttestation:
    Codable, Equatable, Sendable {
    let field: CatalogDataField
    let observationScreen: StockContributionObservationScreen
    let directlyReadInGame: Bool
    let untouchedStockConfirmed: Bool
    let englishUnitsConfirmedWhenRelevant: Bool
    let observedAt: Date
}

struct StockCatalogContributionRights:
    Codable, Equatable, Sendable {
    var testerAuthoredStructuredFacts = false
    var deidentifiedStructuredReuse = false
    var catalogCurationUse = false
    var futureBundledRedistribution = false

    var allGranted: Bool {
        testerAuthoredStructuredFacts
            && deidentifiedStructuredReuse
            && catalogCurationUse
            && futureBundledRedistribution
    }
}

struct StockCatalogContributionVehicle:
    Codable, Equatable, Sendable {
    let year: Int
    let make: String
    let model: String
    let stock: CatalogStockSpecifications
}

struct StockCatalogContributionRecord:
    Codable, Equatable, Identifiable, Sendable {
    static let currentSchemaVersion = 1
    static let currentConsentVersion = "stock-catalog-contribution-v1"

    let schemaVersion: Int
    let consentVersion: String
    let id: UUID
    let submissionID: UUID
    let permissionReceiptID: UUID
    let capturedAt: Date
    let game: ForzaGame
    let gameVersion: String
    let platform: StockContributionPlatform
    let vehicle: StockCatalogContributionVehicle
    let reviewedFields: [CatalogDataField]
    let fieldAttestations: [StockCatalogFieldAttestation]
    let exactUntouchedStockConfirmed: Bool
    let personallyReadFromGameConfirmed: Bool
    let firstPartyAuthorshipConfirmed: Bool
    let localStoragePermissionConfirmed: Bool
    let rights: StockCatalogContributionRights

    init(
        id: UUID = UUID(),
        submissionID: UUID = UUID(),
        permissionReceiptID: UUID = UUID(),
        capturedAt: Date = .now,
        game: ForzaGame,
        gameVersion: String,
        platform: StockContributionPlatform,
        vehicle: StockCatalogContributionVehicle,
        reviewedFields: [CatalogDataField],
        fieldAttestations: [StockCatalogFieldAttestation],
        exactUntouchedStockConfirmed: Bool,
        personallyReadFromGameConfirmed: Bool,
        firstPartyAuthorshipConfirmed: Bool,
        localStoragePermissionConfirmed: Bool,
        rights: StockCatalogContributionRights = .init()
    ) {
        schemaVersion = Self.currentSchemaVersion
        consentVersion = Self.currentConsentVersion
        self.id = id
        self.submissionID = submissionID
        self.permissionReceiptID = permissionReceiptID
        self.capturedAt = capturedAt
        self.game = game
        self.gameVersion = gameVersion
        self.platform = platform
        self.vehicle = vehicle
        self.reviewedFields = reviewedFields
        self.fieldAttestations = fieldAttestations
        self.exactUntouchedStockConfirmed = exactUntouchedStockConfirmed
        self.personallyReadFromGameConfirmed = personallyReadFromGameConfirmed
        self.firstPartyAuthorshipConfirmed = firstPartyAuthorshipConfirmed
        self.localStoragePermissionConfirmed = localStoragePermissionConfirmed
        self.rights = rights
    }
}

struct StockCatalogContributionExport:
    Codable, Equatable, Sendable {
    let schemaVersion: Int
    let consentVersion: String
    let submissionID: UUID
    let permissionReceiptID: UUID
    let capturedAt: Date
    let game: ForzaGame
    let gameVersion: String
    let platform: StockContributionPlatform
    let vehicle: StockCatalogContributionVehicle
    let reviewedFields: [CatalogDataField]
    let fieldAttestations: [StockCatalogFieldAttestation]
    let exactUntouchedStockConfirmed: Bool
    let personallyReadFromGameConfirmed: Bool
    let firstPartyAuthorshipConfirmed: Bool
    let rights: StockCatalogContributionRights
    let privacyExclusions: [String]
    let contentFingerprint: String
}

enum StockCatalogContributionError:
    Error, Equatable, LocalizedError {
    case invalidRecord
    case exportRightsNotGranted
    case emptyPayload
    case payloadTooLarge
    case invalidJSON
    case unknownFields
    case nonCanonicalJSON
    case invalidStructure
    case invalidFingerprint
    case directReceiptNotConfirmed
    case reusePermissionNotConfirmed
    case completeRightsNotConfirmed
    case exactDuplicate

    var errorDescription: String? {
        switch self {
        case .invalidRecord:
            "Complete every stock fact, field attestation, and local capture confirmation."
        case .exportRightsNotGranted:
            "Grant all four structured-fact, reuse, curation, and future redistribution rights before exporting."
        case .emptyPayload: "Paste a stock catalog contribution export first."
        case .payloadTooLarge: "This contribution exceeds the 64 KiB limit."
        case .invalidJSON: "This is not a readable stock catalog contribution."
        case .unknownFields: "This contribution contains fields outside the public schema."
        case .nonCanonicalJSON: "Use the exact canonical JSON exported by ForzAdvisor."
        case .invalidStructure: "This contribution failed its schema, value, field-coverage, rights, privacy, or attestation checks."
        case .invalidFingerprint: "This contribution's content fingerprint does not match its facts."
        case .directReceiptNotConfirmed: "Confirm direct receipt of this exact export."
        case .reusePermissionNotConfirmed: "Confirm the tester granted deidentified structured reuse."
        case .completeRightsNotConfirmed:
            "Confirm the complete tester-authored facts, reuse, catalog curation, and future bundled redistribution grant."
        case .exactDuplicate:
            "This exact contribution is already in the reviewed queue."
        }
    }
}

struct ValidatedStockCatalogContribution: Sendable {
    let export: StockCatalogContributionExport
    let canonicalExportDigest: String
    let semanticFingerprint: String
    let associationFingerprint: String
}

enum StockCatalogReviewDisposition:
    Codable, Equatable, Sendable {
    case received
    case exactDuplicate
    case matchingObservation
    case conflictingObservation(fields: [CatalogDataField])
    case excluded
}

struct StockCatalogContributionReviewPermission:
    Codable, Equatable, Sendable {
    let directReceiptConfirmed: Bool
    let testerAuthoredStructuredFactsConfirmed: Bool
    let structuredReusePermissionConfirmed: Bool
    let catalogCurationPermissionConfirmed: Bool
    let bundledRedistributionPermissionConfirmed: Bool
    let reviewedAt: Date

    var isComplete: Bool {
        directReceiptConfirmed
            && testerAuthoredStructuredFactsConfirmed
            && structuredReusePermissionConfirmed
            && catalogCurationPermissionConfirmed
            && bundledRedistributionPermissionConfirmed
    }
}

struct StockCatalogContributionReviewEntry:
    Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let canonicalExportJSON: Data
    let permission: StockCatalogContributionReviewPermission
    let disposition: StockCatalogReviewDisposition

    static func locallyReviewed(
        canonicalExportJSON: Data,
        reviewerConfirmedDirectReceipt: Bool,
        reviewerConfirmedTesterAuthoredStructuredFacts: Bool,
        reviewerConfirmedStructuredReusePermission: Bool,
        reviewerConfirmedCatalogCurationPermission: Bool,
        reviewerConfirmedBundledRedistributionPermission: Bool,
        existing: [StockCatalogContributionReviewEntry],
        id: UUID = UUID(),
        now: Date = .now
    ) throws -> Self {
        guard reviewerConfirmedDirectReceipt else {
            throw StockCatalogContributionError.directReceiptNotConfirmed
        }
        guard reviewerConfirmedStructuredReusePermission else {
            throw StockCatalogContributionError.reusePermissionNotConfirmed
        }
        guard reviewerConfirmedTesterAuthoredStructuredFacts,
              reviewerConfirmedCatalogCurationPermission,
              reviewerConfirmedBundledRedistributionPermission else {
            throw StockCatalogContributionError.completeRightsNotConfirmed
        }
        let validated = try StockCatalogContributionIngestor()
            .validate(canonicalExportJSON)
        let disposition = StockCatalogContributionReviewEvaluator()
            .disposition(for: validated, existing: existing)
        guard disposition != .exactDuplicate else {
            throw StockCatalogContributionError.exactDuplicate
        }
        return Self(
            id: id,
            canonicalExportJSON: canonicalExportJSON,
            permission: .init(
                directReceiptConfirmed: true,
                testerAuthoredStructuredFactsConfirmed: true,
                structuredReusePermissionConfirmed: true,
                catalogCurationPermissionConfirmed: true,
                bundledRedistributionPermissionConfirmed: true,
                reviewedAt: now
            ),
            disposition: disposition
        )
    }
}

struct StockCatalogContributionReviewQueue {
    struct Reclassification: Equatable, Sendable {
        let entries: [StockCatalogContributionReviewEntry]
        let changed: Bool
    }

    static func reclassify(
        _ entries: [StockCatalogContributionReviewEntry]
    ) -> Reclassification {
        var accepted: [StockCatalogContributionReviewEntry] = []
        var changed = false
        for entry in entries {
            guard entry.permission.isComplete,
                  let validated =
                    try? StockCatalogContributionIngestor()
                    .validate(entry.canonicalExportJSON) else {
                changed = true
                continue
            }
            let disposition = StockCatalogContributionReviewEvaluator()
                .disposition(for: validated, existing: accepted)
            guard disposition != .exactDuplicate else {
                changed = true
                continue
            }
            let reclassified = StockCatalogContributionReviewEntry(
                id: entry.id,
                canonicalExportJSON: entry.canonicalExportJSON,
                permission: entry.permission,
                disposition: disposition
            )
            if reclassified != entry {
                changed = true
            }
            accepted.append(reclassified)
        }
        return Reclassification(
            entries: accepted,
            changed: changed
        )
    }
}

enum StockCatalogContributionPolicy {
    static let privacyExclusions = [
        "account-identifiers", "api-provider-data", "device-identifiers",
        "location", "notes", "ocr-content", "screenshots",
        "share-destination", "source-artwork", "source-prose",
        "third-party-databases", "tune-results", "tune-values"
    ]

    static let permissionBoundary =
        "Share only tester-authored structured facts. This permission excludes screenshots, artwork, source prose, third-party databases, and tunes, and makes no endorsement, ownership, or licensing claim."

    static let collectionBoundary =
        "Contributions are collection and review only. They never create a catalog entry, change the bundled catalog, average or approve facts, rank or validate evidence, promote a tune or ruleset, generate tuning, or upload in the background. UUIDs and hashes bind bytes, not tester identity."
}

struct StockCatalogCaptureConfirmationState:
    Equatable, Sendable {
    var exactStockConfirmed = false
    var personallyReadConfirmed = false
    var englishUnitsConfirmed = false
    var authorshipConfirmed = false
    var localStorageConfirmed = false
    var testerFactsRight = false
    var reuseRight = false
    var curationRight = false
    var redistributionRight = false

    mutating func reset() {
        self = .init()
    }

    mutating func invalidateIfDraftChanged(
        from previous: String,
        to current: String
    ) {
        if previous != current {
            reset()
        }
    }
}

struct StockCatalogReviewConfirmationState:
    Equatable, Sendable {
    var directReceiptConfirmed = false
    var testerFactsConfirmed = false
    var reuseConfirmed = false
    var curationConfirmed = false
    var redistributionConfirmed = false

    mutating func reset() {
        self = .init()
    }

    mutating func invalidateIfPayloadChanged(
        from previous: String,
        to current: String
    ) {
        if previous != current {
            reset()
        }
    }
}

enum StockCatalogContributionDraftProvenance:
    Equatable, Sendable {
    case gameOnly
    case officialRosterIdentity(id: String, game: ForzaGame)

    var lockedGame: ForzaGame? {
        switch self {
        case .gameOnly:
            nil
        case .officialRosterIdentity(_, let game):
            game
        }
    }
}

struct StockCatalogContributionDraft:
    Equatable, Sendable {
    let provenance: StockCatalogContributionDraftProvenance
    var game: ForzaGame {
        didSet {
            if let lockedGame = provenance.lockedGame,
               game != lockedGame {
                game = lockedGame
                return
            }
            if let performanceClass,
               !game.supportedPerformanceClasses.contains(
                    performanceClass
               ) {
                self.performanceClass = nil
            }
        }
    }
    var gameVersion = ""
    var platform: StockContributionPlatform?
    var year = ""
    var make = ""
    var model = ""
    var performanceIndex = ""
    var performanceClass: PerformanceClass?
    var drivetrain: Drivetrain?
    var weightPounds = ""
    var frontWeightPercent = ""
    var peakHorsepower = ""
    var peakTorque = ""
    var observationScreens:
        [CatalogDataField: StockContributionObservationScreen] = [:]
    var captureConfirmations =
        StockCatalogCaptureConfirmationState()

    init(game: ForzaGame) {
        provenance = .gameOnly
        self.game = game
    }

    init(officialRosterIdentity identity: OfficialRosterCarIdentity) {
        provenance = .officialRosterIdentity(
            id: identity.id,
            game: identity.game
        )
        game = identity.game
        year = String(identity.year)
        make = identity.make
        model = identity.model
    }

    var isGameSelectionLocked: Bool {
        provenance.lockedGame != nil
    }
}

struct StockCatalogCurationChoiceState:
    Equatable, Sendable {
    var proposedVerificationStatus:
        CatalogVerificationStatus?
    var identityRightsBasis:
        StockCatalogIdentityRightsBasis?
}

enum StockCatalogVehicleYearPolicy {
    static func allows(_ year: Int) -> Bool {
        (1886...2100).contains(year) || year == 2554
    }
}

struct StockCatalogContributionValidator {
    static let expectedFields =
        CatalogDataField.allCases.sorted { $0.rawValue < $1.rawValue }
    private static let englishUnitFields: Set<CatalogDataField> = [
        .weightPounds, .frontWeightPercent, .peakHorsepower,
        .peakTorqueFootPounds
    ]

    func isValid(_ record: StockCatalogContributionRecord) -> Bool {
        guard record.schemaVersion == StockCatalogContributionRecord.currentSchemaVersion,
              record.consentVersion == StockCatalogContributionRecord.currentConsentVersion,
              canonicalString(record.gameVersion, maximumLength: 120),
              canonicalString(record.vehicle.make, maximumLength: 120),
              canonicalString(record.vehicle.model, maximumLength: 160),
              StockCatalogVehicleYearPolicy.allows(
                record.vehicle.year
              ),
              record.exactUntouchedStockConfirmed,
              record.personallyReadFromGameConfirmed,
              record.firstPartyAuthorshipConfirmed,
              record.localStoragePermissionConfirmed,
              record.capturedAt.timeIntervalSince1970.isFinite,
              (1_577_836_800...4_102_444_800)
                .contains(record.capturedAt.timeIntervalSince1970),
              record.reviewedFields == Self.expectedFields,
              record.fieldAttestations.map(\.field) == Self.expectedFields,
              Set(record.fieldAttestations.map(\.field)).count
                == Self.expectedFields.count,
              record.fieldAttestations.allSatisfy({
                  $0.directlyReadInGame
                    && $0.untouchedStockConfirmed
                    && (!Self.englishUnitFields.contains($0.field)
                        || $0.englishUnitsConfirmedWhenRelevant)
                    && $0.observedAt == record.capturedAt
              }) else {
            return false
        }
        let stock = record.vehicle.stock
        return record.game.performanceIndexRange(
            for: stock.performanceClass
        )?.contains(stock.performanceIndex) == true
            && (1_500...7_000).contains(stock.weightPounds)
            && stock.frontWeightPercent.isFinite
            && (30...70).contains(stock.frontWeightPercent)
            && (1...5_000).contains(stock.peakHorsepower)
            && (1...5_000).contains(stock.peakTorqueFootPounds)
    }

    private func canonicalString(
        _ value: String,
        maximumLength: Int
    ) -> Bool {
        let canonical = value.split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        return canonical == value
            && (1...maximumLength).contains(canonical.count)
    }
}

struct StockCatalogContributionExporter {
    func canonicalJSON(
        for record: StockCatalogContributionRecord
    ) throws -> Data {
        guard StockCatalogContributionValidator().isValid(record) else {
            throw StockCatalogContributionError.invalidRecord
        }
        guard record.rights.allGranted else {
            throw StockCatalogContributionError.exportRightsNotGranted
        }
        var export = StockCatalogContributionExport(
            schemaVersion: record.schemaVersion,
            consentVersion: record.consentVersion,
            submissionID: record.submissionID,
            permissionReceiptID: record.permissionReceiptID,
            capturedAt: record.capturedAt,
            game: record.game,
            gameVersion: record.gameVersion,
            platform: record.platform,
            vehicle: record.vehicle,
            reviewedFields: record.reviewedFields,
            fieldAttestations: record.fieldAttestations,
            exactUntouchedStockConfirmed:
                record.exactUntouchedStockConfirmed,
            personallyReadFromGameConfirmed:
                record.personallyReadFromGameConfirmed,
            firstPartyAuthorshipConfirmed:
                record.firstPartyAuthorshipConfirmed,
            rights: record.rights,
            privacyExclusions:
                StockCatalogContributionPolicy.privacyExclusions,
            contentFingerprint: ""
        )
        export = StockCatalogContributionExport(
            schemaVersion: export.schemaVersion,
            consentVersion: export.consentVersion,
            submissionID: export.submissionID,
            permissionReceiptID: export.permissionReceiptID,
            capturedAt: export.capturedAt,
            game: export.game,
            gameVersion: export.gameVersion,
            platform: export.platform,
            vehicle: export.vehicle,
            reviewedFields: export.reviewedFields,
            fieldAttestations: export.fieldAttestations,
            exactUntouchedStockConfirmed:
                export.exactUntouchedStockConfirmed,
            personallyReadFromGameConfirmed:
                export.personallyReadFromGameConfirmed,
            firstPartyAuthorshipConfirmed:
                export.firstPartyAuthorshipConfirmed,
            rights: export.rights,
            privacyExclusions: export.privacyExclusions,
            contentFingerprint:
                try StockCatalogContributionIngestor
                    .contentFingerprint(for: export)
        )
        return try StockCatalogContributionIngestor
            .canonicalData(for: export)
    }
}

struct StockCatalogContributionIngestor {
    static let maximumPayloadBytes = 64 * 1_024

    func validate(
        _ data: Data
    ) throws -> ValidatedStockCatalogContribution {
        guard !data.isEmpty else {
            throw StockCatalogContributionError.emptyPayload
        }
        guard data.count <= Self.maximumPayloadBytes else {
            throw StockCatalogContributionError.payloadTooLarge
        }
        guard Self.hasOnlyKnownJSONFields(data) else {
            throw StockCatalogContributionError.unknownFields
        }
        let export: StockCatalogContributionExport
        do {
            export = try Self.decoder.decode(
                StockCatalogContributionExport.self,
                from: data
            )
        } catch {
            throw StockCatalogContributionError.invalidJSON
        }
        guard (try? Self.canonicalData(for: export)) == data else {
            throw StockCatalogContributionError.nonCanonicalJSON
        }
        guard Self.hasValidStructure(export) else {
            throw StockCatalogContributionError.invalidStructure
        }
        guard (try? Self.contentFingerprint(for: export))
                == export.contentFingerprint else {
            throw StockCatalogContributionError.invalidFingerprint
        }
        return ValidatedStockCatalogContribution(
            export: export,
            canonicalExportDigest: Self.sha256(data),
            semanticFingerprint: try Self.semanticFingerprint(export),
            associationFingerprint: try Self.associationFingerprint(export)
        )
    }

    static func canonicalData(
        for export: StockCatalogContributionExport
    ) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .sortedKeys, .prettyPrinted, .withoutEscapingSlashes
        ]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(export)
    }

    static func contentFingerprint(
        for export: StockCatalogContributionExport
    ) throws -> String {
        try fingerprint(ContentPayload(export: export))
    }

    static func semanticFingerprint(
        _ export: StockCatalogContributionExport
    ) throws -> String {
        try fingerprint(SemanticPayload(export: export))
    }

    static func associationFingerprint(
        _ export: StockCatalogContributionExport
    ) throws -> String {
        try fingerprint(AssociationPayload(export: export))
    }

    /// Comparison-only normalization. Exported/displayed facts remain exact.
    /// Whitespace is trimmed/collapsed before Unicode canonical composition
    /// and POSIX case/diacritic-insensitive folding.
    static func comparisonNormalizedString(
        _ value: String
    ) -> String {
        value
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .precomposedStringWithCanonicalMapping
            .folding(
                options: [
                    .caseInsensitive, .diacriticInsensitive
                ],
                locale: Locale(identifier: "en_US_POSIX")
            )
    }

    private static func hasValidStructure(
        _ export: StockCatalogContributionExport
    ) -> Bool {
        let record = StockCatalogContributionRecord(
            id: UUID(),
            submissionID: export.submissionID,
            permissionReceiptID: export.permissionReceiptID,
            capturedAt: export.capturedAt,
            game: export.game,
            gameVersion: export.gameVersion,
            platform: export.platform,
            vehicle: export.vehicle,
            reviewedFields: export.reviewedFields,
            fieldAttestations: export.fieldAttestations,
            exactUntouchedStockConfirmed:
                export.exactUntouchedStockConfirmed,
            personallyReadFromGameConfirmed:
                export.personallyReadFromGameConfirmed,
            firstPartyAuthorshipConfirmed:
                export.firstPartyAuthorshipConfirmed,
            localStoragePermissionConfirmed: true,
            rights: export.rights
        )
        return StockCatalogContributionValidator().isValid(record)
            && export.rights.allGranted
            && export.privacyExclusions
                == StockCatalogContributionPolicy.privacyExclusions
            && export.contentFingerprint.count == 64
    }

    private static func hasOnlyKnownJSONFields(_ data: Data) -> Bool {
        guard let root = try? JSONSerialization.jsonObject(with: data),
              let object = root as? [String: Any],
              Set(object.keys) == [
                  "schemaVersion", "consentVersion", "submissionID",
                  "permissionReceiptID", "capturedAt", "game",
                  "gameVersion", "platform", "vehicle", "reviewedFields",
                  "fieldAttestations", "exactUntouchedStockConfirmed",
                  "personallyReadFromGameConfirmed",
                  "firstPartyAuthorshipConfirmed", "rights",
                  "privacyExclusions", "contentFingerprint"
              ],
              let vehicle = object["vehicle"] as? [String: Any],
              Set(vehicle.keys) == ["year", "make", "model", "stock"],
              let stock = vehicle["stock"] as? [String: Any],
              Set(stock.keys) == [
                  "performanceIndex", "performanceClass", "drivetrain",
                  "weightPounds", "frontWeightPercent", "peakHorsepower",
                  "peakTorqueFootPounds"
              ],
              let rights = object["rights"] as? [String: Any],
              Set(rights.keys) == [
                  "testerAuthoredStructuredFacts",
                  "deidentifiedStructuredReuse", "catalogCurationUse",
                  "futureBundledRedistribution"
              ],
              let attestations =
                object["fieldAttestations"] as? [[String: Any]],
              attestations.allSatisfy({
                  Set($0.keys) == [
                      "field", "observationScreen", "directlyReadInGame",
                      "untouchedStockConfirmed",
                      "englishUnitsConfirmedWhenRelevant", "observedAt"
                  ]
              }) else {
            return false
        }
        return true
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private static func fingerprint<T: Encodable>(
        _ value: T
    ) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return sha256(try encoder.encode(value))
    }

    fileprivate static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }
            .joined()
    }

    private struct ContentPayload: Encodable {
        let schemaVersion: Int
        let consentVersion: String
        let submissionID: UUID
        let permissionReceiptID: UUID
        let capturedAt: Date
        let game: ForzaGame
        let gameVersion: String
        let platform: StockContributionPlatform
        let vehicle: StockCatalogContributionVehicle
        let reviewedFields: [CatalogDataField]
        let fieldAttestations: [StockCatalogFieldAttestation]
        let exactUntouchedStockConfirmed: Bool
        let personallyReadFromGameConfirmed: Bool
        let firstPartyAuthorshipConfirmed: Bool
        let rights: StockCatalogContributionRights
        let privacyExclusions: [String]

        init(export: StockCatalogContributionExport) {
            schemaVersion = export.schemaVersion
            consentVersion = export.consentVersion
            submissionID = export.submissionID
            permissionReceiptID = export.permissionReceiptID
            capturedAt = export.capturedAt
            game = export.game
            gameVersion = export.gameVersion
            platform = export.platform
            vehicle = export.vehicle
            reviewedFields = export.reviewedFields
            fieldAttestations = export.fieldAttestations
            exactUntouchedStockConfirmed =
                export.exactUntouchedStockConfirmed
            personallyReadFromGameConfirmed =
                export.personallyReadFromGameConfirmed
            firstPartyAuthorshipConfirmed =
                export.firstPartyAuthorshipConfirmed
            rights = export.rights
            privacyExclusions = export.privacyExclusions
        }
    }

    private struct SemanticPayload: Encodable {
        let game: ForzaGame
        let gameVersion: String
        let platform: StockContributionPlatform
        let vehicle: ComparisonVehicle
        let reviewedFields: [CatalogDataField]

        init(export: StockCatalogContributionExport) {
            game = export.game
            gameVersion = comparisonNormalizedString(
                export.gameVersion
            )
            platform = export.platform
            vehicle = ComparisonVehicle(export.vehicle)
            reviewedFields = export.reviewedFields
        }
    }

    private struct ComparisonVehicle: Encodable {
        let year: Int
        let make: String
        let model: String
        let stock: CatalogStockSpecifications

        init(_ vehicle: StockCatalogContributionVehicle) {
            year = vehicle.year
            make = comparisonNormalizedString(vehicle.make)
            model = comparisonNormalizedString(vehicle.model)
            stock = vehicle.stock
        }
    }

    private struct AssociationPayload: Encodable {
        let game: ForzaGame
        let gameVersion: String
        let year: Int
        let make: String
        let model: String
        let platform: StockContributionPlatform

        init(export: StockCatalogContributionExport) {
            game = export.game
            gameVersion = comparisonNormalizedString(
                export.gameVersion
            )
            year = export.vehicle.year
            make = comparisonNormalizedString(
                export.vehicle.make
            )
            model = comparisonNormalizedString(
                export.vehicle.model
            )
            platform = export.platform
        }
    }
}

struct StockCatalogContributionReviewEvaluator {
    func disposition(
        for data: Data,
        existing: [StockCatalogContributionReviewEntry]
    ) -> StockCatalogReviewDisposition {
        guard let validated =
            try? StockCatalogContributionIngestor().validate(data) else {
            return .excluded
        }
        return disposition(for: validated, existing: existing)
    }

    func disposition(
        for candidate: ValidatedStockCatalogContribution,
        existing: [StockCatalogContributionReviewEntry]
    ) -> StockCatalogReviewDisposition {
        let validated = existing.compactMap {
            try? StockCatalogContributionIngestor().validate(
                $0.canonicalExportJSON
            )
        }
        if validated.contains(where: {
            $0.canonicalExportDigest == candidate.canonicalExportDigest
        }) {
            return .exactDuplicate
        }
        if validated.contains(where: {
            $0.export.submissionID == candidate.export.submissionID
                || $0.export.permissionReceiptID
                    == candidate.export.permissionReceiptID
        }) {
            return .excluded
        }
        if validated.contains(where: {
            $0.semanticFingerprint == candidate.semanticFingerprint
        }) {
            return .matchingObservation
        }
        let conflicts = validated.filter {
            $0.associationFingerprint == candidate.associationFingerprint
        }
        if !conflicts.isEmpty {
            let fields = Set(conflicts.flatMap {
                conflictingFields(
                    candidate.export,
                    $0.export
                )
            }).sorted { $0.rawValue < $1.rawValue }
            return .conflictingObservation(
                fields: fields
            )
        }
        return .received
    }

    private func conflictingFields(
        _ lhs: StockCatalogContributionExport,
        _ rhs: StockCatalogContributionExport
    ) -> [CatalogDataField] {
        let a = lhs.vehicle.stock
        let b = rhs.vehicle.stock
        var fields: [CatalogDataField] = []
        if lhs.vehicle.year != rhs.vehicle.year
            || StockCatalogContributionIngestor
                .comparisonNormalizedString(lhs.vehicle.make)
                != StockCatalogContributionIngestor
                .comparisonNormalizedString(rhs.vehicle.make)
            || StockCatalogContributionIngestor
                .comparisonNormalizedString(lhs.vehicle.model)
                != StockCatalogContributionIngestor
                .comparisonNormalizedString(rhs.vehicle.model) {
            fields.append(.identity)
        }
        if a.performanceIndex != b.performanceIndex {
            fields.append(.performanceIndex)
        }
        if a.performanceClass != b.performanceClass {
            fields.append(.performanceClass)
        }
        if a.drivetrain != b.drivetrain {
            fields.append(.drivetrain)
        }
        if a.weightPounds != b.weightPounds {
            fields.append(.weightPounds)
        }
        if a.frontWeightPercent != b.frontWeightPercent {
            fields.append(.frontWeightPercent)
        }
        if a.peakHorsepower != b.peakHorsepower {
            fields.append(.peakHorsepower)
        }
        if a.peakTorqueFootPounds != b.peakTorqueFootPounds {
            fields.append(.peakTorqueFootPounds)
        }
        return fields.sorted { $0.rawValue < $1.rawValue }
    }
}

struct StockCatalogContributionStoreSnapshot:
    Equatable, Sendable {
    var captured: [StockCatalogContributionRecord]
    var reviewed: [StockCatalogContributionReviewEntry]
    var recoveredFromMalformedData: Bool

    static let empty = Self(
        captured: [],
        reviewed: [],
        recoveredFromMalformedData: false
    )
}

struct StockCatalogContributionStore {
    static let storageKey =
        "stockCatalogContributionStore.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> StockCatalogContributionStoreSnapshot {
        guard let data = defaults.data(forKey: Self.storageKey) else {
            return .empty
        }
        guard let envelope = try? JSONDecoder().decode(
            Envelope.self,
            from: data
        ), envelope.schemaVersion == 1 else {
            var snapshot = StockCatalogContributionStoreSnapshot.empty
            snapshot.recoveredFromMalformedData = true
            return snapshot
        }
        let captured = envelope.captured.filter {
            StockCatalogContributionValidator().isValid($0)
        }
        let reviewed = StockCatalogContributionReviewQueue
            .reclassify(envelope.reviewed)
        let recovered =
            captured.count != envelope.captured.count
            || reviewed.changed
        return .init(
            captured: captured,
            reviewed: reviewed.entries,
            recoveredFromMalformedData: recovered
        )
    }

    func save(_ snapshot: StockCatalogContributionStoreSnapshot) throws {
        guard snapshot.captured.allSatisfy({
            StockCatalogContributionValidator().isValid($0)
        }), hasValidReviewedQueue(snapshot.reviewed) else {
            throw StockCatalogContributionError.invalidRecord
        }
        let data = try JSONEncoder().encode(Envelope(
            schemaVersion: 1,
            captured: snapshot.captured,
            reviewed: snapshot.reviewed
        ))
        defaults.set(data, forKey: Self.storageKey)
    }

    private func hasValidReviewedQueue(
        _ entries: [StockCatalogContributionReviewEntry]
    ) -> Bool {
        let reclassified = StockCatalogContributionReviewQueue
            .reclassify(entries)
        return !reclassified.changed
            && reclassified.entries == entries
    }

    private struct Envelope: Codable {
        let schemaVersion: Int
        let captured: [StockCatalogContributionRecord]
        let reviewed: [StockCatalogContributionReviewEntry]
    }
}
