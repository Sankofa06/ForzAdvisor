//
//  FH5ControlledOutcomeEvaluator.swift
//  forzadvisor
//
//  Deterministic, candidate-bound evaluation for test-injected FH5 rulesets.
//  Production registration and numeric activation remain intentionally absent.
//

import Foundation

enum FH5ControlledOutcomeReportState: String, Equatable, Sendable {
    case unregistered
    case pending
    case blocked
    case passed
}

enum FH5ControlledOutcomeIssue: String, CaseIterable, Equatable, Sendable {
    case missingResearchRecord
    case unregisteredAlgorithm
    case invalidCandidateBinding
    case invalidClaimedRecord
    case duplicateRecordID
    case duplicateSubmissionID
    case duplicatePermissionReceiptID
    case duplicateContentFingerprint
    case duplicateSemanticFingerprint
    case insufficientUniqueRecords
    case insufficientVariantPreferred
    case baselinePreferredExceeded
    case nonDecisiveExceeded
    case insufficientDistinctUTCDays
}

struct FH5ControlledOutcomePolicyReport: Equatable, Sendable {
    static let currentVersion = "fh5-controlled-outcome-policy-unregistered"
    static let empty = unregistered(matchingRecordCount: 0)

    let state: FH5ControlledOutcomeReportState
    let policyVersion: String
    let candidateBinding: FH5RulesetCandidateBinding?
    let matchingRecordCount: Int
    let variantPreferredCount: Int
    let baselinePreferredCount: Int
    let nonDecisiveCount: Int
    let distinctUTCDayCount: Int
    let issues: [FH5ControlledOutcomeIssue]

    var passes: Bool { state == .passed }

    private init(
        state: FH5ControlledOutcomeReportState,
        policyVersion: String,
        candidateBinding: FH5RulesetCandidateBinding?,
        matchingRecordCount: Int,
        variantPreferredCount: Int,
        baselinePreferredCount: Int,
        nonDecisiveCount: Int,
        distinctUTCDayCount: Int,
        issues: [FH5ControlledOutcomeIssue]
    ) {
        self.state = state
        self.policyVersion = policyVersion
        self.candidateBinding = candidateBinding
        self.matchingRecordCount = max(0, matchingRecordCount)
        self.variantPreferredCount = max(0, variantPreferredCount)
        self.baselinePreferredCount = max(0, baselinePreferredCount)
        self.nonDecisiveCount = max(0, nonDecisiveCount)
        self.distinctUTCDayCount = max(0, distinctUTCDayCount)
        self.issues = FH5ControlledOutcomeIssue.allCases.filter(
            Set(issues).contains
        )
    }

    static func unregistered(
        matchingRecordCount: Int,
        issues: [FH5ControlledOutcomeIssue] = []
    ) -> FH5ControlledOutcomePolicyReport {
        FH5ControlledOutcomePolicyReport(
            state: .unregistered,
            policyVersion: currentVersion,
            candidateBinding: nil,
            matchingRecordCount: matchingRecordCount,
            variantPreferredCount: 0,
            baselinePreferredCount: 0,
            nonDecisiveCount: 0,
            distinctUTCDayCount: 0,
            issues: issues
        )
    }

    fileprivate static func evaluated(
        state: FH5ControlledOutcomeReportState,
        registration: FH5NumericRulesetRegistration,
        candidateBinding: FH5RulesetCandidateBinding,
        matchingRecordCount: Int,
        variantPreferredCount: Int,
        baselinePreferredCount: Int,
        nonDecisiveCount: Int,
        distinctUTCDayCount: Int,
        issues: [FH5ControlledOutcomeIssue]
    ) -> FH5ControlledOutcomePolicyReport {
        FH5ControlledOutcomePolicyReport(
            state: state,
            policyVersion: registration.outcomeThreshold.policyVersion,
            candidateBinding: candidateBinding,
            matchingRecordCount: matchingRecordCount,
            variantPreferredCount: variantPreferredCount,
            baselinePreferredCount: baselinePreferredCount,
            nonDecisiveCount: nonDecisiveCount,
            distinctUTCDayCount: distinctUTCDayCount,
            issues: issues
        )
    }

    func authorizes(
        registration: FH5NumericRulesetRegistration,
        candidateBinding: FH5RulesetCandidateBinding?
    ) -> Bool {
        guard let candidateBinding else { return false }
        return passes
            && policyVersion == registration.outcomeThreshold.policyVersion
            && self.candidateBinding == candidateBinding
            && candidateBinding.isValid(for: registration)
    }
}

struct FH5ControlledOutcomeEvaluator {
    func evaluate(
        records: [FH5ControlledExperimentRecord],
        tune: TuneResult,
        researchRecord: FH5ResearchObservationRecord?,
        candidateBinding: FH5RulesetCandidateBinding,
        registry: FH5TrustedNumericRulesetRegistry
    ) -> FH5ControlledOutcomePolicyReport {
        guard let researchRecord else {
            return .unregistered(
                matchingRecordCount: 0,
                issues: [.missingResearchRecord]
            )
        }
        guard let registration = registry.registration(
            for: candidateBinding.algorithmID
        ) else {
            return .unregistered(
                matchingRecordCount: 0,
                issues: [.unregisteredAlgorithm]
            )
        }
        guard candidateBinding.isValid(for: registration) else {
            return .evaluated(
                state: .blocked,
                registration: registration,
                candidateBinding: candidateBinding,
                matchingRecordCount: 0,
                variantPreferredCount: 0,
                baselinePreferredCount: 0,
                nonDecisiveCount: 0,
                distinctUTCDayCount: 0,
                issues: [.invalidCandidateBinding]
            )
        }

        let factory = FH5ControlledExperimentFactory()
        let candidateShapedRecords = records
            .filter {
                $0.schemaVersion
                    == FH5ControlledExperimentRecord
                        .candidateBoundSchemaVersion
                    || $0.candidateBinding != nil
            }
            .sorted(by: stableOrder)
        let validBoundRecords = candidateShapedRecords.filter {
            factory.isValid($0)
                && isRegistered($0.candidateBinding, in: registry)
        }
        let candidateRecords = validBoundRecords.filter {
            $0.candidateBinding == candidateBinding
        }

        let duplicateRecordIDs = duplicateValues(
            candidateShapedRecords.map(\.recordID)
        )
        let duplicateSubmissionIDs = duplicateValues(
            candidateShapedRecords.map(\.submissionID)
        )
        let duplicatePermissionReceiptIDs = duplicateValues(
            candidateShapedRecords.map(\.permissionReceiptID)
        )
        let duplicateContentFingerprints = duplicateValues(
            candidateShapedRecords.map(\.contentFingerprint)
        )
        var semanticFingerprintsByRecord: [UUID: [String]] = [:]
        var semanticFingerprints: [String] = []
        for record in candidateShapedRecords {
            guard let semantic = try? factory
                .candidateBoundAuditSemanticFingerprint(for: record) else {
                continue
            }
            semanticFingerprintsByRecord[record.recordID, default: []]
                .append(semantic)
            semanticFingerprints.append(semantic)
        }
        let duplicateSemanticFingerprints = duplicateValues(
            semanticFingerprints
        )
        let candidateRecordIDs = Set(candidateRecords.map(\.recordID))
        let candidateSubmissionIDs = Set(
            candidateRecords.map(\.submissionID)
        )
        let candidatePermissionReceiptIDs = Set(
            candidateRecords.map(\.permissionReceiptID)
        )
        let candidateContentFingerprints = Set(
            candidateRecords.map(\.contentFingerprint)
        )
        let candidateSemanticFingerprints = Set(
            candidateRecords.flatMap {
                semanticFingerprintsByRecord[$0.recordID] ?? []
            }
        )
        let invalidClaimedRecord = candidateShapedRecords.contains { record in
            let trustedRecord = factory.isValid(record)
                && isRegistered(record.candidateBinding, in: registry)
            guard !trustedRecord else { return false }
            if record.candidateBinding == candidateBinding {
                return true
            }
            let semanticReplay = (
                try? factory.candidateBoundAuditSemanticFingerprint(
                    for: record
                )
            ).map(candidateSemanticFingerprints.contains) ?? false
            return candidateRecordIDs.contains(record.recordID)
                || candidateSubmissionIDs.contains(record.submissionID)
                || candidatePermissionReceiptIDs.contains(
                    record.permissionReceiptID
                )
                || candidateContentFingerprints.contains(
                    record.contentFingerprint
                )
                || semanticReplay
        }

        var integrityIssues: [FH5ControlledOutcomeIssue] = []
        if invalidClaimedRecord {
            integrityIssues.append(.invalidClaimedRecord)
        }
        if candidateRecords.contains(where: {
            duplicateRecordIDs.contains($0.recordID)
        }) {
            integrityIssues.append(.duplicateRecordID)
        }
        if candidateRecords.contains(where: {
            duplicateSubmissionIDs.contains($0.submissionID)
        }) {
            integrityIssues.append(.duplicateSubmissionID)
        }
        if candidateRecords.contains(where: {
            duplicatePermissionReceiptIDs.contains($0.permissionReceiptID)
        }) {
            integrityIssues.append(.duplicatePermissionReceiptID)
        }
        if candidateRecords.contains(where: {
            duplicateContentFingerprints.contains($0.contentFingerprint)
        }) {
            integrityIssues.append(.duplicateContentFingerprint)
        }
        if candidateRecords.contains(where: {
            (semanticFingerprintsByRecord[$0.recordID] ?? []).contains {
                duplicateSemanticFingerprints.contains($0)
            }
        }) {
            integrityIssues.append(.duplicateSemanticFingerprint)
        }

        let matching = candidateRecords.filter {
            $0.attestations.deidentifiedReusePermitted
                && factory.matches(
                    $0,
                    tune: tune,
                    researchRecord: researchRecord
                )
        }
        let variantPreferredCount = matching.count {
            $0.outcome == .variantPreferred
        }
        let baselinePreferredCount = matching.count {
            $0.outcome == .baselinePreferred
        }
        let nonDecisiveCount = matching.count {
            $0.outcome == .noClearDifference
                || $0.outcome == .inconclusive
        }
        let distinctUTCDayCount = distinctUTCDays(in: matching)
        let threshold = registration.outcomeThreshold

        var thresholdIssues: [FH5ControlledOutcomeIssue] = []
        if matching.count < threshold.minimumUniqueRecords {
            thresholdIssues.append(.insufficientUniqueRecords)
        }
        if variantPreferredCount < threshold.minimumVariantPreferred {
            thresholdIssues.append(.insufficientVariantPreferred)
        }
        if baselinePreferredCount > threshold.maximumBaselinePreferred {
            thresholdIssues.append(.baselinePreferredExceeded)
        }
        if nonDecisiveCount > threshold.maximumNonDecisive {
            thresholdIssues.append(.nonDecisiveExceeded)
        }
        if distinctUTCDayCount < threshold.minimumDistinctUTCDays {
            thresholdIssues.append(.insufficientDistinctUTCDays)
        }

        let issues = integrityIssues + thresholdIssues
        let state: FH5ControlledOutcomeReportState
        if !integrityIssues.isEmpty {
            state = .blocked
        } else if thresholdIssues.isEmpty {
            state = .passed
        } else {
            state = .pending
        }
        return .evaluated(
            state: state,
            registration: registration,
            candidateBinding: candidateBinding,
            matchingRecordCount: matching.count,
            variantPreferredCount: variantPreferredCount,
            baselinePreferredCount: baselinePreferredCount,
            nonDecisiveCount: nonDecisiveCount,
            distinctUTCDayCount: distinctUTCDayCount,
            issues: issues
        )
    }

    private func isRegistered(
        _ candidateBinding: FH5RulesetCandidateBinding?,
        in registry: FH5TrustedNumericRulesetRegistry
    ) -> Bool {
        guard
            let candidateBinding,
            let registration = registry.registration(
                for: candidateBinding.algorithmID
            )
        else {
            return false
        }
        return candidateBinding.isValid(for: registration)
    }

    private func duplicateValues<Value: Hashable>(
        _ values: [Value]
    ) -> Set<Value> {
        var seen = Set<Value>()
        var duplicates = Set<Value>()
        for value in values where !seen.insert(value).inserted {
            duplicates.insert(value)
        }
        return duplicates
    }

    private func distinctUTCDays(
        in records: [FH5ControlledExperimentRecord]
    ) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        if let utc = TimeZone(secondsFromGMT: 0) {
            calendar.timeZone = utc
        }
        return Set(records.map {
            calendar.dateComponents(
                [.year, .month, .day],
                from: $0.createdAt
            )
        }).count
    }

    private func stableOrder(
        _ lhs: FH5ControlledExperimentRecord,
        _ rhs: FH5ControlledExperimentRecord
    ) -> Bool {
        if lhs.contentFingerprint != rhs.contentFingerprint {
            return lhs.contentFingerprint < rhs.contentFingerprint
        }
        return lhs.recordID.uuidString < rhs.recordID.uuidString
    }
}
