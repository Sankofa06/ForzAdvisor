//
//  FH6OfficialRoster.swift
//  forzadvisor
//
//  Official FH6 identity and PI/class data, deliberately separate from
//  reviewed stock specifications used for tuning.
//

import Foundation

struct OfficialRosterCarIdentity:
    Equatable,
    Identifiable,
    Sendable
{
    let id: String
    let game: ForzaGame
    let year: Int
    let make: String
    let model: String
    let officialDesignation: String
    let performanceIndex: Int?
    let performanceClass: PerformanceClass?
}

struct FH5OfficialRosterEntry:
    Codable,
    Equatable,
    Identifiable,
    Sendable
{
    let id: String
    let year: Int
    let officialDesignation: String
    let carType: String
    let collect: String
    let added: String
    let nickname: String
    let officialID: Int

    var displayName: String {
        officialDesignation
    }

    var genericModel: String {
        String(
            officialDesignation.dropFirst(
                String(year).count + 1
            )
        )
    }

    var identity: OfficialRosterCarIdentity {
        OfficialRosterCarIdentity(
            id: id,
            game: .fh5,
            year: year,
            make: "",
            model: genericModel,
            officialDesignation: officialDesignation,
            performanceIndex: nil,
            performanceClass: nil
        )
    }
}

struct FH5OfficialRosterSnapshot: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let revision: String
    let sourceURL: URL
    let sourceUpdatedAt: Date
    let sourceSHA256: String
    let entries: [FH5OfficialRosterEntry]
}

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

    var identity: OfficialRosterCarIdentity {
        OfficialRosterCarIdentity(
            id: id,
            game: .fh6,
            year: year,
            make: make,
            model: model,
            officialDesignation: officialDesignation,
            performanceIndex: performanceIndex,
            performanceClass: performanceClass
        )
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
    let officialPerformanceIndex: Int?
    let officialPerformanceClass: PerformanceClass?
    let reviewedSelection: CatalogCarSelection?

    var displayName: String {
        officialDesignation
    }

    var isReviewedStock: Bool {
        reviewedSelection != nil
    }

    var identity: OfficialRosterCarIdentity {
        OfficialRosterCarIdentity(
            id: id,
            game: game,
            year: year,
            make: make,
            model: model,
            officialDesignation: officialDesignation,
            performanceIndex: officialPerformanceIndex,
            performanceClass: officialPerformanceClass
        )
    }

    init(rosterEntry: FH5OfficialRosterEntry) {
        self.init(identity: rosterEntry.identity)
    }

    init(rosterEntry: FH6OfficialRosterEntry) {
        self.init(identity: rosterEntry.identity)
    }

    init(identity: OfficialRosterCarIdentity) {
        id = identity.id
        game = identity.game
        year = identity.year
        make = identity.make
        model = identity.model
        officialDesignation = identity.officialDesignation
        officialPerformanceIndex = identity.performanceIndex
        officialPerformanceClass = identity.performanceClass
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
        officialPerformanceIndex: Int?,
        officialPerformanceClass: PerformanceClass?,
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
    let rosterIssueDescriptions: [ForzaGame: String]

    func rosterIssueDescription(
        for game: ForzaGame
    ) -> String? {
        rosterIssueDescriptions[game]
    }
}
