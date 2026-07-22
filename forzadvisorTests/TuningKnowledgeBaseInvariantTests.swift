//
//  TuningKnowledgeBaseInvariantTests.swift
//  forzadvisorTests
//
//  Matrix-style coverage for offline tuning formula invariants across
//  representative disciplines, drivetrains, and car classes.
//

import XCTest
@testable import forzadvisor

final class TuningKnowledgeBaseInvariantTests: XCTestCase {
    func testKnowledgeBaseKeepsBaselineValuesInsideFH6RangesAcrossRepresentativeMatrix() {
        let cars = [
            representativeCar(drivetrain: .fwd, performanceClass: .b, weightPounds: 2_350, frontWeightPercent: 60, horsepower: 280),
            representativeCar(drivetrain: .rwd, performanceClass: .s1, weightPounds: 3_340, frontWeightPercent: 53, horsepower: 480),
            representativeCar(drivetrain: .awd, performanceClass: .s2, weightPounds: 4_450, frontWeightPercent: 48, horsepower: 820)
        ]

        for car in cars {
            for discipline in DrivingDiscipline.allCases {
                let request = TuneRequest(car: car, discipline: discipline)
                let tires = TuningKnowledgeBase.tirePressures(for: request)
                let finalDrive = TuningKnowledgeBase.finalDrive(for: request)
                let alignment = TuningKnowledgeBase.alignment(for: request)
                let antirollBars = TuningKnowledgeBase.antirollBars(for: request)
                let springs = TuningKnowledgeBase.springs(for: request)
                let rideHeight = TuningKnowledgeBase.rideHeight(for: request)
                let damping = TuningKnowledgeBase.damping(for: request, springs: springs)
                let aero = TuningKnowledgeBase.aero(for: request)
                let brakes = TuningKnowledgeBase.brakes(for: request)
                let differential = TuningKnowledgeBase.differential(for: request)
                let label = "\(car.drivetrain.rawValue) \(car.performanceClass.rawValue) \(discipline.title)"

                assert(tires.frontPsi, isIn: 15.5...40, label: "\(label) front tire pressure")
                assert(tires.rearPsi, isIn: 15.5...33, label: "\(label) rear tire pressure")
                XCTAssertFalse(tires.detail.isEmpty, "\(label) tire detail should explain the baseline")
                assert(finalDrive, isIn: 2.5...5.5, label: "\(label) final drive")
                assert(alignment.frontCamber, isIn: -5...0, label: "\(label) front camber")
                assert(alignment.rearCamber, isIn: -1.4...0.2, label: "\(label) rear camber")
                assert(alignment.frontToe, isIn: 0...1, label: "\(label) front toe")
                assert(alignment.rearToe, isIn: -0.1...0, label: "\(label) rear toe")
                assert(alignment.caster, isIn: 5.5...7, label: "\(label) caster")
                assert(antirollBars.front, isIn: 1...65, label: "\(label) front antiroll bar")
                assert(antirollBars.rear, isIn: 1...65, label: "\(label) rear antiroll bar")
                assert(springs.frontRate, isIn: 180...1_200, label: "\(label) front spring")
                assert(springs.rearRate, isIn: 180...1_200, label: "\(label) rear spring")
                assert(rideHeight.front, isIn: 4.3...7.5, label: "\(label) front ride height")
                assert(rideHeight.rear, isIn: 4.4...7.5, label: "\(label) rear ride height")
                assert(damping.frontRebound, isIn: 1...20, label: "\(label) front rebound")
                assert(damping.rearRebound, isIn: 1...20, label: "\(label) rear rebound")
                assert(damping.frontBump, isIn: 1...20, label: "\(label) front bump")
                assert(damping.rearBump, isIn: 1...20, label: "\(label) rear bump")
                assert(aero.front, isIn: 0...500, label: "\(label) front aero")
                assert(aero.rear, isIn: 0...500, label: "\(label) rear aero")
                assert(brakes.balancePercent, isIn: 47...70, label: "\(label) brake balance")
                assert(brakes.pressurePercent, isIn: 95...110, label: "\(label) brake pressure")
                assertOptional(differential.accel, isIn: 0...100, label: "\(label) differential accel")
                assertOptional(differential.decel, isIn: 0...100, label: "\(label) differential decel")
                assertOptional(differential.frontAccel, isIn: 0...100, label: "\(label) front differential accel")
                assertOptional(differential.frontDecel, isIn: 0...100, label: "\(label) front differential decel")
                assertOptional(differential.rearAccel, isIn: 0...100, label: "\(label) rear differential accel")
                assertOptional(differential.rearDecel, isIn: 0...100, label: "\(label) rear differential decel")
                assertOptional(differential.centerBalance, isIn: 40...85, label: "\(label) center balance")
            }
        }
    }

    func testKnowledgeBaseDifferentialOutputMatchesDrivetrainShapeAcrossDisciplines() {
        for discipline in DrivingDiscipline.allCases {
            let fwd = TuningKnowledgeBase.differential(
                for: TuneRequest(car: representativeCar(drivetrain: .fwd), discipline: discipline)
            )
            XCTAssertNil(fwd.accel, "\(discipline.title) FWD should not expose rear-only accel")
            XCTAssertNil(fwd.decel, "\(discipline.title) FWD should not expose rear-only decel")
            XCTAssertNotNil(fwd.frontAccel, "\(discipline.title) FWD should expose front accel")
            XCTAssertNotNil(fwd.frontDecel, "\(discipline.title) FWD should expose front decel")
            XCTAssertNil(fwd.rearAccel, "\(discipline.title) FWD should not expose rear accel")
            XCTAssertNil(fwd.rearDecel, "\(discipline.title) FWD should not expose rear decel")
            XCTAssertNil(fwd.centerBalance, "\(discipline.title) FWD should not expose center balance")

            let rwd = TuningKnowledgeBase.differential(
                for: TuneRequest(car: representativeCar(drivetrain: .rwd), discipline: discipline)
            )
            XCTAssertNotNil(rwd.accel, "\(discipline.title) RWD should expose axle accel")
            XCTAssertNotNil(rwd.decel, "\(discipline.title) RWD should expose axle decel")
            XCTAssertNil(rwd.frontAccel, "\(discipline.title) RWD should not expose front accel")
            XCTAssertNil(rwd.frontDecel, "\(discipline.title) RWD should not expose front decel")
            XCTAssertNil(rwd.rearAccel, "\(discipline.title) RWD should not expose separate rear accel")
            XCTAssertNil(rwd.rearDecel, "\(discipline.title) RWD should not expose separate rear decel")
            XCTAssertNil(rwd.centerBalance, "\(discipline.title) RWD should not expose center balance")

            let awd = TuningKnowledgeBase.differential(
                for: TuneRequest(car: representativeCar(drivetrain: .awd), discipline: discipline)
            )
            XCTAssertNil(awd.accel, "\(discipline.title) AWD should use front/rear accel instead")
            XCTAssertNil(awd.decel, "\(discipline.title) AWD should use front/rear decel instead")
            XCTAssertNotNil(awd.frontAccel, "\(discipline.title) AWD should expose front accel")
            XCTAssertNotNil(awd.frontDecel, "\(discipline.title) AWD should expose front decel")
            XCTAssertNotNil(awd.rearAccel, "\(discipline.title) AWD should expose rear accel")
            XCTAssertNotNil(awd.rearDecel, "\(discipline.title) AWD should expose rear decel")
            XCTAssertNotNil(awd.centerBalance, "\(discipline.title) AWD should expose center balance")
        }
    }

    func testKnowledgeBaseDisciplineInvariantsDoNotRegress() {
        let rwdCar = representativeCar(drivetrain: .rwd)
        let awdCar = representativeCar(drivetrain: .awd, weightPounds: 4_200)

        let road = TuneRequest(car: rwdCar, discipline: .road)
        let touge = TuneRequest(car: rwdCar, discipline: .touge)
        let roadBars = TuningKnowledgeBase.antirollBars(for: road)
        let tougeBars = TuningKnowledgeBase.antirollBars(for: touge)

        XCTAssertGreaterThan(TuningKnowledgeBase.finalDrive(for: touge), TuningKnowledgeBase.finalDrive(for: road))
        XCTAssertGreaterThan(TuningKnowledgeBase.alignment(for: touge).frontToe, TuningKnowledgeBase.alignment(for: road).frontToe)
        XCTAssertLessThan(TuningKnowledgeBase.alignment(for: touge).rearToe, TuningKnowledgeBase.alignment(for: road).rearToe)
        XCTAssertLessThan(tougeBars.front, roadBars.front)
        XCTAssertGreaterThan(tougeBars.rear, roadBars.rear)

        let drag = TuneRequest(car: rwdCar, discipline: .drag)
        let dragTires = TuningKnowledgeBase.tirePressures(for: drag)
        let dragAlignment = TuningKnowledgeBase.alignment(for: drag)
        XCTAssertGreaterThan(dragTires.frontPsi, dragTires.rearPsi)
        XCTAssertEqual(dragAlignment.frontCamber, -0.3)
        XCTAssertEqual(dragAlignment.rearCamber, 0.2)
        XCTAssertEqual(dragAlignment.frontToe, 0)
        XCTAssertEqual(dragAlignment.rearToe, 0)
        XCTAssertEqual(dragAlignment.caster, 7)
        XCTAssertLessThan(TuningKnowledgeBase.finalDrive(for: drag), TuningKnowledgeBase.finalDrive(for: road))
        XCTAssertEqual(TuningKnowledgeBase.aero(for: drag).front, 0)
        XCTAssertEqual(TuningKnowledgeBase.aero(for: drag).rear, 0)
        XCTAssertEqual(TuningKnowledgeBase.differential(for: drag).decel, 0)

        let drift = TuneRequest(car: rwdCar, discipline: .drift)
        let driftAlignment = TuningKnowledgeBase.alignment(for: drift)
        XCTAssertEqual(driftAlignment.frontCamber, -5)
        XCTAssertEqual(driftAlignment.rearCamber, -1)
        XCTAssertEqual(driftAlignment.frontToe, 1)
        XCTAssertEqual(driftAlignment.rearToe, -0.1)
        XCTAssertEqual(driftAlignment.caster, 7)
        XCTAssertEqual(TuningKnowledgeBase.aero(for: drift).rear, 0)
        XCTAssertEqual(TuningKnowledgeBase.differential(for: drift).accel, 100)

        let dirt = TuneRequest(car: awdCar, discipline: .dirt)
        let crossCountry = TuneRequest(car: awdCar, discipline: .crossCountry)
        XCTAssertLessThanOrEqual(TuningKnowledgeBase.tirePressures(for: dirt).frontPsi, 21)
        XCTAssertLessThanOrEqual(TuningKnowledgeBase.tirePressures(for: crossCountry).frontPsi, 21)
        XCTAssertGreaterThan(TuningKnowledgeBase.rideHeight(for: crossCountry).front, TuningKnowledgeBase.rideHeight(for: dirt).front)
        XCTAssertLessThan(
            TuningKnowledgeBase.differential(for: crossCountry).centerBalance ?? 0,
            TuningKnowledgeBase.differential(for: dirt).centerBalance ?? 0
        )
    }

    private func representativeCar(
        drivetrain: Drivetrain,
        performanceClass: PerformanceClass = .s1,
        weightPounds: Int = 3_340,
        frontWeightPercent: Double = 53,
        horsepower: Int = 480
    ) -> CarInput {
        CarInput(
            year: 2019,
            make: "Toyota",
            model: "Supra",
            weightPounds: weightPounds,
            frontWeightPercent: frontWeightPercent,
            performanceIndex: 750,
            performanceClass: performanceClass,
            drivetrain: drivetrain,
            peakHorsepower: horsepower,
            peakTorqueFootPounds: nil
        )
    }

    private func assert(
        _ value: Double,
        isIn range: ClosedRange<Double>,
        label: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(value.isFinite, "\(label) should be finite", file: file, line: line)
        XCTAssertTrue(range.contains(value), "\(label) \(value) should be in \(range)", file: file, line: line)
    }

    private func assertOptional(
        _ value: Double?,
        isIn range: ClosedRange<Double>,
        label: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let value else { return }
        assert(value, isIn: range, label: label, file: file, line: line)
    }
}
