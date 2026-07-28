//
//  StockCatalogOfficialRosterPicker.swift
//  forzadvisor
//
//  Pure identity-only selection support for stock catalog contributions.
//

import Foundation

extension StockCatalogContributionDraft {
    var isPristineGameOnly: Bool {
        self == StockCatalogContributionDraft(game: game)
    }

    @discardableResult
    mutating func applyOfficialRosterIdentityIfPristine(
        _ identity: OfficialRosterCarIdentity
    ) -> Bool {
        guard isPristineGameOnly else {
            return false
        }
        self = StockCatalogContributionDraft(
            officialRosterIdentity: identity
        )
        return true
    }
}

struct StockCatalogOfficialRosterPickerEntry:
    Equatable,
    Identifiable,
    Sendable
{
    let identity: OfficialRosterCarIdentity
    let localCaptureCount: Int

    init(
        identity: OfficialRosterCarIdentity,
        localCaptureCount: Int
    ) {
        self.identity = identity
        self.localCaptureCount = max(0, localCaptureCount)
    }

    var id: String {
        identity.id
    }

    var game: ForzaGame {
        identity.game
    }

    var displayName: String {
        identity.officialDesignation
    }

    var localCaptureStatus: String {
        switch localCaptureCount {
        case 0:
            "No local captures"
        case 1:
            "1 local capture"
        default:
            "\(localCaptureCount) local captures"
        }
    }
}

struct StockCatalogOfficialRosterPickerSnapshot:
    Equatable,
    Sendable
{
    struct GameRoster: Equatable, Sendable {
        let entries: [StockCatalogOfficialRosterPickerEntry]
        let localizedIssue: String?

        var isAvailable: Bool {
            localizedIssue == nil
        }
    }

    let fh5: GameRoster
    let fh6: GameRoster

    init(
        fh5Result: Result<
            FH5OfficialRosterSnapshot,
            FH5OfficialRosterLoadError
        >,
        fh6Result: Result<
            FH6OfficialRosterSnapshot,
            FH6OfficialRosterLoadError
        >,
        capturedRecords: [StockCatalogContributionRecord] = []
    ) {
        let coverage = StockCatalogOfficialRosterCoverage(
            capturedRecords: capturedRecords
        )
        switch fh5Result {
        case .success(let snapshot):
            fh5 = GameRoster(
                entries: snapshot.entries.map {
                    StockCatalogOfficialRosterPickerEntry(
                        identity: $0.identity,
                        localCaptureCount: coverage.localCaptureCount(
                            for: $0.identity
                        )
                    )
                },
                localizedIssue: nil
            )
        case .failure(let error):
            fh5 = GameRoster(
                entries: [],
                localizedIssue: error.localizedDescription
            )
        }

        switch fh6Result {
        case .success(let snapshot):
            fh6 = GameRoster(
                entries: snapshot.entries.map {
                    StockCatalogOfficialRosterPickerEntry(
                        identity: $0.identity,
                        localCaptureCount: coverage.localCaptureCount(
                            for: $0.identity
                        )
                    )
                },
                localizedIssue: nil
            )
        case .failure(let error):
            fh6 = GameRoster(
                entries: [],
                localizedIssue: error.localizedDescription
            )
        }
    }

    func roster(for game: ForzaGame) -> GameRoster {
        switch game {
        case .fh5:
            fh5
        case .fh6:
            fh6
        }
    }

    func entries(
        for game: ForzaGame,
        matching query: String,
        coverageFilter: StockCatalogOfficialRosterCoverageFilter = .all
    ) -> [StockCatalogOfficialRosterPickerEntry] {
        let roster = roster(for: game)
        guard roster.isAvailable else {
            return []
        }
        let normalizedQuery =
            StockCatalogOfficialRosterCoverage.normalized(query)
        return roster.entries.filter { entry in
            let includesQuery = normalizedQuery.isEmpty
                || StockCatalogOfficialRosterCoverage.normalized(
                    entry.displayName
                )
                .contains(normalizedQuery)
            let includesCoverage: Bool
            switch coverageFilter {
            case .all:
                includesCoverage = true
            case .needsLocalCapture:
                includesCoverage = entry.localCaptureCount == 0
            }
            return includesQuery && includesCoverage
        }
    }
}
