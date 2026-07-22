//
//  TuneFieldTaggingTests.swift
//  forzadvisorTests
//
//  Ensures every generated numeric value has a stable client-owned field ID.
//

import XCTest
@testable import forzadvisor

final class TuneFieldTaggingTests: XCTestCase {
    func testLocalProviderTagsEveryNumericRWDLine() async throws {
        let tune = try await LocalSampleTuneProvider().generateTune(
            for: TuneRequest(car: SampleTuningData.starterCar, discipline: .road)
        )

        let numericLines = tune.sections.flatMap(\.lines).filter { $0.numericValue != nil }
        XCTAssertEqual(numericLines.count, 24)
        XCTAssertTrue(numericLines.allSatisfy { $0.fieldID != nil })
        XCTAssertEqual(tune.section("Gearing")?.lines.first(where: { $0.label == "Final drive" })?.fieldID, .finalDrive)
        XCTAssertNil(tune.section("Gearing")?.lines.first(where: { $0.label == "Individual gears" })?.fieldID)
        XCTAssertEqual(
            Set(tune.section("Differential")?.lines.compactMap(\.fieldID) ?? []),
            [.differentialAcceleration, .differentialDeceleration]
        )
    }

    func testLocalDifferentialTagsMatchFWDAndAWDAxles() async throws {
        var fwdCar = SampleTuningData.starterCar
        fwdCar.drivetrain = .fwd
        let fwd = try await LocalSampleTuneProvider().generateTune(
            for: TuneRequest(car: fwdCar, discipline: .road)
        )
        XCTAssertEqual(
            Set(fwd.section("Differential")?.lines.compactMap(\.fieldID) ?? []),
            [.frontDifferentialAcceleration, .frontDifferentialDeceleration]
        )

        var awdCar = SampleTuningData.starterCar
        awdCar.drivetrain = .awd
        let awd = try await LocalSampleTuneProvider().generateTune(
            for: TuneRequest(car: awdCar, discipline: .road)
        )
        XCTAssertEqual(
            Set(awd.section("Differential")?.lines.compactMap(\.fieldID) ?? []),
            [
                .frontDifferentialAcceleration,
                .frontDifferentialDeceleration,
                .rearDifferentialAcceleration,
                .rearDifferentialDeceleration,
                .differentialCenterBalance
            ]
        )
    }

    func testAPISectionsTagIndexedGearsAndDifferentialFields() throws {
        let apiTune = TuneAPITune(
            gearing: TuneAPIGearing(finalDrive: 3.7, gears: [3.2, 2.1, 1.4]),
            differential: TuneAPIDifferential(
                frontAccelPercent: 20,
                frontDecelPercent: 10,
                rearAccelPercent: 60,
                rearDecelPercent: 20,
                centerBalanceRearPercent: 70
            )
        )
        let sections = apiTune.sections()
        let gearing = try XCTUnwrap(sections.first(where: { $0.title == "Gearing" }))
        XCTAssertEqual(
            gearing.lines.compactMap(\.fieldID),
            [.finalDrive, .gearRatio(1), .gearRatio(2), .gearRatio(3)]
        )
        XCTAssertEqual(gearing.lines.map(\.label), ["Final drive", "Gear 1", "Gear 2", "Gear 3"])

        let differential = try XCTUnwrap(sections.first(where: { $0.title == "Differential" }))
        XCTAssertEqual(
            differential.lines.compactMap(\.fieldID),
            [
                .frontDifferentialAcceleration,
                .frontDifferentialDeceleration,
                .rearDifferentialAcceleration,
                .rearDifferentialDeceleration,
                .differentialCenterBalance
            ]
        )
    }

    func testAPIGearingRoundTripPreservesIndexedValues() throws {
        let section = TuneSection(
            title: "Gearing",
            symbolName: "gearshape.2",
            lines: [
                TuneLine(label: "Final drive", value: "3.70", unit: "", detail: nil, fieldID: .finalDrive),
                TuneLine(label: "Gear 2", value: "2.10", unit: "", detail: nil, fieldID: .gearRatio(2)),
                TuneLine(label: "Gear 1", value: "3.20", unit: "", detail: nil, fieldID: .gearRatio(1))
            ]
        )
        let gearing = try XCTUnwrap(TuneAPIGearing(section: section))
        XCTAssertEqual(gearing.finalDrive, 3.7)
        XCTAssertEqual(gearing.gears ?? [], [3.2, 2.1])
    }

    func testAPIGearingDoesNotCompressMissingOrDuplicateIndices() throws {
        let missingFirst = TuneSection(
            title: "Gearing",
            symbolName: "gearshape.2",
            lines: [
                TuneLine(label: "Gear 2", value: "2.10", unit: "", detail: nil, fieldID: .gearRatio(2))
            ]
        )
        XCTAssertNil(try XCTUnwrap(TuneAPIGearing(section: missingFirst)).gears)

        let duplicateFirst = TuneSection(
            title: "Gearing",
            symbolName: "gearshape.2",
            lines: [
                TuneLine(label: "Gear 1", value: "3.20", unit: "", detail: nil, fieldID: .gearRatio(1)),
                TuneLine(label: "First duplicate", value: "3.10", unit: "", detail: nil, fieldID: .gearRatio(1))
            ]
        )
        XCTAssertNil(try XCTUnwrap(TuneAPIGearing(section: duplicateFirst)).gears)
    }

    func testPartialMergeCannotEraseExistingFieldIdentity() throws {
        let existing = TuneLine(
            label: "Front pressure",
            value: "27.0",
            unit: "PSI",
            detail: "Existing",
            fieldID: .frontTirePressure
        )
        let untypedPartial = TuneLine(
            label: "Front pressure",
            value: "26.8",
            unit: "PSI",
            detail: "Partial"
        )

        let merged = [untypedPartial].merging(into: [existing])
        let line = try XCTUnwrap(merged.first)
        XCTAssertEqual(line.value, "26.8")
        XCTAssertEqual(line.detail, "Partial")
        XCTAssertEqual(line.fieldID, .frontTirePressure)
    }
}
