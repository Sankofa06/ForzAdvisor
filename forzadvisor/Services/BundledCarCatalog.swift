//
//  BundledCarCatalog.swift
//  forzadvisor
//
//  Safe resource loading, validation, and normalized game-scoped search.
//

import Foundation

enum CatalogLoadError: Error, Equatable, LocalizedError {
    case missingResource(String)
    case unreadableResource(String)
    case decodingFailed
    case unsupportedSchemaVersion(Int)
    case emptyCatalog
    case duplicateEntryID(String)
    case mismatchedIDPrefix(String)
    case invalidCarInput(String)
    case missingProvenance(String)
    case missingSourceRole(String, CatalogSourceRole)
    case duplicateSourceID(String, String)
    case invalidSource(String, String)
    case uncoveredField(String, CatalogDataField)
    case invalidLegacyEntryCount

    var errorDescription: String? {
        switch self {
        case .missingResource: "The bundled car catalog could not be found."
        case .unreadableResource: "The bundled car catalog could not be read."
        case .decodingFailed: "The bundled car catalog is not valid JSON."
        case .unsupportedSchemaVersion(let version):
            "Car catalog schema \(version) is not supported."
        case .emptyCatalog: "The bundled car catalog is empty."
        case .duplicateEntryID(let id): "Car catalog entry \(id) is duplicated."
        case .mismatchedIDPrefix(let id): "Car catalog entry \(id) has the wrong game prefix."
        case .invalidCarInput(let id): "Car catalog entry \(id) has invalid stock values."
        case .missingProvenance(let id): "Car catalog entry \(id) has no provenance."
        case .missingSourceRole(let id, let role):
            "Car catalog entry \(id) is missing source role \(role.rawValue)."
        case .duplicateSourceID(let entryID, let sourceID):
            "Car catalog source \(sourceID) is duplicated for \(entryID)."
        case .invalidSource(let entryID, let sourceID):
            "Car catalog source \(sourceID) for \(entryID) is invalid."
        case .uncoveredField(let id, let field):
            "Car catalog field \(field.rawValue) is not sourced for \(id)."
        case .invalidLegacyEntryCount:
            "A schema-v2 catalog must identify its unchanged schema-v1 entry prefix."
        }
    }
}

enum BundledCarCatalog {
    static let resourceName = "CarCatalog.v1"
    static let supportedSchemaVersions: Set<Int> = [1, 2]
    static let supportedSchemaVersion = 1

    static func load(
        bundle: Bundle = Bundle(for: CarCatalogBundleToken.self),
        resourceName: String = resourceName
    ) -> Result<CarCatalogSnapshot, CatalogLoadError> {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            return .failure(.missingResource(resourceName))
        }

        guard let data = try? Data(contentsOf: url) else {
            return .failure(.unreadableResource(resourceName))
        }

        return load(data: data)
    }

    static func load(data: Data) -> Result<CarCatalogSnapshot, CatalogLoadError> {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let snapshot = try? decoder.decode(CarCatalogSnapshot.self, from: data) else {
            return .failure(.decodingFailed)
        }

        if let validationError = validationError(in: snapshot) {
            return .failure(validationError)
        }

        return .success(snapshot)
    }

    static func search(
        _ snapshot: CarCatalogSnapshot,
        game: ForzaGame,
        query: String
    ) -> [CatalogCarEntry] {
        let normalizedQuery = normalized(query)

        return snapshot.entries.filter { entry in
            guard entry.game == game else { return false }
            guard !normalizedQuery.isEmpty else { return true }
            return normalized(entry.displayName).contains(normalizedQuery)
        }
    }

    private static func validationError(
        in snapshot: CarCatalogSnapshot
    ) -> CatalogLoadError? {
        guard supportedSchemaVersions.contains(snapshot.schemaVersion) else {
            return .unsupportedSchemaVersion(snapshot.schemaVersion)
        }
        guard !snapshot.entries.isEmpty else { return .emptyCatalog }
        let legacyEntryCount: Int
        if snapshot.schemaVersion == 1 {
            guard snapshot.legacyEntryCount == nil else {
                return .invalidLegacyEntryCount
            }
            legacyEntryCount = snapshot.entries.count
        } else {
            guard let count = snapshot.legacyEntryCount,
                  count >= 0,
                  count < snapshot.entries.count else {
                return .invalidLegacyEntryCount
            }
            legacyEntryCount = count
        }

        var entryIDs: Set<String> = []
        for (entryIndex, entry) in snapshot.entries.enumerated() {
            let usesLegacyProvenance =
                entryIndex < legacyEntryCount
            guard entryIDs.insert(entry.id).inserted else {
                return .duplicateEntryID(entry.id)
            }
            guard entry.id.hasPrefix("\(entry.game.rawValue)-") else {
                return .mismatchedIDPrefix(entry.id)
            }

            let selection = snapshot.selection(for: entry)
            guard entry.year > 0,
                  entry.stock.peakHorsepower > 0,
                  entry.stock.peakTorqueFootPounds > 0,
                  selection.carInput.isValid else {
                return .invalidCarInput(entry.id)
            }
            guard !entry.sources.isEmpty else {
                return .missingProvenance(entry.id)
            }

            var sourceIDs: Set<String> = []
            var sourceTitles: Set<String> = []
            for source in entry.sources {
                guard sourceIDs.insert(source.id).inserted else {
                    return .duplicateSourceID(entry.id, source.id)
                }
                let safeID = source.id.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                let safeTitle = source.title.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                guard source.id == safeID,
                      source.title == safeTitle,
                      !safeID.isEmpty,
                      !safeTitle.isEmpty,
                      safeID.unicodeScalars.allSatisfy({
                          !CharacterSet.controlCharacters
                              .contains($0)
                      }),
                      safeTitle.unicodeScalars.allSatisfy({
                          !CharacterSet.controlCharacters
                              .contains($0)
                      }),
                      sourceTitles.insert(safeTitle).inserted,
                      !source.fields.isEmpty,
                      Set(source.fields).count == source.fields.count else {
                    return .invalidSource(entry.id, source.id)
                }
                switch source.role {
                case .officialRoster, .communityQA:
                    guard source.url?.scheme?.lowercased() == "https",
                          source.url?.host != nil else {
                        return .invalidSource(entry.id, source.id)
                    }
                case .firstPartyObservation:
                    guard snapshot.schemaVersion == 2,
                          !usesLegacyProvenance,
                          source.url == nil else {
                        return .invalidSource(entry.id, source.id)
                    }
                }
            }

            let coveredFields = Set(entry.sources.flatMap(\.fields))
            for field in CatalogDataField.allCases where !coveredFields.contains(field) {
                return .uncoveredField(entry.id, field)
            }
            if usesLegacyProvenance {
                for role in [
                    CatalogSourceRole.officialRoster,
                    .communityQA
                ] where !entry.sources.contains(where: {
                    $0.role == role
                }) {
                    return .missingSourceRole(entry.id, role)
                }
            } else {
                guard entry.sources.contains(where: {
                    ($0.role == .officialRoster
                        || $0.role == .communityQA)
                        && $0.url != nil
                        && $0.fields.contains(.identity)
                }) else {
                    return .missingSourceRole(
                        entry.id,
                        .officialRoster
                    )
                }
                let firstPartyFields = Set(
                    entry.sources
                        .filter {
                            $0.role == .firstPartyObservation
                        }
                        .flatMap(\.fields)
                )
                for field in CatalogDataField.allCases
                where field != .identity
                    && !firstPartyFields.contains(field) {
                    return .uncoveredField(entry.id, field)
                }
            }
        }

        return nil
    }

    private static func normalized(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: Locale(identifier: "en_US_POSIX")
            )
    }
}

private final class CarCatalogBundleToken {}
