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
