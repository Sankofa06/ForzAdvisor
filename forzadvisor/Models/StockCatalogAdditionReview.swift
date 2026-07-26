//
//  StockCatalogAdditionReview.swift
//  forzadvisor
//
//  Release-review-only proposal derived from an exact curation preflight.
//  This artifact never writes the bundled catalog or activates tuning.
//

import CryptoKit
import Foundation

enum StockCatalogAdditionReviewError:
    Error, Equatable, LocalizedError {
    case invalidStatus
    case invalidIdentityRole
    case invalidReviewDate
    case incompleteConfirmations
    case invalidProposedCatalog
    case emptyPayload
    case payloadTooLarge
    case invalidJSON
    case unknownFields
    case nonCanonicalJSON
    case invalidStructure
    case invalidFingerprint
    case bindingMismatch

    var errorDescription: String? {
        switch self {
        case .invalidStatus:
            "Observation-derived stock facts require a community-crosschecked or in-game-verified proposed status."
        case .invalidIdentityRole:
            "Choose an official-roster or community-QA role for the reviewed HTTPS identity source."
        case .invalidReviewDate:
            "Choose a finite release-review date after the current catalog review date."
        case .incompleteConfirmations:
            "Complete all six independent release-review confirmations."
        case .invalidProposedCatalog:
            "The derived schema-v2 catalog proposal failed the bundled catalog contract."
        case .emptyPayload:
            "Use a prepared catalog addition review."
        case .payloadTooLarge:
            "The catalog addition review exceeds the 1 MiB limit."
        case .invalidJSON:
            "This is not a readable catalog addition review."
        case .unknownFields:
            "This catalog addition review contains fields outside its public schema."
        case .nonCanonicalJSON:
            "Use the exact canonical catalog addition review exported by ForzAdvisor."
        case .invalidStructure:
            "This catalog addition review failed its schema, privacy, or release-only boundary."
        case .invalidFingerprint:
            "This catalog addition review's integrity fingerprint does not match its contents."
        case .bindingMismatch:
            "This catalog addition review no longer matches the exact preflight, packet, or current catalog."
        }
    }
}

struct StockCatalogAdditionReviewConfirmations:
    Codable, Equatable, Sendable {
    var currentPreflightAndCatalogRevalidated: Bool
    var identityRoleReviewed: Bool
    var factsAndStatusReviewed: Bool
    var rightsSufficientForRelease: Bool
    var revisionAndDateApproved: Bool
    var manualBundleChangeUnderstood: Bool

    static let empty = Self(
        currentPreflightAndCatalogRevalidated: false,
        identityRoleReviewed: false,
        factsAndStatusReviewed: false,
        rightsSufficientForRelease: false,
        revisionAndDateApproved: false,
        manualBundleChangeUnderstood: false
    )

    static let complete = Self(
        currentPreflightAndCatalogRevalidated: true,
        identityRoleReviewed: true,
        factsAndStatusReviewed: true,
        rightsSufficientForRelease: true,
        revisionAndDateApproved: true,
        manualBundleChangeUnderstood: true
    )

    var allConfirmed: Bool {
        self == .complete
    }
}

struct StockCatalogAdditionReviewRequest: Sendable {
    let reviewedAt: Date
    let identitySourceRole: CatalogSourceRole
    let confirmations: StockCatalogAdditionReviewConfirmations
}

struct StockCatalogAdditionRightsSummary:
    Codable, Equatable, Sendable {
    let basis: StockCatalogIdentityRightsBasis
    let accessedOn: String
    let evidenceSHA256: String
    let independentlyReviewed: Bool
}

struct StockCatalogAdditionReview:
    Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1
    static let currentPolicyVersion =
        "stock-catalog-addition-release-review-v1"

    let schemaVersion: Int
    let policyVersion: String
    let preflightFingerprint: String
    let maintainerPacketDigest: String
    let baseCatalogDigest: String
    let candidateDigest: String
    let rightsSummary: StockCatalogAdditionRightsSummary
    let confirmations: StockCatalogAdditionReviewConfirmations
    let proposedEntry: CatalogCarEntry
    let proposedCatalogSnapshot: CarCatalogSnapshot
    let automaticCatalogMutationPermitted: Bool
    let tuningActivationPermitted: Bool
    let legalSufficiencyEstablished: Bool
    let requiresManualBundleChange: Bool
    let reviewBoundary: String
    let privacyExclusions: [String]
    let artifactFingerprint: String
}

struct StockCatalogAdditionReviewArtifact: Sendable {
    let review: StockCatalogAdditionReview
    let canonicalJSON: Data
}

enum StockCatalogAdditionReviewPolicy {
    static let firstPartySourceTitle =
        "Permission-bound first-party in-game observations"
    static let reviewBoundary =
        "Release review proposal only. This artifact does not establish legal sufficiency, approve or write a bundled catalog, add a live car, or activate tuning. A maintainer must make the resource change and run the catalog and tuning release gates separately."
    static let privacyExclusions = [
        "account-identifiers",
        "admin-identifiers",
        "canonical-contribution-json",
        "device-data",
        "local-review-identifiers",
        "local-review-times",
        "location",
        "observation-digests",
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
