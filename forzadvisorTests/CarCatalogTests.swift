//
//  CarCatalogTests.swift
//  forzadvisorTests
//
//  Contract coverage for bundled values, provenance, lineage, and safe loading.
//

import SwiftData
import XCTest
@testable import forzadvisor

@MainActor
final class CarCatalogTests: XCTestCase {
    func testFH5CatalogReviewExplainsProviderIndependentPlanOnlyBehavior() {
        XCTAssertEqual(
            CarCatalogReviewView.fh5PlanOnlyMessage,
            "FH5 uses a provider-independent local build planner. It creates upgrade paths only and does not generate numeric tuning settings."
        )
        XCTAssertFalse(CarCatalogReviewView.fh5PlanOnlyMessage.contains("Settings"))
    }

    func testRealBundleLoadsVersionedCatalogResource() throws {
        let snapshot = try loadedSnapshot()

        XCTAssertEqual(snapshot.schemaVersion, 1)
        XCTAssertEqual(snapshot.revision, "2026.07.23.1")
        XCTAssertEqual(snapshot.reviewedAt, try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-07-23T00:00:00Z")))
    }

    func testCatalogContainsExactElevenGameScopedStockRecords() throws {
        let snapshot = try loadedSnapshot()
        XCTAssertEqual(snapshot.entries.count, 11)
        XCTAssertEqual(Set(snapshot.entries.map(\.id)).count, 11)
        XCTAssertEqual(snapshot.entries.filter { $0.game == .fh5 }.count, 3)
        XCTAssertEqual(snapshot.entries.filter { $0.game == .fh6 }.count, 8)

        let expected: [String: ExpectedCar] = [
            "fh5-2020-toyota-gr-supra": ExpectedCar(.fh5, 2020, "Toyota", "GR Supra", .a, 731, .rwd, 3_397, 51, 335, 365),
            "fh5-2022-subaru-brz": ExpectedCar(.fh5, 2022, "Subaru", "BRZ", .b, 673, .rwd, 2_835, 53, 228, 184),
            "fh5-2018-porsche-911-gt2-rs": ExpectedCar(.fh5, 2018, "Porsche", "911 GT2 RS", .s1, 888, .rwd, 3_197, 40, 691, 553),
            "fh6-2020-toyota-gr-supra": ExpectedCar(.fh6, 2020, "Toyota", "GR Supra", .a, 616, .rwd, 3_397, 51, 335, 365),
            "fh6-2022-subaru-brz": ExpectedCar(.fh6, 2022, "Subaru", "BRZ", .b, 551, .rwd, 2_835, 53, 228, 184),
            "fh6-2018-porsche-911-gt2-rs": ExpectedCar(.fh6, 2018, "Porsche", "911 GT2 RS", .s2, 803, .rwd, 3_197, 40, 691, 553),
            "fh6-1985-toyota-sprinter-trueno-gt-apex": ExpectedCar(.fh6, 1985, "Toyota", "Sprinter Trueno GT Apex", .d, 376, .rwd, 2_094, 53, 128, 110),
            "fh6-1998-toyota-supra-rz": ExpectedCar(.fh6, 1998, "Toyota", "Supra RZ", .b, 529, .rwd, 3_329, 53, 320, 315),
            "fh6-1992-honda-nsx-r": ExpectedCar(.fh6, 1992, "Honda", "NSX-R", .b, 572, .rwd, 2_712, 42, 276, 217),
            "fh6-2017-nissan-gt-r-r35": ExpectedCar(.fh6, 2017, "Nissan", "GT-R (R35)", .s1, 709, .awd, 3_933, 54, 565, 467),
            "fh6-2022-toyota-gr86": ExpectedCar(.fh6, 2022, "Toyota", "GR86", .b, 556, .rwd, 2_811, 53, 228, 184)
        ]

        for entry in snapshot.entries {
            XCTAssertEqual(ExpectedCar(entry), expected[entry.id], entry.id)
        }
    }

    func testEveryEntryHasHonestHTTPSSourceRolesAndFieldCoverage() throws {
        let snapshot = try loadedSnapshot()
        let allFields = Set(CatalogDataField.allCases)

        for entry in snapshot.entries {
            XCTAssertEqual(Set(entry.sources.map(\.id)), ["official", "wiki", "forzalabs"])
            XCTAssertTrue(entry.sources.allSatisfy { $0.url.scheme == "https" })
            XCTAssertTrue(entry.sources.contains { $0.role == .officialRoster })
            XCTAssertTrue(entry.sources.contains { $0.role == .communityQA })
            XCTAssertEqual(Set(entry.sources.flatMap(\.fields)), allFields)

            let official = try XCTUnwrap(entry.sources.first { $0.id == "official" })
            let wiki = try XCTUnwrap(entry.sources.first { $0.id == "wiki" })
            let labs = try XCTUnwrap(entry.sources.first { $0.id == "forzalabs" })
            XCTAssertEqual(wiki.fields, CatalogDataField.allCases)

            if entry.game == .fh5 {
                XCTAssertEqual(official.url.absoluteString, "https://forza.net/fh5cars/")
                XCTAssertEqual(official.fields, [.identity])
                XCTAssertFalse(labs.fields.contains(.performanceIndex))
                XCTAssertFalse(labs.fields.contains(.performanceClass))
            } else {
                XCTAssertEqual(official.url.absoluteString, "https://forza.net/fh6cars")
                XCTAssertEqual(official.fields, [.identity, .performanceIndex, .performanceClass])
                XCTAssertTrue(labs.fields.contains(.performanceIndex))
                XCTAssertTrue(labs.fields.contains(.performanceClass))
            }
        }
    }

    func testSearchIsTrimmedCaseAndDiacriticInsensitiveAndGameScoped() throws {
        let snapshot = try loadedSnapshot()

        XCTAssertEqual(
            BundledCarCatalog.search(snapshot, game: .fh6, query: "  sUpRa ").map(\.id),
            ["fh6-2020-toyota-gr-supra", "fh6-1998-toyota-supra-rz"]
        )
        XCTAssertEqual(
            BundledCarCatalog.search(snapshot, game: .fh5, query: " PÓRSCHE ").map(\.id),
            ["fh5-2018-porsche-911-gt2-rs"]
        )
        XCTAssertEqual(
            BundledCarCatalog.search(snapshot, game: .fh6, query: "  trueno ").map(\.id),
            ["fh6-1985-toyota-sprinter-trueno-gt-apex"]
        )
        XCTAssertEqual(
            BundledCarCatalog.search(snapshot, game: .fh6, query: " GT-R ").map(\.id),
            ["fh6-2017-nissan-gt-r-r35"]
        )
        XCTAssertTrue(BundledCarCatalog.search(snapshot, game: .fh6, query: "1997 RX-7").isEmpty)
        XCTAssertTrue(
            BundledCarCatalog.search(
                snapshot,
                game: .fh6,
                query: "2002 Skyline GT-R V-Spec II"
            ).isEmpty
        )
        XCTAssertEqual(BundledCarCatalog.search(snapshot, game: .fh6, query: "").count, 8)
        XCTAssertEqual(BundledCarCatalog.search(snapshot, game: .fh5, query: "").count, 3)
    }

    func testSelectionMapsGameSpecificValuesAndCopiesLineage() throws {
        let snapshot = try loadedSnapshot()
        let entry = try XCTUnwrap(snapshot.entries.first { $0.id == "fh6-2020-toyota-gr-supra" })
        let selection = snapshot.selection(for: entry)
        let car = selection.carInput

        XCTAssertEqual(car.game, .fh6)
        XCTAssertEqual(car.performanceClass, .a)
        XCTAssertEqual(car.performanceIndex, 616)
        XCTAssertEqual(car.catalogReference, selection.reference)
        XCTAssertFalse(car.catalogValuesModified)
        XCTAssertEqual(selection.reference.entryID, entry.id)
        XCTAssertEqual(selection.reference.sources, entry.sources)
    }

    func testEveryFH6CatalogCarGeneratesOfflineTuneAcrossAllDisciplines() async throws {
        let snapshot = try loadedSnapshot()
        let provider = LocalSampleTuneProvider()

        for entry in snapshot.entries.filter({ $0.game == .fh6 }) {
            let car = snapshot.selection(for: entry).carInput

            for discipline in DrivingDiscipline.allCases {
                let tune = try await provider.generateTune(
                    for: TuneRequest(car: car, discipline: discipline)
                )

                XCTAssertEqual(tune.request.car, car, "\(entry.id) · \(discipline.rawValue)")
                XCTAssertEqual(tune.request.discipline, discipline, entry.id)
                XCTAssertEqual(tune.purpose, .numericTune, entry.id)
                XCTAssertFalse(tune.sections.isEmpty, entry.id)
                XCTAssertTrue(
                    tune.sections
                        .flatMap(\.lines)
                        .compactMap(\.numericValue)
                        .allSatisfy(\.isFinite),
                    "\(entry.id) · \(discipline.rawValue)"
                )
            }
        }
    }

    func testUntouchedCatalogOriginCreatesCapabilityOnlyUnknownBuildSnapshot() throws {
        let catalog = try loadedSnapshot()
        let entry = try XCTUnwrap(catalog.entries.first { $0.id == "fh6-2020-toyota-gr-supra" })
        let selection = catalog.selection(for: entry)
        let capturedAt = Date(timeIntervalSinceReferenceDate: 42)

        let snapshot = try XCTUnwrap(
            InputOrigin.catalog(selection).buildSnapshot(matching: selection.carInput, capturedAt: capturedAt)
        )

        XCTAssertEqual(snapshot.kind, .capabilityOnly)
        XCTAssertEqual(snapshot.capturedAt, capturedAt)
        XCTAssertEqual(snapshot.car, selection.carInput)
        XCTAssertEqual(snapshot.capabilityProfile, entry.capabilityProfile)
        XCTAssertNil(snapshot.gameBuild.version)
        XCTAssertNil(snapshot.gameBuild.capturedAt)
        XCTAssertTrue(snapshot.constraints.isEmpty)
        XCTAssertTrue(snapshot.evidenceSources.isEmpty)
        XCTAssertTrue(snapshot.isValid, "Unexpected issues: \(snapshot.validationIssues)")
    }

    func testEditedCatalogManualAndOCROriginsDoNotCreateSnapshots() throws {
        let catalog = try loadedSnapshot()
        let entry = try XCTUnwrap(catalog.entries.first { $0.id == "fh6-2020-toyota-gr-supra" })
        let selection = catalog.selection(for: entry)
        var edited = selection.carInput
        edited.weightPounds += 1

        XCTAssertNil(InputOrigin.catalog(selection).buildSnapshot(matching: edited))
        XCTAssertNil(InputOrigin.manual(selection.carInput).buildSnapshot(matching: selection.carInput))
        XCTAssertNil(InputOrigin.ocr(OCRConfirmationDraft()).buildSnapshot(matching: selection.carInput))
    }

    func testRetryAndRetunePreserveOnlyMatchingSnapshot() throws {
        let catalog = try loadedSnapshot()
        let entry = try XCTUnwrap(catalog.entries.first { $0.id == "fh6-2020-toyota-gr-supra" })
        let selection = catalog.selection(for: entry)
        let preserved = selection.capabilityOnlyBuildSnapshot(
            capturedAt: Date(timeIntervalSinceReferenceDate: 42)
        )
        let manualOrigin = InputOrigin.manual(selection.carInput)

        XCTAssertEqual(
            manualOrigin.resolvedBuildSnapshot(matching: selection.carInput, preserving: preserved),
            preserved
        )

        var edited = selection.carInput
        edited.peakHorsepower = (edited.peakHorsepower ?? 0) + 1
        XCTAssertNil(manualOrigin.resolvedBuildSnapshot(matching: edited, preserving: preserved))

        var invalid = preserved
        invalid.kind = .exactBuildObservation
        XCTAssertFalse(invalid.isValid)
        XCTAssertNil(
            manualOrigin.resolvedBuildSnapshot(matching: selection.carInput, preserving: invalid)
        )

        let catalogFallback = try XCTUnwrap(
            InputOrigin.catalog(selection).resolvedBuildSnapshot(
                matching: selection.carInput,
                preserving: nil,
                capturedAt: Date(timeIntervalSinceReferenceDate: 84)
            )
        )
        XCTAssertEqual(catalogFallback.kind, .capabilityOnly)
        XCTAssertEqual(catalogFallback.capturedAt, Date(timeIntervalSinceReferenceDate: 84))
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

        let car = try JSONDecoder().decode(CarInput.self, from: Data(payload.utf8))
        XCTAssertNil(car.catalogReference)
        XCTAssertFalse(car.catalogValuesModified)
    }

    func testCarInputLineageSurvivesCodableRoundTrip() throws {
        var car = try catalogCar()
        car.weightPounds += 1
        let decoded = try roundTrip(car)

        XCTAssertEqual(decoded, car)
        XCTAssertEqual(decoded.catalogReference, car.catalogReference)
        XCTAssertTrue(decoded.catalogValuesModified)
    }

    func testEveryIdentityMutationClearsLineage() throws {
        var original = try catalogCar()
        original.weightPounds += 1
        XCTAssertTrue(original.catalogValuesModified)

        var changedGame = original
        changedGame.game = .fh5
        XCTAssertNil(changedGame.catalogReference)
        XCTAssertFalse(changedGame.catalogValuesModified)

        var changedYear = original
        changedYear.year = 2021
        XCTAssertNil(changedYear.catalogReference)
        XCTAssertFalse(changedYear.catalogValuesModified)

        var changedMake = original
        changedMake.make = "BMW"
        XCTAssertNil(changedMake.catalogReference)
        XCTAssertFalse(changedMake.catalogValuesModified)

        var changedModel = original
        changedModel.model = "M3"
        XCTAssertNil(changedModel.catalogReference)
        XCTAssertFalse(changedModel.catalogValuesModified)
    }

    func testEveryStockStatMutationPreservesLineage() throws {
        let original = try catalogCar()
        let reference = try XCTUnwrap(original.catalogReference)

        var weight = original
        weight.weightPounds += 1
        assertEdited(weight, reference: reference)

        var frontWeight = original
        frontWeight.frontWeightPercent += 1
        assertEdited(frontWeight, reference: reference)

        var pi = original
        pi.performanceIndex += 1
        assertEdited(pi, reference: reference)

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

    func testManualDraftPreservesLineageForStatsAndClearsItForIdentity() throws {
        let original = try catalogCar()
        let reference = try XCTUnwrap(original.catalogReference)
        var draft = ManualEntryDraft(car: original)

        XCTAssertEqual(draft.catalogReference, reference)
        XCTAssertFalse(draft.catalogValuesModified)
        draft.weightPounds = 3_500
        draft.performanceIndex = 650
        XCTAssertEqual(draft.catalogReference, reference)
        XCTAssertTrue(draft.catalogValuesModified)
        XCTAssertEqual(draft.confirmedCarInput()?.catalogReference, reference)
        XCTAssertTrue(draft.confirmedCarInput()?.catalogValuesModified == true)

        draft.model = "Edited Identity"
        XCTAssertNil(draft.catalogReference)
        XCTAssertFalse(draft.catalogValuesModified)
        XCTAssertNil(draft.confirmedCarInput()?.catalogReference)
        XCTAssertFalse(draft.confirmedCarInput()?.catalogValuesModified == true)
    }

    func testCatalogCapabilityProfileInventsNoUpgradeAvailability() throws {
        let snapshot = try loadedSnapshot()
        let entry = try XCTUnwrap(snapshot.entries.first)
        XCTAssertTrue(entry.capabilityProfile.parts.isEmpty)
        XCTAssertTrue(entry.capabilityProfile.stockAdjustableSettings.isEmpty)

        let result = TuneCapabilityResolver(game: entry.game).resolve(profile: entry.capabilityProfile)
        XCTAssertEqual(capability(.tirePressure, in: result).status, .stockAvailable)
        XCTAssertEqual(capability(.differentialCenter, in: result).status, .unavailable)
        for setting in TuneSetting.allCases
        where setting != .tirePressure && setting != .differentialCenter {
            XCTAssertEqual(capability(setting, in: result).status, .unknown, setting.rawValue)
        }
        XCTAssertTrue(result.requiredPurchases.isEmpty)
    }

    func testSwiftDataSaveUpdateAndReopenPreserveCatalogLineage() throws {
        let container = try ModelContainer(
            for: SavedTune.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        var car = try catalogCar()
        let originalReference = try XCTUnwrap(car.catalogReference)
        var tune = makeTune(car: car)
        let saved = try SavedTune(tune: tune)
        context.insert(saved)
        try context.save()

        XCTAssertEqual(saved.carInput?.catalogReference, originalReference)

        car.weightPounds += 10
        XCTAssertTrue(car.catalogValuesModified)
        tune.request.car = car
        try saved.update(with: tune)
        try context.save()

        let reopened = try XCTUnwrap(context.fetch(FetchDescriptor<SavedTune>()).first)
        XCTAssertEqual(reopened.tuneResult?.request.car.catalogReference, originalReference)
        XCTAssertEqual(reopened.carInput?.catalogReference, originalReference)
        XCTAssertEqual(reopened.carInput?.weightPounds, car.weightPounds)
        XCTAssertTrue(reopened.carInput?.catalogValuesModified == true)
    }

    func testCorruptDuplicateUnsupportedAndMissingResourcesFailSafely() throws {
        XCTAssertEqual(BundledCarCatalog.load(data: Data("not json".utf8)), .failure(.decodingFailed))

        let valid = try loadedSnapshot()
        let unsupported = CarCatalogSnapshot(
            schemaVersion: 2,
            revision: valid.revision,
            reviewedAt: valid.reviewedAt,
            entries: valid.entries
        )
        XCTAssertEqual(
            BundledCarCatalog.load(data: try encoded(unsupported)),
            .failure(.unsupportedSchemaVersion(2))
        )

        let first = try XCTUnwrap(valid.entries.first)
        let duplicate = CarCatalogSnapshot(
            schemaVersion: 1,
            revision: valid.revision,
            reviewedAt: valid.reviewedAt,
            entries: [first, first]
        )
        XCTAssertEqual(
            BundledCarCatalog.load(data: try encoded(duplicate)),
            .failure(.duplicateEntryID(first.id))
        )

        XCTAssertEqual(
            BundledCarCatalog.load(bundle: Bundle(for: MissingCatalogBundleToken.self), resourceName: "MissingCatalog"),
            .failure(.missingResource("MissingCatalog"))
        )
    }

    func testValidationRejectsEmptyInvalidPrefixInvalidValuesAndBadProvenance() throws {
        let valid = try loadedSnapshot()
        let entry = try XCTUnwrap(valid.entries.first)

        XCTAssertEqual(
            BundledCarCatalog.load(data: try encoded(snapshot(entries: [], basedOn: valid))),
            .failure(.emptyCatalog)
        )

        let wrongPrefix = replacing(entry, id: "fh6-wrong-prefix")
        XCTAssertEqual(
            BundledCarCatalog.load(data: try encoded(snapshot(entries: [wrongPrefix], basedOn: valid))),
            .failure(.mismatchedIDPrefix(wrongPrefix.id))
        )

        let invalidStock = CatalogStockSpecifications(
            performanceIndex: entry.stock.performanceIndex,
            performanceClass: entry.stock.performanceClass,
            drivetrain: entry.stock.drivetrain,
            weightPounds: 1,
            frontWeightPercent: entry.stock.frontWeightPercent,
            peakHorsepower: entry.stock.peakHorsepower,
            peakTorqueFootPounds: entry.stock.peakTorqueFootPounds
        )
        let invalid = replacing(entry, stock: invalidStock)
        XCTAssertEqual(
            BundledCarCatalog.load(data: try encoded(snapshot(entries: [invalid], basedOn: valid))),
            .failure(.invalidCarInput(invalid.id))
        )

        let missingSources = replacing(entry, sources: [])
        XCTAssertEqual(
            BundledCarCatalog.load(data: try encoded(snapshot(entries: [missingSources], basedOn: valid))),
            .failure(.missingProvenance(missingSources.id))
        )

        let httpURL = try XCTUnwrap(URL(string: "http://example.com/car"))
        var badSources = entry.sources
        let firstSource = badSources.removeFirst()
        badSources.insert(
            CatalogSource(
                id: firstSource.id,
                title: firstSource.title,
                url: httpURL,
                role: firstSource.role,
                fields: firstSource.fields
            ),
            at: 0
        )
        let nonHTTPS = replacing(entry, sources: badSources)
        XCTAssertEqual(
            BundledCarCatalog.load(data: try encoded(snapshot(entries: [nonHTTPS], basedOn: valid))),
            .failure(.invalidSource(nonHTTPS.id, firstSource.id))
        )

        let uncoveredSources = entry.sources.map { source in
            CatalogSource(
                id: source.id,
                title: source.title,
                url: source.url,
                role: source.role,
                fields: source.fields.filter { $0 != .peakTorqueFootPounds }
            )
        }
        let uncovered = replacing(entry, sources: uncoveredSources)
        XCTAssertEqual(
            BundledCarCatalog.load(data: try encoded(snapshot(entries: [uncovered], basedOn: valid))),
            .failure(.uncoveredField(uncovered.id, .peakTorqueFootPounds))
        )
    }

    func testValidationRejectsInvalidCatalogOnlyIdentityAndStockValues() throws {
        let valid = try loadedSnapshot()
        let entry = try XCTUnwrap(valid.entries.first)

        let invalidYear = replacing(entry, year: 0)
        XCTAssertEqual(
            BundledCarCatalog.load(data: try encoded(snapshot(entries: [invalidYear], basedOn: valid))),
            .failure(.invalidCarInput(invalidYear.id))
        )

        let invalidHorsepower = replacing(
            entry,
            stock: replacing(entry.stock, peakHorsepower: 0)
        )
        XCTAssertEqual(
            BundledCarCatalog.load(data: try encoded(snapshot(entries: [invalidHorsepower], basedOn: valid))),
            .failure(.invalidCarInput(invalidHorsepower.id))
        )

        let invalidTorque = replacing(
            entry,
            stock: replacing(entry.stock, peakTorqueFootPounds: 0)
        )
        XCTAssertEqual(
            BundledCarCatalog.load(data: try encoded(snapshot(entries: [invalidTorque], basedOn: valid))),
            .failure(.invalidCarInput(invalidTorque.id))
        )
    }

    func testValidationRejectsDuplicateSourceIDsWithinEntry() throws {
        let valid = try loadedSnapshot()
        let entry = try XCTUnwrap(valid.entries.first)
        let official = try XCTUnwrap(entry.sources.first)
        let duplicate = replacing(entry, sources: entry.sources + [official])

        XCTAssertEqual(
            BundledCarCatalog.load(data: try encoded(snapshot(entries: [duplicate], basedOn: valid))),
            .failure(.duplicateSourceID(entry.id, official.id))
        )
    }

    private func loadedSnapshot() throws -> CarCatalogSnapshot {
        try BundledCarCatalog.load().get()
    }

    private func catalogCar() throws -> CarInput {
        let snapshot = try loadedSnapshot()
        let entry = try XCTUnwrap(snapshot.entries.first { $0.id == "fh6-2020-toyota-gr-supra" })
        return snapshot.selection(for: entry).carInput
    }

    private func encoded(_ snapshot: CarCatalogSnapshot) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(snapshot)
    }

    private func roundTrip(_ car: CarInput) throws -> CarInput {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(CarInput.self, from: encoder.encode(car))
    }

    private func snapshot(
        entries: [CatalogCarEntry],
        basedOn original: CarCatalogSnapshot
    ) -> CarCatalogSnapshot {
        CarCatalogSnapshot(
            schemaVersion: original.schemaVersion,
            revision: original.revision,
            reviewedAt: original.reviewedAt,
            entries: entries
        )
    }

    private func replacing(
        _ entry: CatalogCarEntry,
        id: String? = nil,
        year: Int? = nil,
        stock: CatalogStockSpecifications? = nil,
        sources: [CatalogSource]? = nil
    ) -> CatalogCarEntry {
        CatalogCarEntry(
            id: id ?? entry.id,
            game: entry.game,
            year: year ?? entry.year,
            make: entry.make,
            model: entry.model,
            stock: stock ?? entry.stock,
            verificationStatus: entry.verificationStatus,
            sources: sources ?? entry.sources
        )
    }

    private func replacing(
        _ stock: CatalogStockSpecifications,
        peakHorsepower: Int? = nil,
        peakTorqueFootPounds: Int? = nil
    ) -> CatalogStockSpecifications {
        CatalogStockSpecifications(
            performanceIndex: stock.performanceIndex,
            performanceClass: stock.performanceClass,
            drivetrain: stock.drivetrain,
            weightPounds: stock.weightPounds,
            frontWeightPercent: stock.frontWeightPercent,
            peakHorsepower: peakHorsepower ?? stock.peakHorsepower,
            peakTorqueFootPounds: peakTorqueFootPounds ?? stock.peakTorqueFootPounds
        )
    }

    private func assertEdited(
        _ car: CarInput,
        reference: CatalogCarReference,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(car.catalogReference, reference, file: file, line: line)
        XCTAssertTrue(car.catalogValuesModified, file: file, line: line)
    }

    private func makeTune(car: CarInput) -> TuneResult {
        TuneResult(
            request: TuneRequest(car: car, discipline: .road),
            sections: [],
            notes: TuneNotes(
                bias: "Catalog test.",
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
        guard let capability = resolution.settings.first(where: { $0.setting == setting }) else {
            XCTFail("Missing capability \(setting.rawValue)", file: file, line: line)
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

private final class MissingCatalogBundleToken {}

private struct ExpectedCar: Equatable {
    let game: ForzaGame
    let year: Int
    let make: String
    let model: String
    let performanceClass: PerformanceClass
    let performanceIndex: Int
    let drivetrain: Drivetrain
    let weightPounds: Int
    let frontWeightPercent: Double
    let horsepower: Int
    let torque: Int

    init(
        _ game: ForzaGame,
        _ year: Int,
        _ make: String,
        _ model: String,
        _ performanceClass: PerformanceClass,
        _ performanceIndex: Int,
        _ drivetrain: Drivetrain,
        _ weightPounds: Int,
        _ frontWeightPercent: Double,
        _ horsepower: Int,
        _ torque: Int
    ) {
        self.game = game
        self.year = year
        self.make = make
        self.model = model
        self.performanceClass = performanceClass
        self.performanceIndex = performanceIndex
        self.drivetrain = drivetrain
        self.weightPounds = weightPounds
        self.frontWeightPercent = frontWeightPercent
        self.horsepower = horsepower
        self.torque = torque
    }

    init(_ entry: CatalogCarEntry) {
        self.init(
            entry.game,
            entry.year,
            entry.make,
            entry.model,
            entry.stock.performanceClass,
            entry.stock.performanceIndex,
            entry.stock.drivetrain,
            entry.stock.weightPounds,
            entry.stock.frontWeightPercent,
            entry.stock.peakHorsepower,
            entry.stock.peakTorqueFootPounds
        )
    }
}
