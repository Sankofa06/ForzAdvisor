import SwiftData
import XCTest
@testable import forzadvisor

final class FH5CandidateGeneratorValidationTests: FH5ResearchTestCase {
    func testCleanRoomDirectionalGeneratorFailsClosedOnAuthorityAndEvidence() async throws {
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
        let generator = FH5CleanRoomDirectionalCandidateGenerator()
        let reviewInputs = try reviewedReplicationInputs(plan: plan)

        XCTAssertThrowsError(try generator.generate(
            tune: plan,
            savedTune: plan,
            isStreaming: false,
            researchRecords: [research],
            reviewInputs: reviewInputs,
            targetSymptom: .pushesWide,
            input: .controller,
            surface: .dry,
            algorithmID: registration.algorithmID,
            registry: .production
        )) {
            XCTAssertEqual(
                $0 as? FH5CleanRoomDirectionalCandidateIssue,
                .experiment(.unregisteredCandidateAlgorithm)
            )
        }
        XCTAssertThrowsError(try generator.generate(
            tune: plan,
            savedTune: plan,
            isStreaming: false,
            researchRecords: [research],
            reviewInputs: reviewInputs,
            targetSymptom: .oversteersOnExit,
            input: .controller,
            surface: .dry,
            algorithmID: registration.algorithmID,
            registry: registry
        )) {
            XCTAssertEqual(
                $0 as? FH5CleanRoomDirectionalCandidateIssue,
                .unsupportedSymptom
            )
        }
        XCTAssertThrowsError(try generator.generate(
            tune: plan,
            savedTune: plan,
            isStreaming: true,
            researchRecords: [research],
            reviewInputs: reviewInputs,
            targetSymptom: .pushesWide,
            input: .controller,
            surface: .dry,
            algorithmID: registration.algorithmID,
            registry: registry
        )) {
            XCTAssertEqual(
                $0 as? FH5CleanRoomDirectionalCandidateIssue,
                .experiment(.streaming)
            )
        }
        XCTAssertThrowsError(try generator.generate(
            tune: plan,
            savedTune: plan,
            isStreaming: false,
            researchRecords: [research],
            reviewInputs: [],
            targetSymptom: .pushesWide,
            input: .controller,
            surface: .dry,
            algorithmID: registration.algorithmID,
            registry: registry
        )) {
            XCTAssertEqual(
                $0 as? FH5CleanRoomDirectionalCandidateIssue,
                .exactReplicationRequired
            )
        }
        XCTAssertThrowsError(try generator.generate(
            tune: plan,
            savedTune: plan,
            isStreaming: false,
            researchRecords: [research],
            reviewInputs: reviewInputs + [
                FH5ResearchReviewInput(
                    exportJSON: Data("not canonical research".utf8),
                    permission: nil
                )
            ],
            targetSymptom: .pushesWide,
            input: .controller,
            surface: .dry,
            algorithmID: registration.algorithmID,
            registry: registry
        )) {
            XCTAssertEqual(
                $0 as? FH5CleanRoomDirectionalCandidateIssue,
                .malformedReview
            )
        }

        let baseExport = try makeReviewExport(
            plan: plan,
            submissionID: UUID(),
            permissionReceiptID: UUID()
        )
        let changedControls = try baseExport.controls.map {
            guard $0.field == .frontTirePressure else { return $0 }
            return adjustable(
                .frontTirePressure,
                minimum: try XCTUnwrap($0.minimum),
                maximum: try XCTUnwrap($0.maximum),
                step: try XCTUnwrap($0.step),
                current: try XCTUnwrap($0.current) + 1
            )
        }
        let conflictingExport = try replacingReviewExport(
            baseExport,
            submissionID: UUID(),
            permissionReceiptID: UUID(),
            capturedAt: capturedAt.addingTimeInterval(60),
            controls: changedControls,
            recomputingFingerprint: true
        )
        let conflictInputs = try [
            reviewedInput(for: baseExport),
            reviewedInput(for: conflictingExport)
        ]
        XCTAssertThrowsError(try generator.generate(
            tune: plan,
            savedTune: plan,
            isStreaming: false,
            researchRecords: [research],
            reviewInputs: conflictInputs,
            targetSymptom: .pushesWide,
            input: .controller,
            surface: .dry,
            algorithmID: registration.algorithmID,
            registry: registry
        )) {
            XCTAssertEqual(
                $0 as? FH5CleanRoomDirectionalCandidateIssue,
                .conflictingReplication
            )
        }
    }
    func testCleanRoomDirectionalGeneratorRequiresLegalFrontPressureStep() async throws {
        let plan = try await makePlan(upgradeBuild: "3.688.109.0")
        var capture = validCapture(
            drivetrain: plan.request.car.drivetrain,
            gearCount: 6,
            availability: .adjustable,
            reuse: true
        )
        capture = replacing(
            capture,
            controls: capture.controls.map {
                $0.field == .frontTirePressure
                    ? adjustable(
                        .frontTirePressure,
                        minimum: 20,
                        maximum: 60,
                        step: 1,
                        current: 20
                    )
                    : $0
            }
        )
        let research = try FH5ResearchObservationFactory().make(
            tune: plan,
            savedTune: plan,
            isStreaming: false,
            capture: capture,
            capturedAt: capturedAt
        )
        let registration = try makeExperimentalRegistration()
        let registry = try FH5TrustedNumericRulesetRegistry(
            validating: [registration]
        )
        let firstExport = try research.publicExport()
        let secondExport = try replacingReviewExport(
            firstExport,
            submissionID: UUID(),
            permissionReceiptID: UUID(),
            capturedAt: capturedAt.addingTimeInterval(60),
            recomputingFingerprint: true
        )
        let matchingInputs = try [
            reviewedInput(for: firstExport),
            reviewedInput(for: secondExport)
        ]
        XCTAssertThrowsError(
            try FH5CleanRoomDirectionalCandidateGenerator().generate(
                tune: plan,
                savedTune: plan,
                isStreaming: false,
                researchRecords: [research],
                reviewInputs: matchingInputs,
                targetSymptom: .pushesWide,
                input: .controller,
                surface: .dry,
                algorithmID: registration.algorithmID,
                registry: registry
            )
        ) {
            XCTAssertEqual(
                $0 as? FH5CleanRoomDirectionalCandidateIssue,
                .frontTirePressureAlreadyAtMinimum
            )
        }
    }
}
