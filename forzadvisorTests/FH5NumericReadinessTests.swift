import SwiftData
import XCTest
@testable import forzadvisor

final class FH5NumericReadinessTests: FH5ResearchTestCase {
    func testNumericReadinessRejectsUnregisteredAlgorithmAfterEveryEvidenceGatePasses() async throws {
        let plan = try await makePlan(upgradeBuild: "3.688.109.0")
        let record = try FH5ResearchObservationFactory().make(
            tune: plan,
            savedTune: plan,
            isStreaming: false,
            capture: validCapture(
                drivetrain: plan.request.car.drivetrain,
                gearCount: 6,
                availability: .adjustable,
                reuse: true
            ),
            capturedAt: capturedAt
        )
        let report = FH5ResearchReviewReport(
            receivedCount: 2,
            verifiedUniqueObservationCount: 2,
            invalidCount: 0,
            quarantinedCount: 0,
            duplicateCount: 0,
            administrativeConflictCount: 0,
            receiptReplayCount: 0,
            groups: [
                FH5ResearchReviewGroup(
                    associationFingerprint: "synthetic-matching-association",
                    association: FH5ResearchReviewAssociation(
                        platform: record.platform,
                        gameVersion: record.gameVersion,
                        vehicle: record.vehicle,
                        tireCompoundDisplayName: record.tireCompoundDisplayName,
                        forwardGearCount: record.forwardGearCount
                    ),
                    observationCount: 2,
                    measurementVariantCount: 1,
                    measurementFingerprint: FH5ResearchReviewIngestor()
                        .measurementFingerprint(for: record.controls),
                    status: .replicated
                )
            ]
        )
        let forged = try XCTUnwrap(TuneRulesetReference(descriptor: TuneRulesetDescriptor(
            id: FH5ExperimentalAlgorithmID.cleanRoomDirectionalV1.rawValue,
            game: .fh5,
            schemaVersion: 1,
            algorithmVersion: "1",
            knowledgeRevision: "unreviewed",
            validationStatus: .validated,
            provenanceIDs: ["self-asserted"]
        )))
        XCTAssertTrue(forged.isValid)

        let assessment = FH5NumericReadinessPolicy().assess(
            tune: plan,
            researchRecords: [record],
            reviewReport: report,
            candidateAlgorithmID: .cleanRoomDirectionalV1,
            controlledOutcomeReport: .unregistered(matchingRecordCount: 1)
        )

        XCTAssertFalse(assessment.canGenerateNumeric)
        XCTAssertEqual(assessment.policyVersion, "fh5-numeric-readiness-v3")
        XCTAssertEqual(
            assessment.items.prefix(4).map(\.state),
            Array(repeating: .complete, count: 4)
        )
        XCTAssertEqual(
            assessment.items.first { $0.gate == .rightsClearedRuleset }?.state,
            .blocked
        )
        XCTAssertEqual(
            assessment.items.first { $0.gate == .controlledOutcomes }?.state,
            .blocked
        )
        XCTAssertTrue(FH5TrustedNumericRulesetRegistry.production.isEmpty)
        XCTAssertNil(
            FH5TrustedNumericRulesetRegistry.production.registration(
                for: .cleanRoomDirectionalV1
            )
        )
    }
    func testRegisteredAlgorithmCompletesRightsGateButCannotActivateNumbers() async throws {
        let plan = try await makePlan(upgradeBuild: "3.688.109.0")
        let record = try FH5ResearchObservationFactory().make(
            tune: plan,
            savedTune: plan,
            isStreaming: false,
            capture: validCapture(
                drivetrain: plan.request.car.drivetrain,
                gearCount: 6,
                availability: .adjustable,
                reuse: true
            ),
            capturedAt: capturedAt
        )
        let report = FH5ResearchReviewReport(
            receivedCount: 2,
            verifiedUniqueObservationCount: 2,
            invalidCount: 0,
            quarantinedCount: 0,
            duplicateCount: 0,
            administrativeConflictCount: 0,
            receiptReplayCount: 0,
            groups: [
                FH5ResearchReviewGroup(
                    associationFingerprint: "synthetic-matching-association",
                    association: FH5ResearchReviewAssociation(
                        platform: record.platform,
                        gameVersion: record.gameVersion,
                        vehicle: record.vehicle,
                        tireCompoundDisplayName:
                            record.tireCompoundDisplayName,
                        forwardGearCount: record.forwardGearCount
                    ),
                    observationCount: 2,
                    measurementVariantCount: 1,
                    measurementFingerprint: FH5ResearchReviewIngestor()
                        .measurementFingerprint(for: record.controls),
                    status: .replicated
                )
            ]
        )
        let registration = try makeExperimentalRegistration()
        let registry = try FH5TrustedNumericRulesetRegistry(
            validating: [registration]
        )
        let assessment = FH5NumericReadinessPolicy(
            registry: registry
        ).assess(
            tune: plan,
            researchRecords: [record],
            reviewReport: report,
            candidateAlgorithmID: registration.algorithmID,
            controlledOutcomeReport: .unregistered(matchingRecordCount: 10)
        )

        XCTAssertEqual(
            assessment.items.first { $0.gate == .rightsClearedRuleset }?.state,
            .complete
        )
        XCTAssertEqual(
            assessment.items.first { $0.gate == .controlledOutcomes }?.state,
            .blocked
        )
        XCTAssertFalse(assessment.canGenerateNumeric)
        XCTAssertEqual(plan.purpose, .fh5BuildPlan)
        XCTAssertTrue(plan.sections.isEmpty)
        XCTAssertNil(plan.providerInfo)
        XCTAssertNil(plan.rulesetReference)
    }
    func testNumericReadinessExplainsMissingEvidenceWithoutUnlockingNumbers() async throws {
        let plan = try await makePlan()
        let assessment = FH5NumericReadinessPolicy().assess(
            tune: plan,
            researchRecords: [],
            reviewReport: .empty
        )

        XCTAssertFalse(assessment.canGenerateNumeric)
        XCTAssertEqual(
            assessment.items.first { $0.gate == .exactStockContext }?.state,
            .complete
        )
        XCTAssertEqual(
            assessment.items.first { $0.gate == .firstPartyMenuObservation }?.state,
            .pending
        )
        XCTAssertEqual(
            assessment.items.first { $0.gate == .completeUpgradeObservation }?.state,
            .pending
        )
        XCTAssertEqual(
            assessment.items.first { $0.gate == .replicatedMenuObservation }?.state,
            .pending
        )
        XCTAssertEqual(
            assessment.items.first { $0.gate == .rightsClearedRuleset }?.state,
            .blocked
        )

        var installedPlan = plan
        var installedSnapshot = try XCTUnwrap(installedPlan.request.buildSnapshot)
        installedSnapshot.capabilityProfile.parts.append(TuneVehiclePart(
            partID: .raceBrakes,
            availability: .installed,
            evidence: TuneEvidence(
                confidence: .medium,
                source: "test.first-party-installed-part",
                version: "test",
                usagePermission: .permitted
            )
        ))
        installedPlan.request.buildSnapshot = installedSnapshot
        let installedAssessment = FH5NumericReadinessPolicy().assess(
            tune: installedPlan,
            researchRecords: [],
            reviewReport: .empty
        )
        XCTAssertEqual(
            installedAssessment.items.first { $0.gate == .exactStockContext }?.state,
            .pending
        )
        XCTAssertFalse(installedAssessment.canGenerateNumeric)
    }
}
