//
//  BundledFH6OfficialRoster.swift
//  forzadvisor
//
//  Strict loading and validation for the official FH6 identity sidecar.
//

import Foundation

enum FH6OfficialRosterLoadError:
    Error,
    Equatable,
    LocalizedError
{
    case missingResource(String)
    case unreadableResource(String)
    case decodingFailed
    case unsupportedSchemaVersion(Int)
    case unexpectedRevision(String)
    case unexpectedSourceURL
    case unexpectedSourceDate
    case unexpectedSourceDigest
    case wrongEntryCount(Int)
    case duplicateEntryID(String)
    case mismatchedID(String)
    case invalidIdentity(String)
    case invalidPerformance(String)

    var errorDescription: String? {
        switch self {
        case .missingResource:
            "The official FH6 roster could not be found."
        case .unreadableResource:
            "The official FH6 roster could not be read."
        case .decodingFailed:
            "The official FH6 roster is not valid JSON."
        case .unsupportedSchemaVersion(let version):
            "FH6 roster schema \(version) is not supported."
        case .unexpectedRevision:
            "The FH6 roster revision is not the reviewed revision."
        case .unexpectedSourceURL:
            "The FH6 roster does not identify the official source."
        case .unexpectedSourceDate:
            "The FH6 roster source date is not the reviewed date."
        case .unexpectedSourceDigest:
            "The FH6 roster source digest is not the reviewed digest."
        case .wrongEntryCount(let count):
            "The FH6 roster contains \(count) cars instead of 627."
        case .duplicateEntryID(let id):
            "FH6 roster entry \(id) is duplicated."
        case .mismatchedID(let id):
            "FH6 roster entry \(id) does not match its official identity."
        case .invalidIdentity(let id):
            "FH6 roster entry \(id) has an invalid identity."
        case .invalidPerformance(let id):
            "FH6 roster entry \(id) has invalid official PI/class data."
        }
    }
}

enum BundledFH6OfficialRoster {
    static let resourceName = "FH6OfficialRoster.v1"
    static let supportedSchemaVersion = 1
    static let expectedRevision = "2026.07.14.official"
    static let expectedSourceURL = URL(
        string: "https://forza.net/fh6cars"
    )!
    static let expectedSourceUpdatedAt = Date(
        timeIntervalSince1970: 1_783_987_200
    )
    static let expectedSourceSHA256 =
        "6d36d510e83d5649b3fd68008ec7f0c19ba98cbf824578dab329e4946f432317"
    static let expectedEntryCount = 627

    static func load(
        bundle: Bundle = Bundle(
            for: FH6OfficialRosterBundleToken.self
        ),
        resourceName: String = resourceName
    ) -> Result<
        FH6OfficialRosterSnapshot,
        FH6OfficialRosterLoadError
    > {
        guard let url = bundle.url(
            forResource: resourceName,
            withExtension: "json"
        ) else {
            return .failure(.missingResource(resourceName))
        }
        guard let data = try? Data(contentsOf: url) else {
            return .failure(.unreadableResource(resourceName))
        }
        return load(data: data)
    }

    static func load(
        data: Data
    ) -> Result<
        FH6OfficialRosterSnapshot,
        FH6OfficialRosterLoadError
    > {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let snapshot = try? decoder.decode(
            FH6OfficialRosterSnapshot.self,
            from: data
        ) else {
            return .failure(.decodingFailed)
        }
        if let error = validationError(in: snapshot) {
            return .failure(error)
        }
        return .success(snapshot)
    }

    private static func validationError(
        in snapshot: FH6OfficialRosterSnapshot
    ) -> FH6OfficialRosterLoadError? {
        guard snapshot.schemaVersion == supportedSchemaVersion else {
            return .unsupportedSchemaVersion(snapshot.schemaVersion)
        }
        guard snapshot.revision == expectedRevision else {
            return .unexpectedRevision(snapshot.revision)
        }
        guard snapshot.sourceURL == expectedSourceURL else {
            return .unexpectedSourceURL
        }
        guard snapshot.sourceUpdatedAt == expectedSourceUpdatedAt else {
            return .unexpectedSourceDate
        }
        guard snapshot.sourceSHA256 == expectedSourceSHA256 else {
            return .unexpectedSourceDigest
        }
        guard snapshot.entries.count == expectedEntryCount else {
            return .wrongEntryCount(snapshot.entries.count)
        }

        var identifiers: Set<String> = []
        for entry in snapshot.entries {
            guard identifiers.insert(entry.id).inserted else {
                return .duplicateEntryID(entry.id)
            }
            guard validIdentity(entry) else {
                return .invalidIdentity(entry.id)
            }
            guard entry.id == stableID(for: entry.officialDesignation) else {
                return .mismatchedID(entry.id)
            }
            guard let range = ForzaGame.fh6.performanceIndexRange(
                for: entry.performanceClass
            ),
                  range.contains(entry.performanceIndex) else {
                return .invalidPerformance(entry.id)
            }
        }
        return nil
    }

    private static func validIdentity(
        _ entry: FH6OfficialRosterEntry
    ) -> Bool {
        let make = entry.make.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let model = entry.model.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let designation = entry.officialDesignation.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        return entry.year > 0
            && make == entry.make
            && model == entry.model
            && designation == entry.officialDesignation
            && !make.isEmpty
            && !model.isEmpty
            && designation == "\(entry.year) \(make) \(model)"
            && [make, model, designation].allSatisfy { value in
                value.unicodeScalars.allSatisfy {
                    !CharacterSet.controlCharacters.contains($0)
                }
            }
    }

    private static func stableID(for designation: String) -> String {
        let folded = designation.folding(
            options: [.diacriticInsensitive, .caseInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
        let pieces = folded.unicodeScalars.split { scalar in
            !CharacterSet.alphanumerics.contains(scalar)
        }
        let slug = pieces
            .map(String.init)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
            .lowercased()
        return "fh6-\(slug)"
    }
}

private final class FH6OfficialRosterBundleToken {}

enum CarCatalogBrowseOverlayError:
    Error,
    Equatable,
    LocalizedError
{
    case reviewedIdentityMissing(ForzaGame, String)
    case reviewedIdentityMismatch(ForzaGame, String)

    var errorDescription: String? {
        switch self {
        case .reviewedIdentityMissing(let game, let id):
            "Reviewed \(game.shortTitle) car \(id) is missing from the official roster."
        case .reviewedIdentityMismatch(let game, let id):
            "Reviewed \(game.shortTitle) car \(id) does not match the official roster identity."
        }
    }
}

enum CarCatalogBrowseOverlay {
    static func make(
        catalog: CarCatalogSnapshot,
        fh5Roster: FH5OfficialRosterSnapshot,
        fh6Roster: FH6OfficialRosterSnapshot
    ) -> Result<CarCatalogBrowseSnapshot, CarCatalogBrowseOverlayError> {
        switch makeFH5Entries(
            catalog: catalog,
            roster: fh5Roster
        ) {
        case .failure(let error):
            return .failure(error)
        case .success(let fh5Entries):
            switch makeFH6Entries(
                catalog: catalog,
                roster: fh6Roster
            ) {
            case .failure(let error):
                return .failure(error)
            case .success(let fh6Entries):
                return .success(
                    CarCatalogBrowseSnapshot(
                        entries: fh5Entries + fh6Entries,
                        rosterIssueDescriptions: [:]
                    )
                )
            }
        }
    }

    static func resolve(
        catalog: CarCatalogSnapshot,
        fh5RosterResult: Result<
            FH5OfficialRosterSnapshot,
            FH5OfficialRosterLoadError
        >,
        fh6RosterResult: Result<
            FH6OfficialRosterSnapshot,
            FH6OfficialRosterLoadError
        >
    ) -> CarCatalogBrowseSnapshot {
        var entries: [CatalogBrowseEntry] = []
        var issues: [ForzaGame: String] = [:]

        switch fh5RosterResult {
        case .failure(let error):
            entries += fallback(catalog: catalog, game: .fh5)
            issues[.fh5] = error.localizedDescription
        case .success(let roster):
            switch makeFH5Entries(catalog: catalog, roster: roster) {
            case .success(let resolved):
                entries += resolved
            case .failure(let error):
                entries += fallback(catalog: catalog, game: .fh5)
                issues[.fh5] = error.localizedDescription
            }
        }

        switch fh6RosterResult {
        case .failure(let error):
            entries += fallback(catalog: catalog, game: .fh6)
            issues[.fh6] = error.localizedDescription
        case .success(let roster):
            switch makeFH6Entries(catalog: catalog, roster: roster) {
            case .success(let resolved):
                entries += resolved
            case .failure(let error):
                entries += fallback(catalog: catalog, game: .fh6)
                issues[.fh6] = error.localizedDescription
            }
        }

        return CarCatalogBrowseSnapshot(
            entries: entries,
            rosterIssueDescriptions: issues
        )
    }

    private static func makeFH5Entries(
        catalog: CarCatalogSnapshot,
        roster: FH5OfficialRosterSnapshot
    ) -> Result<[CatalogBrowseEntry], CarCatalogBrowseOverlayError> {
        let rosterByID = Dictionary(
            uniqueKeysWithValues: roster.entries.map { ($0.id, $0) }
        )
        let reviewed = catalog.entries.filter { $0.game == .fh5 }
        var selectionByID: [String: CatalogCarSelection] = [:]

        for entry in reviewed {
            guard let identity = rosterByID[entry.id] else {
                return .failure(
                    .reviewedIdentityMissing(.fh5, entry.id)
                )
            }
            guard entry.year == identity.year,
                  normalized(entry.displayName)
                    == normalized(identity.officialDesignation)
            else {
                return .failure(
                    .reviewedIdentityMismatch(.fh5, entry.id)
                )
            }
            selectionByID[entry.id] = catalog.selection(for: entry)
        }

        return .success(
            roster.entries.map { rosterEntry in
                let browseEntry = CatalogBrowseEntry(
                    rosterEntry: rosterEntry
                )
                guard let selection =
                    selectionByID[rosterEntry.id] else {
                    return browseEntry
                }
                return browseEntry.attaching(
                    reviewedSelection: selection
                )
            }
        )
    }

    private static func makeFH6Entries(
        catalog: CarCatalogSnapshot,
        roster: FH6OfficialRosterSnapshot
    ) -> Result<[CatalogBrowseEntry], CarCatalogBrowseOverlayError> {
        let rosterByID = Dictionary(
            uniqueKeysWithValues: roster.entries.map { ($0.id, $0) }
        )
        let reviewed = catalog.entries.filter { $0.game == .fh6 }
        var selectionByID: [String: CatalogCarSelection] = [:]

        for entry in reviewed {
            guard let identity = rosterByID[entry.id] else {
                return .failure(
                    .reviewedIdentityMissing(.fh6, entry.id)
                )
            }
            guard entry.year == identity.year,
                  entry.make == identity.make,
                  entry.model == identity.model else {
                return .failure(
                    .reviewedIdentityMismatch(.fh6, entry.id)
                )
            }
            selectionByID[entry.id] = catalog.selection(for: entry)
        }

        return .success(
            roster.entries.map { rosterEntry in
                let browseEntry = CatalogBrowseEntry(
                    rosterEntry: rosterEntry
                )
                guard let selection =
                    selectionByID[rosterEntry.id] else {
                    return browseEntry
                }
                return browseEntry.attaching(
                    reviewedSelection: selection
                )
            }
        )
    }

    static func search(
        _ snapshot: CarCatalogBrowseSnapshot,
        game: ForzaGame,
        query: String
    ) -> [CatalogBrowseEntry] {
        let normalizedQuery = normalized(query)
        return snapshot.entries.filter { entry in
            guard entry.game == game else { return false }
            return normalizedQuery.isEmpty
                || normalized(entry.displayName)
                    .contains(normalizedQuery)
        }
    }

    private static func fallback(
        catalog: CarCatalogSnapshot,
        game: ForzaGame
    ) -> [CatalogBrowseEntry] {
        catalog.entries
            .filter { $0.game == game }
            .map {
                CatalogBrowseEntry(
                    selection: catalog.selection(for: $0)
                )
            }
    }

    private static func normalized(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(
                options: [
                    .caseInsensitive,
                    .diacriticInsensitive,
                    .widthInsensitive
                ],
                locale: .current
            )
    }
}
