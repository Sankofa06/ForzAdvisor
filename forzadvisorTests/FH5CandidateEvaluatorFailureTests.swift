import SwiftData
import XCTest
@testable import forzadvisor

final class FH5CandidateEvaluatorFailureTests: FH5ResearchTestCase {
    func testCandidateBoundEvaluatorFailsClosedOnThresholdsLegacyAndReplay() async throws {
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
        let passingOutcomes = Array(
            repeating: FH5ExperimentOutcome.variantPreferred,
            count: 8
        ) + [.noClearDifference, .inconclusive]
        let passing = try makeBoundExperiments(
            plan: plan,
            research: research,
            registry: registry,
            registration: registration,
            outcomes: passingOutcomes
        )
        let binding = try XCTUnwrap(passing.first?.candidateBinding)
        let evaluator = FH5ControlledOutcomeEvaluator()

        let short = evaluator.evaluate(
            records: Array(passing.prefix(9)),
            tune: plan,
            researchRecord: research,
            candidateBinding: binding,
            registry: registry
        )
        XCTAssertEqual(short.state, .pending)
        XCTAssertTrue(short.issues.contains(.insufficientUniqueRecords))

        let baseline = try makeBoundExperiments(
            plan: plan,
            research: research,
            registry: registry,
            registration: registration,
            outcomes: Array(
                repeating: FH5ExperimentOutcome.variantPreferred,
                count: 8
            ) + [.baselinePreferred, .noClearDifference]
        )
        let baselineReport = evaluator.evaluate(
            records: baseline,
            tune: plan,
            researchRecord: research,
            candidateBinding: try XCTUnwrap(
                baseline.first?.candidateBinding
            ),
            registry: registry
        )
        XCTAssertFalse(baselineReport.passes)
        XCTAssertTrue(
            baselineReport.issues.contains(.baselinePreferredExceeded)
        )

        let tooManyNonDecisive = try makeBoundExperiments(
            plan: plan,
            research: research,
            registry: registry,
            registration: registration,
            outcomes: Array(
                repeating: FH5ExperimentOutcome.variantPreferred,
                count: 7
            ) + [
                .noClearDifference,
                .noClearDifference,
                .inconclusive
            ]
        )
        let nonDecisiveReport = evaluator.evaluate(
            records: tooManyNonDecisive,
            tune: plan,
            researchRecord: research,
            candidateBinding: try XCTUnwrap(
                tooManyNonDecisive.first?.candidateBinding
            ),
            registry: registry
        )
        XCTAssertFalse(nonDecisiveReport.passes)
        XCTAssertTrue(
            nonDecisiveReport.issues.contains(
                .insufficientVariantPreferred
            )
        )
        XCTAssertTrue(
            nonDecisiveReport.issues.contains(.nonDecisiveExceeded)
        )

        let elevenWithBaseline = try makeBoundExperiments(
            plan: plan,
            research: research,
            registry: registry,
            registration: registration,
            outcomes: Array(
                repeating: FH5ExperimentOutcome.variantPreferred,
                count: 8
            ) + [
                .noClearDifference,
                .inconclusive,
                .baselinePreferred
            ]
        )
        let elevenBaselineReport = evaluator.evaluate(
            records: elevenWithBaseline,
            tune: plan,
            researchRecord: research,
            candidateBinding: try XCTUnwrap(
                elevenWithBaseline.first?.candidateBinding
            ),
            registry: registry
        )
        XCTAssertEqual(elevenBaselineReport.matchingRecordCount, 11)
        XCTAssertFalse(elevenBaselineReport.passes)
        XCTAssertTrue(
            elevenBaselineReport.issues.contains(
                .baselinePreferredExceeded
            )
        )

        let elevenWithThreeNonDecisive = try makeBoundExperiments(
            plan: plan,
            research: research,
            registry: registry,
            registration: registration,
            outcomes: Array(
                repeating: FH5ExperimentOutcome.variantPreferred,
                count: 8
            ) + [
                .noClearDifference,
                .noClearDifference,
                .inconclusive
            ]
        )
        let elevenNonDecisiveReport = evaluator.evaluate(
            records: elevenWithThreeNonDecisive,
            tune: plan,
            researchRecord: research,
            candidateBinding: try XCTUnwrap(
                elevenWithThreeNonDecisive.first?.candidateBinding
            ),
            registry: registry
        )
        XCTAssertEqual(elevenNonDecisiveReport.matchingRecordCount, 11)
        XCTAssertFalse(elevenNonDecisiveReport.passes)
        XCTAssertTrue(
            elevenNonDecisiveReport.issues.contains(
                .nonDecisiveExceeded
            )
        )

        let oneDayDates = passing.indices.map {
            capturedAt.addingTimeInterval(Double($0 * 60))
        }
        let oneDay = try makeBoundExperiments(
            plan: plan,
            research: research,
            registry: registry,
            registration: registration,
            outcomes: passingOutcomes,
            dates: oneDayDates
        )
        let oneDayReport = evaluator.evaluate(
            records: oneDay,
            tune: plan,
            researchRecord: research,
            candidateBinding: try XCTUnwrap(oneDay.first?.candidateBinding),
            registry: registry
        )
        XCTAssertFalse(oneDayReport.passes)
        XCTAssertEqual(oneDayReport.distinctUTCDayCount, 1)
        XCTAssertTrue(
            oneDayReport.issues.contains(.insufficientDistinctUTCDays)
        )

        let iso8601 = ISO8601DateFormatter()
        let beforeUTCMidnight = try XCTUnwrap(
            iso8601.date(from: "2026-07-23T23:59:50Z")
        )
        let afterUTCMidnight = try XCTUnwrap(
            iso8601.date(from: "2026-07-24T00:00:00Z")
        )
        let boundaryDates = passing.indices.map { index in
            if index < passing.count / 2 {
                beforeUTCMidnight.addingTimeInterval(Double(index))
            } else {
                afterUTCMidnight.addingTimeInterval(
                    Double(index - passing.count / 2)
                )
            }
        }
        let utcBoundaryRecords = try makeBoundExperiments(
            plan: plan,
            research: research,
            registry: registry,
            registration: registration,
            outcomes: passingOutcomes,
            dates: boundaryDates
        )
        let utcBoundaryReport = evaluator.evaluate(
            records: utcBoundaryRecords,
            tune: plan,
            researchRecord: research,
            candidateBinding: try XCTUnwrap(
                utcBoundaryRecords.first?.candidateBinding
            ),
            registry: registry
        )
        XCTAssertTrue(utcBoundaryReport.passes)
        XCTAssertEqual(utcBoundaryReport.distinctUTCDayCount, 2)

        let startOfUTCDate = try XCTUnwrap(
            iso8601.date(from: "2026-07-23T00:00:00Z")
        )
        let endOfUTCDate = try XCTUnwrap(
            iso8601.date(from: "2026-07-23T23:59:50Z")
        )
        let splitLocalDateTimes = passing.indices.map { index in
            if index < passing.count / 2 {
                startOfUTCDate.addingTimeInterval(Double(index))
            } else {
                endOfUTCDate.addingTimeInterval(
                    Double(index - passing.count / 2)
                )
            }
        }
        let oneUTCDateRecords = try makeBoundExperiments(
            plan: plan,
            research: research,
            registry: registry,
            registration: registration,
            outcomes: passingOutcomes,
            dates: splitLocalDateTimes
        )
        let oneUTCDateReport = evaluator.evaluate(
            records: oneUTCDateRecords,
            tune: plan,
            researchRecord: research,
            candidateBinding: try XCTUnwrap(
                oneUTCDateRecords.first?.candidateBinding
            ),
            registry: registry
        )
        XCTAssertFalse(oneUTCDateReport.passes)
        XCTAssertEqual(oneUTCDateReport.distinctUTCDayCount, 1)

        let permissionExcluded = try makeBoundExperiments(
            plan: plan,
            research: research,
            registry: registry,
            registration: registration,
            outcomes: passingOutcomes,
            reuseExcludedIndex: 9
        )
        let permissionReport = evaluator.evaluate(
            records: permissionExcluded,
            tune: plan,
            researchRecord: research,
            candidateBinding: try XCTUnwrap(
                permissionExcluded.first?.candidateBinding
            ),
            registry: registry
        )
        XCTAssertEqual(permissionReport.matchingRecordCount, 9)
        XCTAssertFalse(permissionReport.passes)

        let legacy = try passingOutcomes.enumerated().map { index, outcome in
            try FH5ControlledExperimentFactory().make(
                tune: plan,
                savedTune: plan,
                isStreaming: false,
                researchRecords: [research],
                capture: experimentCapture(
                    field: try XCTUnwrap(research.controls.first?.field),
                    candidate: 49,
                    reusePermitted: true,
                    outcome: outcome
                ),
                createdAt: capturedAt.addingTimeInterval(
                    Double(index * 60)
                )
            )
        }
        let legacyReport = evaluator.evaluate(
            records: legacy,
            tune: plan,
            researchRecord: research,
            candidateBinding: binding,
            registry: registry
        )
        XCTAssertEqual(legacyReport.matchingRecordCount, 0)
        XCTAssertFalse(legacyReport.passes)

        let duplicated = evaluator.evaluate(
            records: passing + [passing[0]],
            tune: plan,
            researchRecord: research,
            candidateBinding: binding,
            registry: registry
        )
        XCTAssertEqual(duplicated.state, .blocked)
        XCTAssertTrue(duplicated.issues.contains(.duplicateRecordID))
        XCTAssertTrue(duplicated.issues.contains(.duplicateSubmissionID))
        XCTAssertTrue(
            duplicated.issues.contains(.duplicatePermissionReceiptID)
        )
        XCTAssertTrue(
            duplicated.issues.contains(.duplicateContentFingerprint)
        )
        XCTAssertTrue(
            duplicated.issues.contains(.duplicateSemanticFingerprint)
        )

        let semanticReplay = try FH5ControlledExperimentFactory()
            .makeCandidateBoundForTesting(
                tune: plan,
                savedTune: plan,
                isStreaming: false,
                researchRecords: [research],
                capture: experimentCapture(
                    field: try XCTUnwrap(research.controls.first?.field),
                    candidate: 49,
                    reusePermitted: true,
                    outcome: passing[0].outcome
                ),
                candidateAlgorithmID: registration.algorithmID,
                registry: registry,
                createdAt: passing[0].createdAt
            )
        let replayReport = evaluator.evaluate(
            records: passing + [semanticReplay],
            tune: plan,
            researchRecord: research,
            candidateBinding: binding,
            registry: registry
        )
        XCTAssertEqual(replayReport.state, .blocked)
        XCTAssertTrue(
            replayReport.issues.contains(.duplicateSemanticFingerprint)
        )

        let crossCandidateReceiptReplay =
            try FH5ControlledExperimentFactory().makeCandidateBoundForTesting(
                tune: plan,
                savedTune: plan,
                isStreaming: false,
                researchRecords: [research],
                capture: experimentCapture(
                    field: try XCTUnwrap(research.controls.first?.field),
                    candidate: 51,
                    reusePermitted: true
                ),
                candidateAlgorithmID: registration.algorithmID,
                registry: registry,
                permissionReceiptID: passing[0].permissionReceiptID,
                createdAt: capturedAt.addingTimeInterval(200_000)
            )
        XCTAssertNotEqual(
            crossCandidateReceiptReplay.candidateBinding,
            binding
        )
        let crossCandidateReplayReport = evaluator.evaluate(
            records: passing + [crossCandidateReceiptReplay],
            tune: plan,
            researchRecord: research,
            candidateBinding: binding,
            registry: registry
        )
        XCTAssertEqual(crossCandidateReplayReport.state, .blocked)
        XCTAssertTrue(
            crossCandidateReplayReport.issues.contains(
                .duplicatePermissionReceiptID
            )
        )

        let alternateSource = FH5NumericRulesetSourceManifest(
            sourceID: "first-party.clean-room-alternate",
            sourceVersion: "1",
            owner: "ForzAdvisor",
            rightsBasis: .firstPartyCleanRoom,
            rightsEvidenceID: "internal.clean-room-alternate",
            usagePermission: .permitted
        )
        let alternateRegistration = try makeExperimentalRegistration(
            sourceManifests: [alternateSource]
        )
        let alternateRegistry = try FH5TrustedNumericRulesetRegistry(
            validating: [alternateRegistration]
        )
        let unregisteredReceiptReplay =
            try FH5ControlledExperimentFactory()
                .makeCandidateBoundForTesting(
                    tune: plan,
                    savedTune: plan,
                    isStreaming: false,
                    researchRecords: [research],
                    capture: experimentCapture(
                        field: try XCTUnwrap(
                            research.controls.first?.field
                        ),
                        candidate: 51,
                        reusePermitted: true
                    ),
                    candidateAlgorithmID:
                        alternateRegistration.algorithmID,
                    registry: alternateRegistry,
                    permissionReceiptID:
                        passing[0].permissionReceiptID,
                    createdAt:
                        capturedAt.addingTimeInterval(300_000)
                )
        for records in [
            passing + [unregisteredReceiptReplay],
            [unregisteredReceiptReplay] + passing
        ] {
            let report = evaluator.evaluate(
                records: records,
                tune: plan,
                researchRecord: research,
                candidateBinding: binding,
                registry: registry
            )
            XCTAssertEqual(report.state, .blocked)
            XCTAssertTrue(report.issues.contains(.invalidClaimedRecord))
            XCTAssertTrue(
                report.issues.contains(.duplicatePermissionReceiptID)
            )
        }

        let corruptedOtherCandidate = copyExperiment(
            crossCandidateReceiptReplay,
            schemaVersion:
                FH5ControlledExperimentRecord.candidateBoundSchemaVersion,
            consentVersion:
                FH5ControlledExperimentRecord.candidateBoundConsentVersion,
            candidateBinding:
                crossCandidateReceiptReplay.candidateBinding,
            contentFingerprint: String(repeating: "0", count: 64)
        )
        let schemaOneWithBinding = copyExperiment(
            passing[0],
            schemaVersion:
                FH5ControlledExperimentRecord.calibrationSchemaVersion,
            consentVersion:
                FH5ControlledExperimentRecord.calibrationConsentVersion,
            candidateBinding: binding
        )
        let schemaTwoWithoutBinding = copyExperiment(
            passing[0],
            schemaVersion:
                FH5ControlledExperimentRecord.candidateBoundSchemaVersion,
            consentVersion:
                FH5ControlledExperimentRecord.candidateBoundConsentVersion,
            candidateBinding: nil
        )
        for replay in [
            corruptedOtherCandidate,
            schemaOneWithBinding,
            schemaTwoWithoutBinding
        ] {
            for records in [
                passing + [replay],
                [replay] + passing
            ] {
                let report = evaluator.evaluate(
                    records: records,
                    tune: plan,
                    researchRecord: research,
                    candidateBinding: binding,
                    registry: registry
                )
                XCTAssertEqual(report.state, .blocked)
                XCTAssertTrue(
                    report.issues.contains(.invalidClaimedRecord)
                )
                XCTAssertTrue(
                    report.issues.contains(
                        .duplicatePermissionReceiptID
                    )
                )
            }
        }

        let passingWithLegacy = evaluator.evaluate(
            records: passing + [legacy[0]],
            tune: plan,
            researchRecord: research,
            candidateBinding: binding,
            registry: registry
        )
        XCTAssertTrue(passingWithLegacy.passes)
    }
}
