//
//  FH5NumericPromotionReviewPacket.swift
//  forzadvisor
//
//  Canonical, review-only packaging for permission-bound FH5 candidate
//  outcomes. A valid packet is eligible for independent maintainer review;
//  it never registers a production ruleset or authorizes numeric output.
//

import CryptoKit
import Foundation

enum FH5NumericPromotionReviewPacketError:
    Error,
    LocalizedError,
    Equatable,
    Sendable {
    case tooManyLocalRecords
    case tooManyReviewedEntries
    case invalidPreparedInput
    case invalidLocalEvidence
    case invalidReviewedEvidence
    case staleOrForeignCandidate
    case unregisteredCandidate
    case submissionConflict
    case permissionReceiptReplay
    case sessionSemanticReplay
    case duplicateAmbiguity
    case insufficientEvidence
    case emptyPayload
    case payloadTooLarge
    case invalidJSON
    case unknownRootField
    case nonCanonicalJSON
    case invalidStructure
    case invalidArtifactFingerprint

    var errorDescription: String? {
        switch self {
        case .tooManyLocalRecords:
            "A promotion review packet accepts at most 250 local records."
        case .tooManyReviewedEntries:
            "A promotion review packet accepts at most 250 reviewed entries."
        case .invalidPreparedInput:
            "The supplied promotion-review input could not be fingerprinted exactly."
        case .invalidLocalEvidence:
            "A supplied candidate-bound local record failed its integrity or permission checks."
        case .invalidReviewedEvidence:
            "A supplied reviewed outcome failed its review receipt or export integrity checks."
        case .staleOrForeignCandidate:
            "The packet does not match the freshly supplied experimental candidate."
        case .unregisteredCandidate:
            "The candidate is not in the code-owned experimental collection registry."
        case .submissionConflict:
            "Two exact-candidate outcomes conflict under one submission identifier."
        case .permissionReceiptReplay:
            "A permission receipt was replayed across distinct exact-candidate outcomes."
        case .sessionSemanticReplay:
            "One exact-candidate test session was replayed under distinct identifiers."
        case .duplicateAmbiguity:
            "Duplicate exact-candidate outcome bytes must be resolved before review."
        case .insufficientEvidence:
            "The exact candidate does not meet the fixed controlled-outcome threshold."
        case .emptyPayload:
            "Select an FH5 Numeric Promotion Review packet first."
        case .payloadTooLarge:
            "The FH5 Numeric Promotion Review packet exceeds the 4 MiB limit."
        case .invalidJSON:
            "This is not a readable FH5 Numeric Promotion Review packet."
        case .unknownRootField:
            "The packet contains an unknown or missing top-level field."
        case .nonCanonicalJSON:
            "The packet is not the exact canonical JSON produced by ForzAdvisor."
        case .invalidStructure:
            "The packet failed its fixed structure, evidence, threshold, or safety-boundary checks."
        case .invalidArtifactFingerprint:
            "The packet artifact fingerprint does not match its contents."
        }
    }
}

enum FH5NumericPromotionReviewStatus: String, Codable, Equatable, Sendable {
    case eligibleForMaintainerReview
}

enum FH5NumericPromotionEvidenceProvenance:
    String,
    Codable,
    Equatable,
    Sendable {
    case local
    case reviewed

    fileprivate var sortOrder: Int {
        switch self {
        case .local: 0
        case .reviewed: 1
        }
    }
}

struct FH5NumericPromotionReviewEvidence:
    Codable,
    Equatable,
    Sendable {
    let provenance: FH5NumericPromotionEvidenceProvenance
    let canonicalExport: FH5CandidateOutcomeExport
    let canonicalExportDigest: String
    let trialSemanticFingerprint: String
    let trialSessionFingerprint: String
}

struct FH5NumericPromotionReviewCounts: Codable, Equatable, Sendable {
    let uniqueSessionCount: Int
    let localCount: Int
    let reviewedCount: Int
    let variantPreferredCount: Int
    let noClearDifferenceCount: Int
    let baselinePreferredCount: Int
    let inconclusiveCount: Int
    let nonDecisiveCount: Int
    let distinctUTCDayCount: Int
}

struct FH5NumericPromotionReviewPacket: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1
    static let currentPolicyVersion =
        "fh5-numeric-promotion-review-v1"
    static let maximumInputCount = 250
    static let maximumPayloadBytes = 4 * 1_024 * 1_024
    static let boundaryExclusions = [
        "automatic or self-approving promotion",
        "numeric tune generation or display",
        "production ruleset registration",
        "provider, projector, readiness, or persistence mutation",
        "tune accuracy, quality, safety, or legal sufficiency claims"
    ]
    static let privacyExclusions = [
        "analytics and share history",
        "attribution and tester identity",
        "device identifiers and location",
        "internal local record and review-entry identifiers",
        "notes, screenshots, OCR, and telemetry",
        "raw Research Review exports",
        "saved plans, generated tunes, and provider data",
        "source documents and source-manifest contents"
    ]

    let schemaVersion: Int
    let policyVersion: String
    let status: FH5NumericPromotionReviewStatus
    let experimentalRulesetReference: TuneRulesetReference
    let sourceManifestFingerprint: String
    let outcomeThreshold: FH5ControlledOutcomeThreshold
    let candidateBinding: FH5RulesetCandidateBinding
    let candidateAssociation: FH5CandidateOutcomeAssociation
    let candidateAssociationFingerprint: String
    let preparedInputStateFingerprint: String
    let evidence: [FH5NumericPromotionReviewEvidence]
    let counts: FH5NumericPromotionReviewCounts
    let accuracyClaimEstablished: Bool
    let automaticPromotionPermitted: Bool
    let productionRegistrationPermitted: Bool
    let numericOutputPermitted: Bool
    let independentMaintainerReviewRequired: Bool
    let boundaryExclusions: [String]
    let privacyExclusions: [String]
    let artifactFingerprint: String

    func deterministicJSON() throws -> Data {
        try FH5NumericPromotionReviewPacketExporter.canonicalData(
            for: self
        )
    }
}

struct FH5NumericPromotionReviewPacketExporter {
    private struct NormalizedEvidence: Equatable {
        let packetEvidence: FH5NumericPromotionReviewEvidence
        let submissionID: UUID
        let permissionReceiptID: UUID
        let associationFingerprint: String
        let createdAt: Date
        let outcome: FH5ExperimentOutcome
    }

    func prepare(
        candidateArtifact: FH5GeneratedCandidateArtifact,
        localRecords: [FH5ControlledExperimentRecord],
        reviewedEntries: [FH5CandidateOutcomeReviewEntry]
    ) throws -> FH5NumericPromotionReviewPacket {
        guard localRecords.count
                <= FH5NumericPromotionReviewPacket.maximumInputCount else {
            throw FH5NumericPromotionReviewPacketError.tooManyLocalRecords
        }
        guard reviewedEntries.count
                <= FH5NumericPromotionReviewPacket.maximumInputCount else {
            throw FH5NumericPromotionReviewPacketError.tooManyReviewedEntries
        }

        let exchange = FH5CandidateOutcomeExchange()
        let registration = try exactRegistration(
            for: candidateArtifact
        )
        let association = exchange.association(for: candidateArtifact)
        let associationFingerprint = try exchange
            .associationFingerprint(for: candidateArtifact)
        let preparedInputStateFingerprint =
            try preparedInputStateFingerprint(
            candidateArtifact: candidateArtifact,
            localRecords: localRecords,
            reviewedEntries: reviewedEntries
        )

        var normalized: [NormalizedEvidence] = []
        var validCandidateEvidenceCount = 0
        for record in localRecords where isCandidateShaped(record) {
            let export: FH5CandidateOutcomeExport
            do {
                export = try exchange.makeExport(
                    from: record,
                    explicitShareConfirmed: true
                )
            } catch {
                throw FH5NumericPromotionReviewPacketError
                    .invalidLocalEvidence
            }
            let value = try validatedEvidence(
                export: export,
                provenance: .local,
                exchange: exchange
            )
            validCandidateEvidenceCount += 1
            if value.associationFingerprint == associationFingerprint {
                normalized.append(value)
            }
        }
        for entry in reviewedEntries {
            guard exchange.isValidReviewEntry(entry) else {
                throw FH5NumericPromotionReviewPacketError
                    .invalidReviewedEvidence
            }
            let validated: FH5ValidatedCandidateOutcome
            do {
                validated = try exchange.validate(
                    entry.canonicalExportJSON
                )
            } catch {
                throw FH5NumericPromotionReviewPacketError
                    .invalidReviewedEvidence
            }
            let value = normalizedEvidence(
                validated: validated,
                provenance: .reviewed
            )
            validCandidateEvidenceCount += 1
            if value.associationFingerprint == associationFingerprint {
                normalized.append(value)
            }
        }

        if normalized.isEmpty && validCandidateEvidenceCount > 0 {
            throw FH5NumericPromotionReviewPacketError
                .staleOrForeignCandidate
        }
        try requireUnambiguous(normalized)
        normalized.sort(by: evidenceSort)
        let counts = counts(for: normalized)
        guard meetsThreshold(
            counts,
            threshold: registration.outcomeThreshold
        ) else {
            throw FH5NumericPromotionReviewPacketError
                .insufficientEvidence
        }

        var packet = FH5NumericPromotionReviewPacket(
            schemaVersion:
                FH5NumericPromotionReviewPacket.currentSchemaVersion,
            policyVersion:
                FH5NumericPromotionReviewPacket.currentPolicyVersion,
            status: .eligibleForMaintainerReview,
            experimentalRulesetReference: registration.reference,
            sourceManifestFingerprint:
                registration.sourceManifestFingerprint ?? "",
            outcomeThreshold: registration.outcomeThreshold,
            candidateBinding: candidateArtifact.candidateBinding,
            candidateAssociation: association,
            candidateAssociationFingerprint: associationFingerprint,
            preparedInputStateFingerprint:
                preparedInputStateFingerprint,
            evidence: normalized.map(\.packetEvidence),
            counts: counts,
            accuracyClaimEstablished: false,
            automaticPromotionPermitted: false,
            productionRegistrationPermitted: false,
            numericOutputPermitted: false,
            independentMaintainerReviewRequired: true,
            boundaryExclusions:
                FH5NumericPromotionReviewPacket.boundaryExclusions,
            privacyExclusions:
                FH5NumericPromotionReviewPacket.privacyExclusions,
            artifactFingerprint: ""
        )
        packet = replacingFingerprint(
            packet,
            with: try Self.artifactFingerprint(for: packet)
        )
        return packet
    }

    func validate(
        _ data: Data,
        candidateArtifact: FH5GeneratedCandidateArtifact
    ) throws -> FH5NumericPromotionReviewPacket {
        guard !data.isEmpty else {
            throw FH5NumericPromotionReviewPacketError.emptyPayload
        }
        guard data.count
                <= FH5NumericPromotionReviewPacket.maximumPayloadBytes else {
            throw FH5NumericPromotionReviewPacketError.payloadTooLarge
        }
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw FH5NumericPromotionReviewPacketError.invalidJSON
        }
        guard let root = object as? [String: Any] else {
            throw FH5NumericPromotionReviewPacketError.invalidJSON
        }
        guard Set(root.keys) == Self.expectedRootFields else {
            throw FH5NumericPromotionReviewPacketError.unknownRootField
        }

        let packet: FH5NumericPromotionReviewPacket
        do {
            packet = try Self.decoder.decode(
                FH5NumericPromotionReviewPacket.self,
                from: data
            )
        } catch {
            throw FH5NumericPromotionReviewPacketError.invalidJSON
        }
        guard (try? Self.canonicalData(for: packet)) == data else {
            throw FH5NumericPromotionReviewPacketError.nonCanonicalJSON
        }
        let expectedAssociation = FH5CandidateOutcomeExchange()
            .association(for: candidateArtifact)
        let expectedAssociationFingerprint =
            try FH5CandidateOutcomeExchange()
                .associationFingerprint(for: candidateArtifact)
        guard packet.candidateBinding
                    == candidateArtifact.candidateBinding,
              packet.candidateAssociation == expectedAssociation,
              packet.candidateAssociationFingerprint
                    == expectedAssociationFingerprint else {
            throw FH5NumericPromotionReviewPacketError
                .staleOrForeignCandidate
        }
        guard try hasFixedStructure(
            packet,
            candidateArtifact: candidateArtifact
        ) else {
            throw FH5NumericPromotionReviewPacketError.invalidStructure
        }
        guard try Self.artifactFingerprint(for: packet)
                == packet.artifactFingerprint else {
            throw FH5NumericPromotionReviewPacketError
                .invalidArtifactFingerprint
        }
        return packet
    }

    static func canonicalData(
        for packet: FH5NumericPromotionReviewPacket
    ) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .prettyPrinted, .sortedKeys, .withoutEscapingSlashes
        ]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(packet)
    }

    private func hasFixedStructure(
        _ packet: FH5NumericPromotionReviewPacket,
        candidateArtifact: FH5GeneratedCandidateArtifact
    ) throws -> Bool {
        let exchange = FH5CandidateOutcomeExchange()
        let registration: FH5NumericRulesetRegistration
        do {
            registration = try exactRegistration(
                for: candidateArtifact
            )
        } catch {
            throw FH5NumericPromotionReviewPacketError
                .staleOrForeignCandidate
        }
        let expectedAssociation = exchange.association(
            for: candidateArtifact
        )
        let expectedAssociationFingerprint = try exchange
            .associationFingerprint(for: candidateArtifact)
        guard packet.schemaVersion
                == FH5NumericPromotionReviewPacket.currentSchemaVersion,
              packet.policyVersion
                == FH5NumericPromotionReviewPacket.currentPolicyVersion,
              packet.status == .eligibleForMaintainerReview,
              packet.experimentalRulesetReference
                == registration.reference,
              packet.sourceManifestFingerprint
                == registration.sourceManifestFingerprint,
              packet.outcomeThreshold
                == FH5ControlledOutcomeThreshold.currentExperimental,
              packet.outcomeThreshold
                == registration.outcomeThreshold,
              packet.candidateBinding
                == candidateArtifact.candidateBinding,
              packet.candidateAssociation == expectedAssociation,
              packet.candidateAssociationFingerprint
                == expectedAssociationFingerprint,
              packet.preparedInputStateFingerprint.isSHA256,
              !packet.accuracyClaimEstablished,
              !packet.automaticPromotionPermitted,
              !packet.productionRegistrationPermitted,
              !packet.numericOutputPermitted,
              packet.independentMaintainerReviewRequired,
              packet.boundaryExclusions
                == FH5NumericPromotionReviewPacket.boundaryExclusions,
              packet.privacyExclusions
                == FH5NumericPromotionReviewPacket.privacyExclusions,
              packet.artifactFingerprint.isSHA256,
              packet.evidence.count
                <= FH5NumericPromotionReviewPacket.maximumInputCount * 2,
              packet.counts.localCount
                <= FH5NumericPromotionReviewPacket.maximumInputCount,
              packet.counts.reviewedCount
                <= FH5NumericPromotionReviewPacket.maximumInputCount
        else {
            return false
        }

        var normalized: [NormalizedEvidence] = []
        for evidence in packet.evidence {
            let canonicalData: Data
            do {
                canonicalData = try evidence.canonicalExport
                    .deterministicJSON()
                let validated = try exchange.validate(canonicalData)
                guard validated.canonicalExportDigest
                        == evidence.canonicalExportDigest,
                      validated.trialSemanticFingerprint
                        == evidence.trialSemanticFingerprint,
                      validated.trialSessionFingerprint
                        == evidence.trialSessionFingerprint,
                      validated.export.associationFingerprint
                        == packet.candidateAssociationFingerprint else {
                    return false
                }
                normalized.append(normalizedEvidence(
                    validated: validated,
                    provenance: evidence.provenance
                ))
            } catch {
                return false
            }
        }
        guard normalized.map(\.packetEvidence) == packet.evidence else {
            return false
        }
        do {
            try requireUnambiguous(normalized)
        } catch {
            return false
        }
        guard normalized.sorted(by: evidenceSort) == normalized else {
            return false
        }
        let recomputedCounts = counts(for: normalized)
        return recomputedCounts == packet.counts
            && meetsThreshold(
                recomputedCounts,
                threshold: registration.outcomeThreshold
            )
    }

    private func exactRegistration(
        for artifact: FH5GeneratedCandidateArtifact
    ) throws -> FH5NumericRulesetRegistration {
        let registry =
            FH5TrustedNumericRulesetRegistry
                .experimentalCandidateCollection
        guard let registration = registry.registration(
            for: artifact.candidateBinding.algorithmID
        ),
              registration.isValid,
              registration.outcomeThreshold == .currentExperimental,
              artifact.candidateBinding.isValid(for: registration),
              artifact.game == .fh5,
              artifact.protocolVersion
                == FH5ControlledExperimentRecord
                    .currentProtocolVersion else {
            throw FH5NumericPromotionReviewPacketError
                .unregisteredCandidate
        }
        return registration
    }

    private func validatedEvidence(
        export: FH5CandidateOutcomeExport,
        provenance: FH5NumericPromotionEvidenceProvenance,
        exchange: FH5CandidateOutcomeExchange
    ) throws -> NormalizedEvidence {
        do {
            return normalizedEvidence(
                validated: try exchange.validate(
                    export.deterministicJSON()
                ),
                provenance: provenance
            )
        } catch {
            throw FH5NumericPromotionReviewPacketError
                .invalidLocalEvidence
        }
    }

    private func normalizedEvidence(
        validated: FH5ValidatedCandidateOutcome,
        provenance: FH5NumericPromotionEvidenceProvenance
    ) -> NormalizedEvidence {
        NormalizedEvidence(
            packetEvidence: FH5NumericPromotionReviewEvidence(
                provenance: provenance,
                canonicalExport: validated.export,
                canonicalExportDigest:
                    validated.canonicalExportDigest,
                trialSemanticFingerprint:
                    validated.trialSemanticFingerprint,
                trialSessionFingerprint:
                    validated.trialSessionFingerprint
            ),
            submissionID: validated.export.submissionID,
            permissionReceiptID:
                validated.export.permissionReceiptID,
            associationFingerprint:
                validated.export.associationFingerprint,
            createdAt: validated.export.createdAt,
            outcome: validated.export.outcome
        )
    }

    private func requireUnambiguous(
        _ evidence: [NormalizedEvidence]
    ) throws {
        let submissionGroups = Dictionary(
            grouping: evidence,
            by: \.submissionID
        )
        if submissionGroups.values.contains(where: {
            Set($0.map(\.packetEvidence.trialSemanticFingerprint))
                .count > 1
        }) {
            throw FH5NumericPromotionReviewPacketError
                .submissionConflict
        }
        let receiptGroups = Dictionary(
            grouping: evidence,
            by: \.permissionReceiptID
        )
        if receiptGroups.values.contains(where: { group in
            Set(group.map {
                "\($0.submissionID.uuidString)|"
                    + $0.packetEvidence.trialSemanticFingerprint
                    + "|\($0.associationFingerprint)"
            }).count > 1
        }) {
            throw FH5NumericPromotionReviewPacketError
                .permissionReceiptReplay
        }
        let sessionGroups = Dictionary(
            grouping: evidence,
            by: \.packetEvidence.trialSessionFingerprint
        )
        if sessionGroups.values.contains(where: { group in
            Set(group.map {
                "\($0.submissionID.uuidString)|"
                    + $0.permissionReceiptID.uuidString
            }).count > 1
        }) {
            throw FH5NumericPromotionReviewPacketError
                .sessionSemanticReplay
        }
        let digestGroups = Dictionary(
            grouping: evidence,
            by: \.packetEvidence.canonicalExportDigest
        )
        if digestGroups.values.contains(where: { $0.count > 1 }) {
            throw FH5NumericPromotionReviewPacketError
                .duplicateAmbiguity
        }
    }

    private func counts(
        for evidence: [NormalizedEvidence]
    ) -> FH5NumericPromotionReviewCounts {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let distinctDays = Set(evidence.map {
            calendar.dateComponents(
                [.year, .month, .day],
                from: $0.createdAt
            )
        })
        let noClearDifferenceCount = evidence.count {
            $0.outcome == .noClearDifference
        }
        let inconclusiveCount = evidence.count {
            $0.outcome == .inconclusive
        }
        return FH5NumericPromotionReviewCounts(
            uniqueSessionCount: evidence.count,
            localCount: evidence.count {
                $0.packetEvidence.provenance == .local
            },
            reviewedCount: evidence.count {
                $0.packetEvidence.provenance == .reviewed
            },
            variantPreferredCount: evidence.count {
                $0.outcome == .variantPreferred
            },
            noClearDifferenceCount: noClearDifferenceCount,
            baselinePreferredCount: evidence.count {
                $0.outcome == .baselinePreferred
            },
            inconclusiveCount: inconclusiveCount,
            nonDecisiveCount:
                noClearDifferenceCount + inconclusiveCount,
            distinctUTCDayCount: distinctDays.count
        )
    }

    private func meetsThreshold(
        _ counts: FH5NumericPromotionReviewCounts,
        threshold: FH5ControlledOutcomeThreshold
    ) -> Bool {
        threshold == .currentExperimental
            && threshold.requiresDeidentifiedReusePermission
            && counts.uniqueSessionCount
                >= threshold.minimumUniqueRecords
            && counts.variantPreferredCount
                >= threshold.minimumVariantPreferred
            && counts.baselinePreferredCount
                <= threshold.maximumBaselinePreferred
            && counts.nonDecisiveCount
                <= threshold.maximumNonDecisive
            && counts.distinctUTCDayCount
                >= threshold.minimumDistinctUTCDays
    }

    private func evidenceSort(
        _ lhs: NormalizedEvidence,
        _ rhs: NormalizedEvidence
    ) -> Bool {
        let lhsProvenance =
            lhs.packetEvidence.provenance.sortOrder
        let rhsProvenance =
            rhs.packetEvidence.provenance.sortOrder
        if lhsProvenance != rhsProvenance {
            return lhsProvenance < rhsProvenance
        }
        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt < rhs.createdAt
        }
        if lhs.submissionID != rhs.submissionID {
            return lhs.submissionID.uuidString
                < rhs.submissionID.uuidString
        }
        return lhs.packetEvidence.canonicalExportDigest
            < rhs.packetEvidence.canonicalExportDigest
    }

    private func isCandidateShaped(
        _ record: FH5ControlledExperimentRecord
    ) -> Bool {
        record.schemaVersion
            == FH5ControlledExperimentRecord
                .candidateBoundSchemaVersion
            || record.candidateBinding != nil
    }

    func preparedInputStateFingerprint(
        candidateArtifact: FH5GeneratedCandidateArtifact,
        localRecords: [FH5ControlledExperimentRecord],
        reviewedEntries: [FH5CandidateOutcomeReviewEntry]
    ) throws -> String {
        let candidateShaped = localRecords.filter(isCandidateShaped)
        do {
            let candidateState = CandidatePreparedState(
                binding: candidateArtifact.candidateBinding,
                association:
                    FH5CandidateOutcomeExchange().association(
                        for: candidateArtifact
                    )
            )
            var components = [
                "candidate:"
                    + Self.sha256(
                        try Self.fingerprintEncoder.encode(
                            candidateState
                        )
                    )
            ]
            components += try candidateShaped.map {
                "local:"
                    + Self.sha256(
                        try Self.fingerprintEncoder.encode($0)
                    )
            }.sorted()
            components += try reviewedEntries.map {
                "reviewed:"
                    + Self.sha256(
                        try Self.fingerprintEncoder.encode($0)
                    )
            }.sorted()
            components.append(
                "counts:\(candidateShaped.count):"
                    + "\(reviewedEntries.count)"
            )
            return Self.sha256(Data(
                components.joined(separator: "\n").utf8
            ))
        } catch {
            throw FH5NumericPromotionReviewPacketError
                .invalidPreparedInput
        }
    }

    private static func artifactFingerprint(
        for packet: FH5NumericPromotionReviewPacket
    ) throws -> String {
        try sha256(fingerprintEncoder.encode(
            ArtifactFingerprintPayload(packet: packet)
        ))
    }

    private func replacingFingerprint(
        _ packet: FH5NumericPromotionReviewPacket,
        with fingerprint: String
    ) -> FH5NumericPromotionReviewPacket {
        FH5NumericPromotionReviewPacket(
            schemaVersion: packet.schemaVersion,
            policyVersion: packet.policyVersion,
            status: packet.status,
            experimentalRulesetReference:
                packet.experimentalRulesetReference,
            sourceManifestFingerprint:
                packet.sourceManifestFingerprint,
            outcomeThreshold: packet.outcomeThreshold,
            candidateBinding: packet.candidateBinding,
            candidateAssociation: packet.candidateAssociation,
            candidateAssociationFingerprint:
                packet.candidateAssociationFingerprint,
            preparedInputStateFingerprint:
                packet.preparedInputStateFingerprint,
            evidence: packet.evidence,
            counts: packet.counts,
            accuracyClaimEstablished:
                packet.accuracyClaimEstablished,
            automaticPromotionPermitted:
                packet.automaticPromotionPermitted,
            productionRegistrationPermitted:
                packet.productionRegistrationPermitted,
            numericOutputPermitted: packet.numericOutputPermitted,
            independentMaintainerReviewRequired:
                packet.independentMaintainerReviewRequired,
            boundaryExclusions: packet.boundaryExclusions,
            privacyExclusions: packet.privacyExclusions,
            artifactFingerprint: fingerprint
        )
    }

    private static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private static let expectedRootFields = Set([
        "schemaVersion",
        "policyVersion",
        "status",
        "experimentalRulesetReference",
        "sourceManifestFingerprint",
        "outcomeThreshold",
        "candidateBinding",
        "candidateAssociation",
        "candidateAssociationFingerprint",
        "preparedInputStateFingerprint",
        "evidence",
        "counts",
        "accuracyClaimEstablished",
        "automaticPromotionPermitted",
        "productionRegistrationPermitted",
        "numericOutputPermitted",
        "independentMaintainerReviewRequired",
        "boundaryExclusions",
        "privacyExclusions",
        "artifactFingerprint"
    ])

    private static let fingerprintEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .sortedKeys, .withoutEscapingSlashes
        ]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private struct CandidatePreparedState: Encodable {
        let binding: FH5RulesetCandidateBinding
        let association: FH5CandidateOutcomeAssociation
    }

    private struct ArtifactFingerprintPayload: Encodable {
        let schemaVersion: Int
        let policyVersion: String
        let status: FH5NumericPromotionReviewStatus
        let experimentalRulesetReference: TuneRulesetReference
        let sourceManifestFingerprint: String
        let outcomeThreshold: FH5ControlledOutcomeThreshold
        let candidateBinding: FH5RulesetCandidateBinding
        let candidateAssociation: FH5CandidateOutcomeAssociation
        let candidateAssociationFingerprint: String
        let preparedInputStateFingerprint: String
        let evidence: [FH5NumericPromotionReviewEvidence]
        let counts: FH5NumericPromotionReviewCounts
        let accuracyClaimEstablished: Bool
        let automaticPromotionPermitted: Bool
        let productionRegistrationPermitted: Bool
        let numericOutputPermitted: Bool
        let independentMaintainerReviewRequired: Bool
        let boundaryExclusions: [String]
        let privacyExclusions: [String]

        init(packet: FH5NumericPromotionReviewPacket) {
            schemaVersion = packet.schemaVersion
            policyVersion = packet.policyVersion
            status = packet.status
            experimentalRulesetReference =
                packet.experimentalRulesetReference
            sourceManifestFingerprint =
                packet.sourceManifestFingerprint
            outcomeThreshold = packet.outcomeThreshold
            candidateBinding = packet.candidateBinding
            candidateAssociation = packet.candidateAssociation
            candidateAssociationFingerprint =
                packet.candidateAssociationFingerprint
            preparedInputStateFingerprint =
                packet.preparedInputStateFingerprint
            evidence = packet.evidence
            counts = packet.counts
            accuracyClaimEstablished =
                packet.accuracyClaimEstablished
            automaticPromotionPermitted =
                packet.automaticPromotionPermitted
            productionRegistrationPermitted =
                packet.productionRegistrationPermitted
            numericOutputPermitted = packet.numericOutputPermitted
            independentMaintainerReviewRequired =
                packet.independentMaintainerReviewRequired
            boundaryExclusions = packet.boundaryExclusions
            privacyExclusions = packet.privacyExclusions
        }
    }
}

private extension String {
    var isSHA256: Bool {
        count == 64
            && unicodeScalars.allSatisfy {
                (48...57).contains($0.value)
                    || (97...102).contains($0.value)
            }
    }
}
