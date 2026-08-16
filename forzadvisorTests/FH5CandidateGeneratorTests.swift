import SwiftData
import XCTest
@testable import forzadvisor

final class FH5CandidateGeneratorTests: FH5ResearchTestCase {
    func testCleanRoomDirectionalGeneratorProducesDeterministicBoundArtifact() async throws {
        let plan = try await makePlan(upgradeBuild: "3.688.109.0")
        let older = try FH5ResearchObservationFactory().make(
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
        let latest = try FH5ResearchObservationFactory().make(
            tune: plan,
            savedTune: plan,
            isStreaming: false,
            capture: validCapture(
                drivetrain: plan.request.car.drivetrain,
                gearCount: 6,
                availability: .adjustable
            ),
            capturedAt: capturedAt.addingTimeInterval(60)
        )
        let registration = try makeExperimentalRegistration()
        let registry = try FH5TrustedNumericRulesetRegistry(
            validating: [registration]
        )
        let generator = FH5CleanRoomDirectionalCandidateGenerator()
        let reviewInputs = try reviewedReplicationInputs(plan: plan)
        let first = try generator.generate(
            tune: plan,
            savedTune: plan,
            isStreaming: false,
            researchRecords: [older, latest],
            reviewInputs: reviewInputs,
            targetSymptom: .pushesWide,
            input: .controller,
            surface: .dry,
            algorithmID: registration.algorithmID,
            registry: registry
        )
        let reordered = try generator.generate(
            tune: plan,
            savedTune: plan,
            isStreaming: false,
            researchRecords: [latest, older],
            reviewInputs: Array(reviewInputs.reversed()),
            targetSymptom: .pushesWide,
            input: .controller,
            surface: .dry,
            algorithmID: registration.algorithmID,
            registry: registry
        )

        XCTAssertEqual(first, reordered)
        XCTAssertEqual(first.game, .fh5)
        XCTAssertEqual(first.researchContentFingerprint, latest.contentFingerprint)
        XCTAssertEqual(first.change.field, .frontTirePressure)
        XCTAssertEqual(first.change.baselineValue, 50)
        XCTAssertEqual(first.change.candidateValue, 49)
        XCTAssertEqual(first.change.step, 1)
        XCTAssertEqual(first.change.unit, .psi)
        XCTAssertEqual(first.targetSymptom, .pushesWide)
        XCTAssertTrue(first.candidateBinding.isValid(for: registration))
        XCTAssertTrue(plan.sections.isEmpty)
        XCTAssertNil(plan.providerInfo)
        XCTAssertNil(plan.rulesetReference)

        let wheel = try generator.generate(
            tune: plan,
            savedTune: plan,
            isStreaming: false,
            researchRecords: [latest],
            reviewInputs: reviewInputs,
            targetSymptom: .pushesWide,
            input: .wheel,
            surface: .dry,
            algorithmID: registration.algorithmID,
            registry: registry
        )
        XCTAssertNotEqual(
            first.candidateBinding.generatedCandidateFingerprint,
            wheel.candidateBinding.generatedCandidateFingerprint
        )

        let record = try FH5ControlledExperimentFactory().makeCandidateBound(
            tune: plan,
            savedTune: plan,
            isStreaming: false,
            researchRecords: [latest],
            capture: experimentCapture(
                field: .frontTirePressure,
                candidate: 49
            ),
            candidateArtifact: first,
            registry: registry
        )
        XCTAssertEqual(
            record.schemaVersion,
            FH5ControlledExperimentRecord.candidateBoundSchemaVersion
        )
        XCTAssertThrowsError(try FH5ControlledExperimentFactory().makeCandidateBound(
            tune: plan,
            savedTune: plan,
            isStreaming: false,
            researchRecords: [latest],
            capture: FH5ControlledExperimentCapture(
                field: .frontTirePressure,
                candidateValue: 49,
                input: .wheel,
                surface: .dry,
                targetSymptom: .pushesWide,
                outcome: .variantPreferred,
                sameRouteAndConditionsConfirmed: true,
                sameAssistsAndInputConfirmed: true,
                onlyDeclaredFieldChangedConfirmed: true,
                sequenceCompletedConfirmed: true,
                stockValuesRestoredConfirmed: true,
                firstPartyAuthorshipConfirmed: true,
                localStoragePermitted: true,
                deidentifiedReusePermitted: false
            ),
            candidateArtifact: first,
            registry: registry
        )) {
            XCTAssertEqual(
                $0 as? FH5ControlledExperimentIssue,
                .candidateArtifactMismatch
            )
        }
    }
    func testExperimentalCandidateCollectionRegistryIsIsolatedAndRightsBound() throws {
        let production = FH5TrustedNumericRulesetRegistry.production
        let collection =
            FH5TrustedNumericRulesetRegistry.experimentalCandidateCollection
        let registration = try XCTUnwrap(
            collection.registration(for: .cleanRoomDirectionalV1)
        )

        XCTAssertTrue(production.isEmpty)
        XCTAssertNil(
            production.registration(for: .cleanRoomDirectionalV1)
        )
        XCTAssertFalse(collection.isEmpty)
        XCTAssertTrue(registration.isValid)
        XCTAssertEqual(registration.sourceManifests.count, 1)
        XCTAssertEqual(
            registration.sourceManifests.first?.rightsEvidenceID,
            "docs.fh5-clean-room-directional-v1.md"
        )
        XCTAssertEqual(
            registration.sourceManifests.first?.rightsBasis,
            .firstPartyCleanRoom
        )
        XCTAssertEqual(
            registration.sourceManifests.first?.usagePermission,
            .permitted
        )
        XCTAssertEqual(
            registration.outcomeThreshold,
            .currentExperimental
        )
    }
    func testCandidateTrialCoordinatorRegeneratesLockedArtifactAndCreatesLocalV2Record() async throws {
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
        let reviewInputs = try reviewedReplicationInputs(plan: plan)
        let coordinator = FH5CandidateTrialCoordinator()
        let locked = try coordinator.generate(
            tune: plan,
            savedTune: plan,
            isStreaming: false,
            researchRecords: [research],
            reviewInputs: reviewInputs,
            input: .controller,
            surface: .dry
        )
        let capture = experimentCapture(
            field: .frontTirePressure,
            candidate: locked.change.candidateValue,
            reusePermitted: true
        )
        let record = try coordinator.makeRecord(
            tune: plan,
            savedTune: plan,
            isStreaming: false,
            researchRecords: [research],
            reviewInputs: reviewInputs,
            submission: FH5CandidateTrialSubmission(
                capture: capture,
                lockedArtifact: locked
            ),
            recordID: recordID,
            submissionID: submissionID,
            permissionReceiptID: permissionID,
            createdAt: capturedAt.addingTimeInterval(120)
        )

        XCTAssertEqual(
            record.schemaVersion,
            FH5ControlledExperimentRecord.candidateBoundSchemaVersion
        )
        XCTAssertEqual(
            record.consentVersion,
            FH5ControlledExperimentRecord.candidateBoundConsentVersion
        )
        XCTAssertNotNil(record.candidateBinding)
        XCTAssertFalse(record.canExport)
        XCTAssertNil(record.deterministicJSONString)
        XCTAssertThrowsError(try record.publicExport()) {
            XCTAssertEqual(
                $0 as? FH5ControlledExperimentIssue,
                .candidateBoundExportUnsupported
            )
        }

        let wrongContextArtifact = try coordinator.generate(
            tune: plan,
            savedTune: plan,
            isStreaming: false,
            researchRecords: [research],
            reviewInputs: reviewInputs,
            input: .wheel,
            surface: .dry
        )
        XCTAssertThrowsError(try coordinator.makeRecord(
            tune: plan,
            savedTune: plan,
            isStreaming: false,
            researchRecords: [research],
            reviewInputs: reviewInputs,
            submission: FH5CandidateTrialSubmission(
                capture: capture,
                lockedArtifact: wrongContextArtifact
            )
        )) {
            XCTAssertEqual(
                $0 as? FH5ControlledExperimentIssue,
                .candidateArtifactMismatch
            )
        }
    }
}
