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
        var capabilityOnly = good
        capabilityOnly.kind = .capabilityOnly
        capabilityOnly.tireCompound = nil
        capabilityOnly.gearCount = nil
        capabilityOnly.constraints = []
        capabilityOnly.evidenceSources = []
        var invalid = good
        invalid.schemaVersion += 1

        for rejected in [
            edited,
            manual,
            tune(snapshot: capabilityOnly),
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
            let source = try sourceSnapshot(for: selection)
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
            if game == .fh5 {
                XCTAssertEqual(
                    generated.purpose,
                    .fh5BuildPlan
                )
                XCTAssertTrue(generated.sections.isEmpty)
            }
        }
    }

}
