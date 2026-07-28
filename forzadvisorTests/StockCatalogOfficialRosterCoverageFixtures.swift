//
//  StockCatalogOfficialRosterCoverageFixtures.swift
//  forzadvisorTests
//

import Foundation
@testable import forzadvisor

extension StockCatalogOfficialRosterCoverageTests {
    func pickerSnapshot(
        captured: [StockCatalogContributionRecord]
    ) -> StockCatalogOfficialRosterPickerSnapshot {
        .init(
            fh5Result: fh5Snapshot(),
            fh6Result: fh6Snapshot(),
            capturedRecords: captured
        )
    }

    func fh5Snapshot() -> Result<
        FH5OfficialRosterSnapshot,
        FH5OfficialRosterLoadError
    > {
        .success(
            .init(
                schemaVersion: 1,
                revision: "test",
                sourceURL: URL(string: "https://example.com/fh5")!,
                sourceUpdatedAt: Date(timeIntervalSince1970: 1_800_000_000),
                sourceSHA256: String(repeating: "a", count: 64),
                entries: [
                    .init(
                        id: "fh5-citroen",
                        year: 1986,
                        officialDesignation: "1986 Citroën BX4TC",
                        carType: "Retro",
                        collect: "Autoshow",
                        added: "Base",
                        nickname: "",
                        officialID: 1
                    ),
                    .init(
                        id: "fh5-ford",
                        year: 2003,
                        officialDesignation: "2003 Ford Focus RS",
                        carType: "Hot Hatch",
                        collect: "Autoshow",
                        added: "Base",
                        nickname: "",
                        officialID: 2
                    )
                ]
            )
        )
    }

    func fh6Snapshot() -> Result<
        FH6OfficialRosterSnapshot,
        FH6OfficialRosterLoadError
    > {
        .success(
            .init(
                schemaVersion: 1,
                revision: "test",
                sourceURL: URL(string: "https://example.com/fh6")!,
                sourceUpdatedAt: Date(timeIntervalSince1970: 1_800_000_000),
                sourceSHA256: String(repeating: "b", count: 64),
                entries: [
                    fh6Entry(
                        id: "fh6-bmw",
                        year: 2025,
                        make: "BMW",
                        model: "M5"
                    ),
                    fh6Entry(
                        id: "fh6-audi",
                        year: 2025,
                        make: "Audi",
                        model: "RS 6"
                    )
                ]
            )
        )
    }

    func fh6Entry(
        id: String,
        year: Int,
        make: String,
        model: String
    ) -> FH6OfficialRosterEntry {
        .init(
            id: id,
            year: year,
            make: make,
            model: model,
            officialDesignation: "\(year) \(make) \(model)",
            performanceIndex: 700,
            performanceClass: .a
        )
    }

    func identity(
        id: String,
        game: ForzaGame,
        year: Int,
        make: String,
        model: String
    ) -> OfficialRosterCarIdentity {
        .init(
            id: id,
            game: game,
            year: year,
            make: make,
            model: model,
            officialDesignation: [String(year), make, model]
                .filter { !$0.isEmpty }
                .joined(separator: " "),
            performanceIndex: nil,
            performanceClass: nil
        )
    }

    func entry(
        _ identity: OfficialRosterCarIdentity,
        count: Int
    ) -> StockCatalogOfficialRosterPickerEntry {
        .init(identity: identity, localCaptureCount: count)
    }

    func record(
        seed: Int,
        game: ForzaGame,
        year: Int,
        make: String,
        model: String,
        gameVersion: String = "build-one",
        platform: StockContributionPlatform = .xboxSeries,
        isValid: Bool = true
    ) -> StockCatalogContributionRecord {
        let observed = Date(
            timeIntervalSince1970: 1_800_000_000 + Double(seed)
        )
        let fields = StockCatalogContributionValidator.expectedFields
        return .init(
            id: uuid(seed),
            submissionID: uuid(seed + 1_000),
            permissionReceiptID: uuid(seed + 2_000),
            capturedAt: observed,
            game: game,
            gameVersion: gameVersion,
            platform: platform,
            vehicle: .init(
                year: year,
                make: make,
                model: model,
                stock: .init(
                    performanceIndex: game == .fh5 ? 750 : 650,
                    performanceClass: .a,
                    drivetrain: .awd,
                    weightPounds: 3_200,
                    frontWeightPercent: 52,
                    peakHorsepower: 500,
                    peakTorqueFootPounds: 450
                )
            ),
            reviewedFields: fields,
            fieldAttestations: fields.map {
                .init(
                    field: $0,
                    observationScreen: .garage,
                    directlyReadInGame: true,
                    untouchedStockConfirmed: true,
                    englishUnitsConfirmedWhenRelevant: true,
                    observedAt: observed
                )
            },
            exactUntouchedStockConfirmed: true,
            personallyReadFromGameConfirmed: true,
            firstPartyAuthorshipConfirmed: true,
            localStoragePermissionConfirmed: isValid
        )
    }

    func canonicalBytes(
        _ records: [StockCatalogContributionRecord]
    ) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .secondsSince1970
        return try encoder.encode(records)
    }

    private func uuid(_ seed: Int) -> UUID {
        UUID(
            uuidString: String(
                format: "00000000-0000-0000-0000-%012d",
                seed
            )
        )!
    }
}
