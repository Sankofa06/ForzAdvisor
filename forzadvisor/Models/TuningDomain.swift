//
//  TuningDomain.swift
//  forzadvisor
//
//  Core value types shared by manual entry, tune generation, tune display, and
//  future SwiftData/API boundaries.
//

import Foundation

enum PerformanceClass: String, CaseIterable, Codable, Identifiable, Sendable {
    case c = "C"
    case b = "B"
    case a = "A"
    case s1 = "S1"
    case s2 = "S2"
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
    var year: Int?
    var make: String
    var model: String
    var weightPounds: Int
    var frontWeightPercent: Double
    var performanceIndex: Int
    var performanceClass: PerformanceClass
    var drivetrain: Drivetrain
    var peakHorsepower: Int?
    var peakTorqueFootPounds: Int?

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

    var id: String { message }

    var message: String {
        switch self {
        case .missingName: "Add at least a make or model."
        case .invalidWeight: "Weight should be between 1,500 and 7,000 lb."
        case .invalidFrontWeight: "Front weight should be between 30% and 70%."
        case .invalidPerformanceIndex: "PI should be between 100 and 999."
        }
    }
}

struct TuneRequest: Codable, Equatable, Sendable {
    var car: CarInput
    var discipline: DrivingDiscipline
}

struct TuneResult: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    var request: TuneRequest
    var sections: [TuneSection]
    var notes: TuneNotes
    var generatedAt: Date = .now
    var providerInfo: TuneProviderInfo?

    enum CodingKeys: String, CodingKey {
        case id
        case request
        case sections
        case notes
        case generatedAt
        case providerInfo
    }

    init(
        id: UUID = UUID(),
        request: TuneRequest,
        sections: [TuneSection],
        notes: TuneNotes,
        generatedAt: Date = .now,
        providerInfo: TuneProviderInfo? = nil
    ) {
        self.id = id
        self.request = request
        self.sections = sections
        self.notes = notes
        self.generatedAt = generatedAt
        self.providerInfo = providerInfo
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        request = try container.decode(TuneRequest.self, forKey: .request)
        sections = try container.decode([TuneSection].self, forKey: .sections)
        notes = try container.decode(TuneNotes.self, forKey: .notes)
        generatedAt = try container.decode(Date.self, forKey: .generatedAt)
        providerInfo = try container.decodeIfPresent(TuneProviderInfo.self, forKey: .providerInfo)
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
