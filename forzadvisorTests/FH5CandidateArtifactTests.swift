import SwiftData
import XCTest
@testable import forzadvisor

final class FH5CandidateArtifactTests: FH5ResearchTestCase {
    func testCandidateBoundSchemaPreservesLegacyCalibrationContract() async throws {
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
        let factory = FH5ControlledExperimentFactory()
        let capture = experimentCapture(
            field: try XCTUnwrap(research.controls.first?.field),
            candidate: 49,
            reusePermitted: true
        )
        let legacy = try factory.make(
            tune: plan,
            savedTune: plan,
            isStreaming: false,
            researchRecords: [research],
            capture: capture,
            recordID: recordID,
            submissionID: submissionID,
            permissionReceiptID: permissionID,
            createdAt: capturedAt.addingTimeInterval(60)
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let legacyData = try encoder.encode(legacy)
        let decodedLegacy = try decoder.decode(
            FH5ControlledExperimentRecord.self,
            from: legacyData
        )

        XCTAssertEqual(
            legacy.schemaVersion,
            FH5ControlledExperimentRecord.calibrationSchemaVersion
        )
        XCTAssertEqual(
            legacy.consentVersion,
            FH5ControlledExperimentRecord.calibrationConsentVersion
        )
        XCTAssertNil(legacy.candidateBinding)
        XCTAssertFalse(
            try XCTUnwrap(String(data: legacyData, encoding: .utf8))
                .contains("\"candidateBinding\"")
        )
        XCTAssertEqual(decodedLegacy, legacy)
        XCTAssertTrue(factory.isValid(decodedLegacy))
        XCTAssertEqual(
            try decodedLegacy.deterministicJSON(),
            try legacy.deterministicJSON()
        )

        let registration = try makeExperimentalRegistration()
        let registry = try FH5TrustedNumericRulesetRegistry(
            validating: [registration]
        )
        let bound = try factory.makeCandidateBoundForTesting(
            tune: plan,
            savedTune: plan,
            isStreaming: false,
            researchRecords: [research],
            capture: capture,
            candidateAlgorithmID: registration.algorithmID,
            registry: registry,
            createdAt: capturedAt.addingTimeInterval(120)
        )
        let boundBinding = try XCTUnwrap(bound.candidateBinding)
        let boundData = try encoder.encode(bound)
        let decodedBound = try decoder.decode(
            FH5ControlledExperimentRecord.self,
            from: boundData
        )

        XCTAssertEqual(
            bound.schemaVersion,
            FH5ControlledExperimentRecord.candidateBoundSchemaVersion
        )
        XCTAssertEqual(
            bound.consentVersion,
            FH5ControlledExperimentRecord.candidateBoundConsentVersion
        )
        XCTAssertTrue(boundBinding.isValid(for: registration))
        XCTAssertTrue(boundBinding.isStructurallyValid)
        XCTAssertTrue(factory.isValid(bound))
        XCTAssertEqual(decodedBound, bound)
        XCTAssertTrue(factory.isValid(decodedBound))
        XCTAssertTrue(
            try XCTUnwrap(String(data: boundData, encoding: .utf8))
                .contains("\"candidateBinding\"")
        )
        XCTAssertFalse(bound.canExport)
        XCTAssertThrowsError(try bound.publicExport()) {
            XCTAssertEqual(
                $0 as? FH5ControlledExperimentIssue,
                .candidateBoundExportUnsupported
            )
        }
        XCTAssertFalse(factory.isValid(copyExperiment(
            legacy,
            schemaVersion:
                FH5ControlledExperimentRecord.calibrationSchemaVersion,
            consentVersion:
                FH5ControlledExperimentRecord.calibrationConsentVersion,
            candidateBinding: boundBinding
        )))
        XCTAssertFalse(factory.isValid(copyExperiment(
            bound,
            schemaVersion:
                FH5ControlledExperimentRecord.candidateBoundSchemaVersion,
            consentVersion:
                FH5ControlledExperimentRecord.candidateBoundConsentVersion,
            candidateBinding: nil
        )))
        let tamperedBinding = FH5RulesetCandidateBinding(
            algorithmID: boundBinding.algorithmID,
            rulesetReference: boundBinding.rulesetReference,
            sourceManifestFingerprint:
                boundBinding.sourceManifestFingerprint,
            outcomePolicyVersion: boundBinding.outcomePolicyVersion,
            generatedCandidateFingerprint: String(repeating: "b", count: 64)
        )
        XCTAssertFalse(factory.isValid(copyExperiment(
            bound,
            schemaVersion:
                FH5ControlledExperimentRecord.candidateBoundSchemaVersion,
            consentVersion:
                FH5ControlledExperimentRecord.candidateBoundConsentVersion,
            candidateBinding: tamperedBinding
        )))
        let decreaseArtifact = try factory
            .makeCandidateArtifactForTesting(
                tune: plan,
                savedTune: plan,
                isStreaming: false,
                researchRecords: [research],
                capture: capture,
                candidateAlgorithmID: registration.algorithmID,
                registry: registry
            )
        XCTAssertThrowsError(try factory.makeCandidateBound(
            tune: plan,
            savedTune: plan,
            isStreaming: false,
            researchRecords: [research],
            capture: experimentCapture(
                field: capture.field,
                candidate: 51,
                reusePermitted: true
            ),
            candidateArtifact: decreaseArtifact,
            registry: registry
        )) {
            XCTAssertEqual(
                $0 as? FH5ControlledExperimentIssue,
                .candidateArtifactMismatch
            )
        }
        XCTAssertThrowsError(try factory.makeCandidateBoundForTesting(
            tune: plan,
            savedTune: plan,
            isStreaming: false,
            researchRecords: [research],
            capture: capture,
            candidateAlgorithmID: registration.algorithmID,
            registry: .production
        )) {
            XCTAssertEqual(
                $0 as? FH5ControlledExperimentIssue,
                .unregisteredCandidateAlgorithm
            )
        }
    }
}
