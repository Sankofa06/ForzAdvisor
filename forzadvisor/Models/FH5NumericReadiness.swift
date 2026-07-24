//
//  FH5NumericReadiness.swift
//  forzadvisor
//
//  Fail-closed evidence contract for a future, separately versioned FH5
//  numeric ruleset. Research observations establish menu facts, not tune
//  quality, and cannot authorize numeric output by themselves.
//

import CryptoKit
import Foundation

enum FH5NumericReadinessGate: String, CaseIterable, Sendable {
    case exactStockContext
    case firstPartyMenuObservation
    case completeUpgradeObservation
    case replicatedMenuObservation
    case rightsClearedRuleset
    case controlledOutcomes

    var title: String {
        switch self {
        case .exactStockContext: "Exact stock context"
        case .firstPartyMenuObservation: "First-party menu capture"
        case .completeUpgradeObservation: "Complete Upgrade Lab"
        case .replicatedMenuObservation: "Independent menu replication"
        case .rightsClearedRuleset: "Rights-cleared FH5 ruleset"
        case .controlledOutcomes: "Controlled Test Track outcomes"
        }
    }
}

enum FH5NumericReadinessState: String, Sendable {
    case complete
    case pending
    case blocked
}

struct FH5NumericReadinessItem: Equatable, Identifiable, Sendable {
    var id: FH5NumericReadinessGate { gate }
    let gate: FH5NumericReadinessGate
    let state: FH5NumericReadinessState
    let detail: String
}

struct FH5NumericReadinessAssessment: Equatable, Sendable {
    let policyVersion: String
    let items: [FH5NumericReadinessItem]

    var canGenerateNumeric: Bool {
        !items.isEmpty && items.allSatisfy { $0.state == .complete }
    }

    var completedCount: Int {
        items.count { $0.state == .complete }
    }
}

nonisolated enum FH5ExperimentalAlgorithmID:
    String,
    Codable,
    CaseIterable,
    Hashable,
    Sendable {
    case cleanRoomDirectionalV1 = "fh5.clean-room-directional-v1"
}

nonisolated enum FH5NumericRulesetRightsBasis: String, Codable, Sendable {
    case firstPartyCleanRoom
    case creatorPermission
    case compatibleLicense
}

nonisolated struct FH5NumericRulesetSourceManifest: Codable, Equatable, Sendable {
    let sourceID: String
    let sourceVersion: String
    let owner: String
    let rightsBasis: FH5NumericRulesetRightsBasis
    let rightsEvidenceID: String
    let usagePermission: TuneDataUsagePermission

    var isValid: Bool {
        isCanonicalIdentifier(sourceID, maximumLength: 160)
            && isCanonicalIdentifier(sourceVersion, maximumLength: 120)
            && isCanonicalText(owner, maximumLength: 200)
            && isCanonicalIdentifier(rightsEvidenceID, maximumLength: 200)
            && usagePermission == .permitted
    }

    static func fingerprint(
        for manifests: [FH5NumericRulesetSourceManifest]
    ) -> String? {
        guard !manifests.isEmpty,
              manifests.allSatisfy(\.isValid),
              Set(manifests.map(\.sourceID)).count == manifests.count else {
            return nil
        }
        let ordered = manifests.sorted { $0.sourceID < $1.sourceID }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(ordered) else { return nil }
        return sha256Fingerprint(data)
    }
}

nonisolated struct FH5ControlledOutcomeThreshold: Codable, Equatable, Sendable {
    static let currentExperimental = Self(
        policyVersion: "fh5-controlled-outcome-experimental-v1",
        protocolVersion:
            FH5ControlledExperimentRecord.currentProtocolVersion,
        minimumUniqueRecords: 10,
        minimumVariantPreferred: 8,
        maximumBaselinePreferred: 0,
        maximumNonDecisive: 2,
        minimumDistinctUTCDays: 2,
        requiresDeidentifiedReusePermission: true
    )

    let policyVersion: String
    let protocolVersion: String
    let minimumUniqueRecords: Int
    let minimumVariantPreferred: Int
    let maximumBaselinePreferred: Int
    let maximumNonDecisive: Int
    let minimumDistinctUTCDays: Int
    let requiresDeidentifiedReusePermission: Bool

    var isValid: Bool {
        isCanonicalIdentifier(policyVersion, maximumLength: 160)
            && protocolVersion
                == FH5ControlledExperimentRecord.currentProtocolVersion
            && minimumUniqueRecords > 0
            && minimumVariantPreferred > 0
            && minimumVariantPreferred <= minimumUniqueRecords
            && maximumBaselinePreferred >= 0
            && maximumNonDecisive >= 0
            && minimumVariantPreferred + maximumNonDecisive
                >= minimumUniqueRecords
            && minimumDistinctUTCDays > 0
            && minimumDistinctUTCDays <= minimumUniqueRecords
            && requiresDeidentifiedReusePermission
    }
}

nonisolated enum FH5NumericRulesetRegistrationIssue: Equatable, Sendable {
    case invalidRulesetReference
    case wrongGame
    case rulesetIDMismatch
    case nonExperimentalStatus
    case missingSourceManifest
    case invalidSourceManifest(String)
    case duplicateSourceManifest(String)
    case provenanceMismatch
    case sourceFingerprintMismatch
    case unsupportedOutcomeThreshold
}

nonisolated struct FH5NumericRulesetRegistration: Codable, Equatable, Sendable {
    let algorithmID: FH5ExperimentalAlgorithmID
    let reference: TuneRulesetReference
    let sourceManifests: [FH5NumericRulesetSourceManifest]
    let outcomeThreshold: FH5ControlledOutcomeThreshold

    var sourceManifestFingerprint: String? {
        FH5NumericRulesetSourceManifest.fingerprint(for: sourceManifests)
    }

    var validationIssues: [FH5NumericRulesetRegistrationIssue] {
        var issues: [FH5NumericRulesetRegistrationIssue] = []
        if !reference.isValid {
            issues.append(.invalidRulesetReference)
        }
        if reference.game != .fh5 {
            issues.append(.wrongGame)
        }
        if reference.id != algorithmID.rawValue {
            issues.append(.rulesetIDMismatch)
        }
        if reference.validationStatus != .experimental {
            issues.append(.nonExperimentalStatus)
        }
        if sourceManifests.isEmpty {
            issues.append(.missingSourceManifest)
        }
        for source in sourceManifests where !source.isValid {
            issues.append(.invalidSourceManifest(source.sourceID))
        }
        var seenSourceIDs = Set<String>()
        for source in sourceManifests
            where !seenSourceIDs.insert(source.sourceID).inserted {
            issues.append(.duplicateSourceManifest(source.sourceID))
        }
        let sourceIDs = sourceManifests.map(\.sourceID).sorted()
        if reference.provenanceIDs != sourceIDs {
            issues.append(.provenanceMismatch)
        }
        if reference.knowledgeRevision != sourceManifestFingerprint {
            issues.append(.sourceFingerprintMismatch)
        }
        if !outcomeThreshold.isValid
            || outcomeThreshold != .currentExperimental {
            issues.append(.unsupportedOutcomeThreshold)
        }
        return issues
    }

    var isValid: Bool { validationIssues.isEmpty }
}

nonisolated struct FH5RulesetCandidateBinding: Codable, Equatable, Sendable {
    let algorithmID: FH5ExperimentalAlgorithmID
    let rulesetReference: TuneRulesetReference
    let sourceManifestFingerprint: String
    let outcomePolicyVersion: String
    let generatedCandidateFingerprint: String

    var isStructurallyValid: Bool {
        rulesetReference.isValid
            && rulesetReference.game == .fh5
            && rulesetReference.id == algorithmID.rawValue
            && rulesetReference.validationStatus == .experimental
            && isSHA256Fingerprint(sourceManifestFingerprint)
            && !outcomePolicyVersion.isEmpty
            && isSHA256Fingerprint(generatedCandidateFingerprint)
    }

    func isValid(
        for registration: FH5NumericRulesetRegistration
    ) -> Bool {
        isStructurallyValid
            && registration.isValid
            && algorithmID == registration.algorithmID
            && rulesetReference == registration.reference
            && sourceManifestFingerprint
                == registration.sourceManifestFingerprint
            && outcomePolicyVersion
                == registration.outcomeThreshold.policyVersion
            && isSHA256Fingerprint(generatedCandidateFingerprint)
    }
}

nonisolated enum FH5NumericRulesetRegistryIssue: Error, Equatable, Sendable {
    case invalidRegistration(FH5ExperimentalAlgorithmID)
    case duplicateAlgorithmID(FH5ExperimentalAlgorithmID)
}

/// A code-owned allow-list is deliberately stronger than
/// `TuneRulesetReference.isValid`, which only validates descriptor structure.
nonisolated struct FH5TrustedNumericRulesetRegistry: Sendable {
    static let production = Self(uncheckedRegistrations: [])
    static let experimentalCandidateCollection: Self = {
        let algorithmID = FH5ExperimentalAlgorithmID.cleanRoomDirectionalV1
        let sources = [
            FH5NumericRulesetSourceManifest(
                sourceID: "first-party.clean-room",
                sourceVersion: "1",
                owner: "ForzAdvisor",
                rightsBasis: .firstPartyCleanRoom,
                rightsEvidenceID:
                    "docs.fh5-clean-room-directional-v1.md",
                usagePermission: .permitted
            )
        ]
        guard let knowledgeRevision =
                FH5NumericRulesetSourceManifest.fingerprint(for: sources),
              let reference = TuneRulesetReference(
                descriptor: TuneRulesetDescriptor(
                    id: algorithmID.rawValue,
                    game: .fh5,
                    schemaVersion: 1,
                    algorithmVersion: "1",
                    knowledgeRevision: knowledgeRevision,
                    validationStatus: .experimental,
                    provenanceIDs: sources.map(\.sourceID).sorted()
                )
              ),
              let registry = try? Self(validating: [
                FH5NumericRulesetRegistration(
                    algorithmID: algorithmID,
                    reference: reference,
                    sourceManifests: sources,
                    outcomeThreshold: .currentExperimental
                )
              ]) else {
            preconditionFailure(
                "The code-owned FH5 candidate collection registration is invalid."
            )
        }
        return registry
    }()

    private let registrations:
        [FH5ExperimentalAlgorithmID: FH5NumericRulesetRegistration]

    private init(
        uncheckedRegistrations: [FH5NumericRulesetRegistration]
    ) {
        registrations = Dictionary(
            uniqueKeysWithValues: uncheckedRegistrations.map {
                ($0.algorithmID, $0)
            }
        )
    }

    init(
        validating registrations: [FH5NumericRulesetRegistration]
    ) throws {
        var registrationsByID:
            [FH5ExperimentalAlgorithmID: FH5NumericRulesetRegistration] = [:]
        for registration in registrations {
            guard registration.isValid else {
                throw FH5NumericRulesetRegistryIssue.invalidRegistration(
                    registration.algorithmID
                )
            }
            guard registrationsByID[registration.algorithmID] == nil else {
                throw FH5NumericRulesetRegistryIssue.duplicateAlgorithmID(
                    registration.algorithmID
                )
            }
            registrationsByID[registration.algorithmID] = registration
        }
        self.registrations = registrationsByID
    }

    var isEmpty: Bool { registrations.isEmpty }

    func registration(
        for algorithmID: FH5ExperimentalAlgorithmID?
    ) -> FH5NumericRulesetRegistration? {
        guard let algorithmID else { return nil }
        return registrations[algorithmID]
    }
}

struct FH5NumericReadinessPolicy {
    static let currentVersion = "fh5-numeric-readiness-v3"

    private let registry: FH5TrustedNumericRulesetRegistry

    init(
        registry: FH5TrustedNumericRulesetRegistry = .production
    ) {
        self.registry = registry
    }

    func assess(
        tune: TuneResult,
        researchRecords: [FH5ResearchObservationRecord],
        reviewReport: FH5ResearchReviewReport,
        candidateAlgorithmID: FH5ExperimentalAlgorithmID? = nil,
        candidateBinding: FH5RulesetCandidateBinding? = nil,
        controlledOutcomeReport: FH5ControlledOutcomePolicyReport = .empty
    ) -> FH5NumericReadinessAssessment {
        let exactContext = hasExactStockContext(tune)
        let matchingRecords = exactContext
            ? researchRecords.filter { FH5ResearchObservationFactory().matches($0, tune: tune) }
            : []
        let latestRecord = matchingRecords.max { $0.capturedAt < $1.capturedAt }
        let hasMenuObservation = latestRecord != nil
        let hasCompleteUpgradeObservation = latestRecord.map(hasCompleteUpgradeObservation) ?? false
        let replicationState = replicationState(
            record: latestRecord,
            report: reviewReport
        )
        let registeredRuleset = registry.registration(
            for: candidateAlgorithmID
        )
        let hasRegisteredRuleset = registeredRuleset != nil
        let hasControlledOutcomes = registeredRuleset.map {
            controlledOutcomeReport.authorizes(
                registration: $0,
                candidateBinding: candidateBinding
            )
        } ?? false

        return FH5NumericReadinessAssessment(
            policyVersion: Self.currentVersion,
            items: [
                item(
                    .exactStockContext,
                    complete: exactContext,
                    completeDetail: "Untouched catalog car and current plan revision match.",
                    pendingDetail: "Use an untouched FH5 car from the reviewed catalog."
                ),
                item(
                    .firstPartyMenuObservation,
                    complete: hasMenuObservation,
                    completeDetail: "Exact slider availability, ranges, steps, and restored stock values recorded.",
                    pendingDetail: "Record the untouched tuning menu in Research Lab."
                ),
                item(
                    .completeUpgradeObservation,
                    complete: hasCompleteUpgradeObservation,
                    completeDetail: "Every supported tuning-control upgrade has an exact shop decision.",
                    pendingDetail: "Complete Upgrade Lab before the Research Lab capture."
                ),
                FH5NumericReadinessItem(
                    gate: .replicatedMenuObservation,
                    state: replicationState,
                    detail: replicationDetail(for: replicationState)
                ),
                item(
                    .rightsClearedRuleset,
                    complete: hasRegisteredRuleset,
                    completeDetail: "The exact FH5 algorithm version is approved by the code-owned registry.",
                    pendingDetail: "No rights-cleared FH5 numeric ruleset is approved yet.",
                    incompleteState: .blocked
                ),
                FH5NumericReadinessItem(
                    gate: .controlledOutcomes,
                    state: hasControlledOutcomes ? .complete : .blocked,
                    detail: controlledOutcomeDetail(
                        report: controlledOutcomeReport,
                        complete: hasControlledOutcomes
                    )
                )
            ]
        )
    }

    private func hasExactStockContext(_ tune: TuneResult) -> Bool {
        guard tune.request.car.game == .fh5,
              tune.purpose == .fh5BuildPlan,
              tune.sections.isEmpty,
              tune.providerInfo == nil,
              tune.rulesetReference == nil,
              tune.request.car.catalogReference != nil,
              !tune.request.car.catalogValuesModified,
              let snapshot = tune.request.buildSnapshot,
              snapshot.kind == .capabilityOnly,
              snapshot.isValid,
              snapshot.matches(car: tune.request.car),
              snapshot.constraints.isEmpty,
              snapshot.tireCompound == nil,
              snapshot.gearCount == nil,
              !snapshot.capabilityProfile.parts.contains(where: {
                  $0.availability == .installed
              }) else {
            return false
        }
        return true
    }

    private func hasCompleteUpgradeObservation(
        _ record: FH5ResearchObservationRecord
    ) -> Bool {
        let expected = Set(TunePartID.allCases)
        return record.upgradeParts.count == expected.count
            && Set(record.upgradeParts.map(\.partID)) == expected
            && record.upgradeParts.allSatisfy {
                $0.availability == .available || $0.availability == .unavailable
            }
    }

    private func replicationState(
        record: FH5ResearchObservationRecord?,
        report: FH5ResearchReviewReport
    ) -> FH5NumericReadinessState {
        guard let record else { return .pending }
        let groups = report.groups.filter { group in
            let association = group.association
            return association.platform == record.platform
                && association.gameVersion == record.gameVersion
                && association.vehicle == record.vehicle
                && association.tireCompoundDisplayName == record.tireCompoundDisplayName
                && association.forwardGearCount == record.forwardGearCount
        }
        if groups.contains(where: { $0.status == .conflicted }) {
            return .blocked
        }
        let localMeasurement = FH5ResearchReviewIngestor()
            .measurementFingerprint(for: record.controls)
        return groups.contains {
            $0.status == .replicated
                && $0.measurementFingerprint == localMeasurement
        }
            ? .complete
            : .pending
    }

    private func item(
        _ gate: FH5NumericReadinessGate,
        complete: Bool,
        completeDetail: String,
        pendingDetail: String,
        incompleteState: FH5NumericReadinessState = .pending
    ) -> FH5NumericReadinessItem {
        FH5NumericReadinessItem(
            gate: gate,
            state: complete ? .complete : incompleteState,
            detail: complete ? completeDetail : pendingDetail
        )
    }

    private func replicationDetail(
        for state: FH5NumericReadinessState
    ) -> String {
        switch state {
        case .complete:
            "At least two permission-bound sessions agree on the exact menu measurements."
        case .pending:
            "Import a second permission-bound observation for the exact same menu context."
        case .blocked:
            "Conflicting measurements must be resolved; values are never averaged."
        }
    }

    private func controlledOutcomeDetail(
        report: FH5ControlledOutcomePolicyReport,
        complete: Bool
    ) -> String {
        if complete {
            return "The registered ruleset passed its declared controlled-outcome policy."
        }
        if report.state == .blocked {
            return "Candidate-bound outcome evidence has an integrity conflict and cannot be promoted."
        }
        if report.state == .pending {
            return "\(report.matchingRecordCount) exact candidate-bound experiments qualify; the declared threshold is not complete."
        }
        if report.matchingRecordCount > 0 {
            let noun = report.matchingRecordCount == 1 ? "experiment" : "experiments"
            return "\(report.matchingRecordCount) matching paired \(noun) recorded; no promotion policy is registered yet."
        }
        return "Controlled A-B-B-A Test Track evidence and a registered promotion policy are still required."
    }
}

nonisolated private func isCanonicalIdentifier(
    _ value: String,
    maximumLength: Int
) -> Bool {
    !value.isEmpty
        && value.count <= maximumLength
        && value == value.lowercased()
        && value.allSatisfy {
            $0.isASCII
                && ($0.isLetter
                    || $0.isNumber
                    || $0 == "."
                    || $0 == "-"
                    || $0 == "_")
        }
}

nonisolated private func isCanonicalText(
    _ value: String,
    maximumLength: Int
) -> Bool {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return !trimmed.isEmpty
        && trimmed == value
        && value.count <= maximumLength
        && !value.unicodeScalars.contains {
            CharacterSet.controlCharacters.contains($0)
        }
}

nonisolated private func sha256Fingerprint(_ data: Data) -> String {
    SHA256.hash(data: data)
        .map { String(format: "%02x", $0) }
        .joined()
}

nonisolated private func isSHA256Fingerprint(_ value: String) -> Bool {
    value.count == 64
        && value.allSatisfy { $0.isHexDigit && !$0.isUppercase }
}
