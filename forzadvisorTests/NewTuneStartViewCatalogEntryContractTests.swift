//
//  NewTuneStartViewCatalogEntryContractTests.swift
//  forzadvisorTests
//

import Foundation
import XCTest

final class NewTuneStartViewCatalogEntryContractTests:
    XCTestCase
{
    func testCatalogEntryAdvertisesFullRosterWithoutTuneReadinessClaim()
        throws {
        let source = try viewSource()
        let catalogStart = try XCTUnwrap(
            source.range(of: "Button(action: onCatalog)")
        )
        let photoStart = try XCTUnwrap(
            source.range(
                of: "Button {",
                range: catalogStart.upperBound..<source.endIndex
            )
        )
        let catalogSource = String(
            source[catalogStart.lowerBound..<photoStart.lowerBound]
        )

        XCTAssertTrue(
            catalogSource.contains(
                "title: \"Browse Full Official FH5/FH6 Roster\""
            )
        )
        XCTAssertTrue(
            catalogSource.contains(
                "subtitle: \"Reviewed cars include complete stock values; roster-only cars need stock details.\""
            )
        )
        XCTAssertTrue(
            catalogSource.contains(
                ".accessibilityIdentifier(\"catalogEntryButton\")"
            )
        )
        XCTAssertEqual(
            source.components(separatedBy: "Button(action: onCatalog)")
                .count,
            2
        )
        for prohibitedClaim in [
            "tune-ready",
            "tune ready",
            "verified roster-only",
            "all cars include complete stock values"
        ] {
            XCTAssertFalse(
                catalogSource.localizedCaseInsensitiveContains(
                    prohibitedClaim
                ),
                prohibitedClaim
            )
        }
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
