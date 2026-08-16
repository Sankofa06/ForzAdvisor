//
//  LegacyCatalogCompatibilityTests.swift
//  forzadvisorTests
//
//  Persisted-boundary coverage for legacy catalog lineage and input origins.
//

import SwiftData
import XCTest
@testable import forzadvisor

@MainActor
final class LegacyCatalogCompatibilityTests: XCTestCase {
    private let reviewedAt = Date(timeIntervalSinceReferenceDate: 42)

    func testSyntheticSelectionMapsGameSpecificValuesAndCopiesLineage() {
        let expectedPerformanceIndex: [ForzaGame: Int] = [
            .fh5: 750,
            .fh6: 700
        ]

        for game in ForzaGame.allCases {
            let selection = catalogSelection(game: game)
            let car = selection.carInput

            XCTAssertEqual(car.game, game)
            XCTAssertEqual(car.performanceClass, .a)
            XCTAssertEqual(
                car.performanceIndex,
                expectedPerformanceIndex[game]
            )
            XCTAssertEqual(car.catalogReference, selection.reference)
            XCTAssertFalse(car.catalogValuesModified)
            XCTAssertEqual(selection.reference.entryID, selection.entry.id)
            XCTAssertEqual(selection.reference.revision, "test-only-fixture-v1")
            XCTAssertEqual(selection.reference.reviewedAt, reviewedAt)
            XCTAssertEqual(
                selection.reference.verificationStatus,
                selection.entry.verificationStatus
            )
            XCTAssertEqual(
                selection.reference.sources,
                selection.entry.sources
            )
        }
    }

    func testUntouchedLegacyCatalogOriginCreatesCapabilityOnlyUnknownBuildSnapshot()
        throws {
        let selection = catalogSelection()
        let capturedAt = Date(timeIntervalSinceReferenceDate: 84)

        let snapshot = try XCTUnwrap(
            InputOrigin.catalog(selection).buildSnapshot(
                matching: selection.carInput,
                capturedAt: capturedAt
            )
        )

        XCTAssertEqual(snapshot.kind, .capabilityOnly)
        XCTAssertEqual(snapshot.capturedAt, capturedAt)
        XCTAssertEqual(snapshot.car, selection.carInput)
        XCTAssertEqual(snapshot.inputFactsSource, .reviewedCatalog)
        XCTAssertEqual(
            snapshot.capabilityProfile,
            selection.entry.capabilityProfile
        )
        XCTAssertNil(snapshot.gameBuild.version)
        XCTAssertNil(snapshot.gameBuild.capturedAt)
        XCTAssertTrue(snapshot.constraints.isEmpty)
        XCTAssertTrue(snapshot.evidenceSources.isEmpty)
        XCTAssertTrue(
            snapshot.isValid,
            "Unexpected issues: \(snapshot.validationIssues)"
        )
    }

    func testMismatchedCatalogAndUnconfirmedOCROriginsDoNotCreateSnapshots() {
        let selection = catalogSelection()
        var edited = selection.carInput
        edited.weightPounds += 1

        XCTAssertNil(
            InputOrigin.catalog(selection).buildSnapshot(matching: edited)
        )
        XCTAssertNotNil(
            InputOrigin.manual(selection.carInput).buildSnapshot(
                matching: selection.carInput
            )
        )
        XCTAssertNil(
            InputOrigin.ocr(OCRConfirmationDraft()).buildSnapshot(
                matching: selection.carInput
            )
        )
    }

    func testRetryAndRetunePreserveOnlyMatchingSnapshot() throws {
        let selection = catalogSelection()
        let preserved = selection.capabilityOnlyBuildSnapshot(
            capturedAt: reviewedAt
        )
        let manualOrigin = InputOrigin.manual(selection.carInput)

        XCTAssertEqual(
            manualOrigin.resolvedBuildSnapshot(
                matching: selection.carInput,
                preserving: preserved
            ),
            preserved
        )

        var edited = selection.carInput
        edited.peakHorsepower = (edited.peakHorsepower ?? 0) + 1
        XCTAssertNil(
            manualOrigin.resolvedBuildSnapshot(
                matching: edited,
                preserving: preserved
            )
        )

        var invalid = preserved
        invalid.kind = .exactBuildObservation
        XCTAssertFalse(invalid.isValid)
        let recoveryCapturedAt = Date(
            timeIntervalSinceReferenceDate: 105
        )
        let rebuilt = try XCTUnwrap(
            manualOrigin.resolvedBuildSnapshot(
                matching: selection.carInput,
                preserving: invalid,
                capturedAt: recoveryCapturedAt
            )
        )
        XCTAssertNotEqual(rebuilt.id, invalid.id)
        XCTAssertEqual(rebuilt.kind, .capabilityOnly)
        XCTAssertEqual(rebuilt.capturedAt, recoveryCapturedAt)
        XCTAssertEqual(rebuilt.inputFactsSource, .reviewedCatalog)
        XCTAssertTrue(rebuilt.matches(car: selection.carInput))

        let fallbackCapturedAt = Date(timeIntervalSinceReferenceDate: 126)
        let catalogFallback = try XCTUnwrap(
            InputOrigin.catalog(selection).resolvedBuildSnapshot(
                matching: selection.carInput,
                preserving: nil,
                capturedAt: fallbackCapturedAt
            )
        )
        XCTAssertEqual(catalogFallback.kind, .capabilityOnly)
        XCTAssertEqual(catalogFallback.capturedAt, fallbackCapturedAt)
    }

    func testLegacyCarInputDecodesWithoutCatalogLineage() throws {
        let payload = """
        {
          "game": "fh5",
          "year": 2020,
          "make": "Toyota",
          "model": "GR Supra",
          "weightPounds": 3397,
          "frontWeightPercent": 51,
          "performanceIndex": 731,
          "performanceClass": "A",
          "drivetrain": "RWD",
          "peakHorsepower": 335,
          "peakTorqueFootPounds": 365
        }
        """

        let car = try JSONDecoder().decode(
            CarInput.self,
            from: Data(payload.utf8)
        )
        XCTAssertNil(car.catalogReference)
        XCTAssertFalse(car.catalogValuesModified)
    }

    func testCarInputLineageSurvivesCodableRoundTrip() throws {
        var car = catalogCar()
        car.weightPounds += 1
        let decoded = try roundTrip(car)

        XCTAssertEqual(decoded, car)
        XCTAssertEqual(decoded.catalogReference, car.catalogReference)
        XCTAssertTrue(decoded.catalogValuesModified)
    }

    func testEveryIdentityMutationClearsLineage() {
        var original = catalogCar()
        original.weightPounds += 1
        XCTAssertTrue(original.catalogValuesModified)

        var changedGame = original
        changedGame.game = .fh5
        assertLineageCleared(changedGame)

        var changedYear = original
        changedYear.year = 2021
        assertLineageCleared(changedYear)

        var changedMake = original
        changedMake.make = "BMW"
        assertLineageCleared(changedMake)

        var changedModel = original
        changedModel.model = "M3"
        assertLineageCleared(changedModel)
    }

    func testEveryStockStatMutationPreservesLineage() throws {
        let original = catalogCar()
        let reference = try XCTUnwrap(original.catalogReference)

        var weight = original
        weight.weightPounds += 1
        assertEdited(weight, reference: reference)

        var frontWeight = original
        frontWeight.frontWeightPercent += 1
        assertEdited(frontWeight, reference: reference)

        var performanceIndex = original
        performanceIndex.performanceIndex += 1
        assertEdited(performanceIndex, reference: reference)

        var performanceClass = original
        performanceClass.performanceClass = .s1
        assertEdited(performanceClass, reference: reference)

        var drivetrain = original
        drivetrain.drivetrain = .awd
        assertEdited(drivetrain, reference: reference)

        var horsepower = original
        horsepower.peakHorsepower = 400
        assertEdited(horsepower, reference: reference)

        var torque = original
        torque.peakTorqueFootPounds = 410
        assertEdited(torque, reference: reference)
    }

    func testManualDraftPreservesLineageForStatsAndClearsItForIdentity()
        throws {
        let original = catalogCar()
        let reference = try XCTUnwrap(original.catalogReference)
        var draft = ManualEntryDraft(car: original)

        XCTAssertEqual(draft.catalogReference, reference)
        XCTAssertFalse(draft.catalogValuesModified)
        draft.weightPounds = 3_500
        draft.performanceIndex = 650
        XCTAssertEqual(draft.catalogReference, reference)
        XCTAssertTrue(draft.catalogValuesModified)
        XCTAssertEqual(
            draft.confirmedCarInput()?.catalogReference,
            reference
        )
        XCTAssertTrue(
            draft.confirmedCarInput()?.catalogValuesModified == true
        )

        draft.model = "Edited Identity"
        XCTAssertNil(draft.catalogReference)
        XCTAssertFalse(draft.catalogValuesModified)
        XCTAssertNil(draft.confirmedCarInput()?.catalogReference)
        XCTAssertFalse(
            draft.confirmedCarInput()?.catalogValuesModified == true
        )
    }

    func testCapabilitySnapshotInventsNoUpgradeAvailability() {
        let selection = catalogSelection()
        let snapshot = selection.capabilityOnlyBuildSnapshot(
            capturedAt: reviewedAt
        )
        let profile = snapshot.capabilityProfile

        XCTAssertTrue(profile.parts.isEmpty)
        XCTAssertTrue(profile.stockAdjustableSettings.isEmpty)

        let result = TuneCapabilityResolver(game: selection.entry.game)
            .resolve(profile: profile)
        XCTAssertEqual(
            capability(.tirePressure, in: result).status,
            .stockAvailable
        )
        XCTAssertEqual(
            capability(.differentialCenter, in: result).status,
            .unavailable
        )
        for setting in TuneSetting.allCases
        where setting != .tirePressure
            && setting != .differentialCenter {
            XCTAssertEqual(
                capability(setting, in: result).status,
                .unknown,
                setting.rawValue
            )
        }
        XCTAssertTrue(result.requiredPurchases.isEmpty)
    }

    func testSwiftDataSaveUpdateAndReopenPreserveCatalogLineage()
        throws {
        let container = try ModelContainer(
            for: SavedTune.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let writeContext = ModelContext(container)
        var car = catalogCar()
        let originalReference = try XCTUnwrap(car.catalogReference)
        var tune = makeTune(car: car)
        let saved = try SavedTune(tune: tune)
        writeContext.insert(saved)
        try writeContext.save()

        XCTAssertEqual(saved.carInput?.catalogReference, originalReference)

        car.weightPounds += 10
        XCTAssertTrue(car.catalogValuesModified)
        tune.request.car = car
        try saved.update(with: tune)
        try writeContext.save()

        let reopenContext = ModelContext(container)
        let reopened = try XCTUnwrap(
            reopenContext.fetch(FetchDescriptor<SavedTune>()).first
        )
        XCTAssertEqual(
            reopened.tuneResult?.request.car.catalogReference,
            originalReference
        )
        XCTAssertEqual(reopened.carInput?.catalogReference, originalReference)
        XCTAssertEqual(reopened.carInput?.weightPounds, car.weightPounds)
        XCTAssertTrue(reopened.carInput?.catalogValuesModified == true)
    }

    private func catalogSelection(
        game: ForzaGame = .fh6
    ) -> CatalogCarSelection {
        SyntheticLegacyTuneFixtureFactory.selection(
            game: game,
            reviewedAt: reviewedAt
        )
    }

    private func catalogCar() -> CarInput {
        catalogSelection().carInput
    }

    private func roundTrip(_ car: CarInput) throws -> CarInput {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(CarInput.self, from: encoder.encode(car))
    }

    private func assertLineageCleared(
        _ car: CarInput,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertNil(car.catalogReference, file: file, line: line)
        XCTAssertFalse(car.catalogValuesModified, file: file, line: line)
    }

    private func assertEdited(
        _ car: CarInput,
        reference: CatalogCarReference,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(
            car.catalogReference,
            reference,
            file: file,
            line: line
        )
        XCTAssertTrue(
            car.catalogValuesModified,
            file: file,
            line: line
        )
    }

    private func makeTune(car: CarInput) -> TuneResult {
        TuneResult(
            request: TuneRequest(car: car, discipline: .road),
            sections: [],
            notes: TuneNotes(
                bias: "Catalog compatibility test.",
                ifPushesWide: "Test.",
                ifSnapsOnLift: "Test.",
                retuneTrigger: "Test."
            )
        )
    }

    private func capability(
        _ setting: TuneSetting,
        in resolution: TuneCapabilityResolution,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> TuneSettingCapability {
        guard let capability = resolution.settings.first(where: {
            $0.setting == setting
        }) else {
            XCTFail(
                "Missing capability \(setting.rawValue)",
                file: file,
                line: line
            )
            return TuneSettingCapability(
                setting: setting,
                status: .unknown,
                requirement: nil,
                requiredPurchaseIDs: [],
                unresolvedPartIDs: [],
                evidence: []
            )
        }
        return capability
    }
}
