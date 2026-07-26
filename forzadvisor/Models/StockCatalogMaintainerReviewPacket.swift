//
//  StockCatalogMaintainerReviewPacket.swift
//  forzadvisor
//
//  Canonical, share-only evidence for later human catalog curation.
//  A packet cannot create or modify a bundled catalog entry.
//

import CryptoKit
import Foundation

enum StockCatalogMaintainerReviewPacketError:
    Error, Equatable, LocalizedError {
    case tooManyEntries
    case invalidBaseCatalog
    case noReviewableEvidence
    case payloadTooLarge
    case invalidJSON
    case unknownFields
    case nonCanonicalJSON
    case invalidStructure
    case invalidFingerprint

    var errorDescription: String? {
        switch self {
        case .tooManyEntries:
            "A maintainer packet can contain at most 250 reviewed observations."
        case .invalidBaseCatalog:
            "The bundled catalog reference is not safe to include."
        case .noReviewableEvidence:
            "No complete, permission-bound reviewed evidence is available."
        case .payloadTooLarge:
            "The maintainer packet exceeds the 1 MiB limit."
        case .invalidJSON:
            "This is not a readable maintainer review packet."
        case .unknownFields:
            "This packet contains fields outside the public schema."
        case .nonCanonicalJSON:
            "Use the exact canonical maintainer packet exported by ForzAdvisor."
        case .invalidStructure:
            "This packet failed its schema, ordering, safety, or policy checks."
        case .invalidFingerprint:
            "This packet's integrity fingerprint does not match its evidence."
        }
    }
}

struct StockCatalogMaintainerReviewPacketArtifact: Sendable {
    let packet: StockCatalogMaintainerReviewPacket
    let canonicalJSON: Data
}

struct StockCatalogMaintainerReviewPacket:
    Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1
    static let currentPolicyVersion =
        "stock-catalog-maintainer-review-v1"

    let schemaVersion: Int
    let policyVersion: String
    let baseCatalog: StockCatalogMaintainerBaseCatalog
    let candidates: [StockCatalogMaintainerCandidate]
    let conflicts: [StockCatalogMaintainerConflict]
    let excludedObservationCount: Int
    let automaticPromotionPermitted: Bool
    let requiresIndependentSourceReview: Bool
    let reviewBoundary: String
    let privacyExclusions: [String]
    let artifactFingerprint: String
}

struct StockCatalogMaintainerBaseCatalog:
    Codable, Equatable, Sendable {
    let schemaVersion: Int
    let revision: String
    let reviewedAt: Date
}

struct StockCatalogMaintainerCandidate:
    Codable, Equatable, Sendable {
    let groupID: String
    let variant: StockCatalogMaintainerEvidenceVariant
}

struct StockCatalogMaintainerConflict:
    Codable, Equatable, Sendable {
    let groupID: String
    let conflictingFields: [CatalogDataField]
    let variants: [StockCatalogMaintainerEvidenceVariant]
}

struct StockCatalogMaintainerEvidenceVariant:
    Codable, Equatable, Sendable {
    let variantID: String
    let game: ForzaGame
    let gameVersion: String
    let platform: StockContributionPlatform
    let vehicle: StockCatalogContributionVehicle
    let observationCount: Int
    let observations: [StockCatalogMaintainerObservation]
    let catalogComparison: StockCatalogMaintainerCatalogComparison
}

struct StockCatalogMaintainerObservation:
    Codable, Equatable, Sendable {
    let observationDigest: String
    let capturedAt: Date
    let consentVersion: String
    let permission:
        StockCatalogMaintainerPermissionEvidence
    let fields: [StockCatalogMaintainerFieldEvidence]
}

struct StockCatalogMaintainerPermissionEvidence:
    Codable, Equatable, Sendable {
    let directReceiptConfirmed: Bool
    let testerAuthoredStructuredFactsConfirmed: Bool
    let deidentifiedStructuredReuseConfirmed: Bool
    let catalogCurationUseConfirmed: Bool
    let futureBundledRedistributionConfirmed: Bool

    static let complete = Self(
        directReceiptConfirmed: true,
        testerAuthoredStructuredFactsConfirmed: true,
        deidentifiedStructuredReuseConfirmed: true,
        catalogCurationUseConfirmed: true,
        futureBundledRedistributionConfirmed: true
    )

    var isComplete: Bool {
        directReceiptConfirmed
            && testerAuthoredStructuredFactsConfirmed
            && deidentifiedStructuredReuseConfirmed
            && catalogCurationUseConfirmed
            && futureBundledRedistributionConfirmed
    }
}

struct StockCatalogMaintainerFieldEvidence:
    Codable, Equatable, Sendable {
    let field: CatalogDataField
    let observationScreen: StockContributionObservationScreen
}

enum StockCatalogMaintainerCatalogComparisonStatus:
    String, Codable, Sendable {
    case absent
    case exactStockMatch
    case stockConflict
    case ambiguousIdentity
}

struct StockCatalogMaintainerCatalogComparison:
    Codable, Equatable, Sendable {
    let status: StockCatalogMaintainerCatalogComparisonStatus
    let existingEntryIDs: [String]
    let differingFields: [CatalogDataField]
}

enum StockCatalogMaintainerReviewPacketPolicy {
    static let reviewBoundary =
        "Evidence for separate human review only. A maintainer must independently choose sources, catalog identity, verification status, revision, and whether the facts are sufficient. This packet never writes a catalog, selects a winner, averages values, authenticates a tester, or activates tuning."

    static let privacyExclusions =
        (StockCatalogContributionPolicy.privacyExclusions + [
            "canonical-contribution-json", "local-review-identifiers",
            "permission-receipt-identifiers", "submission-identifiers"
        ]).sorted()
}

struct StockCatalogMaintainerReviewPacketExporter {
    static let maximumReviewedEntries = 250
    static let maximumPayloadBytes = 1_024 * 1_024

    func makeArtifact(
        reviewedEntries: [StockCatalogContributionReviewEntry],
        baseCatalog: CarCatalogSnapshot
    ) throws -> StockCatalogMaintainerReviewPacketArtifact {
        guard reviewedEntries.count <= Self.maximumReviewedEntries else {
            throw StockCatalogMaintainerReviewPacketError.tooManyEntries
        }
        guard validBaseCatalog(baseCatalog) else {
            throw StockCatalogMaintainerReviewPacketError.invalidBaseCatalog
        }

        let normalized = normalizedObservations(reviewedEntries)
        guard !normalized.observations.isEmpty else {
            throw StockCatalogMaintainerReviewPacketError
                .noReviewableEvidence
        }

        let associationGroups = Dictionary(
            grouping: normalized.observations,
            by: \.validated.associationFingerprint
        )
        var candidates: [StockCatalogMaintainerCandidate] = []
        var conflicts: [StockCatalogMaintainerConflict] = []

        for association in associationGroups.keys.sorted() {
            guard let observations = associationGroups[association] else {
                continue
            }
            let semanticGroups = Dictionary(
                grouping: observations,
                by: \.validated.semanticFingerprint
            )
            let groupID = domainHash(
                domain: "forzadvisor.stock-maintainer.group.v1",
                value: association
            )
            let variants = try semanticGroups.keys.sorted().compactMap {
                semantic -> StockCatalogMaintainerEvidenceVariant? in
                guard let group = semanticGroups[semantic] else {
                    return nil
                }
                return try makeVariant(
                    semanticFingerprint: semantic,
                    observations: group,
                    baseCatalog: baseCatalog
                )
            }.sorted { $0.variantID < $1.variantID }

            if variants.count == 1, let variant = variants.first {
                candidates.append(.init(
                    groupID: groupID,
                    variant: variant
                ))
            } else if variants.count > 1 {
                conflicts.append(.init(
                    groupID: groupID,
                    conflictingFields:
                        conflictingFields(in: variants),
                    variants: variants
                ))
            }
        }

        guard !candidates.isEmpty || !conflicts.isEmpty else {
            throw StockCatalogMaintainerReviewPacketError
                .noReviewableEvidence
        }

        let unsigned = StockCatalogMaintainerReviewPacket(
            schemaVersion:
                StockCatalogMaintainerReviewPacket
                .currentSchemaVersion,
            policyVersion:
                StockCatalogMaintainerReviewPacket
                .currentPolicyVersion,
            baseCatalog: .init(
                schemaVersion: baseCatalog.schemaVersion,
                revision: baseCatalog.revision,
                reviewedAt: baseCatalog.reviewedAt
            ),
            candidates: candidates.sorted {
                $0.groupID < $1.groupID
            },
            conflicts: conflicts.sorted {
                $0.groupID < $1.groupID
            },
            excludedObservationCount: normalized.excludedCount,
            automaticPromotionPermitted: false,
            requiresIndependentSourceReview: true,
            reviewBoundary:
                StockCatalogMaintainerReviewPacketPolicy
                .reviewBoundary,
            privacyExclusions:
                StockCatalogMaintainerReviewPacketPolicy
                .privacyExclusions,
            artifactFingerprint: ""
        )
        let packet = replacingFingerprint(
            in: unsigned,
            with: fingerprint(for: unsigned)
        )
        let data = try canonicalData(for: packet)
        guard data.count <= Self.maximumPayloadBytes else {
            throw StockCatalogMaintainerReviewPacketError
                .payloadTooLarge
        }
        return .init(packet: packet, canonicalJSON: data)
    }

    func validate(
        _ data: Data
    ) throws -> StockCatalogMaintainerReviewPacket {
        guard !data.isEmpty else {
            throw StockCatalogMaintainerReviewPacketError.invalidJSON
        }
        guard data.count <= Self.maximumPayloadBytes else {
            throw StockCatalogMaintainerReviewPacketError.payloadTooLarge
        }
        guard hasOnlyKnownJSONFields(data) else {
            throw StockCatalogMaintainerReviewPacketError.unknownFields
        }
        let packet: StockCatalogMaintainerReviewPacket
        do {
            packet = try Self.decoder.decode(
                StockCatalogMaintainerReviewPacket.self,
                from: data
            )
        } catch {
            throw StockCatalogMaintainerReviewPacketError.invalidJSON
        }
        guard (try? canonicalData(for: packet)) == data else {
            throw StockCatalogMaintainerReviewPacketError.nonCanonicalJSON
        }
        guard hasValidStructure(packet) else {
            throw StockCatalogMaintainerReviewPacketError.invalidStructure
        }
        guard fingerprint(for: packet)
                == packet.artifactFingerprint else {
            throw StockCatalogMaintainerReviewPacketError.invalidFingerprint
        }
        return packet
    }

    private struct ReviewedObservation {
        let validated: ValidatedStockCatalogContribution
    }

    private struct NormalizedObservations {
        let observations: [ReviewedObservation]
        let excludedCount: Int
    }

    private func normalizedObservations(
        _ entries: [StockCatalogContributionReviewEntry]
    ) -> NormalizedObservations {
        var excluded = 0
        var valid: [ReviewedObservation] = []
        for entry in entries {
            guard entry.permission.isComplete,
                  let validated =
                    try? StockCatalogContributionIngestor()
                    .validate(entry.canonicalExportJSON),
                  safeExportStrings(validated.export) else {
                excluded += 1
                continue
            }
            valid.append(.init(validated: validated))
        }

        let exactGroups = Dictionary(
            grouping: valid,
            by: \.validated.canonicalExportDigest
        )
        var deduplicated: [ReviewedObservation] = []
        for digest in exactGroups.keys.sorted() {
            guard let group = exactGroups[digest],
                  let first = group.first else {
                continue
            }
            deduplicated.append(first)
            excluded += group.count - 1
        }

        let replayedSubmissions = replayedIdentifiers(
            deduplicated,
            id: \.validated.export.submissionID
        )
        let replayedReceipts = replayedIdentifiers(
            deduplicated,
            id: \.validated.export.permissionReceiptID
        )
        let accepted = deduplicated.filter {
            let isReplayed =
                replayedSubmissions.contains(
                    $0.validated.export.submissionID
                )
                || replayedReceipts.contains(
                    $0.validated.export.permissionReceiptID
                )
            if isReplayed { excluded += 1 }
            return !isReplayed
        }
        return .init(
            observations: accepted.sorted {
                $0.validated.canonicalExportDigest
                    < $1.validated.canonicalExportDigest
            },
            excludedCount: excluded
        )
    }

    private func replayedIdentifiers<ID: Hashable>(
        _ observations: [ReviewedObservation],
        id: KeyPath<ReviewedObservation, ID>
    ) -> Set<ID> {
        Set(Dictionary(grouping: observations, by: {
            $0[keyPath: id]
        }).compactMap { key, group in
            Set(group.map(\.validated.canonicalExportDigest)).count > 1
                ? key : nil
        })
    }

    private func makeVariant(
        semanticFingerprint: String,
        observations: [ReviewedObservation],
        baseCatalog: CarCatalogSnapshot
    ) throws -> StockCatalogMaintainerEvidenceVariant {
        guard let first = observations.first else {
            throw StockCatalogMaintainerReviewPacketError
                .noReviewableEvidence
        }
        let export = first.validated.export
        let publicObservations = observations.map {
            makeObservation($0)
        }.sorted {
            $0.observationDigest < $1.observationDigest
        }
        return .init(
            variantID: domainHash(
                domain: "forzadvisor.stock-maintainer.variant.v1",
                value: semanticFingerprint
            ),
            game: export.game,
            gameVersion: export.gameVersion,
            platform: export.platform,
            vehicle: export.vehicle,
            observationCount: publicObservations.count,
            observations: publicObservations,
            catalogComparison: catalogComparison(
                for: export,
                in: baseCatalog
            )
        )
    }

    private func makeObservation(
        _ observation: ReviewedObservation
    ) -> StockCatalogMaintainerObservation {
        let export = observation.validated.export
        return .init(
            observationDigest: domainHash(
                domain:
                    "forzadvisor.stock-maintainer.observation.v1",
                value:
                    observation.validated.canonicalExportDigest
            ),
            capturedAt: export.capturedAt,
            consentVersion: export.consentVersion,
            permission: .complete,
            fields: export.fieldAttestations.map {
                StockCatalogMaintainerFieldEvidence(
                    field: $0.field,
                    observationScreen: $0.observationScreen
                )
            }.sorted {
                $0.field.rawValue < $1.field.rawValue
            }
        )
    }

    private func catalogComparison(
        for export: StockCatalogContributionExport,
        in catalog: CarCatalogSnapshot
    ) -> StockCatalogMaintainerCatalogComparison {
        let matches = catalog.entries.filter {
            $0.game == export.game
                && $0.year == export.vehicle.year
                && StockCatalogContributionIngestor
                    .comparisonNormalizedString($0.make)
                    == StockCatalogContributionIngestor
                    .comparisonNormalizedString(
                        export.vehicle.make
                    )
                && StockCatalogContributionIngestor
                    .comparisonNormalizedString($0.model)
                    == StockCatalogContributionIngestor
                    .comparisonNormalizedString(
                        export.vehicle.model
                    )
        }.sorted { $0.id < $1.id }
        guard matches.count == 1, let match = matches.first else {
            return .init(
                status: matches.isEmpty ? .absent : .ambiguousIdentity,
                existingEntryIDs: matches.map(\.id),
                differingFields: []
            )
        }
        let fields = differingFields(
            export.vehicle.stock,
            match.stock
        )
        return .init(
            status: fields.isEmpty ? .exactStockMatch : .stockConflict,
            existingEntryIDs: [match.id],
            differingFields: fields
        )
    }

    private func conflictingFields(
        in variants: [StockCatalogMaintainerEvidenceVariant]
    ) -> [CatalogDataField] {
        var fields: Set<CatalogDataField> = []
        for left in variants.indices {
            for right in variants.indices where right > left {
                fields.formUnion(differingFields(
                    variants[left].vehicle.stock,
                    variants[right].vehicle.stock
                ))
            }
        }
        return fields.sorted { $0.rawValue < $1.rawValue }
    }

    private func differingFields(
        _ lhs: CatalogStockSpecifications,
        _ rhs: CatalogStockSpecifications
    ) -> [CatalogDataField] {
        var fields: [CatalogDataField] = []
        if lhs.performanceIndex != rhs.performanceIndex {
            fields.append(.performanceIndex)
        }
        if lhs.performanceClass != rhs.performanceClass {
            fields.append(.performanceClass)
        }
        if lhs.drivetrain != rhs.drivetrain {
            fields.append(.drivetrain)
        }
        if lhs.weightPounds != rhs.weightPounds {
            fields.append(.weightPounds)
        }
        if lhs.frontWeightPercent != rhs.frontWeightPercent {
            fields.append(.frontWeightPercent)
        }
        if lhs.peakHorsepower != rhs.peakHorsepower {
            fields.append(.peakHorsepower)
        }
        if lhs.peakTorqueFootPounds != rhs.peakTorqueFootPounds {
            fields.append(.peakTorqueFootPounds)
        }
        return fields.sorted { $0.rawValue < $1.rawValue }
    }

    private func safeExportStrings(
        _ export: StockCatalogContributionExport
    ) -> Bool {
        safePublicString(export.gameVersion, maximumLength: 120)
            && safePublicString(
                export.vehicle.make,
                maximumLength: 120
            )
            && safePublicString(
                export.vehicle.model,
                maximumLength: 160
            )
            && safePublicString(
                export.consentVersion,
                maximumLength: 120
            )
    }

    private func validBaseCatalog(
        _ catalog: CarCatalogSnapshot
    ) -> Bool {
        catalog.schemaVersion == BundledCarCatalog.supportedSchemaVersion
            && safePublicString(
                catalog.revision,
                maximumLength: 120
            )
            && catalog.reviewedAt.timeIntervalSince1970.isFinite
            && catalog.entries.allSatisfy {
                safePublicString($0.id, maximumLength: 200)
                    && safePublicString(
                        $0.make,
                        maximumLength: 120
                    )
                    && safePublicString(
                        $0.model,
                        maximumLength: 160
                    )
            }
    }

    private func safePublicString(
        _ value: String,
        maximumLength: Int
    ) -> Bool {
        let canonical = value.split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        guard canonical == value,
              (1...maximumLength).contains(value.count) else {
            return false
        }
        return value.unicodeScalars.allSatisfy {
            let category = $0.properties.generalCategory
            return !CharacterSet.controlCharacters.contains($0)
                && category != .format
                && category != .lineSeparator
                && category != .paragraphSeparator
        }
    }

    private func hasValidStructure(
        _ packet: StockCatalogMaintainerReviewPacket
    ) -> Bool {
        guard packet.schemaVersion
                == StockCatalogMaintainerReviewPacket
                .currentSchemaVersion,
              packet.policyVersion
                == StockCatalogMaintainerReviewPacket
                .currentPolicyVersion,
              packet.automaticPromotionPermitted == false,
              packet.requiresIndependentSourceReview,
              packet.reviewBoundary
                == StockCatalogMaintainerReviewPacketPolicy
                .reviewBoundary,
              packet.privacyExclusions
                == StockCatalogMaintainerReviewPacketPolicy
                .privacyExclusions,
              packet.excludedObservationCount >= 0,
              isDigest(packet.artifactFingerprint),
              packet.candidates == packet.candidates.sorted(by: {
                  $0.groupID < $1.groupID
              }),
              packet.conflicts == packet.conflicts.sorted(by: {
                  $0.groupID < $1.groupID
              }),
              !packet.candidates.isEmpty || !packet.conflicts.isEmpty,
              validBasePacket(packet.baseCatalog) else {
            return false
        }
        let groupIDs =
            packet.candidates.map(\.groupID)
            + packet.conflicts.map(\.groupID)
        guard Set(groupIDs).count == groupIDs.count,
              groupIDs.allSatisfy(isDigest) else {
            return false
        }
        return packet.candidates.allSatisfy {
            validVariant($0.variant)
        } && packet.conflicts.allSatisfy {
            $0.variants.count > 1
                && !$0.conflictingFields.isEmpty
                && $0.conflictingFields
                    == $0.conflictingFields.sorted {
                        $0.rawValue < $1.rawValue
                    }
                && Set($0.conflictingFields).count
                    == $0.conflictingFields.count
                && $0.variants
                    == $0.variants.sorted {
                        $0.variantID < $1.variantID
                    }
                && $0.variants.allSatisfy(validVariant)
        }
    }

    private func validBasePacket(
        _ base: StockCatalogMaintainerBaseCatalog
    ) -> Bool {
        base.schemaVersion == BundledCarCatalog.supportedSchemaVersion
            && safePublicString(base.revision, maximumLength: 120)
            && base.reviewedAt.timeIntervalSince1970.isFinite
    }

    private func validVariant(
        _ variant: StockCatalogMaintainerEvidenceVariant
    ) -> Bool {
        isDigest(variant.variantID)
            && safePublicString(
                variant.gameVersion,
                maximumLength: 120
            )
            && safePublicString(
                variant.vehicle.make,
                maximumLength: 120
            )
            && safePublicString(
                variant.vehicle.model,
                maximumLength: 160
            )
            && variant.observationCount
                == variant.observations.count
            && variant.observationCount > 0
            && variant.observations
                == variant.observations.sorted {
                    $0.observationDigest < $1.observationDigest
                }
            && Set(variant.observations.map(\.observationDigest))
                .count == variant.observations.count
            && variant.observations.allSatisfy(validObservation)
            && variant.catalogComparison.existingEntryIDs
                == variant.catalogComparison.existingEntryIDs.sorted()
            && variant.catalogComparison.differingFields
                == variant.catalogComparison.differingFields.sorted {
                    $0.rawValue < $1.rawValue
                }
            && Set(variant.catalogComparison.existingEntryIDs).count
                == variant.catalogComparison.existingEntryIDs.count
            && Set(variant.catalogComparison.differingFields).count
                == variant.catalogComparison.differingFields.count
            && validComparison(variant.catalogComparison)
    }

    private func validComparison(
        _ comparison: StockCatalogMaintainerCatalogComparison
    ) -> Bool {
        switch comparison.status {
        case .absent:
            comparison.existingEntryIDs.isEmpty
                && comparison.differingFields.isEmpty
        case .exactStockMatch:
            comparison.existingEntryIDs.count == 1
                && comparison.differingFields.isEmpty
        case .stockConflict:
            comparison.existingEntryIDs.count == 1
                && !comparison.differingFields.isEmpty
        case .ambiguousIdentity:
            comparison.existingEntryIDs.count > 1
                && comparison.differingFields.isEmpty
        }
    }

    private func validObservation(
        _ observation: StockCatalogMaintainerObservation
    ) -> Bool {
        isDigest(observation.observationDigest)
            && safePublicString(
                observation.consentVersion,
                maximumLength: 120
            )
            && observation.capturedAt.timeIntervalSince1970.isFinite
            && observation.permission.isComplete
            && observation.fields
                == observation.fields.sorted {
                    $0.field.rawValue < $1.field.rawValue
                }
            && observation.fields.map(\.field)
                == StockCatalogContributionValidator.expectedFields
    }

    private func isDigest(_ value: String) -> Bool {
        value.count == 64
            && value.allSatisfy {
                $0.isNumber || ("a"..."f").contains($0)
            }
    }

    private func fingerprint(
        for packet: StockCatalogMaintainerReviewPacket
    ) -> String {
        let unsigned = replacingFingerprint(in: packet, with: "")
        guard let data = try? canonicalData(for: unsigned) else {
            return ""
        }
        return domainHash(
            domain: "forzadvisor.stock-maintainer.packet.v1",
            data: data
        )
    }

    private func replacingFingerprint(
        in packet: StockCatalogMaintainerReviewPacket,
        with fingerprint: String
    ) -> StockCatalogMaintainerReviewPacket {
        .init(
            schemaVersion: packet.schemaVersion,
            policyVersion: packet.policyVersion,
            baseCatalog: packet.baseCatalog,
            candidates: packet.candidates,
            conflicts: packet.conflicts,
            excludedObservationCount:
                packet.excludedObservationCount,
            automaticPromotionPermitted:
                packet.automaticPromotionPermitted,
            requiresIndependentSourceReview:
                packet.requiresIndependentSourceReview,
            reviewBoundary: packet.reviewBoundary,
            privacyExclusions: packet.privacyExclusions,
            artifactFingerprint: fingerprint
        )
    }

    private func canonicalData(
        for packet: StockCatalogMaintainerReviewPacket
    ) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .sortedKeys, .prettyPrinted, .withoutEscapingSlashes
        ]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(packet)
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private func domainHash(
        domain: String,
        value: String
    ) -> String {
        domainHash(domain: domain, data: Data(value.utf8))
    }

    private func domainHash(
        domain: String,
        data: Data
    ) -> String {
        var payload = Data(domain.utf8)
        payload.append(0)
        payload.append(data)
        return SHA256.hash(data: payload)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private func hasOnlyKnownJSONFields(_ data: Data) -> Bool {
        guard let root = try? JSONSerialization.jsonObject(with: data),
              let object = root as? [String: Any],
              hasKeys(object, [
                  "schemaVersion", "policyVersion", "baseCatalog",
                  "candidates", "conflicts",
                  "excludedObservationCount",
                  "automaticPromotionPermitted",
                  "requiresIndependentSourceReview",
                  "reviewBoundary", "privacyExclusions",
                  "artifactFingerprint"
              ]),
              let base = object["baseCatalog"] as? [String: Any],
              hasKeys(base, [
                  "schemaVersion", "revision", "reviewedAt"
              ]),
              let candidates =
                object["candidates"] as? [[String: Any]],
              candidates.allSatisfy({
                  hasKeys($0, ["groupID", "variant"])
                    && validVariantJSON($0["variant"])
              }),
              let conflicts =
                object["conflicts"] as? [[String: Any]],
              conflicts.allSatisfy({
                  hasKeys($0, [
                      "groupID", "conflictingFields", "variants"
                  ])
                    && (($0["variants"] as? [Any]) ?? [])
                        .allSatisfy(validVariantJSON)
              }) else {
            return false
        }
        return true
    }

    private func validVariantJSON(_ value: Any?) -> Bool {
        guard let object = value as? [String: Any],
              hasKeys(object, [
                  "variantID", "game", "gameVersion", "platform",
                  "vehicle", "observationCount", "observations",
                  "catalogComparison"
              ]),
              let vehicle = object["vehicle"] as? [String: Any],
              hasKeys(vehicle, ["year", "make", "model", "stock"]),
              let stock = vehicle["stock"] as? [String: Any],
              hasKeys(stock, [
                  "performanceIndex", "performanceClass",
                  "drivetrain", "weightPounds",
                  "frontWeightPercent", "peakHorsepower",
                  "peakTorqueFootPounds"
              ]),
              let comparison =
                object["catalogComparison"] as? [String: Any],
              hasKeys(comparison, [
                  "status", "existingEntryIDs", "differingFields"
              ]),
              let observations =
                object["observations"] as? [[String: Any]],
              observations.allSatisfy(validObservationJSON) else {
            return false
        }
        return true
    }

    private func validObservationJSON(
        _ object: [String: Any]
    ) -> Bool {
        guard hasKeys(object, [
            "observationDigest", "capturedAt", "consentVersion",
            "permission", "fields"
        ]),
              let permission =
                object["permission"] as? [String: Any],
              hasKeys(permission, [
                  "directReceiptConfirmed",
                  "testerAuthoredStructuredFactsConfirmed",
                  "deidentifiedStructuredReuseConfirmed",
                  "catalogCurationUseConfirmed",
                  "futureBundledRedistributionConfirmed"
              ]),
              let fields = object["fields"] as? [[String: Any]],
              fields.allSatisfy({
                  hasKeys($0, ["field", "observationScreen"])
              }) else {
            return false
        }
        return true
    }

    private func hasKeys(
        _ object: [String: Any],
        _ keys: Set<String>
    ) -> Bool {
        Set(object.keys) == keys
    }
}
