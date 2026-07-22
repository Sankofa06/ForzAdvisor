//
//  TuneOutputProjectorTests.swift
//  forzadvisorTests
//
//  Adversarial coverage for the boundary that withholds unverified values.
//

import XCTest
@testable import forzadvisor

@MainActor
final class TuneOutputProjectorTests: XCTestCase {
    func testCurrentCatalogCarWithFullLocalCandidateWithholdsEveryNumber() async throws {
        let selection = try catalogSelection()
        let request = TuneRequest(
            car: selection.carInput,
            discipline: .road,
            buildSnapshot: selection.capabilityOnlyBuildSnapshot()
        )
        let raw = try await LocalSampleTuneProvider().generateTune(for: request)

        let projected = TuneOutputProjector().project(raw)
        let report = try XCTUnwrap(projected.projectionReport)

        XCTAssertTrue(projected.sections.isEmpty)
        XCTAssertEqual(report.readyCount, 0)
        XCTAssertEqual(projection(.frontTirePressure, in: report).status, .needsConstraint)
        XCTAssertEqual(projection(.rearTirePressure, in: report).status, .needsConstraint)
        XCTAssertEqual(projection(.frontARB, in: report).status, .needsPartConfirmation)
        XCTAssertNil(report.fields.first { $0.field == .differentialCenterBalance })
        XCTAssertTrue(report.purchasePlan.isEmpty)
        XCTAssertFalse(report.confirmations.isEmpty)
        XCTAssertNil(try JSONEncoder().encode(projected).range(of: Data("27.5".utf8)))
    }

    func testOneTrustedGlobalConstraintExposesOnlyItsMatchingField() throws {
        let selection = try catalogSelection()
        var snapshot = selection.capabilityOnlyBuildSnapshot()
        let evidence = globalEvidence()
        snapshot.constraints = [constraint(.frontTirePressure, evidenceID: evidence.id)]
        snapshot.evidenceSources = [evidence]
        XCTAssertTrue(snapshot.isValid, "Unexpected issues: \(snapshot.validationIssues)")

        let request = TuneRequest(car: selection.carInput, discipline: .road, buildSnapshot: snapshot)
        let raw = rawTune(request: request, lines: [
            TuneLine(label: "Front pressure", value: "30.0", unit: "PSI", fieldID: .frontTirePressure),
            TuneLine(label: "Rear pressure", value: "30.0", unit: "PSI", fieldID: .rearTirePressure)
        ])

        let projected = TuneOutputProjector().project(raw)
        let report = try XCTUnwrap(projected.projectionReport)

        XCTAssertEqual(projected.sections.flatMap(\.lines).map(\.fieldID), [.frontTirePressure])
        XCTAssertEqual(projection(.frontTirePressure, in: report).status, .ready)
        XCTAssertEqual(projection(.rearTirePressure, in: report).status, .needsConstraint)
    }

    func testReadyOutputUsesCanonicalPresentationAndDropsProviderProse() throws {
        let selection = try catalogSelection()
        var snapshot = selection.capabilityOnlyBuildSnapshot()
        let evidence = globalEvidence()
        snapshot.constraints = [constraint(.frontTirePressure, evidenceID: evidence.id)]
        snapshot.evidenceSources = [evidence]
        let request = TuneRequest(car: selection.carInput, discipline: .road, buildSnapshot: snapshot)
        let candidate = TuneResult(
            request: request,
            sections: [TuneSection(title: "Secret 777.7", symbolName: "exclamationmark", lines: [
                TuneLine(
                    label: "Front pressure 999.9",
                    value: "30.0",
                    unit: "PSI",
                    detail: "Hidden 888.8",
                    fieldID: .frontTirePressure
                ),
                TuneLine(label: "Untyped 666.6", value: "123.4", unit: "", fieldID: nil)
            ])],
            notes: TuneNotes(bias: "Raw", ifPushesWide: "Raw", ifSnapsOnLift: "Raw", retuneTrigger: "Raw")
        )

        let projected = TuneOutputProjector().project(candidate)
        let line = try XCTUnwrap(projected.sections.first?.lines.first)
        XCTAssertEqual(projected.sections.first?.title, "Tires")
        XCTAssertEqual(projected.sections.first?.symbolName, "circle.dashed")
        XCTAssertEqual(line.label, "Front tire pressure")
        XCTAssertNil(line.detail)
        let encoded = try JSONEncoder().encode(projected)
        for forbidden in ["777.7", "999.9", "888.8", "666.6", "123.4"] {
            XCTAssertNil(encoded.range(of: Data(forbidden.utf8)), "Leaked \(forbidden)")
        }
    }

    func testMissingSnapshotWrongUnitDuplicateAndOffStepValuesFailClosed() throws {
        let selection = try catalogSelection()
        let missingRequest = TuneRequest(car: selection.carInput, discipline: .road)
        let missing = TuneOutputProjector().project(rawTune(request: missingRequest, lines: [
            TuneLine(label: "Front pressure", value: "30.0", unit: "PSI", fieldID: .frontTirePressure)
        ]))
        XCTAssertTrue(missing.sections.isEmpty)
        XCTAssertEqual(missing.projectionReport?.contextStatus, .missingSnapshot)

        var snapshot = selection.capabilityOnlyBuildSnapshot()
        let evidence = globalEvidence()
        snapshot.constraints = [constraint(.frontTirePressure, evidenceID: evidence.id)]
        snapshot.evidenceSources = [evidence]
        let request = TuneRequest(car: selection.carInput, discipline: .road, buildSnapshot: snapshot)

        let wrongUnit = TuneOutputProjector().project(rawTune(request: request, lines: [
            TuneLine(label: "Front pressure", value: "30.0", unit: "bar", fieldID: .frontTirePressure)
        ]))
        XCTAssertEqual(wrongUnit.projectionReport.map { projection(.frontTirePressure, in: $0).reason }, .wrongDisplayUnit)

        let offStep = TuneOutputProjector().project(rawTune(request: request, lines: [
            TuneLine(label: "Front pressure", value: "30.05", unit: "PSI", fieldID: .frontTirePressure)
        ]))
        XCTAssertEqual(offStep.projectionReport.map { projection(.frontTirePressure, in: $0).reason }, .valueOutsideConstraint)

        let duplicate = TuneOutputProjector().project(rawTune(request: request, lines: [
            TuneLine(label: "Front pressure A", value: "30.0", unit: "PSI", fieldID: .frontTirePressure),
            TuneLine(label: "Front pressure B", value: "31.0", unit: "PSI", fieldID: .frontTirePressure)
        ]))
        XCTAssertEqual(duplicate.projectionReport.map { projection(.frontTirePressure, in: $0).reason }, .duplicateField)
        XCTAssertTrue(duplicate.sections.isEmpty)
    }

    func testExactPurchasesAreDeduplicatedAndUnknownPartsStayConfirmations() throws {
        let selection = try catalogSelection()
        var snapshot = selection.capabilityOnlyBuildSnapshot()
        snapshot.capabilityProfile.parts = suspensionParts(raceAvailability: .available)
        XCTAssertTrue(snapshot.isValid, "Unexpected issues: \(snapshot.validationIssues)")
        let request = TuneRequest(car: selection.carInput, discipline: .road, buildSnapshot: snapshot)

        let report = try XCTUnwrap(
            TuneOutputProjector().project(rawTune(request: request, lines: [])).projectionReport
        )
        let purchase = try XCTUnwrap(report.purchasePlan.first)
        XCTAssertEqual(report.purchasePlan.count, 1)
        XCTAssertEqual(purchase.part.id, .raceSuspension)
        XCTAssertEqual(
            Set(purchase.unlocks),
            [.alignment, .springRates, .rideHeight, .damping]
        )
        XCTAssertFalse(report.confirmations.contains { $0.setting == .alignment })

        snapshot.capabilityProfile.parts = suspensionParts(raceAvailability: .available).filter {
            $0.partID != .driftSuspension
        }
        let unknownReport = try XCTUnwrap(
            TuneOutputProjector().project(rawTune(
                request: TuneRequest(car: selection.carInput, discipline: .road, buildSnapshot: snapshot),
                lines: []
            )).projectionReport
        )
        XCTAssertFalse(unknownReport.purchasePlan.contains { $0.part.id == .raceSuspension })
        XCTAssertTrue(unknownReport.confirmations.contains { $0.setting == .alignment })
    }

    func testProviderDecoratorProjectsStreamingPartialAndFinal() async throws {
        let selection = try catalogSelection()
        let request = TuneRequest(
            car: selection.carInput,
            discipline: .road,
            buildSnapshot: selection.capabilityOnlyBuildSnapshot()
        )
        let raw = rawTune(request: request, lines: [
            TuneLine(label: "Front pressure", value: "30.0", unit: "PSI", fieldID: .frontTirePressure)
        ])
        let provider = CapabilityProjectingTuneProvider(base: ProjectorStubProvider(result: raw))
        var partials: [TuneResult] = []

        let final = try await provider.generateTune(for: request) { partial in
            partials.append(partial)
        }

        XCTAssertEqual(partials.count, 1)
        XCTAssertTrue(partials[0].sections.isEmpty)
        XCTAssertEqual(partials[0].projectionReport?.fields.first { $0.field == .frontTirePressure }?.status, .needsConstraint)
        XCTAssertTrue(final.sections.isEmpty)
        XCTAssertNotNil(final.projectionReport)
        XCTAssertEqual(final.providerInfo, raw.providerInfo)
    }

    func testProjectionReportRoundTripsAndLegacyTuneStillDecodes() throws {
        let selection = try catalogSelection()
        let request = TuneRequest(
            car: selection.carInput,
            discipline: .road,
            buildSnapshot: selection.capabilityOnlyBuildSnapshot()
        )
        let projected = TuneOutputProjector().project(rawTune(request: request, lines: []))
        XCTAssertEqual(
            try JSONDecoder().decode(TuneResult.self, from: JSONEncoder().encode(projected)),
            projected
        )

        let legacy = rawTune(request: request, lines: [])
        XCTAssertNil(legacy.projectionReport)
        XCTAssertNil(try JSONDecoder().decode(TuneResult.self, from: JSONEncoder().encode(legacy)).projectionReport)
    }

    func testProjectionIsIdempotent() throws {
        let selection = try catalogSelection()
        var snapshot = selection.capabilityOnlyBuildSnapshot()
        let evidence = globalEvidence()
        snapshot.constraints = [
            constraint(.frontTirePressure, evidenceID: evidence.id),
            constraint(.rearTirePressure, evidenceID: evidence.id)
        ]
        snapshot.evidenceSources = [evidence]
        let request = TuneRequest(car: selection.carInput, discipline: .road, buildSnapshot: snapshot)
        let candidate = rawTune(request: request, lines: [
            TuneLine(label: "Front pressure", value: "30.0", unit: "PSI", fieldID: .frontTirePressure),
            TuneLine(label: "Duplicate A", value: "30.0", unit: "PSI", fieldID: .rearTirePressure),
            TuneLine(label: "Duplicate B", value: "31.0", unit: "PSI", fieldID: .rearTirePressure),
            TuneLine(label: "Untyped", value: "999.9", unit: "", fieldID: nil)
        ])

        let once = TuneOutputProjector().project(candidate)
        XCTAssertEqual(TuneOutputProjector().project(once), once)
    }

    func testDrivetrainUsesOnlyApplicableDifferentialFields() {
        XCTAssertEqual(
            differentialFields(for: .fwd),
            [.frontDifferentialAcceleration, .frontDifferentialDeceleration]
        )
        XCTAssertEqual(
            differentialFields(for: .rwd),
            [.differentialAcceleration, .differentialDeceleration]
        )
        XCTAssertEqual(
            differentialFields(for: .awd),
            [
                .frontDifferentialAcceleration,
                .frontDifferentialDeceleration,
                .rearDifferentialAcceleration,
                .rearDifferentialDeceleration,
                .differentialCenterBalance
            ]
        )
    }

    func testAdjustmentAcceptsOnlyEligibleTargetFields() async throws {
        let previous = try adjustableTune()
        let request = previous.request
        let candidate = rawTune(request: request, lines: [
            TuneLine(label: "ARB", value: "25.0", unit: "", fieldID: .frontARB),
            TuneLine(label: "Tire", value: "35.0", unit: "PSI", fieldID: .frontTirePressure)
        ])
        let provider = CapabilityProjectingTuneProvider(base: ProjectorStubProvider(result: candidate))

        let result = try await provider.adjustTune(previous: previous, adjustment: .moreRotation)

        XCTAssertEqual(value(for: .frontARB, in: result.tune), "25.0")
        XCTAssertEqual(value(for: .frontTirePressure, in: result.tune), "30.0")
        XCTAssertEqual(result.changes.count, 1)
        XCTAssertEqual(result.changes.first?.lineLabel, "Front antiroll bar")
    }

    func testDuplicateEligibleAdjustmentFailsWithoutCrashing() async throws {
        let previous = try adjustableTune()
        let candidate = rawTune(request: previous.request, lines: [
            TuneLine(label: "ARB A", value: "25.0", unit: "", fieldID: .frontARB),
            TuneLine(label: "ARB B", value: "30.0", unit: "", fieldID: .frontARB),
            TuneLine(label: "Tire", value: "30.0", unit: "PSI", fieldID: .frontTirePressure)
        ])
        let provider = CapabilityProjectingTuneProvider(base: ProjectorStubProvider(result: candidate))

        do {
            _ = try await provider.adjustTune(previous: previous, adjustment: .moreRotation)
            XCTFail("Expected duplicate target fields to fail closed")
        } catch {
            XCTAssertEqual(error as? TuneProjectionError, .noVerifiedChange)
        }
    }

    private func projection(_ field: TuneFieldID, in report: TuneProjectionReport) -> TuneFieldProjection {
        report.fields.first { $0.field == field }!
    }

    private func differentialFields(for drivetrain: Drivetrain) -> [TuneFieldID] {
        TuneFieldID.expectedFields(drivetrain: drivetrain, gearCount: nil).filter {
            $0.setting == .differentialAcceleration
                || $0.setting == .differentialDeceleration
                || $0.setting == .differentialCenter
        }
    }

    private func adjustableTune() throws -> TuneResult {
        let selection = try catalogSelection()
        var snapshot = selection.capabilityOnlyBuildSnapshot()
        let capabilityEvidence = TuneEvidence(
            confidence: .high,
            source: "fixture.stock-adjustability",
            version: "1",
            usagePermission: .permitted
        )
        snapshot.capabilityProfile.stockAdjustableSettings = [
            StockAdjustableSetting(setting: .frontARB, evidence: capabilityEvidence)
        ]
        let provenance = globalEvidence()
        snapshot.evidenceSources = [provenance]
        snapshot.constraints = [
            constraint(.frontTirePressure, evidenceID: provenance.id),
            TuneFieldConstraint(
                field: .frontARB,
                minimum: 1,
                maximum: 65,
                step: 0.1,
                defaultValue: 20,
                currentValue: 20,
                unit: .scalar,
                scope: .gameGlobal,
                verification: .productionEligible,
                evidenceIDs: [provenance.id]
            )
        ]
        XCTAssertTrue(snapshot.isValid, "Unexpected issues: \(snapshot.validationIssues)")
        let request = TuneRequest(car: selection.carInput, discipline: .road, buildSnapshot: snapshot)
        return TuneOutputProjector().project(rawTune(request: request, lines: [
            TuneLine(label: "ARB", value: "20.0", unit: "", fieldID: .frontARB),
            TuneLine(label: "Tire", value: "30.0", unit: "PSI", fieldID: .frontTirePressure)
        ]))
    }

    private func value(for field: TuneFieldID, in tune: TuneResult) -> String? {
        tune.sections.flatMap(\.lines).first { $0.fieldID == field }?.value
    }

    private func catalogSelection() throws -> CatalogCarSelection {
        let catalog = try BundledCarCatalog.load().get()
        let entry = try XCTUnwrap(catalog.entries.first { $0.id == "fh6-2020-toyota-gr-supra" })
        return catalog.selection(for: entry)
    }

    private func rawTune(request: TuneRequest, lines: [TuneLine]) -> TuneResult {
        TuneResult(
            request: request,
            sections: [TuneSection(title: "Tires", symbolName: "circle.dashed", lines: lines)],
            notes: TuneNotes(
                bias: "Raw 999.9 candidate",
                ifPushesWide: "Raw",
                ifSnapsOnLift: "Raw",
                retuneTrigger: "Raw"
            ),
            providerInfo: .direct(.offlineFormula)
        )
    }

    private func globalEvidence() -> TuneDataProvenance {
        TuneDataProvenance(
            id: "rules.fh6.global-tire-range",
            game: .fh6,
            gameBuildVersion: nil,
            scope: .gameGlobal,
            source: "forzadvisor.test-fixture",
            version: "1",
            capturedAt: Date(timeIntervalSinceReferenceDate: 1),
            confidence: .high,
            usagePermission: .permitted
        )
    }

    private func constraint(_ field: TuneFieldID, evidenceID: String) -> TuneFieldConstraint {
        TuneFieldConstraint(
            field: field,
            minimum: 15,
            maximum: 40,
            step: 0.1,
            defaultValue: 30,
            currentValue: 30,
            unit: .psi,
            scope: .gameGlobal,
            verification: .productionEligible,
            evidenceIDs: [evidenceID]
        )
    }

    private func suspensionParts(raceAvailability: TunePartAvailability) -> [TuneVehiclePart] {
        let evidence = TuneEvidence(
            confidence: .high,
            source: "fixture.parts",
            version: "1",
            usagePermission: .permitted
        )
        return [
            TuneVehiclePart(partID: .raceSuspension, availability: raceAvailability, evidence: evidence),
            TuneVehiclePart(partID: .rallySuspension, availability: .unavailable, evidence: evidence),
            TuneVehiclePart(partID: .offroadSuspension, availability: .unavailable, evidence: evidence),
            TuneVehiclePart(partID: .driftSuspension, availability: .unavailable, evidence: evidence)
        ]
    }
}

private struct ProjectorStubProvider: TuneProvider {
    let result: TuneResult

    func generateTune(for request: TuneRequest) async throws -> TuneResult {
        result
    }

    func generateTune(for request: TuneRequest, onPartial: TuneProgressHandler?) async throws -> TuneResult {
        onPartial?(result)
        return result
    }

    func adjustTune(previous tune: TuneResult, adjustment: TuneAdjustment) async throws -> TuneAdjustmentResult {
        TuneAdjustmentResult(tune: result, changes: [])
    }
}
