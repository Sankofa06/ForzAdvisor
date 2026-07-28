//
//  TuneControlUpgradePathCopyViewContractTests.swift
//  forzadvisorTests
//
//  Static wiring boundaries for one copy action per rendered path.
//

import Foundation
import XCTest

final class TuneControlUpgradePathCopyViewContractTests:
    XCTestCase {
    func testOneCopyActionLivesInsidePathLoopAndUsesFreshFormatter()
        throws {
        let pathView = try source(
            "forzadvisor/Views/TuneControlUpgradePathsView.swift"
        )
        let resultView = try source(
            "forzadvisor/Views/TuneResultView.swift"
        )

        XCTAssertEqual(
            pathView.components(
                separatedBy: "copyTuningControlUpgradePath-"
            ).count,
            2
        )
        let loop = try XCTUnwrap(
            pathView.range(of: "ForEach(Array(paths.enumerated())")
        )
        let copy = try XCTUnwrap(
            pathView.range(of: "copy(path: path, number: index + 1)")
        )
        XCTAssertLessThan(loop.lowerBound, copy.lowerBound)
        XCTAssertTrue(pathView.contains("\"Copy This Path\""))
        XCTAssertTrue(pathView.contains("\"Copied Path \\(index + 1)\""))
        XCTAssertTrue(pathView.contains("Nothing was copied"))
        XCTAssertTrue(resultView.contains(
            "TuneControlUpgradePathClipboardFormatter.text("
        ))
    }

    func testCopyFunctionHasOnlyPasteboardAndLocalFeedbackEffects()
        throws {
        let pathView = try source(
            "forzadvisor/Views/TuneControlUpgradePathsView.swift"
        )
        let start = try XCTUnwrap(
            pathView.range(of: "private func copy(")
        )
        let function = String(pathView[start.lowerBound...])

        XCTAssertTrue(function.contains("UIPasteboard.general.string"))
        XCTAssertTrue(function.contains("copiedPathID"))
        XCTAssertTrue(function.contains("feedbackMessage"))
        for forbidden in [
            "save", "persist", "delete", "URLSession", "provider",
            "generateTune", "adjustTune", "snapshot =", "tune ="
        ] {
            XCTAssertFalse(
                function.localizedCaseInsensitiveContains(forbidden),
                forbidden
            )
        }
    }

    private func source(_ path: String) throws -> String {
        let repository = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(
            contentsOf:
                repository.appendingPathComponent(path),
            encoding: .utf8
        )
    }
}
