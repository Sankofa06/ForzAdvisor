//
//  FH6OfficialRoster.swift
//  forzadvisor
//
//  Official FH6 identity and PI/class data, deliberately separate from
//  reviewed stock specifications used for tuning.
//

import Foundation

struct FH6OfficialRosterEntry:
    Codable,
    Equatable,
    Identifiable,
    Sendable
{
    let id: String
    let year: Int
    let make: String
    let model: String
    let officialDesignation: String
    let performanceIndex: Int
    let performanceClass: PerformanceClass

    var displayName: String {
        officialDesignation
    }
}

struct FH6OfficialRosterSnapshot: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let revision: String
    let sourceURL: URL
    let sourceUpdatedAt: Date
    let sourceSHA256: String
    let entries: [FH6OfficialRosterEntry]
}

struct CatalogBrowseEntry: Equatable, Identifiable, Sendable {
    let id: String
    let game: ForzaGame
    let year: Int
    let make: String
    let model: String
    let officialDesignation: String
    let officialPerformanceIndex: Int
    let officialPerformanceClass: PerformanceClass
    let reviewedSelection: CatalogCarSelection?

    var displayName: String {
        officialDesignation
    }

    var isReviewedStock: Bool {
        reviewedSelection != nil
    }

    init(rosterEntry: FH6OfficialRosterEntry) {
        id = rosterEntry.id
        game = .fh6
        year = rosterEntry.year
        make = rosterEntry.make
        model = rosterEntry.model
        officialDesignation = rosterEntry.officialDesignation
        officialPerformanceIndex = rosterEntry.performanceIndex
        officialPerformanceClass = rosterEntry.performanceClass
        reviewedSelection = nil
    }

    init(selection: CatalogCarSelection) {
        let entry = selection.entry
        id = entry.id
        game = entry.game
        year = entry.year
        make = entry.make
        model = entry.model
        officialDesignation = entry.displayName
        officialPerformanceIndex = entry.stock.performanceIndex
        officialPerformanceClass = entry.stock.performanceClass
        reviewedSelection = selection
    }

    func attaching(
        reviewedSelection: CatalogCarSelection
    ) -> CatalogBrowseEntry {
        CatalogBrowseEntry(
            id: id,
            game: game,
            year: year,
            make: make,
            model: model,
            officialDesignation: officialDesignation,
            officialPerformanceIndex: officialPerformanceIndex,
            officialPerformanceClass: officialPerformanceClass,
            reviewedSelection: reviewedSelection
        )
    }

    private init(
        id: String,
        game: ForzaGame,
        year: Int,
        make: String,
        model: String,
        officialDesignation: String,
        officialPerformanceIndex: Int,
        officialPerformanceClass: PerformanceClass,
        reviewedSelection: CatalogCarSelection?
    ) {
        self.id = id
        self.game = game
        self.year = year
        self.make = make
        self.model = model
        self.officialDesignation = officialDesignation
        self.officialPerformanceIndex = officialPerformanceIndex
        self.officialPerformanceClass = officialPerformanceClass
        self.reviewedSelection = reviewedSelection
    }
}

struct CarCatalogBrowseSnapshot: Equatable, Sendable {
    let entries: [CatalogBrowseEntry]
    let rosterIssueDescription: String?
}
