//
//  BundledFH5OfficialRoster.swift
//  forzadvisor
//
//  Strict loading for the official FH5 identity/listing sidecar.
//

import Foundation

enum FH5OfficialRosterLoadError:
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
    case incompleteListingMetadata(String)
    case unexpectedPerformance(String)

    var errorDescription: String? {
        switch self {
        case .missingResource:
            "The official FH5 roster could not be found."
        case .unreadableResource:
            "The official FH5 roster could not be read."
        case .decodingFailed:
            "The official FH5 roster is not valid JSON."
        case .unsupportedSchemaVersion(let version):
            "FH5 roster schema \(version) is not supported."
        case .unexpectedRevision:
            "The FH5 roster revision is not the reviewed revision."
        case .unexpectedSourceURL:
            "The FH5 roster does not identify the official source."
        case .unexpectedSourceDate:
            "The FH5 roster source date is not the reviewed date."
        case .unexpectedSourceDigest:
            "The FH5 roster source digest is not the reviewed digest."
        case .wrongEntryCount(let count):
            "The FH5 roster contains \(count) cars instead of 902."
        case .duplicateEntryID(let id):
            "FH5 roster entry \(id) is duplicated."
        case .mismatchedID(let id):
            "FH5 roster entry \(id) does not match its official identity."
        case .invalidIdentity(let id):
            "FH5 roster entry \(id) has an invalid identity."
        case .incompleteListingMetadata(let id):
            "FH5 roster entry \(id) has incomplete official listing metadata."
        case .unexpectedPerformance(let id):
            "FH5 roster entry \(id) contains unsupported PI/class data."
        }
    }
}

enum BundledFH5OfficialRoster {
    static let resourceName = "FH5OfficialRoster.v1"
    static let supportedSchemaVersion = 1
    static let expectedRevision = "2026.03.26.official"
    static let expectedSourceURL = URL(
        string: "https://forza.net/fh5cars/"
    )!
    static let expectedSourceUpdatedAt = Date(
        timeIntervalSince1970: 1_774_483_200
    )
    static let expectedSourceSHA256 =
        "e408fc57d88de9e34fc81da5a0aad31df97f089cc8f058955ed279d683ef0483"
    static let expectedEntryCount = 902

    static func load(
        bundle: Bundle = Bundle(
            for: FH5OfficialRosterBundleToken.self
        ),
        resourceName: String = resourceName
    ) -> Result<
        FH5OfficialRosterSnapshot,
        FH5OfficialRosterLoadError
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
        FH5OfficialRosterSnapshot,
        FH5OfficialRosterLoadError
    > {
        if let structureError = structureError(in: data) {
            return .failure(structureError)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let snapshot = try? decoder.decode(
            FH5OfficialRosterSnapshot.self,
            from: data
        ) else {
            return .failure(.decodingFailed)
        }
        if let error = validationError(in: snapshot) {
            return .failure(error)
        }
        return .success(snapshot)
    }

    private static func structureError(
        in data: Data
    ) -> FH5OfficialRosterLoadError? {
        guard let root = try? JSONSerialization
            .jsonObject(with: data) as? [String: Any],
              Set(root.keys) == [
                  "schemaVersion",
                  "revision",
                  "sourceURL",
                  "sourceUpdatedAt",
                  "sourceSHA256",
                  "entries"
              ],
              let entries = root["entries"] as? [[String: Any]]
        else {
            return .decodingFailed
        }
        let exactEntryKeys: Set<String> = [
            "id",
            "year",
            "officialDesignation",
            "carType",
            "collect",
            "added",
            "nickname",
            "officialID"
        ]
        for entry in entries {
            let id = entry["id"] as? String ?? "unknown"
            let keys = Set(entry.keys)
            if keys.contains("performanceIndex")
                || keys.contains("performanceClass") {
                return .unexpectedPerformance(id)
            }
            guard keys == exactEntryKeys else {
                return .incompleteListingMetadata(id)
            }
        }
        return nil
    }

    private static func validationError(
        in snapshot: FH5OfficialRosterSnapshot
    ) -> FH5OfficialRosterLoadError? {
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
            guard entry.id == stableID(
                for: entry.officialDesignation
            ) else {
                return .mismatchedID(entry.id)
            }
            guard entry.officialID > 0,
                  [
                      entry.carType,
                      entry.collect,
                      entry.added,
                      entry.nickname
                  ].allSatisfy(validMetadata)
            else {
                return .incompleteListingMetadata(entry.id)
            }
        }
        return nil
    }

    private static func validIdentity(
        _ entry: FH5OfficialRosterEntry
    ) -> Bool {
        let designation = entry.officialDesignation
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return entry.year > 0
            && designation == entry.officialDesignation
            && designation.hasPrefix("\(entry.year) ")
            && !entry.genericModel.isEmpty
            && validMetadata(designation)
    }

    nonisolated private static func validMetadata(
        _ value: String
    ) -> Bool {
        !value.isEmpty
            && value == value.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            && value.unicodeScalars.allSatisfy {
                !CharacterSet.controlCharacters.contains($0)
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
        return "fh5-\(slug)"
    }
}

private final class FH5OfficialRosterBundleToken {}
