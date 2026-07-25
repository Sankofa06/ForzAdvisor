//
//  FH6CommunityOutcomeReview.swift
//  forzadvisor
//
//  Strict local ingestion and collection-only aggregation of permission-bound
//  FH6 community comparison outcomes. Reviewed evidence never changes tuning.
//

import CryptoKit
import Foundation
import SwiftData

@MainActor
struct FH6CommunityOutcomeSavedTuneResolver {
    func fetch(
        id: UUID,
        from modelContext: ModelContext
    ) throws -> SavedTune? {
        var descriptor = FetchDescriptor<SavedTune>(
            predicate: #Predicate<SavedTune> { tune in
                tune.id == id
            }
        )
        descriptor.fetchLimit = 1
        descriptor.includePendingChanges = false
        return try modelContext.fetch(descriptor).first
    }
}

struct FH6CommunityOutcomeReviewPermission:
    Codable, Equatable, Sendable {
    let submissionID: UUID
    let permissionReceiptID: UUID
    let consentVersion: String
    let protocolVersion: String
    let canonicalExportDigest: String
    let contentFingerprint: String
    let candidateFingerprint: String
    let directReceiptConfirmed: Bool
    let structuredReusePermissionConfirmed: Bool
    let locallyReviewedAt: Date
}

struct FH6CommunityOutcomeReviewEntry:
    Codable, Equatable, Identifiable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let id: UUID
    let importedAt: Date
    let canonicalExportJSON: Data
    let permission: FH6CommunityOutcomeReviewPermission

    var hasConsistentLocalReviewTimestamp: Bool {
        importedAt == permission.locallyReviewedAt
    }

    init(
        id: UUID = UUID(),
        importedAt: Date = .now,
        canonicalExportJSON: Data,
        permission: FH6CommunityOutcomeReviewPermission
    ) {
        schemaVersion = Self.currentSchemaVersion
        self.id = id
        self.importedAt = importedAt
        self.canonicalExportJSON = canonicalExportJSON
        self.permission = permission
    }

    static func locallyReviewed(
        canonicalExportJSON: Data,
        expectedTune: TuneResult,
        reviewerConfirmedDirectReceipt: Bool,
        reviewerConfirmedStructuredReusePermission: Bool,
        id: UUID = UUID(),
        now: Date = .now
    ) throws -> Self {
        guard reviewerConfirmedDirectReceipt else {
            throw FH6CommunityOutcomeReviewError
                .directReceiptNotConfirmed
        }
        guard reviewerConfirmedStructuredReusePermission else {
            throw FH6CommunityOutcomeReviewError
                .reusePermissionNotConfirmed
        }
        let ingestor = FH6CommunityOutcomeReviewIngestor()
        let validated = try ingestor.validate(
            canonicalExportJSON
        )
        guard ingestor.matchesSavedTune(
            validated,
            tune: expectedTune
        ) else {
            throw FH6CommunityOutcomeReviewError.tuneMismatch
        }
        return Self(
            id: id,
            importedAt: now,
            canonicalExportJSON: canonicalExportJSON,
            permission: .init(
                submissionID:
                    validated.export.submissionID,
                permissionReceiptID:
                    validated.export.permissionReceiptID,
                consentVersion:
                    validated.export.consentVersion,
                protocolVersion:
                    validated.export.protocolVersion,
                canonicalExportDigest:
                    validated.canonicalExportDigest,
                contentFingerprint:
                    validated.export.contentFingerprint,
                candidateFingerprint:
                    validated.export.candidateAssociation
                        .candidateFingerprint,
                directReceiptConfirmed: true,
                structuredReusePermissionConfirmed: true,
                locallyReviewedAt: now
            )
        )
    }
}

enum FH6CommunityOutcomeReviewError:
    Error, LocalizedError, Equatable {
    case emptyPayload
    case payloadTooLarge
    case invalidJSON
    case nonCanonicalJSON
    case invalidStructure
    case directReceiptNotConfirmed
    case reusePermissionNotConfirmed
    case permissionBindingMismatch
    case tuneMismatch
    case corruptStorage

    var errorDescription: String? {
        switch self {
        case .emptyPayload:
            "Paste a ForzAdvisor FH6 community comparison JSON export first."
        case .payloadTooLarge:
            "This community comparison export exceeds the supported 256 KiB limit."
        case .invalidJSON:
            "This is not a readable FH6 community comparison JSON export."
        case .nonCanonicalJSON:
            "Use the exact canonical JSON exported by ForzAdvisor."
        case .invalidStructure:
            "This export failed its schema, protocol, privacy, source, attestation, or fingerprint checks."
        case .directReceiptNotConfirmed:
            "Confirm that you received this exact export directly."
        case .reusePermissionNotConfirmed:
            "Confirm permission for deidentified structured outcome reuse."
        case .permissionBindingMismatch:
            "The local review permission does not bind this exact export."
        case .tuneMismatch:
            "This comparison targets a different or stale FH6 candidate."
        case .corruptStorage:
            "Stored FH6 Community Outcome Review data is unreadable. The saved tune and other evidence were not changed."
        }
    }
}

struct ValidatedFH6CommunityOutcome: Sendable {
    let export: FH6CommunityReferenceTrialExport
    let canonicalExportDigest: String
    let trialSemanticFingerprint: String
    let trialSessionFingerprint: String
}

struct FH6CommunityOutcomeValueCount:
    Equatable, Sendable {
    let value: String
    let count: Int
}

struct FH6CommunityOutcomeDimensions:
    Equatable, Sendable {
    let platformCounts: [FH6CommunityOutcomeValueCount]
    let outcomeCounts: [FH6CommunityOutcomeValueCount]
    let courseTypeCounts: [FH6CommunityOutcomeValueCount]
    let surfaceCounts: [FH6CommunityOutcomeValueCount]
    let inputCounts: [FH6CommunityOutcomeValueCount]
    let candidateDeficiencySymptomCounts:
        [FH6CommunityOutcomeValueCount]

    static let empty = Self(
        platformCounts: [],
        outcomeCounts: [],
        courseTypeCounts: [],
        surfaceCounts: [],
        inputCounts: [],
        candidateDeficiencySymptomCounts: []
    )
}

struct FH6CommunityOutcomeCollectionReport:
    Equatable, Sendable {
    let receivedCount: Int
    let validLocalCount: Int
    let validReviewedCount: Int
    let verifiedUniqueSessionCount: Int
    let quarantinedCount: Int
    let invalidCount: Int
    let duplicateCount: Int
    let conflictCount: Int
    let receiptReplayCount: Int
    let semanticReplayCount: Int
    let localDimensions: FH6CommunityOutcomeDimensions
    let reviewedDimensions: FH6CommunityOutcomeDimensions
    let combinedDimensions: FH6CommunityOutcomeDimensions

    static let empty = Self(
        receivedCount: 0,
        validLocalCount: 0,
        validReviewedCount: 0,
        verifiedUniqueSessionCount: 0,
        quarantinedCount: 0,
        invalidCount: 0,
        duplicateCount: 0,
        conflictCount: 0,
        receiptReplayCount: 0,
        semanticReplayCount: 0,
        localDimensions: .empty,
        reviewedDimensions: .empty,
        combinedDimensions: .empty
    )

    var summary: String {
        "Unique current-candidate comparisons: "
            + "\(verifiedUniqueSessionCount) "
            + "(\(validLocalCount) local, "
            + "\(validReviewedCount) reviewed)."
    }
}

struct FH6CommunityOutcomeReviewIngestor {
    static let maximumPayloadBytes = 256 * 1_024

    func validate(
        _ data: Data
    ) throws -> ValidatedFH6CommunityOutcome {
        guard !data.isEmpty else {
            throw FH6CommunityOutcomeReviewError.emptyPayload
        }
        guard data.count <= Self.maximumPayloadBytes else {
            throw FH6CommunityOutcomeReviewError.payloadTooLarge
        }
        let export: FH6CommunityReferenceTrialExport
        do {
            export = try Self.decoder.decode(
                FH6CommunityReferenceTrialExport.self,
                from: data
            )
        } catch {
            throw FH6CommunityOutcomeReviewError.invalidJSON
        }
        let canonical: Data
        do {
            canonical = try Self.canonicalData(for: export)
        } catch {
            throw FH6CommunityOutcomeReviewError.invalidJSON
        }
        guard canonical == data else {
            throw FH6CommunityOutcomeReviewError
                .nonCanonicalJSON
        }
        guard FH6CommunityReferenceTrialFactory()
            .isValid(export) else {
            throw FH6CommunityOutcomeReviewError
                .invalidStructure
        }
        return ValidatedFH6CommunityOutcome(
            export: export,
            canonicalExportDigest: Self.sha256(canonical),
            trialSemanticFingerprint:
                export.contentFingerprint,
            trialSessionFingerprint:
                try Self.sessionFingerprint(for: export)
        )
    }

    func matchesSavedTune(
        _ validated: ValidatedFH6CommunityOutcome,
        tune: TuneResult
    ) -> Bool {
        FH6CommunityReferenceTrialFactory().matches(
            validated.export,
            tune: tune
        )
    }

    func validateCurrentCandidate(
        _ data: Data,
        displayedTune: TuneResult,
        persistedTune: TuneResult?
    ) throws -> ValidatedFH6CommunityOutcome {
        guard let persistedTune,
              case .success =
                FH6CommunityReferenceTrialFactory()
                    .eligibility(
                    for: displayedTune,
                    savedTune: persistedTune,
                    isStreaming: false
                ) else {
            throw FH6CommunityOutcomeReviewError.tuneMismatch
        }
        let validated = try validate(data)
        guard matchesSavedTune(
            validated,
            tune: persistedTune
        ) else {
            throw FH6CommunityOutcomeReviewError.tuneMismatch
        }
        return validated
    }

    func isValidReviewEntry(
        _ entry: FH6CommunityOutcomeReviewEntry
    ) -> Bool {
        guard entry.schemaVersion
                == FH6CommunityOutcomeReviewEntry
                    .currentSchemaVersion,
              entry.hasConsistentLocalReviewTimestamp,
              entry.permission.directReceiptConfirmed,
              entry.permission
                .structuredReusePermissionConfirmed,
              let validated = try? validate(
                entry.canonicalExportJSON
              ) else {
            return false
        }
        let permission = entry.permission
        return permission.submissionID
                == validated.export.submissionID
            && permission.permissionReceiptID
                == validated.export.permissionReceiptID
            && permission.consentVersion
                == validated.export.consentVersion
            && permission.protocolVersion
                == validated.export.protocolVersion
            && permission.canonicalExportDigest
                == validated.canonicalExportDigest
            && permission.contentFingerprint
                == validated.export.contentFingerprint
            && permission.candidateFingerprint
                == validated.export.candidateAssociation
                    .candidateFingerprint
    }

    static func canonicalData(
        for export: FH6CommunityReferenceTrialExport
    ) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .prettyPrinted,
            .sortedKeys,
            .withoutEscapingSlashes
        ]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(export)
    }

    static func sessionFingerprint(
        for export: FH6CommunityReferenceTrialExport
    ) throws -> String {
        try fingerprint(SessionPayload(
            candidateFingerprint:
                export.candidateAssociation
                    .candidateFingerprint,
            createdAt: export.createdAt,
            context: export.context,
            runs: export.runs,
            attestations: SessionAttestations(
                sameRouteAndConditions:
                    export.attestations
                        .sameRouteAndConditions,
                sameAssistsAndInput:
                    export.attestations
                        .sameAssistsAndInput,
                candidateSettingsApplied:
                    export.attestations
                        .candidateSettingsApplied,
                communityIdentityConfirmed:
                    export.attestations
                        .communityIdentityConfirmed,
                finalCandidateRestored:
                    export.attestations
                        .finalCandidateRestored,
                firstPartyAuthorship:
                    export.attestations
                        .firstPartyAuthorship,
                localStoragePermitted:
                    export.attestations
                        .localStoragePermitted
            )
        ))
    }

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private static func fingerprint<T: Encodable>(
        _ value: T
    ) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .sortedKeys,
            .withoutEscapingSlashes
        ]
        encoder.dateEncodingStrategy = .iso8601
        return sha256(try encoder.encode(value))
    }

    private static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private struct SessionPayload: Codable {
        let candidateFingerprint: String
        let createdAt: Date
        let context: FH6CommunityReferenceTrialContext
        let runs: [FH6CommunityReferenceTrialRun]
        let attestations: SessionAttestations
    }

    private struct SessionAttestations: Codable {
        let sameRouteAndConditions: Bool
        let sameAssistsAndInput: Bool
        let candidateSettingsApplied: Bool
        let communityIdentityConfirmed: Bool
        let finalCandidateRestored: Bool
        let firstPartyAuthorship: Bool
        let localStoragePermitted: Bool
    }
}

struct FH6CommunityOutcomeCollectionEvaluator {
    private struct Evidence {
        enum Provenance: Int {
            case local
            case reviewed
        }

        let submissionID: UUID
        let permissionReceiptID: UUID
        let canonicalDigest: String
        let semanticFingerprint: String
        let sessionFingerprint: String
        let createdAt: Date
        let export: FH6CommunityReferenceTrialExport
        let provenance: Provenance
    }

    func evaluate(
        localRecords: [FH6CommunityReferenceTrialRecord],
        reviewedEntries: [FH6CommunityOutcomeReviewEntry],
        tune: TuneResult
    ) -> FH6CommunityOutcomeCollectionReport {
        let ingestor = FH6CommunityOutcomeReviewIngestor()
        let factory = FH6CommunityReferenceTrialFactory()
        var evidence: [Evidence] = []
        var invalidCount = 0

        for record in localRecords {
            guard factory.matches(record, tune: tune),
                  let export = exportForEvaluation(record),
                  let session = try? FH6CommunityOutcomeReviewIngestor
                    .sessionFingerprint(for: export) else {
                continue
            }
            evidence.append(Evidence(
                submissionID: record.submissionID,
                permissionReceiptID:
                    record.permissionReceiptID,
                canonicalDigest:
                    "local:\(record.recordID.uuidString.lowercased())",
                semanticFingerprint:
                    record.contentFingerprint,
                sessionFingerprint: session,
                createdAt: record.createdAt,
                export: export,
                provenance: .local
            ))
        }

        for entry in reviewedEntries {
            guard ingestor.isValidReviewEntry(entry),
                  let validated = try? ingestor.validate(
                    entry.canonicalExportJSON
                  ) else {
                invalidCount += 1
                continue
            }
            guard ingestor.matchesSavedTune(
                validated,
                tune: tune
            ) else {
                continue
            }
            evidence.append(Evidence(
                submissionID:
                    validated.export.submissionID,
                permissionReceiptID:
                    validated.export.permissionReceiptID,
                canonicalDigest:
                    validated.canonicalExportDigest,
                semanticFingerprint:
                    validated.trialSemanticFingerprint,
                sessionFingerprint:
                    validated.trialSessionFingerprint,
                createdAt: validated.export.createdAt,
                export: validated.export,
                provenance: .reviewed
            ))
        }

        let submissionConflicts = Set(
            Dictionary(grouping: evidence, by: \.submissionID)
                .filter { _, values in
                    Set(values.map(\.semanticFingerprint))
                        .count > 1
                }
                .map(\.key)
        )
        let receiptReplays = Set(
            Dictionary(
                grouping: evidence,
                by: \.permissionReceiptID
            ).filter { _, values in
                Set(values.map {
                    "\($0.submissionID.uuidString)|"
                        + $0.semanticFingerprint
                }).count > 1
            }.map(\.key)
        )
        let administrativelyConflictFree = evidence.filter {
            !submissionConflicts.contains($0.submissionID)
                && !receiptReplays.contains(
                    $0.permissionReceiptID
                )
        }
        let sessionReplays = Set(
            Dictionary(
                grouping: administrativelyConflictFree,
                by: \.sessionFingerprint
            ).filter { _, values in
                Set(values.map(\.semanticFingerprint))
                    .count > 1
            }.map(\.key)
        )
        let quarantined = evidence.filter {
            submissionConflicts.contains($0.submissionID)
                || receiptReplays.contains(
                    $0.permissionReceiptID
                )
                || sessionReplays.contains(
                    $0.sessionFingerprint
                )
        }
        let conflictFree = evidence.filter {
            !submissionConflicts.contains($0.submissionID)
                && !receiptReplays.contains(
                    $0.permissionReceiptID
                )
                && !sessionReplays.contains(
                    $0.sessionFingerprint
                )
        }
        let semanticGroups = Dictionary(
            grouping: conflictFree,
            by: \.semanticFingerprint
        )
        let unique = semanticGroups.values.compactMap {
            $0.sorted(by: evidencePrecedes).first
        }.sorted(by: evidencePrecedes)

        return FH6CommunityOutcomeCollectionReport(
            receivedCount: evidence.count + invalidCount,
            validLocalCount: unique.count {
                $0.provenance == .local
            },
            validReviewedCount: unique.count {
                $0.provenance == .reviewed
            },
            verifiedUniqueSessionCount: unique.count,
            quarantinedCount: quarantined.count,
            invalidCount: invalidCount,
            duplicateCount: semanticGroups.values.reduce(0) {
                $0 + max(0, $1.count - 1)
            },
            conflictCount: evidence.count {
                submissionConflicts.contains($0.submissionID)
            },
            receiptReplayCount: evidence.count {
                receiptReplays.contains(
                    $0.permissionReceiptID
                )
            },
            semanticReplayCount: evidence.count {
                sessionReplays.contains(
                    $0.sessionFingerprint
                )
            },
            localDimensions: dimensions(
                unique.filter { $0.provenance == .local }
            ),
            reviewedDimensions: dimensions(
                unique.filter {
                    $0.provenance == .reviewed
                }
            ),
            combinedDimensions: dimensions(unique)
        )
    }

    private func dimensions(
        _ evidence: [Evidence]
    ) -> FH6CommunityOutcomeDimensions {
        FH6CommunityOutcomeDimensions(
            platformCounts: counts(
                evidence.map {
                    $0.export.source.kind.rawValue
                }
            ),
            outcomeCounts: counts(
                evidence.map { $0.export.outcome.rawValue }
            ),
            courseTypeCounts: counts(
                evidence.map {
                    $0.export.context.courseType.rawValue
                }
            ),
            surfaceCounts: counts(
                evidence.map {
                    $0.export.context.surface.rawValue
                }
            ),
            inputCounts: counts(
                evidence.map {
                    $0.export.context.input.rawValue
                }
            ),
            candidateDeficiencySymptomCounts: counts(
                evidence.flatMap {
                    $0.export.candidateDeficiencySymptoms
                        .map(\.rawValue)
                }
            )
        )
    }

    private func exportForEvaluation(
        _ record: FH6CommunityReferenceTrialRecord
    ) -> FH6CommunityReferenceTrialExport? {
        guard FH6CommunityReferenceTrialFactory()
            .isValid(record) else {
            return nil
        }
        return FH6CommunityReferenceTrialExport(
            schemaVersion: record.schemaVersion,
            consentVersion: record.consentVersion,
            protocolVersion: record.protocolVersion,
            submissionID: record.submissionID,
            permissionReceiptID:
                record.permissionReceiptID,
            createdAt: record.createdAt,
            game: record.game,
            source: record.source,
            candidateAssociation:
                record.candidateAssociation,
            context: record.context,
            runs: record.runs,
            outcome: record.outcome,
            candidateDeficiencySymptoms:
                record.candidateDeficiencySymptoms,
            attestations: record.attestations,
            consentScope: record.consentScope,
            unknowns: record.unknowns,
            privacyExclusions: record.privacyExclusions,
            contentFingerprint: record.contentFingerprint
        )
    }

    private func evidencePrecedes(
        _ lhs: Evidence,
        _ rhs: Evidence
    ) -> Bool {
        if lhs.provenance != rhs.provenance {
            return lhs.provenance.rawValue
                < rhs.provenance.rawValue
        }
        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt < rhs.createdAt
        }
        if lhs.submissionID != rhs.submissionID {
            return lhs.submissionID.uuidString
                < rhs.submissionID.uuidString
        }
        return lhs.canonicalDigest < rhs.canonicalDigest
    }

    private func counts(
        _ values: [String]
    ) -> [FH6CommunityOutcomeValueCount] {
        Dictionary(grouping: values, by: { $0 })
            .map {
                FH6CommunityOutcomeValueCount(
                    value: $0.key,
                    count: $0.value.count
                )
            }
            .sorted { $0.value < $1.value }
    }
}
