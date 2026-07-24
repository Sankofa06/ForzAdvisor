//
//  FH6TuneMenuCaptureTests.swift
//  forzadvisorTests
//

import XCTest
@testable import forzadvisor

final class FH6TuneMenuCaptureTests: XCTestCase {
    private let capturedAt = Date(timeIntervalSinceReferenceDate: 1_234)
    private let snapshotID = UUID(
        uuidString: "A1A1A1A1-B2B2-C3C3-D4D4-E5E5E5E5E5E5"
    )!
    private let evidenceID = "fh6-menu.test-observation"

    func testCompleteRWDAndAWDCapturesCreateProductionEligibleExactSnapshots() throws {
        for drivetrain in [Drivetrain.rwd, .awd] {
            let base = try capabilitySnapshot(drivetrain: drivetrain)
            let original = base
            let capture = validCapture(for: base, allAdjustable: true)

            let exact = try capture.exactBuildSnapshot(
                upgrading: base,
                capturedAt: capturedAt,
                snapshotID: snapshotID,
                evidenceID: evidenceID
            )

            XCTAssertEqual(base, original)
            XCTAssertEqual(exact.kind, .exactBuildObservation)
            XCTAssertEqual(exact.id, snapshotID)
            XCTAssertEqual(
                exact.gameBuild,
                GameBuildReference(
                    game: .fh6,
                    version: "2026.07.24",
                    capturedAt: capturedAt
                )
            )
            XCTAssertEqual(exact.gearCount, 6)
            XCTAssertEqual(exact.constraints.count, capture.controls.count)
            XCTAssertTrue(exact.constraints.allSatisfy {
                $0.scope == .exactVehicleBuild
                    && $0.verification == .productionEligible
                    && $0.evidenceIDs == [evidenceID]
            })
            XCTAssertEqual(
                Set(exact.constraints.map(\.field)),
                Set(TuneFieldID.expectedFields(
                    drivetrain: drivetrain,
                    gearCount: 6
                ))
            )
            XCTAssertEqual(
                Set(exact.capabilityProfile.stockAdjustableSettings.map(\.setting)),
                Set(TuneSetting.allCases.filter {
                    drivetrain == .awd || $0 != .differentialCenter
                })
            )
            XCTAssertTrue(exact.isValid, "Unexpected issues: \(exact.validationIssues)")

            let provenance = try XCTUnwrap(exact.evidenceSources.first)
            XCTAssertEqual(provenance.id, evidenceID)
            XCTAssertEqual(provenance.source, FH6TuneMenuCapture.provenanceSource)
            XCTAssertEqual(provenance.version, FH6TuneMenuCapture.provenanceVersion)
            XCTAssertEqual(provenance.gameBuildVersion, "2026.07.24")
            XCTAssertEqual(provenance.scope, .exactVehicleBuild)
            XCTAssertEqual(provenance.confidence, .medium)
            XCTAssertEqual(provenance.usagePermission, .permitted)
        }
    }

    func testLockedAndNotShownFieldsCreateNoConstraintsOrPartialSettingOverride() throws {
        let base = try capabilitySnapshot(drivetrain: .rwd)
        var capture = validCapture(for: base, allAdjustable: true)
        setAvailability(.frontCamber, to: .shownLocked, in: &capture)
        setAvailability(.frontAero, to: .notShown, in: &capture)

        let exact = try capture.exactBuildSnapshot(upgrading: base)

        XCTAssertNil(exact.constraints.first { $0.field == .frontCamber })
        XCTAssertNil(exact.constraints.first { $0.field == .frontAero })
        XCTAssertFalse(exact.capabilityProfile.stockAdjustableSettings.contains {
            $0.setting == .alignment
        })
        XCTAssertFalse(exact.capabilityProfile.stockAdjustableSettings.contains {
            $0.setting == .frontAero
        })
        XCTAssertTrue(exact.capabilityProfile.stockAdjustableSettings.contains {
            $0.setting == .rearAero
        })
        XCTAssertTrue(exact.isValid, "Unexpected issues: \(exact.validationIssues)")
    }

    func testCaptureReplacesPriorExactMenuEvidenceAndKeepsMatchingUpgradeFacts() throws {
        let capability = try capabilitySnapshot(drivetrain: .rwd)
        let upgraded = try UpgradePartCapture(
            gameBuildVersion: "2026.07.24",
            parts: TunePartID.allCases.map {
                UpgradePartCaptureValue(partID: $0, status: .offered)
            },
            exactStockBuildConfirmed: true,
            localUsePermitted: true
        ).verifiedSnapshot(upgrading: capability)
        let tire = try TirePressureCapture(
            gameBuildVersion: "2026.07.24",
            tireCompound: "Stock",
            gearCount: 6,
            front: .init(
                minimumPSI: 15,
                maximumPSI: 40,
                stepPSI: 0.5,
                currentPSI: 30
            ),
            rear: .init(
                minimumPSI: 15,
                maximumPSI: 40,
                stepPSI: 0.5,
                currentPSI: 30
            ),
            exactStockBuildConfirmed: true,
            localUsePermitted: true
        ).exactBuildSnapshot(
            upgrading: upgraded,
            evidenceID: "old-tire-evidence"
        )

        let exact = try validCapture(for: tire).exactBuildSnapshot(
            upgrading: tire,
            capturedAt: capturedAt,
            snapshotID: snapshotID,
            evidenceID: evidenceID
        )

        XCTAssertEqual(
            exact.capabilityProfile.parts,
            upgraded.capabilityProfile.parts
        )
        XCTAssertFalse(exact.evidenceSources.contains {
            $0.id == "old-tire-evidence"
        })
        XCTAssertFalse(exact.constraints.flatMap(\.evidenceIDs).contains {
            $0 == "old-tire-evidence"
        })
        XCTAssertEqual(exact.evidenceSources.map(\.id), [evidenceID])
        XCTAssertTrue(exact.isValid, "Unexpected issues: \(exact.validationIssues)")
    }

    func testValidationRejectsMismatchedUpgradeBuild() throws {
        let base = try capabilitySnapshot(drivetrain: .rwd)
        let upgraded = try UpgradePartCapture(
            gameBuildVersion: "older-build",
            parts: TunePartID.allCases.map {
                UpgradePartCaptureValue(partID: $0, status: .offered)
            },
            exactStockBuildConfirmed: true,
            localUsePermitted: true
        ).verifiedSnapshot(upgrading: base)
        var capture = validCapture(for: upgraded)
        capture.gameBuildVersion = "newer-build"

        let issues = capture.validationIssues(upgrading: upgraded)

        XCTAssertTrue(issues.contains(
            .mismatchedGameBuild(
                expected: "older-build",
                entered: "newer-build"
            )
        ))
        XCTAssertTrue(issues.contains(
            .mismatchedUpgradeGameBuild(
                expected: "older-build",
                entered: "newer-build"
            )
        ))
        XCTAssertThrowsError(try capture.exactBuildSnapshot(upgrading: upgraded))
    }

    func testValidationRejectsMissingDuplicateUnexpectedAndMalformedFields() throws {
        let base = try capabilitySnapshot(drivetrain: .rwd)
        var capture = validCapture(for: base)
        let missing = capture.controls.removeFirst()
        capture.controls.append(capture.controls[0])
        capture.controls.append(observation(
            field: .gearRatio(7),
            availability: .adjustable
        ))
        if let index = capture.controls.firstIndex(where: {
            $0.field == .frontCamber
        }) {
            capture.controls[index] = observation(
                field: .frontCamber,
                availability: .adjustable
            )
            capture.controls[index].unit = .psi
        }
        if let index = capture.controls.firstIndex(where: {
            $0.field == .frontAero
        }) {
            capture.controls[index] = observation(
                field: .frontAero,
                availability: .shownLocked
            )
            capture.controls[index].current = 5
        }

        let issues = capture.validationIssues(upgrading: base)

        XCTAssertTrue(issues.contains(.missingField(missing.field)))
        XCTAssertTrue(issues.contains(.duplicateField(capture.controls[0].field)))
        XCTAssertTrue(issues.contains(.unexpectedField(.gearRatio(7))))
        XCTAssertTrue(issues.contains(.invalidAdjustableField(.frontCamber)))
        XCTAssertTrue(issues.contains(.lockedFieldContainsValues(.frontAero)))
    }

    func testValidationRejectsWrongScopeMetadataAttestationsAndReusedIdentity() throws {
        let fh5Base = try capabilitySnapshot(game: .fh5, drivetrain: .rwd)
        XCTAssertTrue(fh5Base.isValid, "Unexpected issues: \(fh5Base.validationIssues)")

        var capture = validCapture(for: fh5Base)
        capture.gameBuildVersion = " "
        capture.tireCompoundDisplayName = String(repeating: "x", count: 121)
        capture.forwardGearCount = 0
        capture.exactUntouchedStockConfirmed = false
        capture.allSlidersRestoredConfirmed = false
        capture.personallyReadFromGameConfirmed = false
        capture.localStoragePermitted = false

        let issues = capture.validationIssues(upgrading: fh5Base)
        XCTAssertTrue(issues.contains(.unsupportedGame(.fh5)))
        XCTAssertTrue(issues.contains(.missingGameBuildVersion))
        XCTAssertTrue(issues.contains(.invalidTireCompound))
        XCTAssertTrue(issues.contains(.invalidGearCount(0)))
        XCTAssertTrue(issues.contains(.exactStockBuildNotConfirmed))
        XCTAssertTrue(issues.contains(.slidersNotRestored))
        XCTAssertTrue(issues.contains(.firstPartyReadingNotConfirmed))
        XCTAssertTrue(issues.contains(.localUseNotPermitted))

        let base = try capabilitySnapshot(drivetrain: .rwd)
        XCTAssertThrowsError(try validCapture(for: base).exactBuildSnapshot(
            upgrading: base,
            snapshotID: base.id,
            evidenceID: " "
        ))
    }

    func testCaptureAndSnapshotRoundTripWithoutSchemaChanges() throws {
        let base = try capabilitySnapshot(drivetrain: .rwd)
        let capture = validCapture(for: base)
        let exact = try capture.exactBuildSnapshot(upgrading: base)

        XCTAssertEqual(
            try JSONDecoder().decode(
                FH6TuneMenuCapture.self,
                from: JSONEncoder().encode(capture)
            ),
            capture
        )
        XCTAssertEqual(
            try JSONDecoder().decode(
                VehicleBuildSnapshot.self,
                from: JSONEncoder().encode(exact)
            ),
            exact
        )
        XCTAssertEqual(
            exact.schemaVersion,
            VehicleBuildSnapshot.currentSchemaVersion
        )
    }

    func testEligibilityAcceptsCanonicalFH6GapAndRejectsUnsafeContexts() throws {
        let snapshot = try capabilitySnapshot(drivetrain: .rwd)
        let eligible = projectedTune(snapshot: snapshot)
        XCTAssertEqual(
            FH6TuneMenuCaptureEligibility().snapshot(for: eligible),
            snapshot
        )
        XCTAssertNil(
            FH6TuneMenuCaptureEligibility().snapshot(
                for: eligible,
                isStreaming: true
            )
        )

        var missingReport = eligible
        missingReport.projectionReport = nil
        XCTAssertNil(FH6TuneMenuCaptureEligibility().snapshot(for: missingReport))

        var duplicate = eligible
        var duplicateReport = try XCTUnwrap(duplicate.projectionReport)
        duplicateReport.fields.append(
            try XCTUnwrap(duplicateReport.fields.first)
        )
        duplicate.projectionReport = duplicateReport
        XCTAssertNil(FH6TuneMenuCaptureEligibility().snapshot(for: duplicate))

        var noGap = eligible
        var noGapReport = try XCTUnwrap(noGap.projectionReport)
        noGapReport.fields = noGapReport.fields.map {
            TuneFieldProjection(
                field: $0.field,
                status: .ready,
                requiredPurchaseIDs: [],
                unresolvedPartIDs: [],
                reason: nil
            )
        }
        noGap.projectionReport = noGapReport
        XCTAssertNil(FH6TuneMenuCaptureEligibility().snapshot(for: noGap))

        var edited = eligible
        edited.request.car.weightPounds += 1
        XCTAssertNil(FH6TuneMenuCaptureEligibility().snapshot(for: edited))
    }

    func testEligibilityDisappearsAfterCompleteMenuCapture() throws {
        let base = try capabilitySnapshot(drivetrain: .rwd)
        let exact = try validCapture(for: base).exactBuildSnapshot(
            upgrading: base,
            capturedAt: capturedAt,
            snapshotID: snapshotID,
            evidenceID: evidenceID
        )
        let projected = projectedTune(snapshot: exact)

        XCTAssertNil(
            FH6TuneMenuCaptureEligibility().snapshot(for: projected)
        )
    }

    private func capabilitySnapshot(
        game: ForzaGame = .fh6,
        drivetrain: Drivetrain
    ) throws -> VehicleBuildSnapshot {
        let catalog = try BundledCarCatalog.load().get()
        let entry = try XCTUnwrap(catalog.entries.first {
            $0.game == game && $0.stock.drivetrain == drivetrain
        })
        return catalog.selection(for: entry).capabilityOnlyBuildSnapshot(
            capturedAt: capturedAt
        )
    }

    private func validCapture(
        for snapshot: VehicleBuildSnapshot,
        allAdjustable: Bool = false
    ) -> FH6TuneMenuCapture {
        FH6TuneMenuCapture(
            gameBuildVersion: "2026.07.24",
            tireCompoundDisplayName: "Stock Road",
            forwardGearCount: 6,
            controls: TuneFieldID.expectedFields(
                drivetrain: snapshot.car.drivetrain,
                gearCount: 6
            ).map {
                observation(
                    field: $0,
                    availability: allAdjustable || $0.setting == .tirePressure
                        ? .adjustable
                        : .shownLocked
                )
            },
            exactUntouchedStockConfirmed: true,
            allSlidersRestoredConfirmed: true,
            personallyReadFromGameConfirmed: true,
            localStoragePermitted: true
        )
    }

    private func observation(
        field: TuneFieldID,
        availability: FH6TuneMenuFieldAvailability
    ) -> FH6TuneMenuFieldObservation {
        if availability != .adjustable {
            return FH6TuneMenuFieldObservation(
                field: field,
                availability: availability,
                minimum: nil,
                maximum: nil,
                step: nil,
                current: nil,
                unit: nil
            )
        }
        return FH6TuneMenuFieldObservation(
            field: field,
            availability: availability,
            minimum: 0,
            maximum: 10,
            step: 0.5,
            current: 5,
            unit: field.expectedUnit
        )
    }

    private func setAvailability(
        _ field: TuneFieldID,
        to availability: FH6TuneMenuFieldAvailability,
        in capture: inout FH6TuneMenuCapture
    ) {
        guard let index = capture.controls.firstIndex(where: {
            $0.field == field
        }) else {
            return
        }
        capture.controls[index] = observation(
            field: field,
            availability: availability
        )
    }

    private func projectedTune(
        snapshot: VehicleBuildSnapshot
    ) -> TuneResult {
        let fields = [
            TuneFieldProjection(
                field: .frontTirePressure,
                status: .needsConstraint,
                requiredPurchaseIDs: [],
                unresolvedPartIDs: [],
                reason: .missingProductionConstraint
            ),
            TuneFieldProjection(
                field: .finalDrive,
                status: .needsPartConfirmation,
                requiredPurchaseIDs: [],
                unresolvedPartIDs: [.sportTransmission],
                reason: .partAvailabilityUnknown
            )
        ]
        return TuneResult(
            request: TuneRequest(
                car: snapshot.car,
                discipline: .road,
                buildSnapshot: snapshot
            ),
            sections: [],
            notes: TuneNotes(
                bias: "",
                ifPushesWide: "",
                ifSnapsOnLift: "",
                retuneTrigger: ""
            ),
            projectionReport: TuneProjectionReport(
                schemaVersion: TuneProjectionReport.currentSchemaVersion,
                snapshotID: snapshot.id,
                contextStatus: snapshot.kind == .exactBuildObservation
                    ? .exactBuild
                    : .capabilityOnly,
                capabilityResolution: nil,
                fields: fields,
                purchasePlan: [],
                confirmations: [],
                diagnostics: []
            )
        )
    }
}
