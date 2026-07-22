//
//  TuneAPIModels.swift
//  forzadvisor
//
//  Codable request and response shapes for remote tune generation. These map
//  the app domain to the PRD JSON contract without making networking required.
//

import Foundation

struct TuneAPIResponse: Codable, Equatable {
    var tune: TuneAPITune
    var notes: TuneAPINotes

    init(tune: TuneAPITune, notes: TuneAPINotes) {
        self.tune = tune
        self.notes = notes
    }

    init(result: TuneResult) {
        self.tune = TuneAPITune(result: result)
        self.notes = TuneAPINotes(notes: result.notes)
    }

    func tuneResult(for request: TuneRequest, id: UUID = UUID()) -> TuneResult {
        TuneResult(
            id: id,
            request: request,
            sections: tune.sections(),
            notes: TuneNotes(
                bias: notes.bias ?? "Remote tune generated.",
                ifPushesWide: notes.ifPushesWide ?? "Request more rotation if the car pushes wide.",
                ifSnapsOnLift: notes.ifSnapsOnLift ?? "Request more stability if the car snaps on lift.",
                retuneTrigger: notes.retuneTrigger ?? "Re-tune if weight distribution shifts more than 2%."
            )
        )
    }

    func mergedTuneResult(updating previous: TuneResult) -> TuneResult {
        var adjustedTune = previous
        adjustedTune.sections = tune.sections().merging(into: previous.sections)
        adjustedTune.notes = notes.merging(into: previous.notes)
        return adjustedTune
    }
}

struct TuneAPITune: Codable, Equatable {
    var tires: TuneAPITires?
    var gearing: TuneAPIGearing?
    var alignment: TuneAPIAlignment?
    var antirollBars: TuneAPIFrontRear?
    var springs: TuneAPISprings?
    var damping: TuneAPIDamping?
    var aero: TuneAPIAero?
    var brakes: TuneAPIBrakes?
    var differential: TuneAPIDifferential?

    enum CodingKeys: String, CodingKey {
        case tires
        case gearing
        case alignment
        case antirollBars = "arbs"
        case springs
        case damping
        case aero
        case brakes
        case differential
    }

    init(
        tires: TuneAPITires? = nil,
        gearing: TuneAPIGearing? = nil,
        alignment: TuneAPIAlignment? = nil,
        antirollBars: TuneAPIFrontRear? = nil,
        springs: TuneAPISprings? = nil,
        damping: TuneAPIDamping? = nil,
        aero: TuneAPIAero? = nil,
        brakes: TuneAPIBrakes? = nil,
        differential: TuneAPIDifferential? = nil
    ) {
        self.tires = tires
        self.gearing = gearing
        self.alignment = alignment
        self.antirollBars = antirollBars
        self.springs = springs
        self.damping = damping
        self.aero = aero
        self.brakes = brakes
        self.differential = differential
    }

    init(result: TuneResult) {
        self.init(
            tires: TuneAPITires(section: result.section("Tires")),
            gearing: TuneAPIGearing(section: result.section("Gearing")),
            alignment: TuneAPIAlignment(section: result.section("Alignment")),
            antirollBars: TuneAPIFrontRear(section: result.section("Antiroll Bars"), front: "Front", rear: "Rear"),
            springs: TuneAPISprings(section: result.section("Springs")),
            damping: TuneAPIDamping(section: result.section("Damping")),
            aero: TuneAPIAero(section: result.section("Aero")),
            brakes: TuneAPIBrakes(section: result.section("Brakes")),
            differential: TuneAPIDifferential(section: result.section("Differential"))
        )
    }
}

struct TuneAPITires: Codable, Equatable {
    var frontPsi: Double?
    var rearPsi: Double?

    enum CodingKeys: String, CodingKey {
        case frontPsi = "front_psi"
        case rearPsi = "rear_psi"
    }

    init(frontPsi: Double? = nil, rearPsi: Double? = nil) {
        self.frontPsi = frontPsi
        self.rearPsi = rearPsi
    }

    init?(section: TuneSection?) {
        guard let section else { return nil }
        self.frontPsi = section.number("Front pressure")
        self.rearPsi = section.number("Rear pressure")
    }
}

struct TuneAPIGearing: Codable, Equatable {
    var finalDrive: Double?
    var gears: [Double]?

    enum CodingKeys: String, CodingKey {
        case finalDrive = "final_drive"
        case gears
    }

    init(finalDrive: Double? = nil, gears: [Double]? = nil) {
        self.finalDrive = finalDrive
        self.gears = gears
    }

    init?(section: TuneSection?) {
        guard let section else { return nil }
        self.finalDrive = section.number("Final drive")
        let indexedGears = section.lines.compactMap { line -> (Int, Double)? in
            guard case .gearRatio(let index) = line.fieldID,
                  let value = line.numericValue else {
                return nil
            }
            return (index, value)
        }
        .sorted { $0.0 < $1.0 }
        guard !indexedGears.isEmpty else {
            self.gears = nil
            return
        }
        let expectedIndices = Array(1...indexedGears.count)
        self.gears = indexedGears.map(\.0) == expectedIndices
            ? indexedGears.map(\.1)
            : nil
    }
}

struct TuneAPIAlignment: Codable, Equatable {
    var frontCamber: Double?
    var rearCamber: Double?
    var frontToe: Double?
    var rearToe: Double?
    var caster: Double?

    enum CodingKeys: String, CodingKey {
        case frontCamber = "front_camber"
        case rearCamber = "rear_camber"
        case frontToe = "front_toe"
        case rearToe = "rear_toe"
        case caster
    }

    init(frontCamber: Double? = nil, rearCamber: Double? = nil, frontToe: Double? = nil, rearToe: Double? = nil, caster: Double? = nil) {
        self.frontCamber = frontCamber
        self.rearCamber = rearCamber
        self.frontToe = frontToe
        self.rearToe = rearToe
        self.caster = caster
    }

    init?(section: TuneSection?) {
        guard let section else { return nil }
        self.frontCamber = section.number("Front camber")
        self.rearCamber = section.number("Rear camber")
        self.frontToe = section.number("Front toe")
        self.rearToe = section.number("Rear toe")
        self.caster = section.number("Caster")
    }
}

struct TuneAPIFrontRear: Codable, Equatable {
    var front: Double?
    var rear: Double?

    init(front: Double? = nil, rear: Double? = nil) {
        self.front = front
        self.rear = rear
    }

    init?(section: TuneSection?, front frontLabel: String, rear rearLabel: String) {
        guard let section else { return nil }
        self.front = section.number(frontLabel)
        self.rear = section.number(rearLabel)
    }
}

struct TuneAPIAero: Codable, Equatable {
    var frontPounds: Double?
    var rearPounds: Double?

    enum CodingKeys: String, CodingKey {
        case frontPounds = "front_lb"
        case rearPounds = "rear_lb"
    }

    init(frontPounds: Double? = nil, rearPounds: Double? = nil) {
        self.frontPounds = frontPounds
        self.rearPounds = rearPounds
    }

    init?(section: TuneSection?) {
        guard let section else { return nil }
        self.frontPounds = section.number("Front")
        self.rearPounds = section.number("Rear")
    }
}

struct TuneAPISprings: Codable, Equatable {
    var frontRate: Double?
    var rearRate: Double?
    var frontRideHeight: Double?
    var rearRideHeight: Double?

    enum CodingKeys: String, CodingKey {
        case frontRate = "front_rate"
        case rearRate = "rear_rate"
        case frontRideHeight = "front_ride_height"
        case rearRideHeight = "rear_ride_height"
    }

    init(frontRate: Double? = nil, rearRate: Double? = nil, frontRideHeight: Double? = nil, rearRideHeight: Double? = nil) {
        self.frontRate = frontRate
        self.rearRate = rearRate
        self.frontRideHeight = frontRideHeight
        self.rearRideHeight = rearRideHeight
    }

    init?(section: TuneSection?) {
        guard let section else { return nil }
        self.frontRate = section.number("Front rate")
        self.rearRate = section.number("Rear rate")
        self.frontRideHeight = section.number("Front ride height")
        self.rearRideHeight = section.number("Rear ride height")
    }
}
