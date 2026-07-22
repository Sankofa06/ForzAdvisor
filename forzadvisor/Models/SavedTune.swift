//
//  SavedTune.swift
//  forzadvisor
//
//  SwiftData persistence model for garage entries. Stores searchable tune
//  metadata alongside the encoded TuneResult used by the tune detail screen.
//

import Foundation
import SwiftData

@Model
final class SavedTune {
    @Attribute(.unique) var id: UUID
    var carName: String
    var year: Int?
    var make: String = ""
    var model: String = ""
    var weightPounds: Int = 0
    var frontWeightPercent: Double = 0
    var disciplineRawValue: String
    var performanceClassRawValue: String
    var performanceIndex: Int
    var drivetrainRawValue: String
    var playerNotes: String = ""
    var generatedAt: Date
    var createdAt: Date
    var updatedAt: Date

    @Attribute(.externalStorage) private var tuneData: Data
    @Attribute(.externalStorage) var thumbnailData: Data?

    @MainActor
    init(
        tune: TuneResult,
        playerNotes: String = "",
        thumbnailData: Data? = nil,
        now: Date = .now
    ) throws {
        self.id = tune.id
        self.carName = tune.request.car.displayName
        self.year = tune.request.car.year
        self.make = tune.request.car.make
        self.model = tune.request.car.model
        self.weightPounds = tune.request.car.weightPounds
        self.frontWeightPercent = tune.request.car.frontWeightPercent
        self.disciplineRawValue = tune.request.discipline.rawValue
        self.performanceClassRawValue = tune.request.car.performanceClass.rawValue
        self.performanceIndex = tune.request.car.performanceIndex
        self.drivetrainRawValue = tune.request.car.drivetrain.rawValue
        self.playerNotes = playerNotes
        self.generatedAt = tune.generatedAt
        self.createdAt = now
        self.updatedAt = now
        self.tuneData = try Self.encoder.encode(tune)
        self.thumbnailData = thumbnailData
    }

    @MainActor
    var tuneResult: TuneResult? {
        try? Self.decoder.decode(TuneResult.self, from: tuneData)
    }

    var discipline: DrivingDiscipline? {
        DrivingDiscipline(rawValue: disciplineRawValue)
    }

    var disciplineTitle: String {
        discipline?.title ?? disciplineRawValue
    }

    var disciplineSymbolName: String {
        discipline?.symbolName ?? "wrench.adjustable"
    }

    @MainActor
    var carInput: CarInput? {
        if let storedCar = tuneResult?.request.car {
            return storedCar
        }

        guard let performanceClass = PerformanceClass(rawValue: performanceClassRawValue),
              let drivetrain = Drivetrain(rawValue: drivetrainRawValue)
        else { return nil }

        return CarInput(
            game: .fh6,
            year: year,
            make: make,
            model: model,
            weightPounds: weightPounds,
            frontWeightPercent: frontWeightPercent,
            performanceIndex: performanceIndex,
            performanceClass: performanceClass,
            drivetrain: drivetrain,
            peakHorsepower: tuneResult?.request.car.peakHorsepower,
            peakTorqueFootPounds: tuneResult?.request.car.peakTorqueFootPounds
        )
    }

    @MainActor
    func update(
        with tune: TuneResult,
        playerNotes: String? = nil,
        thumbnailData: Data? = nil,
        now: Date = .now
    ) throws {
        carName = tune.request.car.displayName
        year = tune.request.car.year
        make = tune.request.car.make
        model = tune.request.car.model
        weightPounds = tune.request.car.weightPounds
        frontWeightPercent = tune.request.car.frontWeightPercent
        disciplineRawValue = tune.request.discipline.rawValue
        performanceClassRawValue = tune.request.car.performanceClass.rawValue
        performanceIndex = tune.request.car.performanceIndex
        drivetrainRawValue = tune.request.car.drivetrain.rawValue
        if let playerNotes {
            self.playerNotes = playerNotes
        }
        generatedAt = tune.generatedAt
        updatedAt = now
        tuneData = try Self.encoder.encode(tune)
        if let thumbnailData {
            self.thumbnailData = thumbnailData
        }
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
