//
//  NewTuneStartViewCatalogEntryContractTests.swift
//  forzadvisorTests
//

import Foundation
import XCTest

final class NewTuneStartViewCatalogEntryContractTests:
    XCTestCase
{
    func testNewTuneStartHasNoBundledCatalogOrRosterEntry() throws {
        let source = try viewSource()
        for removedRosterSurface in [
            "onCatalog",
            "catalogEntryButton",
            "Browse Full Official",
            "official FH5",
            "official FH6",
            "roster-only"
        ] {
            XCTAssertFalse(
                source.localizedCaseInsensitiveContains(
                    removedRosterSurface
                ),
                removedRosterSurface
            )
        }

        XCTAssertTrue(source.contains("title: \"Take Photo\""))
        XCTAssertTrue(source.contains("title: \"Import Screenshot\""))
        XCTAssertTrue(source.contains("title: \"Enter Manually\""))
    }

    private func viewSource() throws -> String {
        let repository = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(
            contentsOf: repository.appendingPathComponent(
                "forzadvisor/Views/NewTuneStartView.swift"
            ),
            encoding: .utf8
        )
    }
}
