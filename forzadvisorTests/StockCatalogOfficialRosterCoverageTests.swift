//
//  StockCatalogOfficialRosterCoverageTests.swift
//  forzadvisorTests
//

import XCTest
@testable import forzadvisor

final class StockCatalogOfficialRosterCoverageTests: XCTestCase {
    func testCountsDistinctValidRecordsForBothGamesAndPresentsSafeStatus()
        throws {
        let fh5 = identity(
            id: "fh5-citroen",
            game: .fh5,
            year: 1986,
            make: "",
            model: "Citroën BX4TC"
        )
        let fh6 = identity(
            id: "fh6-bmw",
            game: .fh6,
            year: 2025,
            make: "BMW",
            model: "M5"
        )
        let captured = [
            record(
                seed: 1,
                game: .fh5,
                year: 1986,
                make: "CITROEN",
                model: "BX4TC",
                gameVersion: "FH5-build-one",
                platform: .xboxSeries
            ),
            record(
                seed: 2,
                game: .fh5,
                year: 1986,
                make: "Ｃｉｔｒｏｅｎ",
                model: "ＢＸ４ＴＣ",
                gameVersion: "FH5-build-two",
                platform: .windowsPC
            ),
            record(
                seed: 3,
                game: .fh6,
                year: 2025,
                make: "BMW",
                model: "M5"
            )
        ]
        let coverage = StockCatalogOfficialRosterCoverage(
            capturedRecords: captured
        )

        XCTAssertEqual(coverage.localCaptureCount(for: fh5), 2)
        XCTAssertEqual(coverage.localCaptureCount(for: fh6), 1)
        XCTAssertEqual(
            entry(fh5, count: 0).localCaptureStatus,
            "No local captures"
        )
        XCTAssertEqual(
            entry(fh6, count: 1).localCaptureStatus,
            "1 local capture"
        )
        XCTAssertEqual(
            entry(fh5, count: 2).localCaptureStatus,
            "2 local captures"
        )
        XCTAssertEqual(entry(fh5, count: -1).localCaptureCount, 0)
    }

    func testExactIdentityDimensionsAndPunctuationFailClosed() {
        let captured = [
            record(
                seed: 10,
                game: .fh6,
                year: 2024,
                make: "Test",
                model: "A-B"
            )
        ]
        let coverage = StockCatalogOfficialRosterCoverage(
            capturedRecords: captured
        )

        XCTAssertEqual(
            coverage.localCaptureCount(
                for: identity(
                    id: "exact",
                    game: .fh6,
                    year: 2024,
                    make: "Test",
                    model: "A-B"
                )
            ),
            1
        )
        for mismatch in [
            identity(
                id: "game",
                game: .fh5,
                year: 2024,
                make: "Test",
                model: "A-B"
            ),
            identity(
                id: "year",
                game: .fh6,
                year: 2023,
                make: "Test",
                model: "A-B"
            ),
            identity(
                id: "make",
                game: .fh6,
                year: 2024,
                make: "Other",
                model: "A-B"
            ),
            identity(
                id: "model",
                game: .fh6,
                year: 2024,
                make: "Test",
                model: "A-C"
            ),
            identity(
                id: "punctuation",
                game: .fh6,
                year: 2024,
                make: "Test",
                model: "A B"
            )
        ] {
            XCTAssertEqual(
                coverage.localCaptureCount(for: mismatch),
                0,
                mismatch.id
            )
        }
    }

    func testInvalidRecordsAreExcludedAndInputBytesRemainUnchanged()
        throws {
        let target = identity(
            id: "fh6-test",
            game: .fh6,
            year: 2024,
            make: "Test",
            model: "Stock Car"
        )
        let captured = [
            record(
                seed: 20,
                game: .fh6,
                year: 2024,
                make: "Test",
                model: "Stock Car"
            ),
            record(
                seed: 21,
                game: .fh6,
                year: 2024,
                make: "Test",
                model: "Stock Car",
                isValid: false
            )
        ]
        let beforeValue = captured
        let beforeBytes = try canonicalBytes(captured)

        let coverage = StockCatalogOfficialRosterCoverage(
            capturedRecords: captured
        )
        _ = coverage.localCaptureCount(for: target)

        XCTAssertEqual(coverage.localCaptureCount(for: target), 1)
        XCTAssertEqual(captured, beforeValue)
        XCTAssertEqual(try canonicalBytes(captured), beforeBytes)
    }

    func testFilterComposesWithGameSearchAndRosterFailure() {
        let captured = [
            record(
                seed: 30,
                game: .fh5,
                year: 1986,
                make: "Citroen",
                model: "BX4TC"
            ),
            record(
                seed: 31,
                game: .fh6,
                year: 2025,
                make: "BMW",
                model: "M5"
            )
        ]
        let snapshot = pickerSnapshot(captured: captured)

        XCTAssertEqual(
            snapshot.entries(for: .fh5, matching: "").count,
            2
        )
        XCTAssertEqual(
            snapshot.entries(
                for: .fh5,
                matching: "",
                coverageFilter: .needsLocalCapture
            ).map(\.id),
            ["fh5-ford"]
        )
        XCTAssertEqual(
            snapshot.entries(
                for: .fh5,
                matching: "  FORD   focus ",
                coverageFilter: .needsLocalCapture
            ).map(\.id),
            ["fh5-ford"]
        )
        XCTAssertTrue(
            snapshot.entries(
                for: .fh5,
                matching: "citroën",
                coverageFilter: .needsLocalCapture
            ).isEmpty
        )
        XCTAssertEqual(
            snapshot.entries(
                for: .fh6,
                matching: "",
                coverageFilter: .needsLocalCapture
            ).map(\.id),
            ["fh6-audi"]
        )

        let failed = StockCatalogOfficialRosterPickerSnapshot(
            fh5Result: .failure(.missingResource("missing")),
            fh6Result: fh6Snapshot(),
            capturedRecords: captured
        )
        XCTAssertTrue(
            failed.entries(
                for: .fh5,
                matching: "",
                coverageFilter: .needsLocalCapture
            ).isEmpty
        )
        XCTAssertFalse(failed.fh5.isAvailable)
    }

    func testCoveredSelectionStillTransfersIdentityOnly() throws {
        let snapshot = pickerSnapshot(
            captured: [
                record(
                    seed: 40,
                    game: .fh6,
                    year: 2025,
                    make: "BMW",
                    model: "M5"
                )
            ]
        )
        let covered = try XCTUnwrap(
            snapshot.fh6.entries.first {
                $0.localCaptureCount == 1
            }
        )
        var draft = StockCatalogContributionDraft(game: .fh5)

        XCTAssertTrue(
            draft.applyOfficialRosterIdentityIfPristine(
                covered.identity
            )
        )
        XCTAssertEqual(
            draft,
            StockCatalogContributionDraft(
                officialRosterIdentity: covered.identity
            )
        )
        XCTAssertEqual(draft.gameVersion, "")
        XCTAssertNil(draft.platform)
        XCTAssertEqual(draft.performanceIndex, "")
        XCTAssertNil(draft.performanceClass)
        XCTAssertNil(draft.drivetrain)
        XCTAssertTrue(draft.observationScreens.isEmpty)
        XCTAssertEqual(
            draft.captureConfirmations,
            StockCatalogCaptureConfirmationState()
        )
    }

}
