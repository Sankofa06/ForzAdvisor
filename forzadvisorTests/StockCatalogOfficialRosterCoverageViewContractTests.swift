//
//  StockCatalogOfficialRosterCoverageViewContractTests.swift
//  forzadvisorTests
//

import Foundation
import XCTest

final class StockCatalogOfficialRosterCoverageViewContractTests:
    XCTestCase
{
    func testParentPassesCapturedValueSnapshotAndSelectionStaysIdentityOnly()
        throws {
        let source = try contributionSource()
        let sheet = try XCTUnwrap(
            source.range(
                of: ".sheet(isPresented: $showingOfficialRosterPicker)"
            )
        )
        let task = try XCTUnwrap(
            source.range(of: ".onChange(of: captureDraftFingerprint)")
        )
        let sheetSource = String(source[sheet.lowerBound..<task.lowerBound])

        XCTAssertTrue(
            sheetSource.contains(
                "capturedRecords: snapshot.captured"
            )
        )
        XCTAssertTrue(
            sheetSource.contains(
                "draft.applyOfficialRosterIdentityIfPristine"
            )
        )
        for prohibited in [
            "snapshot.captured.append",
            "snapshot.captured.remove",
            "snapshot.reviewed",
            "store.save",
            "StockCatalogContributionImporter",
            "curation",
            "continuation"
        ] {
            XCTAssertFalse(
                sheetSource.localizedCaseInsensitiveContains(prohibited),
                prohibited
            )
        }
    }

    func testPickerReadsCoverageAndExposesBoundaryStatusAndFilter()
        throws {
        let source = try pickerSource()

        XCTAssertTrue(
            source.contains(
                "capturedRecords: [StockCatalogContributionRecord]"
            )
        )
        XCTAssertTrue(
            source.contains(
                "StockCatalogOfficialRosterPickerSnapshot("
            )
        )
        XCTAssertTrue(
            source.contains(
                "stockCatalogOfficialRosterNeedsCaptureFilter"
            )
        )
        XCTAssertTrue(source.contains("entry.localCaptureStatus"))
        XCTAssertTrue(source.contains("collection-only"))
        let trustBoundary =
            "establish verification, approval, permission completeness, or catalog readiness"
        XCTAssertEqual(
            source.components(separatedBy: trustBoundary).count - 1,
            2
        )
        XCTAssertTrue(
            source.contains(
                "collection-only; does not \(trustBoundary)"
            )
        )
        XCTAssertTrue(
            source.contains(
                "stockCatalogOfficialRosterNoCaptureNeeds"
            )
        )

        for prohibited in [
            "capturedRecords.append",
            "capturedRecords.remove",
            "snapshot.captured",
            "snapshot.reviewed",
            "store.save",
            "UserDefaults",
            "URLSession",
            "delete",
            "StockCatalogContributionImporter",
            "curation",
            "continuation"
        ] {
            XCTAssertFalse(
                source.localizedCaseInsensitiveContains(prohibited),
                prohibited
            )
        }
    }

    func testCoverageCopyIsPureAndValidatorFiltered() throws {
        let source = try coverageSource()

        XCTAssertTrue(
            source.contains("let validator = StockCatalogContributionValidator()")
        )
        XCTAssertTrue(
            source.contains("validator.isValid(record)")
        )
        XCTAssertTrue(
            source.contains("identity.officialDesignation")
        )
        XCTAssertTrue(
            source.contains("record.vehicle.make")
        )
        XCTAssertTrue(
            source.contains("record.vehicle.model")
        )
        for prohibited in [
            "UserDefaults",
            "URLSession",
            ".append(",
            ".remove",
            ".save(",
            ".delete",
            "reviewed"
        ] {
            XCTAssertFalse(
                source.localizedCaseInsensitiveContains(prohibited),
                prohibited
            )
        }
    }

    private func contributionSource() throws -> String {
        try source(
            relativePath:
                "forzadvisor/Views/StockCatalogContributionView.swift"
        )
    }

    private func pickerSource() throws -> String {
        try source(
            relativePath:
                "forzadvisor/Views/StockCatalogOfficialRosterPickerView.swift"
        )
    }

    private func coverageSource() throws -> String {
        try source(
            relativePath:
                "forzadvisor/Models/StockCatalogOfficialRosterCoverage.swift"
        )
    }

    private func source(relativePath: String) throws -> String {
        let testsDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
        let repository = testsDirectory.deletingLastPathComponent()
        return try String(
            contentsOf: repository.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }
}
