//
//  StockCatalogCurationPreflight.swift
//  forzadvisor
//
//  Canonical, review-only evidence for a prospective catalog addition.
//  A preflight cannot create a catalog entry or activate tuning.
//

import CryptoKit
import Foundation

enum StockCatalogCurationPreflightError:
    Error, Equatable, LocalizedError {
    case invalidPacket
    case candidateNotFound
    case candidateNotEligible
    case insufficientEvidence
    case invalidFieldDecisions
    case invalidSourceRightsReview
    case invalidProposal
    case invalidBaseCatalog
    case emptyPayload
    case payloadTooLarge
    case invalidJSON
    case unknownFields
    case nonCanonicalJSON
    case invalidStructure
    case invalidFingerprint
    case packetBindingMismatch
    case catalogBindingMismatch
    case candidateBindingMismatch

    var errorDescription: String? {
        switch self {
        case .invalidPacket:
            "Use an exact canonical maintainer review packet."
        case .candidateNotFound:
            "Explicitly select one candidate group and variant from the packet."
        case .candidateNotEligible:
            "Only a non-conflicting candidate absent from the base catalog can enter preflight."
        case .insufficientEvidence:
            "At least two distinct, permission-complete observations must support every stock field."
        case .invalidFieldDecisions:
            "Record exactly one canonically ordered decision for every stock field using only the selected candidate's complete evidence."
        case .invalidSourceRightsReview:
            "Complete a compatible-license or explicit-permission identity-source review with safe HTTPS evidence."
        case .invalidProposal:
            "Enter a safe game-prefixed catalog ID, a new revision, and a prospective verification status."
        case .invalidBaseCatalog:
            "The exact base catalog cannot be canonically bound."
        case .emptyPayload: "Paste a curation preflight first."
        case .payloadTooLarge:
            "The curation preflight exceeds the 256 KiB limit."
        case .invalidJSON:
            "This is not a readable curation preflight."
        case .unknownFields:
            "This preflight contains fields outside the public schema."
        case .nonCanonicalJSON:
            "Use the exact canonical preflight exported by ForzAdvisor."
        case .invalidStructure:
            "This preflight failed its schema, ordering, safety, privacy, or policy checks."
        case .invalidFingerprint:
            "This preflight's integrity fingerprint does not match its review data."
        case .packetBindingMismatch:
            "This preflight does not bind the supplied exact maintainer packet."
        case .catalogBindingMismatch:
            "This preflight does not bind the supplied exact base catalog."
        case .candidateBindingMismatch:
            "The selected candidate no longer matches the bound maintainer packet."
        }
    }
}

enum StockCatalogIdentityRightsBasis:
    String, CaseIterable, Codable, Identifiable, Sendable {
    case compatibleLicense
    case explicitPermission

    var id: String { rawValue }

    var label: String {
        switch self {
        case .compatibleLicense: "Compatible license"
        case .explicitPermission: "Explicit permission"
        }
    }
}

struct StockCatalogIdentitySourceRightsReview:
    Codable, Equatable, Sendable {
    let sourceTitle: String
    let sourceURL: String
    let accessedOn: String
    let rightsBasis: StockCatalogIdentityRightsBasis
    let rightsEvidenceReference: String
    let rightsEvidenceSHA256: String
    let rightsIndependentlyReviewed: Bool
    let noSourceFactsCopied: Bool
    let noSourceProseCopied: Bool
    let noSourceMediaCopied: Bool
}

struct StockCatalogCurationFieldDecision:
    Codable, Equatable, Sendable {
    let field: CatalogDataField
    let observationDigests: [String]
}

struct StockCatalogCurationProposal:
    Codable, Equatable, Sendable {
    let catalogID: String
    let revision: String
    let verificationStatus: CatalogVerificationStatus
}

struct StockCatalogCurationSelection:
    Codable, Equatable, Sendable {
    let groupID: String
    let variantID: String
    let candidateDigest: String
    let game: ForzaGame
    let gameVersion: String
    let platform: StockContributionPlatform
    let vehicle: StockCatalogContributionVehicle
    let observationDigests: [String]
}

struct StockCatalogCurationPreflight:
    Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1
    static let currentPolicyVersion =
        "stock-catalog-curation-preflight-v1"

    let schemaVersion: Int
    let policyVersion: String
    let maintainerPacketDigest: String
    let baseCatalogDigest: String
    let selection: StockCatalogCurationSelection
    let fieldDecisions: [StockCatalogCurationFieldDecision]
    let identitySourceRightsReview:
        StockCatalogIdentitySourceRightsReview
    let proposal: StockCatalogCurationProposal
    let automaticCatalogMutationPermitted: Bool
    let tuningActivationPermitted: Bool
    let requiresSeparateReleaseReview: Bool
    let reviewBoundary: String
    let privacyExclusions: [String]
    let artifactFingerprint: String
}

struct StockCatalogCurationPreflightArtifact: Sendable {
    let preflight: StockCatalogCurationPreflight
    let canonicalJSON: Data
}

struct StockCatalogCurationPreflightRequest: Sendable {
    let groupID: String
    let variantID: String
    let fieldDecisions: [StockCatalogCurationFieldDecision]
    let identitySourceRightsReview:
        StockCatalogIdentitySourceRightsReview
    let proposal: StockCatalogCurationProposal
    let allPermissionedEvidenceUsedForEveryField: Bool
    let separateReleaseReviewConfirmed: Bool
}

enum StockCatalogCurationPreflightPolicy {
    static let reviewBoundary =
        "Prospective review evidence only. This preflight does not establish legal sufficiency, verify a candidate, change a bundled catalog, create a catalog entry, or activate tuning. A separate release review must independently decide source sufficiency, catalog verification, and any catalog change."

    static let privacyExclusions = [
        "admin-identifiers",
        "canonical-contribution-json",
        "device-data",
        "local-review-identifiers",
        "local-review-times",
        "permission-receipt-identifiers",
        "provider-configuration",
        "raw-contribution-json",
        "rulesets",
        "screenshots",
        "source-media",
        "source-prose",
        "submission-identifiers",
        "tune-values"
    ]
}

struct StockCatalogCurationPreflightExporter {
    static let maximumPayloadBytes = 256 * 1_024

    func makeArtifact(
        packetCanonicalJSON: Data,
        baseCatalog: CarCatalogSnapshot,
        request: StockCatalogCurationPreflightRequest
    ) throws -> StockCatalogCurationPreflightArtifact {
        let packet = try validatedPacket(packetCanonicalJSON)
        let baseData = try canonicalCatalogData(baseCatalog)
        guard packet.baseCatalog.schemaVersion == baseCatalog.schemaVersion,
              packet.baseCatalog.revision == baseCatalog.revision,
              packet.baseCatalog.reviewedAt == baseCatalog.reviewedAt else {
            throw StockCatalogCurationPreflightError
                .catalogBindingMismatch
        }
        let candidate = try selectedCandidate(
            in: packet,
            groupID: request.groupID,
            variantID: request.variantID
        )
        try validateCandidate(candidate)
        try validateCandidateIdentityIsAbsent(
            candidate,
            in: baseCatalog
        )
        guard request.allPermissionedEvidenceUsedForEveryField,
              request.separateReleaseReviewConfirmed else {
            throw StockCatalogCurationPreflightError
                .invalidStructure
        }
        try validateFieldDecisions(
            request.fieldDecisions,
            candidate: candidate
        )
        try validateSourceRightsReview(
            request.identitySourceRightsReview
        )
        try validateProposal(
            request.proposal,
            game: candidate.variant.game,
            baseCatalog: baseCatalog
        )

        let unsigned = StockCatalogCurationPreflight(
            schemaVersion:
                StockCatalogCurationPreflight.currentSchemaVersion,
            policyVersion:
                StockCatalogCurationPreflight.currentPolicyVersion,
            maintainerPacketDigest: domainHash(
                domain:
                    "forzadvisor.stock-curation.packet.v1",
                data: packetCanonicalJSON
            ),
            baseCatalogDigest: domainHash(
                domain:
                    "forzadvisor.stock-curation.catalog.v1",
                data: baseData
            ),
            selection: makeSelection(candidate),
            fieldDecisions: request.fieldDecisions,
            identitySourceRightsReview:
                request.identitySourceRightsReview,
            proposal: request.proposal,
            automaticCatalogMutationPermitted: false,
            tuningActivationPermitted: false,
            requiresSeparateReleaseReview: true,
            reviewBoundary:
                StockCatalogCurationPreflightPolicy.reviewBoundary,
            privacyExclusions:
                StockCatalogCurationPreflightPolicy
                .privacyExclusions,
            artifactFingerprint: ""
        )
        guard hasValidStructure(unsigned, allowEmptyFingerprint: true) else {
            throw StockCatalogCurationPreflightError.invalidStructure
        }
        let preflight = replacingFingerprint(
            in: unsigned,
            with: fingerprint(for: unsigned)
        )
        let data = try canonicalData(for: preflight)
        guard data.count <= Self.maximumPayloadBytes else {
            throw StockCatalogCurationPreflightError.payloadTooLarge
        }
        return .init(preflight: preflight, canonicalJSON: data)
    }

    func validate(
        _ data: Data,
        packetCanonicalJSON: Data,
        baseCatalog: CarCatalogSnapshot
    ) throws -> StockCatalogCurationPreflight {
        guard !data.isEmpty else {
            throw StockCatalogCurationPreflightError.emptyPayload
        }
        guard data.count <= Self.maximumPayloadBytes else {
            throw StockCatalogCurationPreflightError.payloadTooLarge
        }
        guard hasOnlyKnownJSONFields(data) else {
            throw StockCatalogCurationPreflightError.unknownFields
        }
        let preflight: StockCatalogCurationPreflight
        do {
            preflight = try Self.decoder.decode(
                StockCatalogCurationPreflight.self,
                from: data
            )
        } catch {
            throw StockCatalogCurationPreflightError.invalidJSON
        }
        guard (try? canonicalData(for: preflight)) == data else {
            throw StockCatalogCurationPreflightError
                .nonCanonicalJSON
        }
        guard hasValidStructure(preflight) else {
            throw StockCatalogCurationPreflightError
                .invalidStructure
        }
        guard fingerprint(for: preflight)
                == preflight.artifactFingerprint else {
            throw StockCatalogCurationPreflightError
                .invalidFingerprint
        }

        let packet = try validatedPacket(packetCanonicalJSON)
        guard preflight.maintainerPacketDigest == domainHash(
            domain: "forzadvisor.stock-curation.packet.v1",
            data: packetCanonicalJSON
        ) else {
            throw StockCatalogCurationPreflightError
                .packetBindingMismatch
        }
        let catalogData = try canonicalCatalogData(baseCatalog)
        guard preflight.baseCatalogDigest == domainHash(
            domain: "forzadvisor.stock-curation.catalog.v1",
            data: catalogData
        ),
        packet.baseCatalog.schemaVersion == baseCatalog.schemaVersion,
        packet.baseCatalog.revision == baseCatalog.revision,
        packet.baseCatalog.reviewedAt == baseCatalog.reviewedAt else {
            throw StockCatalogCurationPreflightError
                .catalogBindingMismatch
        }

        let candidate = try selectedCandidate(
            in: packet,
            groupID: preflight.selection.groupID,
            variantID: preflight.selection.variantID
        )
        try validateCandidate(candidate)
        try validateCandidateIdentityIsAbsent(
            candidate,
            in: baseCatalog
        )
        guard preflight.selection == makeSelection(candidate) else {
            throw StockCatalogCurationPreflightError
                .candidateBindingMismatch
        }
        try validateFieldDecisions(
            preflight.fieldDecisions,
            candidate: candidate
        )
        try validateSourceRightsReview(
            preflight.identitySourceRightsReview
        )
        try validateProposal(
            preflight.proposal,
            game: candidate.variant.game,
            baseCatalog: baseCatalog
        )
        return preflight
    }

    private typealias Candidate =
        (groupID: String, variant: StockCatalogMaintainerEvidenceVariant)

    private func validatedPacket(
        _ data: Data
    ) throws -> StockCatalogMaintainerReviewPacket {
        do {
            return try StockCatalogMaintainerReviewPacketExporter()
                .validate(data)
        } catch {
            throw StockCatalogCurationPreflightError.invalidPacket
        }
    }

    private func selectedCandidate(
        in packet: StockCatalogMaintainerReviewPacket,
        groupID: String,
        variantID: String
    ) throws -> Candidate {
        guard isDigest(groupID), isDigest(variantID),
              let candidate = packet.candidates.first(where: {
                  $0.groupID == groupID
                      && $0.variant.variantID == variantID
              }) else {
            throw StockCatalogCurationPreflightError
                .candidateNotFound
        }
        return (candidate.groupID, candidate.variant)
    }

    private func validateCandidate(_ candidate: Candidate) throws {
        let variant = candidate.variant
        guard variant.catalogComparison.status == .absent,
              variant.catalogComparison.existingEntryIDs.isEmpty,
              variant.catalogComparison.differingFields.isEmpty else {
            throw StockCatalogCurationPreflightError
                .candidateNotEligible
        }
        let observations = variant.observations
        guard observations.count >= 2,
              Set(observations.map(\.observationDigest)).count
                == observations.count,
              observations.allSatisfy(\.permission.isComplete) else {
            throw StockCatalogCurationPreflightError
                .insufficientEvidence
        }
    }

    private func validateCandidateIdentityIsAbsent(
        _ candidate: Candidate,
        in baseCatalog: CarCatalogSnapshot
    ) throws {
        let variant = candidate.variant
        let matchingIdentityExists = baseCatalog.entries.contains {
            $0.game == variant.game
                && $0.year == variant.vehicle.year
                && StockCatalogContributionIngestor
                    .comparisonNormalizedString($0.make)
                    == StockCatalogContributionIngestor
                    .comparisonNormalizedString(
                        variant.vehicle.make
                    )
                && StockCatalogContributionIngestor
                    .comparisonNormalizedString($0.model)
                    == StockCatalogContributionIngestor
                    .comparisonNormalizedString(
                        variant.vehicle.model
                    )
        }
        guard !matchingIdentityExists else {
            throw StockCatalogCurationPreflightError
                .candidateNotEligible
        }
    }

    private func validateFieldDecisions(
        _ decisions: [StockCatalogCurationFieldDecision],
        candidate: Candidate
    ) throws {
        let expected = StockCatalogContributionValidator
            .expectedFields
        guard decisions.map(\.field) == expected,
              Set(decisions.map(\.field)).count == expected.count else {
            throw StockCatalogCurationPreflightError
                .invalidFieldDecisions
        }
        for decision in decisions {
            let supporting = candidate.variant.observations
                .filter {
                    $0.permission.isComplete
                        && $0.fields.contains {
                            $0.field == decision.field
                        }
                }
                .map(\.observationDigest)
                .sorted()
            guard supporting.count >= 2,
                  Set(supporting).count == supporting.count,
                  decision.observationDigests == supporting else {
                throw StockCatalogCurationPreflightError
                    .invalidFieldDecisions
            }
        }
    }

    private func validateSourceRightsReview(
        _ review: StockCatalogIdentitySourceRightsReview
    ) throws {
        guard safeString(review.sourceTitle, maximumLength: 160),
              safeHTTPSURL(review.sourceURL),
              validCalendarDate(review.accessedOn),
              safeString(
                  review.rightsEvidenceReference,
                  maximumLength: 240
              ),
              isDigest(review.rightsEvidenceSHA256),
              review.rightsIndependentlyReviewed,
              review.noSourceFactsCopied,
              review.noSourceProseCopied,
              review.noSourceMediaCopied else {
            throw StockCatalogCurationPreflightError
                .invalidSourceRightsReview
        }
    }

    private func validateProposal(
        _ proposal: StockCatalogCurationProposal,
        game: ForzaGame,
        baseCatalog: CarCatalogSnapshot
    ) throws {
        let prefix = "\(game.rawValue)-"
        guard safeSlug(proposal.catalogID),
              proposal.catalogID.hasPrefix(prefix),
              proposal.catalogID.count > prefix.count,
              safeString(proposal.revision, maximumLength: 120),
              proposal.revision != baseCatalog.revision,
              !baseCatalog.entries.contains(where: {
                  $0.id == proposal.catalogID
              }) else {
            throw StockCatalogCurationPreflightError
                .invalidProposal
        }
    }

    private func makeSelection(
        _ candidate: Candidate
    ) -> StockCatalogCurationSelection {
        .init(
            groupID: candidate.groupID,
            variantID: candidate.variant.variantID,
            candidateDigest: candidateDigest(candidate.variant),
            game: candidate.variant.game,
            gameVersion: candidate.variant.gameVersion,
            platform: candidate.variant.platform,
            vehicle: candidate.variant.vehicle,
            observationDigests:
                candidate.variant.observations
                .map(\.observationDigest)
                .sorted()
        )
    }

    private func candidateDigest(
        _ candidate: StockCatalogMaintainerEvidenceVariant
    ) -> String {
        guard let data = try? canonicalData(for: candidate) else {
            return ""
        }
        return domainHash(
            domain: "forzadvisor.stock-curation.candidate.v1",
            data: data
        )
    }

    private func hasValidStructure(
        _ value: StockCatalogCurationPreflight,
        allowEmptyFingerprint: Bool = false
    ) -> Bool {
        value.schemaVersion
            == StockCatalogCurationPreflight.currentSchemaVersion
            && value.policyVersion
                == StockCatalogCurationPreflight
                .currentPolicyVersion
            && isDigest(value.maintainerPacketDigest)
            && isDigest(value.baseCatalogDigest)
            && isDigest(value.selection.groupID)
            && isDigest(value.selection.variantID)
            && isDigest(value.selection.candidateDigest)
            && safeString(
                value.selection.gameVersion,
                maximumLength: 120
            )
            && safeVehicle(value.selection.vehicle)
            && value.selection.observationDigests
                == value.selection.observationDigests.sorted()
            && Set(value.selection.observationDigests).count
                == value.selection.observationDigests.count
            && value.selection.observationDigests.count >= 2
            && value.selection.observationDigests.allSatisfy(isDigest)
            && value.fieldDecisions.map(\.field)
                == StockCatalogContributionValidator.expectedFields
            && value.fieldDecisions.allSatisfy {
                $0.observationDigests
                    == $0.observationDigests.sorted()
                    && Set($0.observationDigests).count
                        == $0.observationDigests.count
                    && $0.observationDigests.count >= 2
                    && $0.observationDigests.allSatisfy(isDigest)
            }
            && value.automaticCatalogMutationPermitted == false
            && value.tuningActivationPermitted == false
            && value.requiresSeparateReleaseReview
            && value.reviewBoundary
                == StockCatalogCurationPreflightPolicy
                .reviewBoundary
            && value.privacyExclusions
                == StockCatalogCurationPreflightPolicy
                .privacyExclusions
            && (
                allowEmptyFingerprint
                    ? value.artifactFingerprint.isEmpty
                    : isDigest(value.artifactFingerprint)
            )
    }

    private func safeVehicle(
        _ vehicle: StockCatalogContributionVehicle
    ) -> Bool {
        StockCatalogVehicleYearPolicy.allows(vehicle.year)
            && safeString(vehicle.make, maximumLength: 120)
            && safeString(vehicle.model, maximumLength: 160)
    }

    private func safeHTTPSURL(_ value: String) -> Bool {
        guard safeString(value, maximumLength: 500),
              let components = URLComponents(string: value),
              components.scheme?.lowercased() == "https",
              let host = components.host, !host.isEmpty,
              components.user == nil,
              components.password == nil,
              components.fragment == nil,
              components.url?.absoluteString == value else {
            return false
        }
        return true
    }

    private func validCalendarDate(_ value: String) -> Bool {
        guard value.count == 10 else { return false }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        guard let date = formatter.date(from: value) else {
            return false
        }
        return formatter.string(from: date) == value
    }

    private func safeSlug(_ value: String) -> Bool {
        guard (5...200).contains(value.count),
              value.first != "-", value.last != "-",
              !value.contains("--") else {
            return false
        }
        return value.allSatisfy {
            $0.isASCII && ($0.isLowercase || $0.isNumber || $0 == "-")
        }
    }

    private func safeString(
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

    private func isDigest(_ value: String) -> Bool {
        value.count == 64
            && value.allSatisfy {
                $0.isNumber || ("a"..."f").contains($0)
            }
    }

    private func canonicalCatalogData(
        _ catalog: CarCatalogSnapshot
    ) throws -> Data {
        guard catalog.schemaVersion
                == BundledCarCatalog.supportedSchemaVersion,
              safeString(catalog.revision, maximumLength: 120),
              catalog.reviewedAt.timeIntervalSince1970.isFinite,
              catalog.entries.allSatisfy({
                  safeSlug($0.id)
                      && safeString($0.make, maximumLength: 120)
                      && safeString($0.model, maximumLength: 160)
              }),
              Set(catalog.entries.map(\.id)).count
                == catalog.entries.count else {
            throw StockCatalogCurationPreflightError
                .invalidBaseCatalog
        }
        let normalized = CarCatalogSnapshot(
            schemaVersion: catalog.schemaVersion,
            revision: catalog.revision,
            reviewedAt: catalog.reviewedAt,
            entries: catalog.entries.map { entry in
                CatalogCarEntry(
                    id: entry.id,
                    game: entry.game,
                    year: entry.year,
                    make: entry.make,
                    model: entry.model,
                    stock: entry.stock,
                    verificationStatus: entry.verificationStatus,
                    sources: entry.sources.map { source in
                        CatalogSource(
                            id: source.id,
                            title: source.title,
                            url: source.url,
                            role: source.role,
                            fields: source.fields.sorted {
                                $0.rawValue < $1.rawValue
                            }
                        )
                    }.sorted { $0.id < $1.id }
                )
            }.sorted { $0.id < $1.id }
        )
        let data = try canonicalData(for: normalized)
        guard case .success = BundledCarCatalog.load(data: data) else {
            throw StockCatalogCurationPreflightError
                .invalidBaseCatalog
        }
        return data
    }

    private func fingerprint(
        for preflight: StockCatalogCurationPreflight
    ) -> String {
        let unsigned = replacingFingerprint(
            in: preflight,
            with: ""
        )
        guard let data = try? canonicalData(for: unsigned) else {
            return ""
        }
        return domainHash(
            domain: "forzadvisor.stock-curation.preflight.v1",
            data: data
        )
    }

    private func replacingFingerprint(
        in value: StockCatalogCurationPreflight,
        with fingerprint: String
    ) -> StockCatalogCurationPreflight {
        .init(
            schemaVersion: value.schemaVersion,
            policyVersion: value.policyVersion,
            maintainerPacketDigest: value.maintainerPacketDigest,
            baseCatalogDigest: value.baseCatalogDigest,
            selection: value.selection,
            fieldDecisions: value.fieldDecisions,
            identitySourceRightsReview:
                value.identitySourceRightsReview,
            proposal: value.proposal,
            automaticCatalogMutationPermitted:
                value.automaticCatalogMutationPermitted,
            tuningActivationPermitted:
                value.tuningActivationPermitted,
            requiresSeparateReleaseReview:
                value.requiresSeparateReleaseReview,
            reviewBoundary: value.reviewBoundary,
            privacyExclusions: value.privacyExclusions,
            artifactFingerprint: fingerprint
        )
    }

    private func canonicalData<T: Encodable>(
        for value: T
    ) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .sortedKeys, .prettyPrinted, .withoutEscapingSlashes
        ]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(value)
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
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
                  "schemaVersion", "policyVersion",
                  "maintainerPacketDigest", "baseCatalogDigest",
                  "selection", "fieldDecisions",
                  "identitySourceRightsReview", "proposal",
                  "automaticCatalogMutationPermitted",
                  "tuningActivationPermitted",
                  "requiresSeparateReleaseReview",
                  "reviewBoundary", "privacyExclusions",
                  "artifactFingerprint"
              ]),
              let selection = object["selection"] as? [String: Any],
              hasKeys(selection, [
                  "groupID", "variantID", "candidateDigest",
                  "game", "gameVersion", "platform", "vehicle",
                  "observationDigests"
              ]),
              validVehicleJSON(selection["vehicle"]),
              let decisions =
                object["fieldDecisions"] as? [[String: Any]],
              decisions.allSatisfy({
                  hasKeys(
                      $0,
                      ["field", "observationDigests"]
                  )
              }),
              let rights =
                object["identitySourceRightsReview"]
                as? [String: Any],
              hasKeys(rights, [
                  "sourceTitle", "sourceURL", "accessedOn",
                  "rightsBasis", "rightsEvidenceReference",
                  "rightsEvidenceSHA256",
                  "rightsIndependentlyReviewed",
                  "noSourceFactsCopied", "noSourceProseCopied",
                  "noSourceMediaCopied"
              ]),
              let proposal = object["proposal"] as? [String: Any],
              hasKeys(proposal, [
                  "catalogID", "revision", "verificationStatus"
              ]) else {
            return false
        }
        return true
    }

    private func validVehicleJSON(_ value: Any?) -> Bool {
        guard let object = value as? [String: Any],
              hasKeys(object, ["year", "make", "model", "stock"]),
              let stock = object["stock"] as? [String: Any],
              hasKeys(stock, [
                  "performanceIndex", "performanceClass",
                  "drivetrain", "weightPounds",
                  "frontWeightPercent", "peakHorsepower",
                  "peakTorqueFootPounds"
              ]) else {
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
