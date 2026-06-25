//
//  TuningDomainTests.swift
//  forzadvisorTests
//
//  Focused coverage for pure tuning inputs and the deterministic local tune
//  provider used by the manual-entry MVP.
//

import XCTest
import SwiftData
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

    func testRoadDampingUsesSourceBackedBumpToReboundRatio() async throws {
        let request = TuneRequest(car: SampleTuningData.starterCar, discipline: .road)
        let tune = try await LocalSampleTuneProvider().generateTune(for: request)

        let frontRatio = numericValue(in: tune, section: "Damping", line: "Front bump")
            / numericValue(in: tune, section: "Damping", line: "Front rebound")
        let rearRatio = numericValue(in: tune, section: "Damping", line: "Rear bump")
            / numericValue(in: tune, section: "Damping", line: "Rear rebound")

        XCTAssertEqual(frontRatio, 0.4, accuracy: 0.03)
        XCTAssertEqual(rearRatio, 0.4, accuracy: 0.03)
    }

    func testDifferentialBaselinesFollowFH6SourceRanges() async throws {
        let provider = LocalSampleTuneProvider()

        var fwdCar = SampleTuningData.starterCar
        fwdCar.drivetrain = .fwd
        let fwdTune = try await provider.generateTune(for: TuneRequest(car: fwdCar, discipline: .road))

        XCTAssertEqual(numericValue(in: fwdTune, section: "Differential", line: "Front accel"), 85)
        XCTAssertEqual(numericValue(in: fwdTune, section: "Differential", line: "Front decel"), 5)

        var awdCar = SampleTuningData.starterCar
        awdCar.drivetrain = .awd
        let awdTune = try await provider.generateTune(for: TuneRequest(car: awdCar, discipline: .road))

        XCTAssertEqual(numericValue(in: awdTune, section: "Differential", line: "Front accel"), 85)
        XCTAssertEqual(numericValue(in: awdTune, section: "Differential", line: "Rear accel"), 55)
        XCTAssertEqual(numericValue(in: awdTune, section: "Differential", line: "Center balance"), 75)
    }

    func testOffRoadBaselinesPrioritizeCompliance() async throws {
        var car = SampleTuningData.starterCar
        car.drivetrain = .awd
        let tune = try await LocalSampleTuneProvider().generateTune(
            for: TuneRequest(car: car, discipline: .dirt)
        )

        XCTAssertLessThanOrEqual(numericValue(in: tune, section: "Tires", line: "Front pressure"), 21)
        XCTAssertLessThanOrEqual(numericValue(in: tune, section: "Antiroll Bars", line: "Front"), 10)
        XCTAssertGreaterThanOrEqual(numericValue(in: tune, section: "Springs", line: "Front ride height"), 6)
        XCTAssertEqual(numericValue(in: tune, section: "Differential", line: "Center balance"), 65)
    }

    func testDragAndDriftUseDisciplineSpecificExceptions() async throws {
        let provider = LocalSampleTuneProvider()
        let dragTune = try await provider.generateTune(
            for: TuneRequest(car: SampleTuningData.starterCar, discipline: .drag)
        )
        let driftTune = try await provider.generateTune(
            for: TuneRequest(car: SampleTuningData.starterCar, discipline: .drift)
        )

        XCTAssertGreaterThan(
            numericValue(in: dragTune, section: "Tires", line: "Front pressure"),
            numericValue(in: dragTune, section: "Tires", line: "Rear pressure")
        )
        XCTAssertEqual(numericValue(in: dragTune, section: "Aero", line: "Front"), 0)
        XCTAssertEqual(numericValue(in: driftTune, section: "Alignment", line: "Front toe"), 1)
        XCTAssertEqual(numericValue(in: driftTune, section: "Differential", line: "Accel"), 100)
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

    func testTuneFeedbackMapsToAdjustmentIntent() {
        XCTAssertEqual(TuneFeedback.pushesWide.adjustment, .moreRotation)
        XCTAssertEqual(TuneFeedback.oversteersOnExit.adjustment, .moreStability)
        XCTAssertEqual(TuneFeedback.snapsOnLift.adjustment, .moreStability)
        XCTAssertEqual(TuneFeedback.wheelspinOnLaunch.adjustment, .moreStability)
        XCTAssertEqual(TuneFeedback.bouncyOverBumps.adjustment, .softer)
        XCTAssertEqual(TuneFeedback.feelsFloaty.adjustment, .stiffer)
        XCTAssertEqual(TuneFeedback.runsOutOfGear.adjustment, .moreTopSpeed)
        XCTAssertEqual(TuneFeedback.needsMorePull.adjustment, .moreAcceleration)
    }

    func testLocalAdjustmentChangesIncludeRationaleAndStayInBounds() async throws {
        let provider = LocalSampleTuneProvider()
        let request = TuneRequest(car: SampleTuningData.starterCar, discipline: .road)
        let tune = try await provider.generateTune(for: request)
        let result = try await provider.adjustTune(previous: tune, adjustment: TuneFeedback.pushesWide.adjustment)

        XCTAssertEqual(result.tune.id, tune.id)
        XCTAssertEqual(result.tune.request, tune.request)
        XCTAssertEqual(result.tune.sections.map(\.title), tune.sections.map(\.title))
        XCTAssertFalse(result.changes.isEmpty)
        XCTAssertTrue(result.changes.allSatisfy { change in
            !(change.rationale ?? "").isEmpty
        })
        XCTAssertTrue(result.tune.sections.flatMap(\.lines).allSatisfy { line in
            guard let value = Double(line.value.replacingOccurrences(of: ",", with: "")) else {
                return true
            }
            return value.isFinite
        })
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

    @MainActor
    func testSavedTuneKeepsStableRecordIDWhenUpdatedWithNewTuneResult() async throws {
        let container = try ModelContainer(
            for: SavedTune.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let provider = LocalSampleTuneProvider()
        let original = try await provider.generateTune(
            for: TuneRequest(car: SampleTuningData.starterCar, discipline: .road)
        )
        let savedTune = try SavedTune(tune: original)
        let savedTuneID = savedTune.id

        context.insert(savedTune)
        try context.save()

        var retunedCar = SampleTuningData.starterCar
        retunedCar.frontWeightPercent += 3
        let retuned = try await provider.generateTune(
            for: TuneRequest(car: retunedCar, discipline: .road)
        )
        XCTAssertNotEqual(retuned.id, savedTuneID)

        try savedTune.update(with: retuned, playerNotes: "Retuned after weight shift")
        try context.save()

        var descriptor = FetchDescriptor<SavedTune>(
            predicate: #Predicate<SavedTune> { tune in
                tune.id == savedTuneID
            }
        )
        descriptor.fetchLimit = 1
        let fetched = try XCTUnwrap(context.fetch(descriptor).first)

        XCTAssertEqual(fetched.id, savedTuneID)
        XCTAssertEqual(fetched.frontWeightPercent, retunedCar.frontWeightPercent)
        XCTAssertEqual(fetched.playerNotes, "Retuned after weight shift")
        XCTAssertEqual(fetched.tuneResult?.id, retuned.id)
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
