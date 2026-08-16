//
//  FH6ExactConstraintQuantizerTests.swift
//  forzadvisorTests
//

import XCTest
@testable import forzadvisor

final class FH6ExactConstraintQuantizerTests: XCTestCase {
    func testTuneMenuCaptureProviderAndProjectorReadyEveryFormulaBackedField() async throws {
        let snapshot = try menuSnapshot()
        let provider = CapabilityProjectingTuneProvider(base: LocalSampleTuneProvider())

        let tune = try await provider.generateTune(for: TuneRequest(
            car: snapshot.car,
            discipline: .road,
            buildSnapshot: snapshot
        ))

        let expectedReady = Set(TuneFieldID.expectedFields(
            drivetrain: snapshot.car.drivetrain,
            gearCount: snapshot.gearCount
        ).filter { $0.gearIndex == nil })
        XCTAssertEqual(tune.projectionReport?.readyFieldIDs, expectedReady)
        XCTAssertEqual(
            Set(tune.sections.flatMap(\.lines).compactMap(\.fieldID)),
            expectedReady
        )
        XCTAssertTrue((1...6).allSatisfy { index in
            tune.projectionReport?.fields.first(where: {
                $0.field == .gearRatio(index)
            })?.status == .providerOmitted
        })
        XCTAssertEqual(tune.rulesetReference?.id, FH6ExactConstraintRuleset.id)
        XCTAssertEqual(
            tune.rulesetReference?.provenanceIDs,
            ["fh6-menu.quantizer-test"]
        )
        for line in tune.sections.flatMap(\.lines) {
            let field = try XCTUnwrap(line.fieldID)
            let constraint = try XCTUnwrap(snapshot.constraints.first {
                $0.field == field
            })
            let value = try XCTUnwrap(line.numericValue)
            XCTAssertTrue(constraint.accepts(value), field.stableID)
        }
    }

    func testQuantizerFailsClosedForOutOfRangeDuplicateGearAndUntrustedEvidence() throws {
        let snapshot = try menuSnapshot()
        let request = TuneRequest(
            car: snapshot.car,
            discipline: .road,
            buildSnapshot: snapshot
        )
        let outOfRange = rawTune(request: request, lines: [
            line(.frontARB, value: 5_000.25)
        ])
        XCTAssertEqual(
            FH6ExactConstraintQuantizer().quantize(outOfRange),
            outOfRange
        )

        let duplicate = rawTune(request: request, lines: [
            line(.frontARB, value: 12.25),
            line(.frontARB, value: 12.25)
        ])
        XCTAssertEqual(
            FH6ExactConstraintQuantizer().quantize(duplicate),
            duplicate
        )

        let gear = rawTune(request: request, lines: [
            line(.gearRatio(1), value: 2.25)
        ])
        XCTAssertEqual(FH6ExactConstraintQuantizer().quantize(gear), gear)

        var rejectedSnapshots: [VehicleBuildSnapshot] = []
        var unrecognizedVersion = snapshot
        unrecognizedVersion.evidenceSources[0].version = "unknown-version"
        rejectedSnapshots.append(unrecognizedVersion)
        var lowConfidence = snapshot
        lowConfidence.evidenceSources[0].confidence = .low
        rejectedSnapshots.append(lowConfidence)
        var prohibited = snapshot
        prohibited.evidenceSources[0].usagePermission = .prohibited
        rejectedSnapshots.append(prohibited)
        var unknownPermission = snapshot
        unknownPermission.evidenceSources[0].usagePermission = .unknown
        rejectedSnapshots.append(unknownPermission)
        var mismatchedBuild = snapshot
        mismatchedBuild.evidenceSources[0].gameBuildVersion = "other-build"
        rejectedSnapshots.append(mismatchedBuild)
        var mismatchedScope = snapshot
        mismatchedScope.evidenceSources[0].scope = .gameGlobal
        rejectedSnapshots.append(mismatchedScope)
        var untrustedSource = snapshot
        untrustedSource.evidenceSources[0].source = "third-party.fixture"
        rejectedSnapshots.append(untrustedSource)

        for rejectedSnapshot in rejectedSnapshots {
            let untrusted = rawTune(
                request: TuneRequest(
                    car: rejectedSnapshot.car,
                    discipline: .road,
                    buildSnapshot: rejectedSnapshot
                ),
                lines: [line(.frontARB, value: 12.25)]
            )
            XCTAssertEqual(
                FH6ExactConstraintQuantizer().quantize(untrusted),
                untrusted
            )
        }
    }

    func testAdjustmentReturnsValuesAlignedToCapturedGrid() async throws {
        let snapshot = try menuSnapshot(stepOverrides: [
            .frontARB: 0.5,
            .rearARB: 0.5
        ])
        let provider = CapabilityProjectingTuneProvider(
            base: LocalSampleTuneProvider()
        )
        let tune = try await provider.generateTune(for: TuneRequest(
            car: snapshot.car,
            discipline: .road,
            buildSnapshot: snapshot
        ))

        let result = try await provider.adjustTune(
            previous: tune,
            adjustment: .moreRotation
        )

        for field in [TuneFieldID.frontARB, .rearARB] {
            let line = try XCTUnwrap(result.tune.sections
                .flatMap(\.lines)
                .first { $0.fieldID == field })
            let value = try XCTUnwrap(line.numericValue)
            let constraint = try XCTUnwrap(snapshot.constraints.first {
                $0.field == field
            })
            XCTAssertTrue(constraint.accepts(value), field.stableID)
            XCTAssertEqual(
                result.changes.first {
                    $0.sectionTitle == "Antiroll Bars"
                        && $0.lineLabel == line.label
                }?.newValue,
                line.value
            )
        }
        XCTAssertEqual(
            result.tune.rulesetReference?.id,
            FH6ExactConstraintRuleset.id
        )

        let narrowSnapshot = try menuSnapshot(maximumOverrides: [
            .frontARB: 1
        ])
        let narrowTune = try await provider.generateTune(for: TuneRequest(
            car: narrowSnapshot.car,
            discipline: .road,
            buildSnapshot: narrowSnapshot
        ))
        XCTAssertFalse(narrowTune.sections.flatMap(\.lines).contains {
            $0.fieldID == .frontARB
        })
        let rejectedFrontARB = narrowTune.projectionReport?.fields.filter {
            $0.field == TuneFieldID.frontARB
        }.first
        XCTAssertEqual(rejectedFrontARB?.status, .rejectedValue)
        XCTAssertEqual(
            rejectedFrontARB?.reason,
            .valueOutsideConstraint
        )
    }

    func testPublicRulesetRegistryPreservesV1AndRecognizesV2() {
        XCTAssertTrue(FH6PublicRulesetRegistry.recognizes(
            id: FH6LocalTirePressureRuleset.id,
            schemaVersion: FH6LocalTirePressureRuleset.schemaVersion,
            algorithmVersion: FH6LocalTirePressureRuleset.algorithmVersion,
            knowledgeRevision: FH6LocalTirePressureRuleset.knowledgeRevision,
            validationStatus: .experimental
        ))
        XCTAssertTrue(FH6PublicRulesetRegistry.recognizes(
            id: FH6ExactConstraintRuleset.id,
            schemaVersion: FH6ExactConstraintRuleset.schemaVersion,
            algorithmVersion: FH6ExactConstraintRuleset.algorithmVersion,
            knowledgeRevision: FH6ExactConstraintRuleset.knowledgeRevision,
            validationStatus: .experimental
        ))
    }

    private func menuSnapshot(
        stepOverrides: [TuneFieldID: Double] = [:],
        maximumOverrides: [TuneFieldID: Double] = [:]
    ) throws -> VehicleBuildSnapshot {
        let base = SyntheticLegacyTuneFixtureFactory.selection(
            drivetrain: .rwd,
            reviewedAt: Date(timeIntervalSinceReferenceDate: 500)
        ).capabilityOnlyBuildSnapshot()
        let controls = TuneFieldID.expectedFields(
            drivetrain: base.car.drivetrain,
            gearCount: 6
        ).map { field in
            let minimum = field.expectedUnit == .degrees ? -10.0 : 0
            let step = stepOverrides[field] ?? 0.5
            let maximum = maximumOverrides[field]
                ?? minimum + (step * 10_000)
            return FH6TuneMenuFieldObservation(
                field: field,
                availability: .adjustable,
                minimum: minimum,
                maximum: maximum,
                step: step,
                current: min(minimum + (step * 10), maximum),
                unit: field.expectedUnit
            )
        }
        return try FH6TuneMenuCapture(
            gameBuildVersion: "2026.07.24",
            tireCompoundDisplayName: "Stock",
            forwardGearCount: 6,
            controls: controls,
            exactUntouchedStockConfirmed: true,
            allSlidersRestoredConfirmed: true,
            personallyReadFromGameConfirmed: true,
            localStoragePermitted: true
        ).exactBuildSnapshot(
            upgrading: base,
            evidenceID: "fh6-menu.quantizer-test"
        )
    }

    private func rawTune(
        request: TuneRequest,
        lines: [TuneLine]
    ) -> TuneResult {
        TuneResult(
            request: request,
            sections: [
                TuneSection(
                    title: "Test",
                    symbolName: "slider.horizontal.3",
                    lines: lines
                )
            ],
            notes: TuneNotes(
                bias: "Test",
                ifPushesWide: "Test",
                ifSnapsOnLift: "Test",
                retuneTrigger: "Test"
            )
        )
    }

    private func line(
        _ field: TuneFieldID,
        value: Double
    ) -> TuneLine {
        TuneLine(
            label: field.projectionLabel,
            value: LocalizedNumberText.format(value, fractionDigits: 2),
            unit: field.expectedDisplayUnit,
            fieldID: field
        )
    }
}
