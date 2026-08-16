import SwiftData
import XCTest
@testable import forzadvisor

final class FH5CandidateEvaluatorSuccessTests: FH5ResearchTestCase {
    func testCandidateBoundEvaluatorPassesExactThresholdWithoutRoutingNumbers() async throws {
        let plan = try await makePlan(upgradeBuild: "3.688.109.0")
        let research = try FH5ResearchObservationFactory().make(
            tune: plan,
            savedTune: plan,
            isStreaming: false,
            capture: validCapture(
                drivetrain: plan.request.car.drivetrain,
                gearCount: 6,
                availability: .adjustable
            ),
            capturedAt: capturedAt
        )
        let registration = try makeExperimentalRegistration()
        let registry = try FH5TrustedNumericRulesetRegistry(
            validating: [registration]
        )
        let outcomes = Array(
            repeating: FH5ExperimentOutcome.variantPreferred,
            count: 8
        ) + [.noClearDifference, .inconclusive]
        let records = try makeBoundExperiments(
            plan: plan,
            research: research,
            registry: registry,
            registration: registration,
            outcomes: outcomes
        )
        let binding = try XCTUnwrap(records.first?.candidateBinding)
        let evaluator = FH5ControlledOutcomeEvaluator()
        let report = evaluator.evaluate(
            records: records,
            tune: plan,
            researchRecord: research,
            candidateBinding: binding,
            registry: registry
        )

        XCTAssertTrue(report.passes)
        XCTAssertEqual(report.state, .passed)
        XCTAssertEqual(report.matchingRecordCount, 10)
        XCTAssertEqual(report.variantPreferredCount, 8)
        XCTAssertEqual(report.baselinePreferredCount, 0)
        XCTAssertEqual(report.nonDecisiveCount, 2)
        XCTAssertEqual(report.distinctUTCDayCount, 2)
        XCTAssertTrue(report.issues.isEmpty)
        XCTAssertEqual(
            evaluator.evaluate(
                records: records.reversed(),
                tune: plan,
                researchRecord: research,
                candidateBinding: binding,
                registry: registry
            ),
            report
        )

        let readiness = FH5NumericReadinessPolicy(
            registry: registry
        ).assess(
            tune: plan,
            researchRecords: [research],
            reviewReport: replicatedReviewReport(for: research),
            candidateAlgorithmID: registration.algorithmID,
            candidateBinding: binding,
            controlledOutcomeReport: report
        )
        XCTAssertTrue(readiness.canGenerateNumeric)
        XCTAssertEqual(
            readiness.items.first {
                $0.gate == .controlledOutcomes
            }?.state,
            .complete
        )
        XCTAssertEqual(plan.purpose, .fh5BuildPlan)
        XCTAssertTrue(plan.sections.isEmpty)
        XCTAssertNil(plan.providerInfo)
        XCTAssertNil(plan.rulesetReference)

        let otherBinding = FH5RulesetCandidateBinding(
            algorithmID: binding.algorithmID,
            rulesetReference: binding.rulesetReference,
            sourceManifestFingerprint: binding.sourceManifestFingerprint,
            outcomePolicyVersion: binding.outcomePolicyVersion,
            generatedCandidateFingerprint: String(repeating: "b", count: 64)
        )
        XCTAssertFalse(report.authorizes(
            registration: registration,
            candidateBinding: otherBinding
        ))
        XCTAssertFalse(FH5NumericReadinessPolicy().assess(
            tune: plan,
            researchRecords: [research],
            reviewReport: replicatedReviewReport(for: research),
            candidateAlgorithmID: registration.algorithmID,
            candidateBinding: binding,
            controlledOutcomeReport: report
        ).canGenerateNumeric)
    }
}
