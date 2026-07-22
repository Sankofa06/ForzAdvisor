//
//  TirePressureCaptureEligibilityTests.swift
//  forzadvisorTests
//

import XCTest
@testable import forzadvisor

final class TirePressureCaptureEligibilityTests: XCTestCase {
    func testUntouchedFH6CatalogTuneWithBothMissingConstraintsIsEligible() throws {
        let tune = try eligibleTune(game: .fh6)

        XCTAssertEqual(
            TirePressureCaptureEligibility().snapshot(for: tune),
            tune.request.buildSnapshot
        )
    }

    func testEligibilityRejectsFH5EditedExactAndMissingProjectionContexts() throws {
        XCTAssertNil(TirePressureCaptureEligibility().snapshot(for: try eligibleTune(game: .fh5)))

        var edited = try eligibleTune(game: .fh6)
        edited.request.car.weightPounds += 1
        XCTAssertTrue(edited.request.car.catalogValuesModified)
        XCTAssertNil(TirePressureCaptureEligibility().snapshot(for: edited))

        var exact = try eligibleTune(game: .fh6)
        exact.request.buildSnapshot?.kind = .exactBuildObservation
        XCTAssertNil(TirePressureCaptureEligibility().snapshot(for: exact))

        var missingReport = try eligibleTune(game: .fh6)
        missingReport.projectionReport = nil
        XCTAssertNil(TirePressureCaptureEligibility().snapshot(for: missingReport))
    }

    func testEligibilityRejectsWrongOrAmbiguousTireStatuses() throws {
        var wrongStatus = try eligibleTune(game: .fh6)
        wrongStatus.projectionReport?.fields[0].status = .ready
        XCTAssertNil(TirePressureCaptureEligibility().snapshot(for: wrongStatus))

        var duplicated = try eligibleTune(game: .fh6)
        let duplicate = try XCTUnwrap(duplicated.projectionReport?.fields.first)
        duplicated.projectionReport?.fields.append(duplicate)
        XCTAssertNil(TirePressureCaptureEligibility().snapshot(for: duplicated))
    }

    private func eligibleTune(game: ForzaGame) throws -> TuneResult {
        let catalog: CarCatalogSnapshot
        switch BundledCarCatalog.load() {
        case .success(let loaded):
            catalog = loaded
        case .failure(let error):
            throw error
        }
        let entry = try XCTUnwrap(catalog.entries.first { $0.game == game })
        let selection = catalog.selection(for: entry)
        let snapshot = selection.capabilityOnlyBuildSnapshot(
            capturedAt: Date(timeIntervalSinceReferenceDate: 42)
        )
        let fields: [TuneFieldProjection] = [
            TuneFieldProjection(
                field: .frontTirePressure,
                status: .needsConstraint,
                requiredPurchaseIDs: [],
                unresolvedPartIDs: [],
                reason: .missingProductionConstraint
            ),
            TuneFieldProjection(
                field: .rearTirePressure,
                status: .needsConstraint,
                requiredPurchaseIDs: [],
                unresolvedPartIDs: [],
                reason: .missingProductionConstraint
            )
        ]
        return TuneResult(
            request: TuneRequest(
                car: selection.carInput,
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
                contextStatus: .capabilityOnly,
                capabilityResolution: nil,
                fields: fields,
                purchasePlan: [],
                confirmations: [],
                diagnostics: []
            )
        )
    }
}
