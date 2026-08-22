//
//  NewTuneStartViewCatalogEntryContractTests.swift
//  forzadvisorTests
//

import XCTest
@testable import forzadvisor

final class NewTuneStartViewCatalogEntryContractTests: XCTestCase {
    @MainActor
    func testNewTuneStartHasOnlySupportedEntryPoints() {
        let view = NewTuneStartView(
            onCancel: {},
            onManualEntry: {},
            onDraftReady: { _ in }
        )
        let renderedContract = reflectedStrings(in: view.body)

        for removedRosterSurface in [
            "onCatalog",
            "catalogEntryButton",
            "Browse Full Official",
            "official FH5",
            "official FH6",
            "roster-only"
        ] {
            XCTAssertFalse(
                renderedContract.localizedCaseInsensitiveContains(
                    removedRosterSurface
                ),
                removedRosterSurface
            )
        }

        for supportedEntry in [
            "Take Photo",
            "Import Screenshot",
            "Enter Manually",
            "takePhotoPrimaryButton",
            "importScreenshotButton",
            "manualEntryButton"
        ] {
            XCTAssertTrue(
                renderedContract.contains(supportedEntry),
                supportedEntry
            )
        }
    }

    private func reflectedStrings(in value: Any) -> String {
        var strings: [String] = []
        collectStrings(from: value, depth: 0, into: &strings)
        return strings.joined(separator: "\n")
    }

    private func collectStrings(
        from value: Any,
        depth: Int,
        into strings: inout [String]
    ) {
        guard depth < 40 else { return }
        if let string = value as? String {
            strings.append(string)
            return
        }
        for child in Mirror(reflecting: value).children {
            collectStrings(
                from: child.value,
                depth: depth + 1,
                into: &strings
            )
        }
    }
}
