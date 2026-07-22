//
//  CarCatalog.swift
//  forzadvisor
//
//  Versioned, source-attributed bundled car catalog values.
//

import Foundation

enum CatalogVerificationStatus: String, Codable, Sendable {
    case officialRoster
    case communityCrossChecked
    case inGameVerified

    var label: String {
        switch self {
        case .officialRoster: "Official roster"
        case .communityCrossChecked: "Community-crosschecked"
        case .inGameVerified: "In-game verified"
        }
    }

    var disclaimer: String {
        switch self {
        case .inGameVerified: "Verified against the current in-game upgrade screen."
        case .officialRoster, .communityCrossChecked:
            "Confirm these stock values in your game before tuning."
        }
    }
}

enum CatalogSourceRole: String, Codable, Sendable {
    case officialRoster
    case communityQA
}

enum CatalogDataField: String, CaseIterable, Codable, Sendable {
    case identity
    case performanceIndex
    case performanceClass
    case drivetrain
    case weightPounds
    case frontWeightPercent
    case peakHorsepower
    case peakTorqueFootPounds
}

struct CatalogSource: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let url: URL
    let role: CatalogSourceRole
    let fields: [CatalogDataField]
}

struct CatalogStockSpecifications: Codable, Equatable, Sendable {
    let performanceIndex: Int
    let performanceClass: PerformanceClass
    let drivetrain: Drivetrain
    let weightPounds: Int
    let frontWeightPercent: Double
    let peakHorsepower: Int
    let peakTorqueFootPounds: Int
}

struct CatalogCarEntry: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let game: ForzaGame
    let year: Int
    let make: String
    let model: String
    let stock: CatalogStockSpecifications
    let verificationStatus: CatalogVerificationStatus
    let sources: [CatalogSource]

    var displayName: String {
        "\(year) \(make) \(model)"
    }

    var capabilityProfile: TuneVehicleCapabilityProfile {
        TuneVehicleCapabilityProfile(
            vehicle: TuneVehicleIdentity(
                game: game,
                catalogID: id,
                year: year,
                make: make,
                model: model
            ),
            drivetrain: stock.drivetrain,
            parts: [],
            stockAdjustableSettings: []
        )
    }
}

struct CarCatalogSnapshot: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let revision: String
    let reviewedAt: Date
    let entries: [CatalogCarEntry]

    func selection(for entry: CatalogCarEntry) -> CatalogCarSelection {
        CatalogCarSelection(
            entry: entry,
            reference: CatalogCarReference(
                entryID: entry.id,
                revision: revision,
                reviewedAt: reviewedAt,
                verificationStatus: entry.verificationStatus,
                sources: entry.sources
            )
        )
    }
}

struct CatalogCarReference: Codable, Equatable, Sendable {
    let entryID: String
    let revision: String
    let reviewedAt: Date
    let verificationStatus: CatalogVerificationStatus
    let sources: [CatalogSource]
}

struct CatalogCarSelection: Codable, Equatable, Sendable {
    let entry: CatalogCarEntry
    let reference: CatalogCarReference

    var carInput: CarInput {
        CarInput(
            game: entry.game,
            year: entry.year,
            make: entry.make,
            model: entry.model,
            weightPounds: entry.stock.weightPounds,
            frontWeightPercent: entry.stock.frontWeightPercent,
            performanceIndex: entry.stock.performanceIndex,
            performanceClass: entry.stock.performanceClass,
            drivetrain: entry.stock.drivetrain,
            peakHorsepower: entry.stock.peakHorsepower,
            peakTorqueFootPounds: entry.stock.peakTorqueFootPounds,
            catalogReference: reference
        )
    }
}
