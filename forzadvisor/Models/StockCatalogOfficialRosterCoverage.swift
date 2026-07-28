//
//  StockCatalogOfficialRosterCoverage.swift
//  forzadvisor
//
//  Read-only local capture counts for official roster identities.
//

import Foundation

enum StockCatalogOfficialRosterCoverageFilter:
    String,
    CaseIterable,
    Identifiable,
    Sendable
{
    case all
    case needsLocalCapture

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            "All Cars"
        case .needsLocalCapture:
            "Needs Local Capture"
        }
    }
}

struct StockCatalogOfficialRosterCoverage:
    Equatable,
    Sendable
{
    private struct Key: Hashable, Sendable {
        let game: ForzaGame
        let year: Int
        let designation: String
    }

    private let counts: [Key: Int]

    init(capturedRecords: [StockCatalogContributionRecord]) {
        let validator = StockCatalogContributionValidator()
        counts = capturedRecords.reduce(into: [:]) { result, record in
            guard validator.isValid(record) else {
                return
            }
            let designation = [
                String(record.vehicle.year),
                record.vehicle.make,
                record.vehicle.model
            ]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            let key = Key(
                game: record.game,
                year: record.vehicle.year,
                designation: Self.normalized(designation)
            )
            result[key, default: 0] += 1
        }
    }

    func localCaptureCount(
        for identity: OfficialRosterCarIdentity
    ) -> Int {
        counts[
            Key(
                game: identity.game,
                year: identity.year,
                designation: Self.normalized(
                    identity.officialDesignation
                )
            ),
            default: 0
        ]
    }

    static func normalized(_ value: String) -> String {
        value.folding(
            options: [
                .caseInsensitive,
                .diacriticInsensitive,
                .widthInsensitive
            ],
            locale: Locale(identifier: "en_US_POSIX")
        )
        .split(whereSeparator: \.isWhitespace)
        .joined(separator: " ")
        .lowercased()
    }
}
