//
//  TuningDomainTests.swift
//  forzadvisorTests
//
//  Focused coverage for pure tuning inputs and the deterministic local tune
//  provider used by the manual-entry MVP.
//

import XCTest
@testable import forzadvisor

final class TuningDomainTests: XCTestCase {
    func testStarterCarPassesValidation() {
        XCTAssertTrue(SampleTuningData.starterCar.isValid)
        XCTAssertTrue(SampleTuningData.starterCar.validationIssues.isEmpty)
    }

    func testValidationCatchesRequiredInputRanges() {
        var car = SampleTuningData.starterCar
        car.make = " "
        car.model = ""
        car.weightPounds = 900
        car.frontWeightPercent = 72
        car.performanceIndex = 1_000

        let issues = car.validationIssues

        XCTAssertEqual(issues.count, 4)
        XCTAssertTrue(issues.contains(.missingName))
        XCTAssertTrue(issues.contains(.invalidWeight))
        XCTAssertTrue(issues.contains(.invalidFrontWeight))
        XCTAssertTrue(issues.contains(.invalidPerformanceIndex))
    }

    func testLocalProviderReturnsTuneMenuOrder() async throws {
        let request = TuneRequest(car: SampleTuningData.starterCar, discipline: .touge)
        let tune = try await LocalSampleTuneProvider().generateTune(for: request)

        XCTAssertEqual(tune.request, request)
        XCTAssertEqual(
            tune.sections.map(\.title),
            [
                "Tires",
                "Gearing",
                "Alignment",
                "Antiroll Bars",
                "Springs",
                "Damping",
                "Aero",
                "Brakes",
                "Differential"
            ]
        )
        XCTAssertTrue(tune.sections.allSatisfy { !$0.lines.isEmpty })
    }

    func testLocalProviderIsDeterministicForTuneValues() async throws {
        let request = TuneRequest(car: SampleTuningData.starterCar, discipline: .road)
        let firstTune = try await LocalSampleTuneProvider().generateTune(for: request)
        let secondTune = try await LocalSampleTuneProvider().generateTune(for: request)

        XCTAssertEqual(firstTune.sections, secondTune.sections)
        XCTAssertEqual(firstTune.notes, secondTune.notes)
    }

    func testLocalAdjustmentPreservesTuneIdentityAndMenuOrder() async throws {
        let provider = LocalSampleTuneProvider()
        let request = TuneRequest(car: SampleTuningData.starterCar, discipline: .touge)
        let tune = try await provider.generateTune(for: request)
        let result = try await provider.adjustTune(previous: tune, adjustment: .moreRotation)

        XCTAssertEqual(result.tune.id, tune.id)
        XCTAssertEqual(result.tune.request, tune.request)
        XCTAssertEqual(result.tune.sections.map(\.title), tune.sections.map(\.title))
        XCTAssertTrue(result.tune.sections.allSatisfy { !$0.lines.isEmpty })
        XCTAssertFalse(result.changes.isEmpty)
    }

    func testMoreRotationChangesBalanceRelatedLines() async throws {
        let provider = LocalSampleTuneProvider()
        let request = TuneRequest(car: SampleTuningData.starterCar, discipline: .touge)
        let tune = try await provider.generateTune(for: request)
        let result = try await provider.adjustTune(previous: tune, adjustment: .moreRotation)

        XCTAssertLessThan(numericValue(in: result.tune, section: "Antiroll Bars", line: "Front"), numericValue(in: tune, section: "Antiroll Bars", line: "Front"))
        XCTAssertGreaterThan(numericValue(in: result.tune, section: "Antiroll Bars", line: "Rear"), numericValue(in: tune, section: "Antiroll Bars", line: "Rear"))
        XCTAssertGreaterThan(numericValue(in: result.tune, section: "Differential", line: "Accel"), numericValue(in: tune, section: "Differential", line: "Accel"))
        XCTAssertLessThan(numericValue(in: result.tune, section: "Differential", line: "Decel"), numericValue(in: tune, section: "Differential", line: "Decel"))
        XCTAssertTrue(result.changes.contains { $0.sectionTitle == "Differential" })
    }

    func testSoftAndStiffAdjustmentsMoveSpringAndDampingOppositeDirections() async throws {
        let provider = LocalSampleTuneProvider()
        let request = TuneRequest(car: SampleTuningData.starterCar, discipline: .road)
        let tune = try await provider.generateTune(for: request)
        let softer = try await provider.adjustTune(previous: tune, adjustment: .softer).tune
        let stiffer = try await provider.adjustTune(previous: tune, adjustment: .stiffer).tune

        XCTAssertLessThan(numericValue(in: softer, section: "Springs", line: "Front rate"), numericValue(in: tune, section: "Springs", line: "Front rate"))
        XCTAssertLessThan(numericValue(in: softer, section: "Damping", line: "Front rebound"), numericValue(in: tune, section: "Damping", line: "Front rebound"))
        XCTAssertGreaterThan(numericValue(in: stiffer, section: "Springs", line: "Front rate"), numericValue(in: tune, section: "Springs", line: "Front rate"))
        XCTAssertGreaterThan(numericValue(in: stiffer, section: "Damping", line: "Front rebound"), numericValue(in: tune, section: "Damping", line: "Front rebound"))
    }

    func testSpeedAndAccelerationAdjustmentsMoveFinalDriveOppositeDirections() async throws {
        let provider = LocalSampleTuneProvider()
        let request = TuneRequest(car: SampleTuningData.starterCar, discipline: .road)
        let tune = try await provider.generateTune(for: request)
        let topSpeed = try await provider.adjustTune(previous: tune, adjustment: .moreTopSpeed).tune
        let acceleration = try await provider.adjustTune(previous: tune, adjustment: .moreAcceleration).tune

        XCTAssertLessThan(numericValue(in: topSpeed, section: "Gearing", line: "Final drive"), numericValue(in: tune, section: "Gearing", line: "Final drive"))
        XCTAssertGreaterThan(numericValue(in: acceleration, section: "Gearing", line: "Final drive"), numericValue(in: tune, section: "Gearing", line: "Final drive"))
        XCTAssertLessThan(numericValue(in: topSpeed, section: "Aero", line: "Front"), numericValue(in: tune, section: "Aero", line: "Front"))
        XCTAssertGreaterThan(numericValue(in: acceleration, section: "Aero", line: "Front"), numericValue(in: tune, section: "Aero", line: "Front"))
    }

    func testSavedTuneEditDraftFlagsRetuneThresholds() async throws {
        let request = TuneRequest(car: SampleTuningData.starterCar, discipline: .touge)
        let tune = try await LocalSampleTuneProvider().generateTune(for: request)
        var draft = SavedTuneEditDraft(tune: tune, playerNotes: "")

        XCTAssertFalse(draft.needsRetune)

        draft.car.frontWeightPercent += 2.5
        XCTAssertTrue(draft.needsRetune)

        draft = SavedTuneEditDraft(tune: tune, playerNotes: "")
        draft.car.weightPounds = Int(Double(draft.car.weightPounds) * 1.03)
        XCTAssertTrue(draft.needsRetune)
    }

    private func numericValue(in tune: TuneResult, section sectionTitle: String, line lineLabel: String) -> Double {
        guard let value = tune.sections
            .first(where: { $0.title == sectionTitle })?
            .lines
            .first(where: { $0.label == lineLabel })?
            .value
            .replacingOccurrences(of: ",", with: ""),
              let number = Double(value)
        else {
            XCTFail("Missing numeric tune line \(sectionTitle) / \(lineLabel)")
            return 0
        }

        return number
    }
}
