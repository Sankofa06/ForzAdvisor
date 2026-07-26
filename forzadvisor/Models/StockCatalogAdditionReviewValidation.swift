//
//  StockCatalogAdditionReviewValidation.swift
//  forzadvisor
//

import CryptoKit
import Foundation

extension StockCatalogAdditionReviewExporter {
    func proposedEntry(
        preflight: StockCatalogCurationPreflight,
        identityRole: CatalogSourceRole
    ) throws -> CatalogCarEntry {
        let selection = preflight.selection
        let rights = preflight.identitySourceRightsReview
        guard let identityURL = URL(string: rights.sourceURL) else {
            throw StockCatalogAdditionReviewError
                .invalidProposedCatalog
        }
        let stockFields = CatalogDataField.allCases
            .filter { $0 != .identity }
            .sorted { $0.rawValue < $1.rawValue }
        return CatalogCarEntry(
            id: preflight.proposal.catalogID,
            game: selection.game,
            year: selection.vehicle.year,
            make: selection.vehicle.make,
            model: selection.vehicle.model,
            stock: selection.vehicle.stock,
            verificationStatus:
                preflight.proposal.verificationStatus,
            sources: [
                CatalogSource(
                    id: "identity-source",
                    title: rights.sourceTitle,
                    url: identityURL,
                    role: identityRole,
                    fields: [.identity]
                ),
                CatalogSource(
                    id: "first-party-observations",
                    title:
                        StockCatalogAdditionReviewPolicy
                        .firstPartySourceTitle,
                    url: nil,
                    role: .firstPartyObservation,
                    fields: stockFields
                )
            ]
        )
    }

    func hasValidStructure(
        _ value: StockCatalogAdditionReview
    ) -> Bool {
        value.schemaVersion
            == StockCatalogAdditionReview.currentSchemaVersion
            && value.policyVersion
                == StockCatalogAdditionReview.currentPolicyVersion
            && isDigest(value.preflightFingerprint)
            && isDigest(value.maintainerPacketDigest)
            && isDigest(value.baseCatalogDigest)
            && isDigest(value.candidateDigest)
            && isDigest(value.rightsSummary.evidenceSHA256)
            && value.rightsSummary.independentlyReviewed
            && value.confirmations.allConfirmed
            && value.proposedCatalogSnapshot.schemaVersion == 2
            && value.proposedCatalogSnapshot.entries.last
                == value.proposedEntry
            && value.automaticCatalogMutationPermitted == false
            && value.tuningActivationPermitted == false
            && value.legalSufficiencyEstablished == false
            && value.requiresManualBundleChange
            && value.reviewBoundary
                == StockCatalogAdditionReviewPolicy.reviewBoundary
            && value.privacyExclusions
                == StockCatalogAdditionReviewPolicy.privacyExclusions
            && isDigest(value.artifactFingerprint)
    }

    func fingerprint(
        for value: StockCatalogAdditionReview
    ) -> String {
        let unsigned = replacingFingerprint(in: value, with: "")
        guard let data = try? canonicalData(for: unsigned) else {
            return ""
        }
        var payload = Data(
            "forzadvisor.stock-catalog-addition-review.v1"
                .utf8
        )
        payload.append(0)
        payload.append(data)
        return SHA256.hash(data: payload)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    func replacingFingerprint(
        in value: StockCatalogAdditionReview,
        with fingerprint: String
    ) -> StockCatalogAdditionReview {
        .init(
            schemaVersion: value.schemaVersion,
            policyVersion: value.policyVersion,
            preflightFingerprint: value.preflightFingerprint,
            maintainerPacketDigest: value.maintainerPacketDigest,
            baseCatalogDigest: value.baseCatalogDigest,
            candidateDigest: value.candidateDigest,
            rightsSummary: value.rightsSummary,
            confirmations: value.confirmations,
            proposedEntry: value.proposedEntry,
            proposedCatalogSnapshot:
                value.proposedCatalogSnapshot,
            automaticCatalogMutationPermitted:
                value.automaticCatalogMutationPermitted,
            tuningActivationPermitted:
                value.tuningActivationPermitted,
            legalSufficiencyEstablished:
                value.legalSufficiencyEstablished,
            requiresManualBundleChange:
                value.requiresManualBundleChange,
            reviewBoundary: value.reviewBoundary,
            privacyExclusions: value.privacyExclusions,
            artifactFingerprint: fingerprint
        )
    }

    func canonicalData<T: Encodable>(
        for value: T
    ) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [
            .sortedKeys,
            .withoutEscapingSlashes
        ]
        return try encoder.encode(value)
    }

    static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    func isDigest(_ value: String) -> Bool {
        value.count == 64
            && value.allSatisfy {
                $0.isNumber || ("a"..."f").contains(
                    String($0)
                )
            }
    }

    func hasOnlyKnownJSONFields(_ data: Data) -> Bool {
        guard let root = try? JSONSerialization
                .jsonObject(with: data) as? [String: Any] else {
            return false
        }
        let rootKeys: Set<String> = [
            "schemaVersion", "policyVersion",
            "preflightFingerprint", "maintainerPacketDigest",
            "baseCatalogDigest", "candidateDigest",
            "rightsSummary", "confirmations", "proposedEntry",
            "proposedCatalogSnapshot",
            "automaticCatalogMutationPermitted",
            "tuningActivationPermitted",
            "legalSufficiencyEstablished",
            "requiresManualBundleChange", "reviewBoundary",
            "privacyExclusions", "artifactFingerprint"
        ]
        guard Set(root.keys) == rootKeys,
              exactKeys(
                root["rightsSummary"],
                [
                    "basis", "accessedOn", "evidenceSHA256",
                    "independentlyReviewed"
                ]
              ),
              exactKeys(
                root["confirmations"],
                [
                    "currentPreflightAndCatalogRevalidated",
                    "identityRoleReviewed",
                    "factsAndStatusReviewed",
                    "rightsSufficientForRelease",
                    "revisionAndDateApproved",
                    "manualBundleChangeUnderstood"
                ]
              ),
              validEntryJSON(root["proposedEntry"]),
              validCatalogJSON(
                root["proposedCatalogSnapshot"]
              ) else {
            return false
        }
        return true
    }

    func validCatalogJSON(_ value: Any?) -> Bool {
        guard let object = value as? [String: Any],
              Set(object.keys) == [
                  "schemaVersion", "revision", "reviewedAt",
                  "legacyEntryCount", "entries"
              ],
              let entries = object["entries"] as? [Any] else {
            return false
        }
        return entries.allSatisfy(validEntryJSON)
    }

    func validEntryJSON(_ value: Any?) -> Bool {
        guard let object = value as? [String: Any],
              Set(object.keys) == [
                  "id", "game", "year", "make", "model", "stock",
                  "verificationStatus", "sources"
              ],
              exactKeys(
                object["stock"],
                [
                    "performanceIndex", "performanceClass",
                    "drivetrain", "weightPounds",
                    "frontWeightPercent", "peakHorsepower",
                    "peakTorqueFootPounds"
                ]
              ),
              let sources = object["sources"] as? [Any] else {
            return false
        }
        return sources.allSatisfy { source in
            guard let sourceObject =
                    source as? [String: Any] else {
                return false
            }
            let allowed: Set<String> = [
                "id", "title", "url", "role", "fields"
            ]
            let required: Set<String> = [
                "id", "title", "role", "fields"
            ]
            return Set(sourceObject.keys).isSubset(of: allowed)
                && Set(sourceObject.keys).isSuperset(of: required)
        }
    }

    func exactKeys(
        _ value: Any?,
        _ keys: Set<String>
    ) -> Bool {
        guard let object = value as? [String: Any] else {
            return false
        }
        return Set(object.keys) == keys
    }
}
