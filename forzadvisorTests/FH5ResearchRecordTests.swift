import SwiftData
import XCTest
@testable import forzadvisor

final class FH5ResearchRecordTests: FH5ResearchTestCase {
    func testFactoryCreatesDetachedProvisionalSnapshotAndCanonicalExport() async throws {
        let plan = try await makePlan(upgradeBuild: "3.688.109.0")
        var capture = validCapture(
            drivetrain: plan.request.car.drivetrain,
            gearCount: 6,
            availability: .adjustable,
            build: "  3.688.109.0  ",
            reuse: true
        )
        capture = replacing(capture, controls: Array(capture.controls.reversed()))

        let record = try FH5ResearchObservationFactory().make(
            tune: plan,
            savedTune: plan,
            isStreaming: false,
            capture: capture,
            recordID: recordID,
            submissionID: submissionID,
            permissionReceiptID: permissionID,
            capturedAt: capturedAt,
            snapshotID: snapshotID
        )
        let expected = TuneFieldID.expectedFields(
            drivetrain: plan.request.car.drivetrain,
            gearCount: 6
        )

        XCTAssertTrue(FH5ResearchObservationFactory().isValid(record))
        XCTAssertEqual(record.game, .fh5)
        XCTAssertEqual(record.gameVersion, "3.688.109.0")
        XCTAssertEqual(record.controls.map(\.field), expected)
        XCTAssertEqual(record.contentFingerprint.count, 64)
        XCTAssertTrue(record.canExport)
        XCTAssertEqual(record.internalValidationSnapshot.kind, .exactBuildObservation)
        XCTAssertEqual(record.internalValidationSnapshot.constraints.count, expected.count)
        XCTAssertTrue(record.internalValidationSnapshot.constraints.allSatisfy {
            $0.scope == .exactVehicleBuild && $0.verification == .provisional
        })
        XCTAssertFalse(record.internalValidationSnapshot.constraints.contains {
            $0.verification == .productionEligible
        })
        XCTAssertEqual(
            Set(record.internalValidationSnapshot.capabilityProfile.parts.map(\.partID)),
            Set(TunePartID.allCases)
        )
        XCTAssertEqual(
            Set(record.internalValidationSnapshot.capabilityProfile.stockAdjustableSettings.map(\.setting)),
            Set(expected.map(\.setting))
        )

        let first = try record.deterministicJSON()
        let second = try record.deterministicJSON()
        XCTAssertEqual(first, second)
        let json = try XCTUnwrap(String(data: first, encoding: .utf8))
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: first) as? [String: Any]
        )
        XCTAssertFalse(json.contains(recordID.uuidString))
        XCTAssertFalse(json.contains(plan.id.uuidString))
        XCTAssertNil(object["discipline"])
        XCTAssertFalse(json.contains("\"providerInfo\""))
        XCTAssertFalse(json.contains("\"rulesetReference\""))
        XCTAssertFalse(json.contains("\"planRevisionFingerprint\""))
        XCTAssertFalse(json.contains("\"internalValidationSnapshot\""))
        XCTAssertFalse(json.contains("\"screenshots\""))
        XCTAssertFalse(json.contains("\"sourceURLs\""))
        XCTAssertTrue(json.contains("\"contentFingerprint\""))
        XCTAssertNil(object["upgradeParts"])
        XCTAssertEqual(Set(object.keys), Set([
            "schemaVersion",
            "consentVersion",
            "submissionID",
            "permissionReceiptID",
            "capturedAt",
            "game",
            "platform",
            "gameVersion",
            "unitScope",
            "vehicle",
            "tireCompoundDisplayName",
            "forwardGearCount",
            "controls",
            "attestations",
            "unknowns",
            "privacyExclusions",
            "contentFingerprint"
        ]))
        XCTAssertNoThrow(try record.publicExport())
    }
    func testReusePermissionDefaultsOffAndExportFailsClosed() async throws {
        let plan = try await makePlan()
        let capture = validCapture(
            drivetrain: plan.request.car.drivetrain,
            gearCount: 6,
            availability: .notShown
        )
        XCTAssertFalse(capture.deidentifiedStructuredReusePermitted)

        let record = try FH5ResearchObservationFactory().make(
            tune: plan,
            savedTune: plan,
            isStreaming: false,
            capture: capture,
            capturedAt: capturedAt
        )
        XCTAssertTrue(FH5ResearchObservationFactory().isValid(record))
        XCTAssertFalse(record.canExport)
        XCTAssertNil(record.deterministicJSONString)
        XCTAssertThrowsError(try record.deterministicJSON()) {
            XCTAssertEqual($0 as? FH5ResearchIssue, .reuseNotPermitted)
        }
        XCTAssertThrowsError(try record.publicExport()) {
            XCTAssertEqual($0 as? FH5ResearchIssue, .reuseNotPermitted)
        }
    }
    func testPublicSemanticFingerprintExcludesLocalUpgradeAvailability() async throws {
        let offeredPlan = try await makePlan(upgradeBuild: "matching-build")
        var unavailablePlan = offeredPlan
        for index in try XCTUnwrap(
            unavailablePlan.request.buildSnapshot
        ).capabilityProfile.parts.indices {
            unavailablePlan.request.buildSnapshot?
                .capabilityProfile.parts[index].availability = .unavailable
        }
        XCTAssertTrue(try XCTUnwrap(unavailablePlan.request.buildSnapshot).isValid)

        let capture = validCapture(
            drivetrain: offeredPlan.request.car.drivetrain,
            gearCount: 6,
            availability: .adjustable,
            build: "matching-build",
            reuse: true
        )
        let factory = FH5ResearchObservationFactory()
        let offered = try factory.make(
            tune: offeredPlan,
            savedTune: offeredPlan,
            isStreaming: false,
            capture: capture,
            recordID: recordID,
            submissionID: submissionID,
            permissionReceiptID: permissionID,
            capturedAt: capturedAt,
            snapshotID: snapshotID
        )
        let unavailable = try factory.make(
            tune: unavailablePlan,
            savedTune: unavailablePlan,
            isStreaming: false,
            capture: capture,
            recordID: UUID(),
            submissionID: submissionID,
            permissionReceiptID: permissionID,
            capturedAt: capturedAt,
            snapshotID: UUID()
        )

        XCTAssertNotEqual(offered.upgradeParts, unavailable.upgradeParts)
        XCTAssertNotEqual(offered.contentFingerprint, unavailable.contentFingerprint)
        let offeredExport = try offered.publicExport()
        let unavailableExport = try unavailable.publicExport()
        XCTAssertEqual(offeredExport, unavailableExport)
        XCTAssertEqual(
            offeredExport.contentFingerprint,
            unavailableExport.contentFingerprint
        )
        XCTAssertNotEqual(offeredExport.contentFingerprint, offered.contentFingerprint)
        XCTAssertNotEqual(unavailableExport.contentFingerprint, unavailable.contentFingerprint)
        XCTAssertEqual(try offered.deterministicJSON(), try unavailable.deterministicJSON())

        var tamperedSnapshot = offered.internalValidationSnapshot
        tamperedSnapshot.capabilityProfile.parts[0].availability = .unavailable
        XCTAssertTrue(tamperedSnapshot.isValid)
        XCTAssertFalse(factory.isValid(replacing(offered, snapshot: tamperedSnapshot)))
    }
    func testStockAdjustableOverridesRequireEveryApplicableField() async throws {
        let plan = try await makePlan()
        var capture = validCapture(
            drivetrain: plan.request.car.drivetrain,
            gearCount: 6,
            availability: .adjustable,
            reuse: true
        )
        let rearCamberIndex = try XCTUnwrap(
            capture.controls.firstIndex { $0.field == .rearCamber }
        )
        var controls = capture.controls
        controls[rearCamberIndex] = FH5TuneFieldObservation(
            field: .rearCamber,
            availability: .shownLocked,
            current: 0,
            unit: .degrees
        )
        capture = replacing(capture, controls: controls)

        let record = try FH5ResearchObservationFactory().make(
            tune: plan,
            savedTune: plan,
            isStreaming: false,
            capture: capture,
            capturedAt: capturedAt
        )
        let settings = Set(
            record.internalValidationSnapshot.capabilityProfile
                .stockAdjustableSettings.map(\.setting)
        )
        XCTAssertFalse(settings.contains(.alignment))
        XCTAssertTrue(settings.contains(.frontARB))
        XCTAssertFalse(
            record.internalValidationSnapshot.constraints.contains {
                $0.field == .rearCamber
            }
        )
    }
    func testCompleteUpgradeObservationRequiresMatchingBuildAndIncompleteEvidenceDoesNotGate() async throws {
        let plan = try await makePlan(upgradeBuild: "matching-build")
        XCTAssertEqual(
            FH5ResearchObservationFactory().verifiedUpgradeGameVersion(
                in: try XCTUnwrap(plan.request.buildSnapshot)
            ),
            "matching-build"
        )
        let matching = try FH5ResearchObservationFactory().make(
            tune: plan,
            savedTune: plan,
            isStreaming: false,
            capture: validCapture(
                drivetrain: plan.request.car.drivetrain,
                gearCount: 6,
                availability: .notShown,
                build: "matching-build"
            ),
            capturedAt: capturedAt
        )
        XCTAssertEqual(
            matching.internalValidationSnapshot.capabilityProfile.parts.count,
            TunePartID.allCases.count
        )

        XCTAssertThrowsError(try FH5ResearchObservationFactory().make(
            tune: plan,
            savedTune: plan,
            isStreaming: false,
            capture: validCapture(
                drivetrain: plan.request.car.drivetrain,
                gearCount: 6,
                availability: .notShown,
                build: "different-build"
            ),
            capturedAt: capturedAt
        )) {
            XCTAssertEqual(
                $0 as? FH5ResearchIssue,
                .mismatchedGameVersion(
                    expected: "matching-build",
                    entered: "different-build"
                )
            )
        }

        var incomplete = try await makePlan()
        let incompleteBuild = "partial-build"
        let evidence = TuneEvidence(
            confidence: .medium,
            source: UpgradePartCapture.provenanceSource,
            version: incompleteBuild,
            usagePermission: .permitted
        )
        incomplete.request.buildSnapshot?.gameBuild = GameBuildReference(
            game: .fh5,
            version: incompleteBuild,
            capturedAt: capturedAt
        )
        incomplete.request.buildSnapshot?.capabilityProfile.parts = [
            TuneVehiclePart(
                partID: TunePartID.allCases[0],
                availability: .available,
                evidence: evidence
            )
        ]
        XCTAssertTrue(try XCTUnwrap(incomplete.request.buildSnapshot).isValid)
        XCTAssertNil(FH5ResearchObservationFactory().verifiedUpgradeGameVersion(
            in: try XCTUnwrap(incomplete.request.buildSnapshot)
        ))
        let independent = try FH5ResearchObservationFactory().make(
            tune: incomplete,
            savedTune: incomplete,
            isStreaming: false,
            capture: validCapture(
                drivetrain: incomplete.request.car.drivetrain,
                gearCount: 6,
                availability: .notShown,
                build: "independently-observed-build"
            ),
            capturedAt: capturedAt
        )
        XCTAssertTrue(independent.upgradeParts.isEmpty)
        XCTAssertTrue(independent.internalValidationSnapshot.capabilityProfile.parts.isEmpty)
    }

}
