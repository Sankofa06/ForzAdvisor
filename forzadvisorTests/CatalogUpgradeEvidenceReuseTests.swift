//
//  CatalogUpgradeEvidenceReuseTests.swift
//  forzadvisorTests
//

import XCTest
@testable import forzadvisor

final class CatalogUpgradeEvidenceReuseTests: XCTestCase {
    private let resolver = CatalogUpgradeEvidenceReuseResolver()
    private let observedAt = Date(
        timeIntervalSinceReferenceDate: 900
    )

    func testOfferDerivesStrippedValidCurrentCatalogSnapshot()
        throws {
        let selection = try selection()
        var source = try sourceSnapshot(for: selection)
        source.capabilityProfile.stockAdjustableSettings = [
            StockAdjustableSetting(
                setting: .alignment,
                evidence: evidence(build: "current-build")
            )
        ]
        XCTAssertTrue(source.isValid)

        let offer = try XCTUnwrap(
            resolver.offer(
                for: selection,
                savedTunes: [tune(snapshot: source)]
            )
        )
        let derived = try XCTUnwrap(
            offer.makeSnapshot(
                for: selection,
                id: fixedUUID(99)
            )
        )

        XCTAssertEqual(offer.buildVersion, "current-build")
        XCTAssertEqual(offer.observedAt, observedAt)
        XCTAssertEqual(derived.kind, .capabilityOnly)
        XCTAssertEqual(derived.id, fixedUUID(99))
        XCTAssertEqual(derived.car, selection.carInput)
        XCTAssertEqual(
            derived.capabilityProfile.parts.map(\.partID),
            TunePartID.allCases
        )
        XCTAssertTrue(
            derived.capabilityProfile.stockAdjustableSettings.isEmpty
        )
        XCTAssertNil(derived.tireCompound)
        XCTAssertNil(derived.gearCount)
        XCTAssertTrue(derived.constraints.isEmpty)
        XCTAssertTrue(derived.evidenceSources.isEmpty)
        XCTAssertTrue(
            derived.isValid,
            "Unexpected issues: \(derived.validationIssues)"
        )
    }

    func testCapabilityOnlyUpgradeLabSourceOffersImmediateReuseForBothGames()
        throws {
        for game in ForzaGame.allCases {
            let selection = try selection(game: game)
            let source = try capabilityOnlySourceSnapshot(
                for: selection
            )

            XCTAssertEqual(source.kind, .capabilityOnly, game.rawValue)
            XCTAssertTrue(
                source.capabilityProfile.stockAdjustableSettings.isEmpty,
                game.rawValue
            )
            XCTAssertNil(source.tireCompound, game.rawValue)
            XCTAssertNil(source.gearCount, game.rawValue)
            XCTAssertTrue(source.constraints.isEmpty, game.rawValue)
            XCTAssertTrue(source.evidenceSources.isEmpty, game.rawValue)

            let offer = try XCTUnwrap(
                resolver.offer(
                    for: selection,
                    savedTunes: [tune(snapshot: source)]
                ),
                game.rawValue
            )
            let derived = try XCTUnwrap(
                offer.makeSnapshot(
                    for: selection,
                    id: fixedUUID(
                        game == .fh5 ? 51 : 61
                    )
                ),
                game.rawValue
            )

            XCTAssertEqual(
                offer.sourceSnapshotID,
                source.id,
                game.rawValue
            )
            XCTAssertNotEqual(derived.id, source.id, game.rawValue)
            XCTAssertEqual(derived.kind, .capabilityOnly, game.rawValue)
            XCTAssertEqual(
                derived.capabilityProfile.parts,
                source.capabilityProfile.parts,
                game.rawValue
            )
            XCTAssertTrue(
                derived.capabilityProfile.stockAdjustableSettings.isEmpty,
                game.rawValue
            )
            XCTAssertNil(derived.tireCompound, game.rawValue)
            XCTAssertNil(derived.gearCount, game.rawValue)
            XCTAssertTrue(derived.constraints.isEmpty, game.rawValue)
            XCTAssertTrue(derived.evidenceSources.isEmpty, game.rawValue)
        }
    }

    func testIdenticalDuplicatesChooseNewestDeterministically()
        throws {
        let selection = try selection()
        let older = try sourceSnapshot(
            for: selection,
            observedAt: observedAt
        )
        let newer = try sourceSnapshot(
            for: selection,
            observedAt: observedAt.addingTimeInterval(60)
        )
        let offer = try XCTUnwrap(
            resolver.offer(
                for: selection,
                savedTunes: [
                    tune(snapshot: newer),
                    tune(snapshot: older),
                    tune(snapshot: newer)
                ]
            )
        )

        XCTAssertEqual(offer.sourceSnapshotID, newer.id)
        XCTAssertEqual(offer.observedAt, newer.capturedAt)
    }

    func testConflictingBuildOrPartAvailabilityReturnsNoOffer()
        throws {
        let selection = try selection()
        let baseline = try sourceSnapshot(for: selection)
        let otherBuild = try sourceSnapshot(
            for: selection,
            build: "other-build"
        )
        var otherParts = baseline
        otherParts.capabilityProfile.parts[0].availability =
            .unavailable

        XCTAssertNil(
            resolver.offer(
                for: selection,
                savedTunes: [
                    tune(snapshot: baseline),
                    tune(snapshot: otherBuild)
                ]
            )
        )
        XCTAssertNil(
            resolver.offer(
                for: selection,
                savedTunes: [
                    tune(snapshot: baseline),
                    tune(snapshot: otherParts)
                ]
            )
        )
    }

    func testWrongIdentityRevisionAndUntrustedShapesFailClosed()
        throws {
        let selection = try selection()
        let good = try sourceSnapshot(for: selection)

        var edited = tune(snapshot: good)
        edited.request.car.weightPounds += 1
        var manual = tune(snapshot: good)
        manual.request.car.catalogReference = nil
        var invalid = good
        invalid.schemaVersion += 1

        for rejected in [
            edited,
            manual,
            tune(snapshot: invalid)
        ] {
            XCTAssertNil(
                resolver.offer(
                    for: selection,
                    savedTunes: [rejected]
                )
            )
        }

        let changedCatalog = CarCatalogSnapshot(
            schemaVersion: 1,
            revision: selection.reference.revision + "-new",
            reviewedAt: selection.reference.reviewedAt,
            entries: [selection.entry]
        )
        let changedSelection = changedCatalog.selection(
            for: selection.entry
        )
        XCTAssertNil(
            resolver.offer(
                for: changedSelection,
                savedTunes: [tune(snapshot: good)]
            )
        )
    }

    func testCapabilityOnlySourceRejectsAnyNonPartPayload()
        throws {
        let selection = try selection()
        let baseline = try capabilityOnlySourceSnapshot(
            for: selection
        )
        var variants: [VehicleBuildSnapshot] = []

        var stockSetting = baseline
        stockSetting.capabilityProfile.stockAdjustableSettings = [
            StockAdjustableSetting(
                setting: .alignment,
                evidence: evidence(build: "current-build")
            )
        ]
        variants.append(stockSetting)

        let provenance = TuneDataProvenance(
            id: "leaked-global-evidence",
            game: selection.entry.game,
            gameBuildVersion: "current-build",
            scope: .gameGlobal,
            source: "leaked-menu-source",
            version: "1",
            capturedAt: observedAt,
            confidence: .medium,
            usagePermission: .permitted
        )
        var tire = baseline
        tire.tireCompound = TireCompoundReference(
            id: "stock",
            displayName: "Stock",
            evidenceIDs: [provenance.id]
        )
        tire.evidenceSources = [provenance]
        variants.append(tire)

        var gears = baseline
        gears.gearCount = 6
        variants.append(gears)

        var constraint = baseline
        constraint.constraints = [
            TuneFieldConstraint(
                field: .frontTirePressure,
                minimum: 15,
                maximum: 40,
                step: 0.5,
                defaultValue: 30,
                currentValue: 30,
                unit: .psi,
                scope: .gameGlobal,
                verification: .productionEligible,
                evidenceIDs: [provenance.id]
            )
        ]
        constraint.evidenceSources = [provenance]
        variants.append(constraint)

        var evidenceSource = baseline
        evidenceSource.evidenceSources = [provenance]
        variants.append(evidenceSource)

        var wrongVehicle = baseline
        wrongVehicle.capabilityProfile.vehicle.model = "Wrong model"
        variants.append(wrongVehicle)

        var wrongDrivetrain = baseline
        wrongDrivetrain.capabilityProfile.drivetrain =
            selection.entry.stock.drivetrain == .awd
                ? .rwd
                : .awd
        variants.append(wrongDrivetrain)

        for variant in variants {
            XCTAssertNil(
                resolver.offer(
                    for: selection,
                    savedTunes: [tune(snapshot: variant)]
                )
            )
        }
    }

    func testIncompleteAndUntrustedPartFactsFailClosed()
        throws {
        let selection = try selection()
        let baseline = try sourceSnapshot(for: selection)
        var variants: [VehicleBuildSnapshot] = []

        var incomplete = baseline
        incomplete.capabilityProfile.parts.removeLast()
        variants.append(incomplete)
        var duplicate = baseline
        duplicate.capabilityProfile.parts.append(
            duplicate.capabilityProfile.parts[0]
        )
        variants.append(duplicate)
        for availability in [
            TunePartAvailability.installed,
            .unknown
        ] {
            var value = baseline
            value.capabilityProfile.parts[0].availability =
                availability
            variants.append(value)
        }
        for evidenceValue in [
            TuneEvidence(
                confidence: .medium,
                source: "wrong-source",
                version: "current-build",
                usagePermission: .permitted
            ),
            TuneEvidence(
                confidence: .low,
                source: UpgradePartCapture.provenanceSource,
                version: "current-build",
                usagePermission: .permitted
            ),
            TuneEvidence(
                confidence: .medium,
                source: UpgradePartCapture.provenanceSource,
                version: "current-build",
                usagePermission: .unknown
            ),
            evidence(build: "wrong-build")
        ] {
            var value = baseline
            value.capabilityProfile.parts[0].evidence =
                evidenceValue
            variants.append(value)
        }

        for variant in variants {
            XCTAssertNil(
                resolver.offer(
                    for: selection,
                    savedTunes: [tune(snapshot: variant)]
                )
            )
        }
    }

    func testInputOriginRequiresExplicitValidReuseAndFallsBack()
        throws {
        let selection = try selection()
        let offer = try XCTUnwrap(
            resolver.offer(
                for: selection,
                savedTunes: [
                    tune(
                        snapshot: try sourceSnapshot(
                            for: selection
                        )
                    )
                ]
            )
        )
        let reuse = try XCTUnwrap(
            offer.makeSnapshot(for: selection)
        )
        let explicit = try XCTUnwrap(
            InputOrigin.catalog(
                selection,
                reusedUpgradeSnapshot: reuse
            ).buildSnapshot(matching: selection.carInput)
        )
        XCTAssertEqual(explicit, reuse)

        let ordinary = try XCTUnwrap(
            InputOrigin.catalog(selection).buildSnapshot(
                matching: selection.carInput
            )
        )
        XCTAssertTrue(ordinary.capabilityProfile.parts.isEmpty)

        var invalidReuse = reuse
        invalidReuse.capabilityProfile.parts.removeLast()
        let fallback = try XCTUnwrap(
            InputOrigin.catalog(
                selection,
                reusedUpgradeSnapshot: invalidReuse
            ).buildSnapshot(matching: selection.carInput)
        )
        XCTAssertTrue(fallback.capabilityProfile.parts.isEmpty)
        XCTAssertNotEqual(fallback.id, invalidReuse.id)
    }

    func testReusedPartsRestoreExactPathsForBothGames()
        async throws {
        for game in ForzaGame.allCases {
            let selection = try selection(game: game)
            let source = try capabilityOnlySourceSnapshot(
                for: selection
            )
            let offer = try XCTUnwrap(
                resolver.offer(
                    for: selection,
                    savedTunes: [tune(snapshot: source)]
                )
            )
            let reuse = try XCTUnwrap(
                offer.makeSnapshot(for: selection)
            )
            let request = TuneRequest(
                car: selection.carInput,
                discipline: .road,
                buildSnapshot: reuse
            )
            let generated = try await
                CapabilityProjectingTuneProvider(
                    base: CompositeTuneProvider()
                ).generateTune(for: request)
            let paths = TuneControlUpgradePlanner().paths(
                for: generated
            )

            XCTAssertEqual(paths.count, 3, game.rawValue)
            XCTAssertTrue(generated.sections.isEmpty, game.rawValue)
            XCTAssertEqual(
                generated.projectionReport?.readyCount,
                0,
                game.rawValue
            )
            if game == .fh5 {
                XCTAssertEqual(
                    generated.purpose,
                    .fh5BuildPlan
                )
            } else {
                XCTAssertEqual(
                    generated.purpose,
                    .numericTune
                )
            }
        }
    }

}
