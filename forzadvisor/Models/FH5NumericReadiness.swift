//
//  FH5NumericReadiness.swift
//  forzadvisor
//
//  Fail-closed evidence contract for a future, separately versioned FH5
//  numeric ruleset. Research observations establish menu facts, not tune
//  quality, and cannot authorize numeric output by themselves.
//

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

/// A code-owned allow-list is deliberately stronger than
/// `TuneRulesetReference.isValid`, which only validates descriptor structure.
struct FH5TrustedNumericRulesetRegistry: Sendable {
    static let production = Self(approvedRulesets: [])

    private let approvedRulesets: [TuneRulesetReference]

    private init(approvedRulesets: [TuneRulesetReference]) {
        self.approvedRulesets = approvedRulesets
    }

    func approves(_ reference: TuneRulesetReference?) -> Bool {
        guard let reference,
              reference.isValid,
              reference.game == .fh5 else { return false }
        return approvedRulesets.contains(reference)
    }
}

struct FH5NumericReadinessPolicy {
    static let currentVersion = "fh5-numeric-readiness-v1"

    private let registry: FH5TrustedNumericRulesetRegistry

    init() {
        registry = .production
    }

    func assess(
        tune: TuneResult,
        researchRecords: [FH5ResearchObservationRecord],
        reviewReport: FH5ResearchReviewReport,
        candidateRuleset: TuneRulesetReference? = nil,
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
        let hasRegisteredRuleset = registry.approves(candidateRuleset)
        let hasControlledOutcomes = hasRegisteredRuleset
            && controlledOutcomeReport.passes

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
        if report.matchingRecordCount > 0 {
            let noun = report.matchingRecordCount == 1 ? "experiment" : "experiments"
            return "\(report.matchingRecordCount) matching paired \(noun) recorded; no promotion policy is registered yet."
        }
        return "Controlled A-B-B-A Test Track evidence and a registered promotion policy are still required."
    }
}
