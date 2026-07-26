//
//  FH6IndependentValidationReviewPacket.swift
//  forzadvisor
//
//  Canonical, review-only evidence for independent human inspection.
//  A packet cannot validate, rank, promote, or change a tune.
//

import CryptoKit
import Foundation

enum FH6IndependentValidationReviewPacketError:
    Error, Equatable, LocalizedError {
    case ineligibleCandidate
    case tooManyInputs
    case missingFirstPartyTestDrive
    case missingCommunityOutcome
    case invalidEvidence
    case emptyPayload
    case payloadTooLarge
    case invalidJSON
    case unknownFields
    case nonCanonicalJSON
    case invalidStructure
    case invalidFingerprint
    case staleOrForeignCandidate

    var errorDescription: String? {
        switch self {
        case .ineligibleCandidate:
            "Use the exact current saved, non-streaming FH6 candidate."
        case .tooManyInputs:
            "A review packet can inspect at most 250 records of each evidence kind."
        case .missingFirstPartyTestDrive:
            "Record at least one currently valid, reuse-permitted Test Drive for this exact candidate."
        case .missingCommunityOutcome:
            "Record or import at least one valid, reuse-permitted community outcome for this exact candidate."
        case .invalidEvidence:
            "The evidence failed its public export, permission, duplicate, conflict, or replay checks."
        case .emptyPayload:
            "Choose an FH6 independent validation review packet first."
        case .payloadTooLarge:
            "The review packet exceeds the 1 MiB limit."
        case .invalidJSON:
            "This is not a readable FH6 independent validation review packet."
        case .unknownFields:
            "This review packet contains fields outside its public schema."
        case .nonCanonicalJSON:
            "Use the exact canonical review packet exported by ForzAdvisor."
        case .invalidStructure:
            "This review packet failed its schema, counts, ordering, privacy, or safety-boundary checks."
        case .invalidFingerprint:
            "This review packet's integrity fingerprint does not match its evidence."
        case .staleOrForeignCandidate:
            "This review packet targets a different or stale FH6 candidate."
        }
    }
}

enum FH6IndependentValidationEvidenceKind:
    String, Codable, Sendable {
    case firstPartyTestDrive
    case localCommunityOutcome
    case reviewedCommunityOutcome
}

enum FH6IndependentValidationEvidenceScope:
    String, Codable, Sendable {
    case exactCurrentFH6Candidate
}

struct FH6IndependentValidationEvidence:
    Codable, Equatable, Sendable {
    let kind: FH6IndependentValidationEvidenceKind
    let scope: FH6IndependentValidationEvidenceScope
    let canonicalDigest: String
    let firstPartyTestDrive: FirstPartyValidationExport?
    let communityOutcome: FH6CommunityReferenceTrialExport?
}

struct FH6IndependentValidationCandidateBinding:
    Codable, Equatable, Sendable {
    let game: ForzaGame
    let catalogID: String
    let tuneRevisionFingerprint: String
    let testedTuneFingerprint: String
    let communityCandidateFingerprint: String
    let bindingFingerprint: String
}

struct FH6IndependentValidationPacketCounts:
    Codable, Equatable, Sendable {
    let includedFirstPartyTestDriveCount: Int
    let includedLocalCommunityOutcomeCount: Int
    let includedReviewedCommunityOutcomeCount: Int
    let includedEvidenceCount: Int
}

struct FH6IndependentValidationReviewPacket:
    Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1
    static let currentPolicyVersion =
        "fh6-independent-validation-review-v1"

    let schemaVersion: Int
    let policyVersion: String
    let candidate: FH6IndependentValidationCandidateBinding
    let evidence: [FH6IndependentValidationEvidence]
    let counts: FH6IndependentValidationPacketCounts
    let accuracyClaimEstablished: Bool
    let automaticPromotionPermitted: Bool
    let independentHumanReviewRequired: Bool
    let reviewBoundary: String
    let privacyExclusions: [String]
    let artifactFingerprint: String
}

struct FH6IndependentValidationReviewPacketArtifact:
    Sendable {
    let packet: FH6IndependentValidationReviewPacket
    let canonicalJSON: Data
}

enum FH6IndependentValidationReviewPacketPolicy {
    static let reviewBoundary =
        "Independent human review only. Hashes, UUIDs, and local permission bindings do not authenticate a person or publisher. This packet does not prove that every externally reviewed comparison historically followed a specific Test Drive. It does not attest, enumerate, or validate omitted or quarantined local inputs. It establishes no accuracy, validation, ranking, endorsement, ruleset promotion, or automatic tune change."

    static let privacyExclusions = [
        "attachments",
        "candidate-tune-identifiers",
        "device-data",
        "packet-preparation-time",
        "local-record-identifiers",
        "local-review-identifiers-and-times",
        "notes",
        "provider-details",
        "raw-persistence"
    ]
}

struct FH6IndependentValidationReviewPacketExporter {
    static let maximumInputCountPerKind = 250
    static let maximumPayloadBytes = 1_024 * 1_024

    func preparedInputStateFingerprint(
        candidate: TuneResult,
        persistedCandidate: TuneResult?,
        isStreaming: Bool,
        firstPartyTestDrives: [FirstPartyValidationRecord],
        localCommunityOutcomes:
            [FH6CommunityReferenceTrialRecord],
        reviewedCommunityOutcomes:
            [FH6CommunityOutcomeReviewEntry]
    ) throws -> String {
        let exactCandidate = try eligibleCandidate(
            candidate,
            persistedCandidate: persistedCandidate,
            isStreaming: isStreaming
        )
        guard firstPartyTestDrives.count
                <= Self.maximumInputCountPerKind,
              localCommunityOutcomes.count
                <= Self.maximumInputCountPerKind,
              reviewedCommunityOutcomes.count
                <= Self.maximumInputCountPerKind else {
            throw FH6IndependentValidationReviewPacketError
                .tooManyInputs
        }
        guard let revision = FirstPartyValidationRecordFactory()
                .revisionFingerprint(for: exactCandidate) else {
            throw FH6IndependentValidationReviewPacketError
                .ineligibleCandidate
        }
        let material = PreparedInputStateMaterial(
            candidateRevisionFingerprint: revision,
            firstPartyInputDigests: try firstPartyTestDrives
                .map {
                    try rawInputDigest(
                        $0,
                        kind: .firstPartyTestDrive
                    )
                }.sorted(),
            localCommunityInputDigests:
                try localCommunityOutcomes.map {
                    try rawInputDigest(
                        $0,
                        kind: .localCommunityOutcome
                    )
                }.sorted(),
            reviewedCommunityInputDigests:
                try reviewedCommunityOutcomes.map {
                    try rawInputDigest(
                        $0,
                        kind: .reviewedCommunityOutcome
                    )
                }.sorted()
        )
        return domainHash(
            domain:
                "forzadvisor.fh6-independent-review.prepared-input.v1",
            data: try canonicalData(for: material)
        )
    }

    func makeArtifact(
        candidate: TuneResult,
        persistedCandidate: TuneResult?,
        isStreaming: Bool,
        firstPartyTestDrives: [FirstPartyValidationRecord],
        localCommunityOutcomes:
            [FH6CommunityReferenceTrialRecord],
        reviewedCommunityOutcomes:
            [FH6CommunityOutcomeReviewEntry]
    ) throws -> FH6IndependentValidationReviewPacketArtifact {
        let exactCandidate = try eligibleCandidate(
            candidate,
            persistedCandidate: persistedCandidate,
            isStreaming: isStreaming
        )
        guard firstPartyTestDrives.count
                <= Self.maximumInputCountPerKind,
              localCommunityOutcomes.count
                <= Self.maximumInputCountPerKind,
              reviewedCommunityOutcomes.count
                <= Self.maximumInputCountPerKind else {
            throw FH6IndependentValidationReviewPacketError
                .tooManyInputs
        }

        let validatedInputs =
            collectFirstParty(
            firstPartyTestDrives,
            candidate: exactCandidate
        )
            + collectCommunity(
                local: localCommunityOutcomes,
                reviewed: reviewedCommunityOutcomes,
                candidate: exactCandidate
            )
        let accepted = normalizeValidated(validatedInputs)
        guard accepted.contains(where: {
            $0.item.kind == .firstPartyTestDrive
        }) else {
            throw FH6IndependentValidationReviewPacketError
                .missingFirstPartyTestDrive
        }
        guard accepted.contains(where: {
            $0.item.kind != .firstPartyTestDrive
        }) else {
            throw FH6IndependentValidationReviewPacketError
                .missingCommunityOutcome
        }

        let candidateBinding = try makeCandidateBinding(
            candidate: exactCandidate,
            evidence: accepted
        )
        let evidence = accepted.map(\.item).sorted(
            by: evidencePrecedes
        )
        let counts = counts(for: evidence)
        let unsigned = FH6IndependentValidationReviewPacket(
            schemaVersion:
                FH6IndependentValidationReviewPacket
                .currentSchemaVersion,
            policyVersion:
                FH6IndependentValidationReviewPacket
                .currentPolicyVersion,
            candidate: candidateBinding,
            evidence: evidence,
            counts: counts,
            accuracyClaimEstablished: false,
            automaticPromotionPermitted: false,
            independentHumanReviewRequired: true,
            reviewBoundary:
                FH6IndependentValidationReviewPacketPolicy
                .reviewBoundary,
            privacyExclusions:
                FH6IndependentValidationReviewPacketPolicy
                .privacyExclusions,
            artifactFingerprint: ""
        )
        guard hasValidStructure(
            unsigned,
            allowEmptyFingerprint: true
        ) else {
            throw FH6IndependentValidationReviewPacketError
                .invalidStructure
        }
        let packet = replacingFingerprint(
            in: unsigned,
            with: fingerprint(for: unsigned)
        )
        let data = try canonicalData(for: packet)
        guard data.count <= Self.maximumPayloadBytes else {
            throw FH6IndependentValidationReviewPacketError
                .payloadTooLarge
        }
        return .init(packet: packet, canonicalJSON: data)
    }

    func validate(
        _ data: Data,
        candidate: TuneResult,
        persistedCandidate: TuneResult?,
        isStreaming: Bool
    ) throws -> FH6IndependentValidationReviewPacket {
        guard !data.isEmpty else {
            throw FH6IndependentValidationReviewPacketError
                .emptyPayload
        }
        guard data.count <= Self.maximumPayloadBytes else {
            throw FH6IndependentValidationReviewPacketError
                .payloadTooLarge
        }
        guard hasOnlyKnownRootFields(data) else {
            throw FH6IndependentValidationReviewPacketError
                .unknownFields
        }
        let packet: FH6IndependentValidationReviewPacket
        do {
            packet = try Self.decoder.decode(
                FH6IndependentValidationReviewPacket.self,
                from: data
            )
        } catch {
            throw FH6IndependentValidationReviewPacketError
                .invalidJSON
        }
        guard (try? canonicalData(for: packet)) == data else {
            throw FH6IndependentValidationReviewPacketError
                .nonCanonicalJSON
        }
        guard hasValidStructure(packet) else {
            throw FH6IndependentValidationReviewPacketError
                .invalidStructure
        }
        guard fingerprint(for: packet)
                == packet.artifactFingerprint else {
            throw FH6IndependentValidationReviewPacketError
                .invalidFingerprint
        }
        let exactCandidate = try eligibleCandidate(
            candidate,
            persistedCandidate: persistedCandidate,
            isStreaming: isStreaming
        )
        let working = try packet.evidence.map {
            try revalidatePacketEvidence(
                $0,
                candidate: exactCandidate
            )
        }
        let includedNormalization =
            normalizeValidated(working)
        guard includedNormalization.count == working.count,
              includedNormalization.map(\.item)
                == packet.evidence else {
            throw FH6IndependentValidationReviewPacketError
                .invalidEvidence
        }
        let expectedBinding = try makeCandidateBinding(
            candidate: exactCandidate,
            evidence: includedNormalization
        )
        guard expectedBinding == packet.candidate else {
            throw FH6IndependentValidationReviewPacketError
                .staleOrForeignCandidate
        }
        return packet
    }

    private struct WorkingEvidence {
        let item: FH6IndependentValidationEvidence
        let submissionID: UUID
        let permissionReceiptID: UUID
        let semanticFingerprint: String
        let sessionFingerprint: String?
        let testedTuneFingerprint: String?
        let communityCandidateFingerprint: String?
    }

    private struct PreparedInputStateMaterial: Encodable {
        let candidateRevisionFingerprint: String
        let firstPartyInputDigests: [String]
        let localCommunityInputDigests: [String]
        let reviewedCommunityInputDigests: [String]
    }

    private func eligibleCandidate(
        _ candidate: TuneResult,
        persistedCandidate: TuneResult?,
        isStreaming: Bool
    ) throws -> TuneResult {
        guard candidate.request.car.game == .fh6,
              let persistedCandidate,
              persistedCandidate.request.car.game == .fh6,
              candidate.id == persistedCandidate.id,
              candidate.generatedAt
                == persistedCandidate.generatedAt,
              case .success(let exactCandidate) =
                FirstPartyValidationRecordFactory()
                .eligibility(
                    for: candidate,
                    savedTune: persistedCandidate,
                    isStreaming: isStreaming
                ) else {
            throw FH6IndependentValidationReviewPacketError
                .ineligibleCandidate
        }
        return exactCandidate
    }

    private func collectFirstParty(
        _ records: [FirstPartyValidationRecord],
        candidate: TuneResult
    ) -> [WorkingEvidence] {
        let factory = FirstPartyValidationRecordFactory()
        let ingestor = FH6ValidationReviewIngestor()
        return records.compactMap { record in
            guard factory.isValid(record),
                  record.deidentifiedReusePermitted,
                  let data = try? record.deterministicJSON(),
                  let validated = try? ingestor.validate(data),
                  ingestor.matchesSavedTune(
                      validated,
                      tune: candidate
                  ) else {
                return nil
            }
            return WorkingEvidence(
                item: .init(
                    kind: .firstPartyTestDrive,
                    scope: .exactCurrentFH6Candidate,
                    canonicalDigest:
                        validated.canonicalExportDigest,
                    firstPartyTestDrive: validated.export,
                    communityOutcome: nil
                ),
                submissionID: validated.export.submissionID,
                permissionReceiptID:
                    validated.export.permissionReceiptID,
                semanticFingerprint:
                    validated.export.contentFingerprint,
                sessionFingerprint: nil,
                testedTuneFingerprint:
                    validated.testedTuneFingerprint,
                communityCandidateFingerprint: nil
            )
        }
    }

    private func collectCommunity(
        local: [FH6CommunityReferenceTrialRecord],
        reviewed: [FH6CommunityOutcomeReviewEntry],
        candidate: TuneResult
    ) -> [WorkingEvidence] {
        let factory = FH6CommunityReferenceTrialFactory()
        let ingestor = FH6CommunityOutcomeReviewIngestor()
        let localInputs: [WorkingEvidence] =
            local.compactMap { record -> WorkingEvidence? in
            guard factory.isValid(record),
                  record.attestations
                    .deidentifiedOutcomeReusePermitted,
                  factory.matches(record, tune: candidate),
                  let data = try? record.deterministicJSON(),
                  let validated = try? ingestor.validate(data),
                  ingestor.matchesSavedTune(
                      validated,
                      tune: candidate
                  ) else {
                return nil
            }
            return makeCommunityWorking(
                validated,
                kind: .localCommunityOutcome
            )
        }
        let reviewedInputs: [WorkingEvidence] =
            reviewed.compactMap { entry -> WorkingEvidence? in
            guard ingestor.isValidReviewEntry(entry),
                  let validated = try? ingestor.validate(
                      entry.canonicalExportJSON
                  ),
                  ingestor.matchesSavedTune(
                      validated,
                      tune: candidate
                  ) else {
                return nil
            }
            return makeCommunityWorking(
                validated,
                kind: .reviewedCommunityOutcome
            )
        }
        return localInputs + reviewedInputs
    }

    private func makeCommunityWorking(
        _ validated: ValidatedFH6CommunityOutcome,
        kind: FH6IndependentValidationEvidenceKind
    ) -> WorkingEvidence {
        .init(
            item: .init(
                kind: kind,
                scope: .exactCurrentFH6Candidate,
                canonicalDigest:
                    validated.canonicalExportDigest,
                firstPartyTestDrive: nil,
                communityOutcome: validated.export
            ),
            submissionID: validated.export.submissionID,
            permissionReceiptID:
                validated.export.permissionReceiptID,
            semanticFingerprint:
                validated.trialSemanticFingerprint,
            sessionFingerprint:
                validated.trialSessionFingerprint,
            testedTuneFingerprint: nil,
            communityCandidateFingerprint:
                validated.export.candidateAssociation
                .candidateFingerprint
        )
    }

    private func normalizeValidated(
        _ evidence: [WorkingEvidence]
    ) -> [WorkingEvidence] {
        let submissionConflicts = Set(
            Dictionary(grouping: evidence, by: \.submissionID)
                .filter { _, values in
                    Set(values.map(\.semanticFingerprint)).count > 1
                }.map(\.key)
        )
        let receiptReplays = Set(
            Dictionary(
                grouping: evidence,
                by: \.permissionReceiptID
            ).filter { _, values in
                Set(values.map {
                    $0.submissionID.uuidString.lowercased()
                        + "|" + $0.semanticFingerprint
                }).count > 1
            }.map(\.key)
        )
        let administrativelyClean = evidence.filter {
            !submissionConflicts.contains($0.submissionID)
                && !receiptReplays.contains(
                    $0.permissionReceiptID
                )
        }
        let sessionReplays: Set<String> = Set(
            Dictionary(
                grouping: administrativelyClean,
                by: { $0.sessionFingerprint ?? "" }
            ).filter { key, values in
                !key.isEmpty
                    && Set(values.map(\.semanticFingerprint))
                    .count > 1
            }.map(\.key)
        )
        let clean = evidence.filter { item in
            !submissionConflicts.contains(
                item.submissionID
            )
                && !receiptReplays.contains(
                    item.permissionReceiptID
                )
                && !(
                    item.sessionFingerprint.map {
                        sessionReplays.contains($0)
                    } ?? false
                )
        }
        return Dictionary(
            grouping: clean,
            by: \.semanticFingerprint
        ).values.compactMap {
            $0.sorted(by: workingPrecedes).first
        }.sorted(by: workingPrecedes)
    }

    private func revalidatePacketEvidence(
        _ item: FH6IndependentValidationEvidence,
        candidate: TuneResult
    ) throws -> WorkingEvidence {
        guard item.scope == .exactCurrentFH6Candidate,
              isDigest(item.canonicalDigest) else {
            throw FH6IndependentValidationReviewPacketError
                .invalidEvidence
        }
        switch item.kind {
        case .firstPartyTestDrive:
            guard let export = item.firstPartyTestDrive,
                  item.communityOutcome == nil,
                  let data = try? FH6ValidationReviewIngestor
                    .canonicalData(for: export),
                  let validated = try?
                    FH6ValidationReviewIngestor().validate(data),
                  validated.canonicalExportDigest
                    == item.canonicalDigest,
                  FH6ValidationReviewIngestor()
                    .matchesSavedTune(
                        validated,
                        tune: candidate
                    ) else {
                throw FH6IndependentValidationReviewPacketError
                    .invalidEvidence
            }
            return .init(
                item: item,
                submissionID: export.submissionID,
                permissionReceiptID: export.permissionReceiptID,
                semanticFingerprint:
                    export.contentFingerprint,
                sessionFingerprint: nil,
                testedTuneFingerprint:
                    validated.testedTuneFingerprint,
                communityCandidateFingerprint: nil
            )
        case .localCommunityOutcome,
                .reviewedCommunityOutcome:
            guard item.firstPartyTestDrive == nil,
                  let export = item.communityOutcome,
                  let data = try?
                    FH6CommunityOutcomeReviewIngestor
                    .canonicalData(for: export),
                  let validated = try?
                    FH6CommunityOutcomeReviewIngestor()
                    .validate(data),
                  validated.canonicalExportDigest
                    == item.canonicalDigest,
                  FH6CommunityOutcomeReviewIngestor()
                    .matchesSavedTune(
                        validated,
                        tune: candidate
                    ) else {
                throw FH6IndependentValidationReviewPacketError
                    .invalidEvidence
            }
            return makeCommunityWorking(
                validated,
                kind: item.kind
            )
        }
    }

    private func makeCandidateBinding(
        candidate: TuneResult,
        evidence: [WorkingEvidence]
    ) throws -> FH6IndependentValidationCandidateBinding {
        guard let revision =
                FirstPartyValidationRecordFactory()
                .revisionFingerprint(for: candidate),
              let tested = single(
                  evidence.compactMap(
                      \.testedTuneFingerprint
                  )
              ),
              let community = single(
                  evidence.compactMap(
                      \.communityCandidateFingerprint
                  )
              ),
              let catalogID = candidate.request.car
                .catalogReference?.entryID,
              safeString(catalogID, maximumLength: 160) else {
            throw FH6IndependentValidationReviewPacketError
                .staleOrForeignCandidate
        }
        let unsigned = FH6IndependentValidationCandidateBinding(
            game: .fh6,
            catalogID: catalogID,
            tuneRevisionFingerprint: revision,
            testedTuneFingerprint: tested,
            communityCandidateFingerprint: community,
            bindingFingerprint: ""
        )
        return .init(
            game: unsigned.game,
            catalogID: unsigned.catalogID,
            tuneRevisionFingerprint:
                unsigned.tuneRevisionFingerprint,
            testedTuneFingerprint:
                unsigned.testedTuneFingerprint,
            communityCandidateFingerprint:
                unsigned.communityCandidateFingerprint,
            bindingFingerprint: domainHash(
                domain:
                    "forzadvisor.fh6-independent-review.candidate.v1",
                data: try canonicalData(for: unsigned)
            )
        )
    }

    private func single(_ values: [String]) -> String? {
        let unique = Set(values)
        guard unique.count == 1, let value = unique.first,
              isDigest(value) else {
            return nil
        }
        return value
    }

    private func counts(
        for evidence: [FH6IndependentValidationEvidence]
    ) -> FH6IndependentValidationPacketCounts {
        return .init(
            includedFirstPartyTestDriveCount:
                evidence.count {
                    $0.kind == .firstPartyTestDrive
                },
            includedLocalCommunityOutcomeCount:
                evidence.count {
                    $0.kind == .localCommunityOutcome
                },
            includedReviewedCommunityOutcomeCount:
                evidence.count {
                    $0.kind == .reviewedCommunityOutcome
                },
            includedEvidenceCount: evidence.count
        )
    }

    private func hasValidStructure(
        _ packet: FH6IndependentValidationReviewPacket,
        allowEmptyFingerprint: Bool = false
    ) -> Bool {
        let counts = packet.counts
        let recomputedCounts = self.counts(
            for: packet.evidence
        )
        guard packet.schemaVersion
                == FH6IndependentValidationReviewPacket
                .currentSchemaVersion,
              packet.policyVersion
                == FH6IndependentValidationReviewPacket
                .currentPolicyVersion,
              packet.accuracyClaimEstablished == false,
              packet.automaticPromotionPermitted == false,
              packet.independentHumanReviewRequired,
              packet.reviewBoundary
                == FH6IndependentValidationReviewPacketPolicy
                .reviewBoundary,
              packet.privacyExclusions
                == FH6IndependentValidationReviewPacketPolicy
                .privacyExclusions,
              packet.candidate.game == .fh6,
              safeString(
                  packet.candidate.catalogID,
                  maximumLength: 160
              ),
              isDigest(
                  packet.candidate
                    .tuneRevisionFingerprint
              ),
              isDigest(
                  packet.candidate.testedTuneFingerprint
              ),
              isDigest(
                  packet.candidate
                    .communityCandidateFingerprint
              ),
              isDigest(
                  packet.candidate.bindingFingerprint
              ),
              packet.evidence
                == packet.evidence.sorted(
                    by: evidencePrecedes
                ),
              counts == recomputedCounts,
              Set(packet.evidence.map {
                  "\($0.kind.rawValue)|\($0.canonicalDigest)"
              }).count == packet.evidence.count,
              counts.includedFirstPartyTestDriveCount > 0,
              counts.includedLocalCommunityOutcomeCount
                + counts
                    .includedReviewedCommunityOutcomeCount > 0,
              packet.evidence.count
                == counts.includedEvidenceCount,
              (
                  allowEmptyFingerprint
                    ? packet.artifactFingerprint.isEmpty
                    : isDigest(packet.artifactFingerprint)
              ) else {
            return false
        }
        return packet.evidence.allSatisfy {
            $0.scope == .exactCurrentFH6Candidate
                && isDigest($0.canonicalDigest)
                && (
                    $0.kind == .firstPartyTestDrive
                        ? $0.firstPartyTestDrive != nil
                            && $0.communityOutcome == nil
                        : $0.firstPartyTestDrive == nil
                            && $0.communityOutcome != nil
                )
        }
    }

    private func evidencePrecedes(
        _ lhs: FH6IndependentValidationEvidence,
        _ rhs: FH6IndependentValidationEvidence
    ) -> Bool {
        if lhs.kind.rawValue != rhs.kind.rawValue {
            return lhs.kind.rawValue < rhs.kind.rawValue
        }
        return lhs.canonicalDigest < rhs.canonicalDigest
    }

    private func workingPrecedes(
        _ lhs: WorkingEvidence,
        _ rhs: WorkingEvidence
    ) -> Bool {
        evidencePrecedes(lhs.item, rhs.item)
    }

    private func rawInputDigest<T: Encodable>(
        _ value: T,
        kind: FH6IndependentValidationEvidenceKind
    ) throws -> String {
        domainHash(
            domain:
                "forzadvisor.fh6-independent-review.received.\(kind.rawValue).v1",
            data: try canonicalData(for: value)
        )
    }

    private func safeString(
        _ value: String,
        maximumLength: Int
    ) -> Bool {
        let canonical = value.split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        return canonical == value
            && (1...maximumLength).contains(value.count)
            && value.unicodeScalars.allSatisfy {
                !CharacterSet.controlCharacters.contains($0)
            }
    }

    private func isDigest(_ value: String) -> Bool {
        value.count == 64
            && value.allSatisfy {
                $0.isNumber || ("a"..."f").contains($0)
            }
    }

    private func fingerprint(
        for packet: FH6IndependentValidationReviewPacket
    ) -> String {
        let unsigned = replacingFingerprint(
            in: packet,
            with: ""
        )
        guard let data = try? canonicalData(for: unsigned) else {
            return ""
        }
        return domainHash(
            domain:
                "forzadvisor.fh6-independent-review.packet.v1",
            data: data
        )
    }

    private func replacingFingerprint(
        in value: FH6IndependentValidationReviewPacket,
        with fingerprint: String
    ) -> FH6IndependentValidationReviewPacket {
        .init(
            schemaVersion: value.schemaVersion,
            policyVersion: value.policyVersion,
            candidate: value.candidate,
            evidence: value.evidence,
            counts: value.counts,
            accuracyClaimEstablished:
                value.accuracyClaimEstablished,
            automaticPromotionPermitted:
                value.automaticPromotionPermitted,
            independentHumanReviewRequired:
                value.independentHumanReviewRequired,
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
            .prettyPrinted, .sortedKeys, .withoutEscapingSlashes
        ]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(value)
    }

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

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

    private func hasOnlyKnownRootFields(_ data: Data) -> Bool {
        guard let root = try? JSONSerialization
            .jsonObject(with: data),
              let object = root as? [String: Any] else {
            return false
        }
        return Set(object.keys) == [
            "schemaVersion", "policyVersion", "candidate",
            "evidence", "counts",
            "accuracyClaimEstablished",
            "automaticPromotionPermitted",
            "independentHumanReviewRequired",
            "reviewBoundary", "privacyExclusions",
            "artifactFingerprint"
        ]
    }
}
