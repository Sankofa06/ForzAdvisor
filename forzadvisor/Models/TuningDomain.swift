//
//  TuningDomain.swift
//  forzadvisor
//
//  Core value types shared by manual entry, tune generation, tune display, and
//  future SwiftData/API boundaries.
//

import Foundation

enum ForzaGame: String, CaseIterable, Codable, Identifiable, Sendable {
    case fh5
    case fh6

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fh5: "Forza Horizon 5"
        case .fh6: "Forza Horizon 6"
        }
    }

    var shortTitle: String { rawValue.uppercased() }

    var supportedPerformanceClasses: [PerformanceClass] {
        switch self {
        case .fh5: [.d, .c, .b, .a, .s1, .s2, .x]
        case .fh6: [.d, .c, .b, .a, .s1, .s2, .r, .x]
        }
    }

    func performanceIndexRange(for performanceClass: PerformanceClass) -> ClosedRange<Int>? {
        switch (self, performanceClass) {
        case (.fh5, .d): 100...500
        case (.fh5, .c): 501...600
        case (.fh5, .b): 601...700
        case (.fh5, .a): 701...800
        case (.fh5, .s1): 801...900
        case (.fh5, .s2): 901...998
        case (.fh5, .x): 999...999
        case (.fh6, .d): 100...400
        case (.fh6, .c): 401...500
        case (.fh6, .b): 501...600
        case (.fh6, .a): 601...700
        case (.fh6, .s1): 701...800
        case (.fh6, .s2): 801...900
        case (.fh6, .r): 901...998
        case (.fh6, .x): 999...999
        default: nil
        }
    }
}

enum PerformanceClass: String, CaseIterable, Codable, Identifiable, Sendable {
    case d = "D"
    case c = "C"
    case b = "B"
    case a = "A"
    case s1 = "S1"
    case s2 = "S2"
    case r = "R"
    case x = "X"

    var id: String { rawValue }
}

enum Drivetrain: String, CaseIterable, Codable, Identifiable, Sendable {
    case fwd = "FWD"
    case rwd = "RWD"
    case awd = "AWD"

    var id: String { rawValue }
}

enum DrivingDiscipline: String, CaseIterable, Codable, Identifiable, Sendable {
    case road
    case touge
    case drift
    case dirt
    case crossCountry
    case drag

    var id: String { rawValue }

    var title: String {
        switch self {
        case .road: "Road"
        case .touge: "Touge"
        case .drift: "Drift"
        case .dirt: "Dirt/Rally"
        case .crossCountry: "Cross-Country"
        case .drag: "Drag"
        }
    }

    var symbolName: String {
        switch self {
        case .road: "road.lanes"
        case .touge: "mountain.2"
        case .drift: "arrow.triangle.2.circlepath"
        case .dirt: "cloud.dust"
        case .crossCountry: "suv.side"
        case .drag: "flag.checkered"
        }
    }

    var summary: String {
        switch self {
        case .road: "Balanced grip and predictable braking"
        case .touge: "Fast rotation for technical descents"
        case .drift: "Loose rear with recoverable angle"
        case .dirt: "Compliance for mixed loose surfaces"
        case .crossCountry: "Travel and stability for rough terrain"
        case .drag: "Launch grip and high-speed pull"
        }
    }
}

struct CarInput: Codable, Equatable, Sendable {
    var game: ForzaGame {
        didSet { clearCatalogReferenceIfChanged(from: oldValue, to: game) }
    }
    var year: Int? {
        didSet { clearCatalogReferenceIfChanged(from: oldValue, to: year) }
    }
    var make: String {
        didSet { clearCatalogReferenceIfChanged(from: oldValue, to: make) }
    }
    var model: String {
        didSet { clearCatalogReferenceIfChanged(from: oldValue, to: model) }
    }
    var weightPounds: Int {
        didSet { markCatalogValuesModifiedIfChanged(from: oldValue, to: weightPounds) }
    }
    var frontWeightPercent: Double {
        didSet { markCatalogValuesModifiedIfChanged(from: oldValue, to: frontWeightPercent) }
    }
    var performanceIndex: Int {
        didSet { markCatalogValuesModifiedIfChanged(from: oldValue, to: performanceIndex) }
    }
    var performanceClass: PerformanceClass {
        didSet { markCatalogValuesModifiedIfChanged(from: oldValue, to: performanceClass) }
    }
    var drivetrain: Drivetrain {
        didSet { markCatalogValuesModifiedIfChanged(from: oldValue, to: drivetrain) }
    }
    var peakHorsepower: Int? {
        didSet { markCatalogValuesModifiedIfChanged(from: oldValue, to: peakHorsepower) }
    }
    var peakTorqueFootPounds: Int? {
        didSet { markCatalogValuesModifiedIfChanged(from: oldValue, to: peakTorqueFootPounds) }
    }
    var catalogReference: CatalogCarReference?
    var catalogValuesModified: Bool

    enum CodingKeys: String, CodingKey {
        case game
        case year
        case make
        case model
        case weightPounds
        case frontWeightPercent
        case performanceIndex
        case performanceClass
        case drivetrain
        case peakHorsepower
        case peakTorqueFootPounds
        case catalogReference
        case catalogValuesModified
    }

    init(
        game: ForzaGame = .fh6,
        year: Int?,
        make: String,
        model: String,
        weightPounds: Int,
        frontWeightPercent: Double,
        performanceIndex: Int,
        performanceClass: PerformanceClass,
        drivetrain: Drivetrain,
        peakHorsepower: Int?,
        peakTorqueFootPounds: Int?,
        catalogReference: CatalogCarReference? = nil,
        catalogValuesModified: Bool = false
    ) {
        self.game = game
        self.year = year
        self.make = make
        self.model = model
        self.weightPounds = weightPounds
        self.frontWeightPercent = frontWeightPercent
        self.performanceIndex = performanceIndex
        self.performanceClass = performanceClass
        self.drivetrain = drivetrain
        self.peakHorsepower = peakHorsepower
        self.peakTorqueFootPounds = peakTorqueFootPounds
        self.catalogReference = catalogReference
        self.catalogValuesModified = catalogReference != nil && catalogValuesModified
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        game = try container.decodeIfPresent(ForzaGame.self, forKey: .game) ?? .fh6
        year = try container.decodeIfPresent(Int.self, forKey: .year)
        make = try container.decode(String.self, forKey: .make)
        model = try container.decode(String.self, forKey: .model)
        weightPounds = try container.decode(Int.self, forKey: .weightPounds)
        frontWeightPercent = try container.decode(Double.self, forKey: .frontWeightPercent)
        performanceIndex = try container.decode(Int.self, forKey: .performanceIndex)
        performanceClass = try container.decode(PerformanceClass.self, forKey: .performanceClass)
        drivetrain = try container.decode(Drivetrain.self, forKey: .drivetrain)
        peakHorsepower = try container.decodeIfPresent(Int.self, forKey: .peakHorsepower)
        peakTorqueFootPounds = try container.decodeIfPresent(Int.self, forKey: .peakTorqueFootPounds)
        catalogReference = try container.decodeIfPresent(CatalogCarReference.self, forKey: .catalogReference)
        let decodedCatalogValuesModified = try container.decodeIfPresent(
            Bool.self,
            forKey: .catalogValuesModified
        ) ?? false
        catalogValuesModified = catalogReference != nil && decodedCatalogValuesModified
    }

    private mutating func clearCatalogReferenceIfChanged<Value: Equatable>(
        from oldValue: Value,
        to newValue: Value
    ) {
        if oldValue != newValue {
            catalogReference = nil
            catalogValuesModified = false
        }
    }

    private mutating func markCatalogValuesModifiedIfChanged<Value: Equatable>(
        from oldValue: Value,
        to newValue: Value
    ) {
        if catalogReference != nil, oldValue != newValue {
            catalogValuesModified = true
        }
    }

    var displayName: String {
        let name = [make, model]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        guard let year else { return name.isEmpty ? "Untitled car" : name }
        return name.isEmpty ? "\(year) car" : "\(year) \(name)"
    }

    var validationIssues: [ValidationIssue] {
        var issues: [ValidationIssue] = []
        if make.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.missingName)
        }
        if !(1500...7000).contains(weightPounds) {
            issues.append(.invalidWeight)
        }
        if !(30...70).contains(frontWeightPercent) {
            issues.append(.invalidFrontWeight)
        }
        if !(100...999).contains(performanceIndex) {
            issues.append(.invalidPerformanceIndex)
        } else if let classRange = game.performanceIndexRange(for: performanceClass) {
            if !classRange.contains(performanceIndex) {
                issues.append(.performanceIndexOutsideClass(game, performanceClass, classRange))
            }
        } else {
            issues.append(.unsupportedPerformanceClass(game, performanceClass))
        }
        return issues
    }

    var isValid: Bool {
        validationIssues.isEmpty
    }
}

enum ValidationIssue: Identifiable, Equatable {
    case missingName
    case invalidWeight
    case invalidFrontWeight
    case invalidPerformanceIndex
    case unsupportedPerformanceClass(ForzaGame, PerformanceClass)
    case performanceIndexOutsideClass(ForzaGame, PerformanceClass, ClosedRange<Int>)

    var id: String { message }

    var message: String {
        switch self {
        case .missingName: "Add at least a make or model."
        case .invalidWeight: "Weight should be between 1,500 and 7,000 lb."
        case .invalidFrontWeight: "Front weight should be between 30% and 70%."
        case .invalidPerformanceIndex: "PI should be between 100 and 999."
        case .unsupportedPerformanceClass(let game, let performanceClass):
            "Class \(performanceClass.rawValue) is not supported by \(game.shortTitle)."
        case .performanceIndexOutsideClass(let game, let performanceClass, let range):
            "\(game.shortTitle) class \(performanceClass.rawValue) uses PI \(range.lowerBound)-\(range.upperBound)."
        }
    }
}

struct TuneRequest: Codable, Equatable, Sendable {
    var car: CarInput
    var discipline: DrivingDiscipline
    var buildSnapshot: VehicleBuildSnapshot? = nil
}

struct TuneResult: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    var request: TuneRequest
    var sections: [TuneSection]
    var notes: TuneNotes
    var generatedAt: Date = .now
    var providerInfo: TuneProviderInfo?
    var rulesetReference: TuneRulesetReference?

    enum CodingKeys: String, CodingKey {
        case id
        case request
        case sections
        case notes
        case generatedAt
        case providerInfo
        case rulesetReference
    }

    init(
        id: UUID = UUID(),
        request: TuneRequest,
        sections: [TuneSection],
        notes: TuneNotes,
        generatedAt: Date = .now,
        providerInfo: TuneProviderInfo? = nil,
        rulesetReference: TuneRulesetReference? = nil
    ) {
        self.id = id
        self.request = request
        self.sections = sections
        self.notes = notes
        self.generatedAt = generatedAt
        self.providerInfo = providerInfo
        self.rulesetReference = rulesetReference
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        request = try container.decode(TuneRequest.self, forKey: .request)
        sections = try container.decode([TuneSection].self, forKey: .sections)
        notes = try container.decode(TuneNotes.self, forKey: .notes)
        generatedAt = try container.decode(Date.self, forKey: .generatedAt)
        providerInfo = try container.decodeIfPresent(TuneProviderInfo.self, forKey: .providerInfo)
        rulesetReference = try container.decodeIfPresent(TuneRulesetReference.self, forKey: .rulesetReference)
    }
}

struct TuneSection: Identifiable, Codable, Equatable, Sendable {
    var id: String { title }
    var title: String
    var symbolName: String
    var lines: [TuneLine]
}

struct TuneLine: Identifiable, Codable, Equatable, Sendable {
    var id: String { "\(label)-\(value)-\(unit)" }
    var label: String
    var value: String
    var unit: String
    var detail: String?
    var fieldID: TuneFieldID? = nil

    var copyText: String {
        unit.isEmpty ? "\(label): \(value)" : "\(label): \(value) \(unit)"
    }
}

struct TuneNotes: Codable, Equatable, Sendable {
    var bias: String
    var ifPushesWide: String
    var ifSnapsOnLift: String
    var retuneTrigger: String
}

enum SampleTuningData {
    static let starterCar = CarInput(
        year: 2019,
        make: "Toyota",
        model: "Supra",
        weightPounds: 3340,
        frontWeightPercent: 53,
        performanceIndex: 750,
        performanceClass: .s1,
        drivetrain: .rwd,
        peakHorsepower: 480,
        peakTorqueFootPounds: 410
    )
}
