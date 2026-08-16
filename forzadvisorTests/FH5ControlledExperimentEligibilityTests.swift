import SwiftData
import XCTest
@testable import forzadvisor

final class FH5ControlledExperimentEligibilityTests: FH5ResearchTestCase {
    func testControlledExperimentEligibilityRequiresMatchingCompleteResearch() async throws {
        let incompletePlan = try await makePlan()
        let factory = FH5ControlledExperimentFactory()

        XCTAssertFailure(
            factory.eligibility(
                tune: incompletePlan,
                savedTune: incompletePlan,
                isStreaming: false,
                researchRecords: []
            ),
            .missingResearchObservation
        )

        let incompleteRecord = try FH5ResearchObservationFactory().make(
            tune: incompletePlan,
            savedTune: incompletePlan,
            isStreaming: false,
            capture: validCapture(
                drivetrain: incompletePlan.request.car.drivetrain,
                gearCount: 6,
                availability: .adjustable
            ),
            capturedAt: capturedAt
        )
        XCTAssertFailure(
            factory.eligibility(
                tune: incompletePlan,
                savedTune: incompletePlan,
                isStreaming: false,
                researchRecords: [incompleteRecord]
            ),
            .incompleteUpgradeObservation
        )

        let plan = try await makePlan(upgradeBuild: "3.688.109.0")
        let record = try FH5ResearchObservationFactory().make(
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
        let eligibility = factory.eligibility(
            tune: plan,
            savedTune: plan,
            isStreaming: false,
            researchRecords: [record]
        )
        if case .failure(let issue) = eligibility {
            XCTFail("Expected controlled experiment eligibility, got \(issue).")
        }
        XCTAssertFailure(
            factory.eligibility(
                tune: plan,
                savedTune: nil,
                isStreaming: false,
                researchRecords: [record]
            ),
            .notSaved
        )
        XCTAssertFailure(
            factory.eligibility(
                tune: plan,
                savedTune: plan,
                isStreaming: true,
                researchRecords: [record]
            ),
            .streaming
        )
    }
    func testControlledExperimentEnforcesOneLegalStepAndABBAAttestations() async throws {
        let plan = try await makePlan(upgradeBuild: "3.688.109.0")
        let record = try FH5ResearchObservationFactory().make(
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
        let field = try XCTUnwrap(record.controls.first?.field)
        let factory = FH5ControlledExperimentFactory()
        let valid = experimentCapture(field: field, candidate: 49)

        let experiment = try factory.make(
            tune: plan,
            savedTune: plan,
            isStreaming: false,
            researchRecords: [record],
            capture: valid,
            recordID: recordID,
            submissionID: submissionID,
            permissionReceiptID: permissionID,
            createdAt: capturedAt.addingTimeInterval(60)
        )
        XCTAssertTrue(factory.isValid(experiment))
        XCTAssertEqual(experiment.game, .fh5)
        XCTAssertEqual(experiment.change.baselineValue, 50)
        XCTAssertEqual(experiment.change.candidateValue, 49)
        XCTAssertEqual(experiment.context.sequence, ["A", "B", "B", "A"])
        XCTAssertEqual(experiment.contentFingerprint.count, 64)
        XCTAssertTrue(factory.changeMatchesResearch(
            experiment.change,
            researchRecord: record
        ))
        let forgedChange = FH5ControlledExperimentRecord.Change(
            field: experiment.change.field,
            baselineValue: 40,
            candidateValue: 39,
            minimum: experiment.change.minimum,
            maximum: experiment.change.maximum,
            step: experiment.change.step,
            unit: experiment.change.unit
        )
        XCTAssertFalse(factory.changeMatchesResearch(
            forgedChange,
            researchRecord: record
        ))

        for (candidate, issue) in [
            (50.0, FH5ControlledExperimentIssue.candidateUnchanged),
            (48.0, .candidateNotOneStep),
            (48.5, .candidateOffLattice),
            (101.0, .candidateOutOfRange)
        ] {
            XCTAssertThrowsError(try factory.make(
                tune: plan,
                savedTune: plan,
                isStreaming: false,
                researchRecords: [record],
                capture: experimentCapture(field: field, candidate: candidate)
            )) {
                XCTAssertEqual($0 as? FH5ControlledExperimentIssue, issue)
            }
        }

        let incomplete = FH5ControlledExperimentCapture(
            field: field,
            candidateValue: 49,
            input: .controller,
            surface: .dry,
            targetSymptom: .pushesWide,
            outcome: .variantPreferred,
            sameRouteAndConditionsConfirmed: true,
            sameAssistsAndInputConfirmed: true,
            onlyDeclaredFieldChangedConfirmed: true,
            sequenceCompletedConfirmed: false,
            stockValuesRestoredConfirmed: true,
            firstPartyAuthorshipConfirmed: true,
            localStoragePermitted: true,
            deidentifiedReusePermitted: false
        )
        XCTAssertThrowsError(try factory.make(
            tune: plan,
            savedTune: plan,
            isStreaming: false,
            researchRecords: [record],
            capture: incomplete
        )) {
            XCTAssertEqual(
                $0 as? FH5ControlledExperimentIssue,
                .sequenceNotCompleted
            )
        }
    }
    func testControlledExperimentExportRequiresReusePermission() async throws {
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
        let field = try XCTUnwrap(research.controls.first?.field)
        let record = try FH5ControlledExperimentFactory().make(
            tune: plan,
            savedTune: plan,
            isStreaming: false,
            researchRecords: [research],
            capture: experimentCapture(
                field: field,
                candidate: 49
            ),
            createdAt: capturedAt.addingTimeInterval(60)
        )

        XCTAssertFalse(record.canExport)
        XCTAssertNil(record.deterministicJSONString)
        XCTAssertThrowsError(try record.deterministicJSON()) {
            XCTAssertEqual(
                $0 as? FH5ControlledExperimentIssue,
                .reuseNotPermitted
            )
        }
        XCTAssertThrowsError(try record.publicExport()) {
            XCTAssertEqual(
                $0 as? FH5ControlledExperimentIssue,
                .reuseNotPermitted
            )
        }
    }
}
