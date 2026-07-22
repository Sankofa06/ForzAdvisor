//
//  UpgradeLabTests.swift
//  forzadvisorTests
//
//  Contract coverage for local part capture and alternative control paths.
//

import XCTest
@testable import forzadvisor

final class UpgradeLabTests: XCTestCase {
    private let capturedAt = Date(timeIntervalSinceReferenceDate: 456)
    private let snapshotID = UUID(uuidString: "12345678-1234-1234-1234-123456789ABC")!

    func testCaptureReplacesEveryCanonicalPartAndPreservesCapabilitySnapshot() throws {
        for game in ForzaGame.allCases {
            let base = try capabilitySnapshot(game: game)
            let original = base
            let verified = try offeredCapture(build: "  2026.07.22  ").verifiedSnapshot(
                upgrading: base,
                capturedAt: capturedAt,
                snapshotID: snapshotID
            )

            XCTAssertEqual(base, original)
            XCTAssertEqual(verified.id, snapshotID)
            XCTAssertNotEqual(verified.id, base.id)
            XCTAssertEqual(verified.kind, .capabilityOnly)
            XCTAssertEqual(verified.capturedAt, capturedAt)
            XCTAssertEqual(
                verified.gameBuild,
                GameBuildReference(game: game, version: "2026.07.22", capturedAt: capturedAt)
            )
            XCTAssertEqual(verified.car, base.car)
            XCTAssertEqual(verified.capabilityProfile.stockAdjustableSettings, base.capabilityProfile.stockAdjustableSettings)
            XCTAssertEqual(verified.capabilityProfile.parts.map(\.partID), TunePartID.allCases)
            XCTAssertEqual(Set(verified.capabilityProfile.parts.map(\.availability)), [.available])
            XCTAssertTrue(verified.capabilityProfile.parts.allSatisfy {
                $0.evidence == TuneEvidence(
                    confidence: .medium,
                    source: UpgradePartCapture.provenanceSource,
                    version: "2026.07.22",
                    usagePermission: .permitted
                )
            })
            XCTAssertEqual(verified.tireCompound, base.tireCompound)
            XCTAssertEqual(verified.gearCount, base.gearCount)
            XCTAssertEqual(verified.constraints, base.constraints)
            XCTAssertEqual(verified.evidenceSources, base.evidenceSources)
            XCTAssertFalse(verified.capabilityProfile.parts.contains { $0.availability == .installed })
            XCTAssertTrue(verified.isValid, "Unexpected issues: \(verified.validationIssues)")
        }
    }

    func testCaptureRequiresEveryDecisionMetadataAttestationsAndNewIdentity() throws {
        let base = try capabilitySnapshot()
        let capture = UpgradePartCapture(
            gameBuildVersion: " ",
            parts: [
                UpgradePartCaptureValue(partID: .sportTransmission, status: .offered),
                UpgradePartCaptureValue(partID: .sportTransmission, status: .notOffered)
            ],
            exactStockBuildConfirmed: false,
            localUsePermitted: false
        )

        let issues = capture.validationIssues(upgrading: base)
        XCTAssertEqual(issues.first, .missingGameBuildVersion)
        XCTAssertTrue(issues.contains(.duplicatePartDecision(.sportTransmission)))
        XCTAssertTrue(issues.contains(.missingPartDecision(.raceTransmission)))
        XCTAssertTrue(issues.contains(.missingPartDecision(.driftDifferential)))
        XCTAssertTrue(issues.contains(.exactStockBuildNotConfirmed))
        XCTAssertTrue(issues.contains(.localUseNotPermitted))

        XCTAssertThrowsError(try offeredCapture().verifiedSnapshot(
            upgrading: base,
            snapshotID: base.id
        )) { error in
            guard case .invalid(let factoryIssues) = error as? UpgradePartCaptureError else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(factoryIssues, [.reusedSnapshotIdentity])
        }
    }

    func testExactCaptureRejectsMismatchedBuildAndInstalledParts() throws {
        let exact = try tireSnapshot()
        var mismatch = offeredCapture(build: "different-build")
        XCTAssertEqual(
            mismatch.validationIssues(upgrading: exact),
            [.mismatchedGameBuild(expected: "test-build", entered: "different-build")]
        )

        var installed = exact
        installed.capabilityProfile.parts = [TuneVehiclePart(
            partID: .raceBrakes,
            availability: .installed,
            evidence: permittedEvidence(version: "test-build")
        )]
        XCTAssertTrue(installed.isValid, "Unexpected issues: \(installed.validationIssues)")
        mismatch.gameBuildVersion = "test-build"
        XCTAssertEqual(mismatch.validationIssues(upgrading: installed), [.installedPartsPresent])
    }

    func testEligibilitySupportsBothGamesAndExactTireSnapshots() throws {
        for game in ForzaGame.allCases {
            let tune = projectedTune(snapshot: try capabilitySnapshot(game: game))
            XCTAssertNotNil(UpgradePartCaptureEligibility().snapshot(for: tune))
        }

        let tireTune = projectedTune(snapshot: try tireSnapshot())
        XCTAssertNotNil(UpgradePartCaptureEligibility().snapshot(for: tireTune))

        var edited = projectedTune(snapshot: try capabilitySnapshot())
        edited.request.car.weightPounds += 1
        XCTAssertNil(UpgradePartCaptureEligibility().snapshot(for: edited))

        var missingReport = projectedTune(snapshot: try capabilitySnapshot())
        missingReport.projectionReport = nil
        XCTAssertNil(UpgradePartCaptureEligibility().snapshot(for: missingReport))
    }

    func testPlannerReturnsThreeDeterministicUniqueMinimalPaths() throws {
        let verified = try offeredCapture().verifiedSnapshot(
            upgrading: capabilitySnapshot(),
            capturedAt: capturedAt,
            snapshotID: snapshotID
        )
        let tune = projectedTune(snapshot: verified)

        let first = TuneControlUpgradePlanner().paths(for: tune)
        let second = TuneControlUpgradePlanner().paths(for: tune)

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.count, 3)
        XCTAssertEqual(Set(first.map(\.id)).count, first.count)
        XCTAssertTrue(first.allSatisfy { path in
            Set(path.items.map(\.part.slot)).count == path.items.count
        })
        XCTAssertTrue(first.allSatisfy { path in
            path.items.contains { $0.part.id == .sportTransmission }
        })
        XCTAssertTrue(first.allSatisfy { path in
            path.items.flatMap(\.unlocks).contains(.finalDrive)
        })
    }

    func testPlannerUsesOnlyRepresentedSettingsAndFailsClosedForUnknownFacts() throws {
        let unknown = projectedTune(snapshot: try capabilitySnapshot())
        XCTAssertTrue(TuneControlUpgradePlanner().paths(for: unknown).isEmpty)

        var verified = try offeredCapture().verifiedSnapshot(upgrading: capabilitySnapshot())
        verified.capabilityProfile.parts.removeAll { $0.partID == .raceBrakes }
        let incomplete = projectedTune(snapshot: verified)
        XCTAssertTrue(TuneControlUpgradePlanner().paths(for: incomplete).isEmpty)

        let noUpgradeFields = TuneResult(
            request: TuneRequest(car: verified.car, discipline: .road, buildSnapshot: verified),
            sections: [],
            notes: emptyNotes,
            projectionReport: TuneProjectionReport(
                schemaVersion: TuneProjectionReport.currentSchemaVersion,
                snapshotID: verified.id,
                contextStatus: .capabilityOnly,
                capabilityResolution: TuneCapabilityResolver(game: verified.car.game).resolve(
                    profile: verified.capabilityProfile
                ),
                fields: [TuneFieldProjection(
                    field: .frontTirePressure,
                    status: .needsConstraint,
                    requiredPurchaseIDs: [],
                    unresolvedPartIDs: [],
                    reason: .missingProductionConstraint
                )],
                purchasePlan: [],
                confirmations: [],
                diagnostics: []
            )
        )
        XCTAssertTrue(TuneControlUpgradePlanner().paths(for: noUpgradeFields).isEmpty)
    }

    func testUpgradeThenTireAndTireThenUpgradePreserveEvidence() throws {
        let capability = try capabilitySnapshot()
        let upgradedFirst = try offeredCapture().verifiedSnapshot(
            upgrading: capability,
            capturedAt: capturedAt,
            snapshotID: snapshotID
        )
        XCTAssertEqual(upgradedFirst.kind, .capabilityOnly)

        let tireAfterUpgrade = try tireCapture().exactBuildSnapshot(
            upgrading: upgradedFirst,
            capturedAt: capturedAt.addingTimeInterval(1),
            evidenceID: "tire-after-upgrade"
        )
        XCTAssertEqual(tireAfterUpgrade.kind, .exactBuildObservation)
        XCTAssertEqual(tireAfterUpgrade.capabilityProfile.parts, upgradedFirst.capabilityProfile.parts)
        XCTAssertTrue(tireAfterUpgrade.isValid, "Unexpected issues: \(tireAfterUpgrade.validationIssues)")

        let tireFirst = try tireSnapshot()
        let upgradedAfterTire = try offeredCapture().verifiedSnapshot(
            upgrading: tireFirst,
            capturedAt: capturedAt.addingTimeInterval(2)
        )
        XCTAssertEqual(upgradedAfterTire.kind, .exactBuildObservation)
        XCTAssertEqual(upgradedAfterTire.tireCompound, tireFirst.tireCompound)
        XCTAssertEqual(upgradedAfterTire.constraints, tireFirst.constraints)
        XCTAssertEqual(upgradedAfterTire.evidenceSources, tireFirst.evidenceSources)
        XCTAssertTrue(upgradedAfterTire.isValid, "Unexpected issues: \(upgradedAfterTire.validationIssues)")
    }

    func testPathsSurviveTuneJSONRoundTripAndClipboardExportsAllPaths() throws {
        let verified = try offeredCapture().verifiedSnapshot(upgrading: capabilitySnapshot())
        let tune = projectedTune(snapshot: verified)
        let decoded = try JSONDecoder().decode(
            TuneResult.self,
            from: JSONEncoder().encode(tune)
        )

        let paths = TuneControlUpgradePlanner().paths(for: decoded)
        XCTAssertEqual(paths.count, 3)
        let text = try XCTUnwrap(TuneClipboardFormatter.buildPlanText(for: decoded))
        XCTAssertTrue(text.contains("Tuning-control upgrade paths"))
        XCTAssertTrue(text.contains("Path 1"))
        XCTAssertTrue(text.contains("Path 2"))
        XCTAssertTrue(text.contains("Path 3"))
        XCTAssertTrue(text.contains("Drivetrain > Transmission > Sport Transmission"))
        XCTAssertTrue(text.contains("do not predict PI, credits, entitlement, performance, or installation order"))
        XCTAssertFalse(text.contains("Buy these upgrades"))
    }

    private func offeredCapture(build: String = "test-build") -> UpgradePartCapture {
        UpgradePartCapture(
            gameBuildVersion: build,
            parts: TunePartID.allCases.map {
                UpgradePartCaptureValue(partID: $0, status: .offered)
            },
            exactStockBuildConfirmed: true,
            localUsePermitted: true
        )
    }

    private func capabilitySnapshot(game: ForzaGame = .fh6) throws -> VehicleBuildSnapshot {
        let catalog = try BundledCarCatalog.load().get()
        let entry = try XCTUnwrap(catalog.entries.first { $0.game == game })
        return catalog.selection(for: entry).capabilityOnlyBuildSnapshot(capturedAt: capturedAt)
    }

    private func tireSnapshot() throws -> VehicleBuildSnapshot {
        try tireCapture().exactBuildSnapshot(
            upgrading: capabilitySnapshot(),
            capturedAt: capturedAt,
            evidenceID: "tire-first"
        )
    }

    private func tireCapture() -> TirePressureCapture {
        TirePressureCapture(
            gameBuildVersion: "test-build",
            tireCompound: "Stock",
            front: TirePressureRangeCapture(
                minimumPSI: 15,
                maximumPSI: 40,
                stepPSI: 0.5,
                currentPSI: 30
            ),
            rear: TirePressureRangeCapture(
                minimumPSI: 15,
                maximumPSI: 40,
                stepPSI: 0.5,
                currentPSI: 30
            ),
            exactStockBuildConfirmed: true,
            localUsePermitted: true
        )
    }

    private func projectedTune(snapshot: VehicleBuildSnapshot) -> TuneResult {
        TuneOutputProjector().project(TuneResult(
            request: TuneRequest(car: snapshot.car, discipline: .road, buildSnapshot: snapshot),
            sections: [],
            notes: emptyNotes
        ))
    }

    private var emptyNotes: TuneNotes {
        TuneNotes(bias: "", ifPushesWide: "", ifSnapsOnLift: "", retuneTrigger: "")
    }

    private func permittedEvidence(version: String) -> TuneEvidence {
        TuneEvidence(
            confidence: .medium,
            source: UpgradePartCapture.provenanceSource,
            version: version,
            usagePermission: .permitted
        )
    }
}
