//
//  TuneAPIModels.swift
//  forzadvisor
//
//  Codable request and response shapes for remote tune generation. These map
//  the app domain to the PRD JSON contract without making networking required.
//

import Foundation

struct TuneAPIRequestPayload: Codable, Equatable {
    var action: String
    var car: TuneAPICar
    var discipline: String
    var notes: String?

    init(request: TuneRequest, action: String = "generate_tune", notes: String? = nil) {
        self.action = action
        self.car = TuneAPICar(car: request.car)
        self.discipline = request.discipline.apiValue
        self.notes = notes
    }
}

struct TuneAPIAdjustmentPayload: Codable, Equatable {
    var action = "adjust_tune"
    var previousTune: TuneAPIResponse
    var adjustment: String

    enum CodingKeys: String, CodingKey {
        case action
        case previousTune = "previous_tune"
        case adjustment
    }
}

struct TuneAPICar: Codable, Equatable {
    var year: Int?
    var make: String
    var model: String
    var weightPounds: Int
    var frontWeightPercent: Double
    var performanceIndex: Int
    var performanceClass: String
    var drivetrain: String
    var peakHorsepower: Int?
    var peakTorqueFootPounds: Int?

    enum CodingKeys: String, CodingKey {
        case year
        case make
        case model
        case weightPounds = "weight_lb"
        case frontWeightPercent = "front_weight_pct"
        case performanceIndex = "pi"
        case performanceClass = "class"
        case drivetrain
        case peakHorsepower = "peak_hp"
        case peakTorqueFootPounds = "peak_torque_ftlb"
    }

    init(car: CarInput) {
        self.year = car.year
        self.make = car.make
        self.model = car.model
        self.weightPounds = car.weightPounds
        self.frontWeightPercent = car.frontWeightPercent
        self.performanceIndex = car.performanceIndex
        self.performanceClass = car.performanceClass.rawValue
        self.drivetrain = car.drivetrain.rawValue
        self.peakHorsepower = car.peakHorsepower
        self.peakTorqueFootPounds = car.peakTorqueFootPounds
    }
}

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
    var aero: TuneAPIFrontRear?
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
        aero: TuneAPIFrontRear? = nil,
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
            aero: TuneAPIFrontRear(section: result.section("Aero"), front: "Front", rear: "Rear"),
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
        self.gears = nil
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
