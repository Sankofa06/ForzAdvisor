import SwiftData
import XCTest
@testable import forzadvisor

final class FH5ControlledExperimentExportTests: FH5ResearchTestCase {
    func testControlledExperimentExportIsAllowListedAndRoundTrips() async throws {
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
                candidate: 49,
                reusePermitted: true
            ),
            recordID: recordID,
            submissionID: submissionID,
            permissionReceiptID: permissionID,
            createdAt: capturedAt.addingTimeInterval(60)
        )
        let factory = FH5ControlledExperimentFactory()
        let data = try record.deterministicJSON()
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let export = try decoder.decode(
            FH5ControlledExperimentExport.self,
            from: data
        )

        XCTAssertTrue(record.canExport)
        XCTAssertTrue(factory.isValid(export))
        XCTAssertEqual(export.submissionID, submissionID)
        XCTAssertEqual(export.permissionReceiptID, permissionID)
        XCTAssertEqual(
            export.privacyExclusions,
            FH5ControlledExperimentRecord.privacyExclusions
        )
        XCTAssertNotEqual(export.contentFingerprint, record.contentFingerprint)
        XCTAssertEqual(try record.deterministicJSON(), data)
        XCTAssertEqual(record.deterministicJSONString, json)

        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        XCTAssertEqual(Set(object.keys), Set([
            "schemaVersion",
            "consentVersion",
            "protocolVersion",
            "submissionID",
            "permissionReceiptID",
            "createdAt",
            "game",
            "measurementFingerprint",
            "context",
            "change",
            "targetSymptom",
            "outcome",
            "attestations",
            "privacyExclusions",
            "contentFingerprint"
        ]))
        let context = try XCTUnwrap(object["context"] as? [String: Any])
        XCTAssertEqual(Set(context.keys), Set([
            "platform",
            "gameVersion",
            "vehicle",
            "tireCompoundDisplayName",
            "forwardGearCount",
            "input",
            "surface",
            "route",
            "sequence"
        ]))
        let vehicle = try XCTUnwrap(context["vehicle"] as? [String: Any])
        XCTAssertEqual(Set(vehicle.keys), Set([
            "catalogID",
            "catalogRevision",
            "catalogReviewedAt",
            "catalogVerificationStatus",
            "year",
            "make",
            "model",
            "performanceClass",
            "performanceIndex",
            "drivetrain",
            "weightPounds",
            "frontWeightPercent",
            "peakHorsepower",
            "peakTorqueFootPounds",
            "stock"
        ]))
        let change = try XCTUnwrap(object["change"] as? [String: Any])
        XCTAssertEqual(Set(change.keys), Set([
            "field",
            "baselineValue",
            "candidateValue",
            "minimum",
            "maximum",
            "step",
            "unit"
        ]))
        let attestations = try XCTUnwrap(
            object["attestations"] as? [String: Any]
        )
        XCTAssertEqual(Set(attestations.keys), Set([
            "sameRouteAndConditions",
            "sameAssistsAndInput",
            "onlyDeclaredFieldChanged",
            "sequenceCompleted",
            "stockValuesRestored",
            "firstPartyAuthorship",
            "localStoragePermitted",
            "deidentifiedReusePermitted"
        ]))

        XCTAssertFalse(json.contains("\"recordID\""))
        XCTAssertFalse(json.contains("\"planRevisionFingerprint\""))
        XCTAssertFalse(json.contains("\"researchContentFingerprint\""))
        XCTAssertFalse(json.contains("\"providerInfo\""))
        XCTAssertFalse(json.contains("\"rulesetReference\""))
        XCTAssertFalse(json.contains(record.recordID.uuidString))
        XCTAssertFalse(json.contains(record.planRevisionFingerprint))
        XCTAssertFalse(json.contains(record.researchContentFingerprint))
    }
    func testControlledExperimentExportRejectsSemanticTampering() async throws {
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
        let record = try FH5ControlledExperimentFactory().make(
            tune: plan,
            savedTune: plan,
            isStreaming: false,
            researchRecords: [research],
            capture: experimentCapture(
                field: try XCTUnwrap(research.controls.first?.field),
                candidate: 49,
                reusePermitted: true
            ),
            createdAt: capturedAt.addingTimeInterval(60)
        )
        let data = try record.deterministicJSON()
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        object["outcome"] = FH5ExperimentOutcome.baselinePreferred.rawValue
        let tamperedData = try JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys]
        )
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let tampered = try decoder.decode(
            FH5ControlledExperimentExport.self,
            from: tamperedData
        )

        XCTAssertFalse(FH5ControlledExperimentFactory().isValid(tampered))
        XCTAssertNotEqual(
            try FH5ControlledExperimentFactory()
                .publicSemanticFingerprint(for: tampered),
            tampered.contentFingerprint
        )
    }

}
