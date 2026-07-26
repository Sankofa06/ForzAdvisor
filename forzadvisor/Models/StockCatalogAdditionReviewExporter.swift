//
//  StockCatalogAdditionReviewExporter.swift
//  forzadvisor
//

import Foundation

struct StockCatalogAdditionReviewExporter {
    static let maximumPayloadBytes = 1_024 * 1_024

    func makeArtifact(
        preflightCanonicalJSON: Data,
        packetCanonicalJSON: Data,
        baseCatalog: CarCatalogSnapshot,
        request: StockCatalogAdditionReviewRequest
    ) throws -> StockCatalogAdditionReviewArtifact {
        let preflight = try StockCatalogCurationPreflightExporter()
            .validate(
                preflightCanonicalJSON,
                packetCanonicalJSON: packetCanonicalJSON,
                baseCatalog: baseCatalog
            )
        guard preflight.proposal.verificationStatus
                == .communityCrossChecked
                || preflight.proposal.verificationStatus
                    == .inGameVerified else {
            throw StockCatalogAdditionReviewError.invalidStatus
        }
        guard request.identitySourceRole == .officialRoster
                || request.identitySourceRole == .communityQA else {
            throw StockCatalogAdditionReviewError.invalidIdentityRole
        }
        guard request.reviewedAt.timeIntervalSince1970.isFinite,
              request.reviewedAt > baseCatalog.reviewedAt else {
            throw StockCatalogAdditionReviewError.invalidReviewDate
        }
        guard request.confirmations.allConfirmed else {
            throw StockCatalogAdditionReviewError
                .incompleteConfirmations
        }

        let entry = try proposedEntry(
            preflight: preflight,
            identityRole: request.identitySourceRole
        )
        let proposedCatalog = CarCatalogSnapshot(
            schemaVersion: 2,
            revision: preflight.proposal.revision,
            reviewedAt: request.reviewedAt,
            legacyEntryCount: baseCatalog.entries.count,
            entries: baseCatalog.entries + [entry]
        )
        let proposedCatalogData = try canonicalData(
            for: proposedCatalog
        )
        guard case .success =
                BundledCarCatalog.load(data: proposedCatalogData),
              proposedCatalog.entries.count
                == baseCatalog.entries.count + 1,
              Array(proposedCatalog.entries.dropLast())
                == baseCatalog.entries else {
            throw StockCatalogAdditionReviewError
                .invalidProposedCatalog
        }

        let rights = preflight.identitySourceRightsReview
        let unsigned = StockCatalogAdditionReview(
            schemaVersion:
                StockCatalogAdditionReview.currentSchemaVersion,
            policyVersion:
                StockCatalogAdditionReview.currentPolicyVersion,
            preflightFingerprint: preflight.artifactFingerprint,
            maintainerPacketDigest:
                preflight.maintainerPacketDigest,
            baseCatalogDigest: preflight.baseCatalogDigest,
            candidateDigest: preflight.selection.candidateDigest,
            rightsSummary: .init(
                basis: rights.rightsBasis,
                accessedOn: rights.accessedOn,
                evidenceSHA256: rights.rightsEvidenceSHA256,
                independentlyReviewed:
                    rights.rightsIndependentlyReviewed
            ),
            confirmations: request.confirmations,
            proposedEntry: entry,
            proposedCatalogSnapshot: proposedCatalog,
            automaticCatalogMutationPermitted: false,
            tuningActivationPermitted: false,
            legalSufficiencyEstablished: false,
            requiresManualBundleChange: true,
            reviewBoundary:
                StockCatalogAdditionReviewPolicy.reviewBoundary,
            privacyExclusions:
                StockCatalogAdditionReviewPolicy.privacyExclusions,
            artifactFingerprint: ""
        )
        let review = replacingFingerprint(
            in: unsigned,
            with: fingerprint(for: unsigned)
        )
        let data = try canonicalData(for: review)
        guard data.count <= Self.maximumPayloadBytes else {
            throw StockCatalogAdditionReviewError.payloadTooLarge
        }
        return .init(review: review, canonicalJSON: data)
    }

    func validate(
        _ data: Data,
        preflightCanonicalJSON: Data,
        packetCanonicalJSON: Data,
        baseCatalog: CarCatalogSnapshot
    ) throws -> StockCatalogAdditionReview {
        guard !data.isEmpty else {
            throw StockCatalogAdditionReviewError.emptyPayload
        }
        guard data.count <= Self.maximumPayloadBytes else {
            throw StockCatalogAdditionReviewError.payloadTooLarge
        }
        guard hasOnlyKnownJSONFields(data) else {
            throw StockCatalogAdditionReviewError.unknownFields
        }
        let decoded: StockCatalogAdditionReview
        do {
            decoded = try Self.decoder.decode(
                StockCatalogAdditionReview.self,
                from: data
            )
        } catch {
            throw StockCatalogAdditionReviewError.invalidJSON
        }
        guard (try? canonicalData(for: decoded)) == data else {
            throw StockCatalogAdditionReviewError.nonCanonicalJSON
        }
        guard hasValidStructure(decoded) else {
            throw StockCatalogAdditionReviewError.invalidStructure
        }
        guard fingerprint(for: decoded)
                == decoded.artifactFingerprint else {
            throw StockCatalogAdditionReviewError
                .invalidFingerprint
        }
        guard let identityRole = decoded.proposedEntry.sources
                .first(where: { $0.id == "identity-source" })?
                .role else {
            throw StockCatalogAdditionReviewError.invalidStructure
        }
        let expected = try makeArtifact(
            preflightCanonicalJSON: preflightCanonicalJSON,
            packetCanonicalJSON: packetCanonicalJSON,
            baseCatalog: baseCatalog,
            request: .init(
                reviewedAt:
                    decoded.proposedCatalogSnapshot.reviewedAt,
                identitySourceRole: identityRole,
                confirmations: decoded.confirmations
            )
        )
        guard expected.canonicalJSON == data else {
            throw StockCatalogAdditionReviewError.bindingMismatch
        }
        return decoded
    }
}
