import Foundation
import XCTest

final class StaleBetaMissionRoutingContractTests: XCTestCase {
    func testStaleMissionRefreshesBoardInlineWithoutGlobalAlert() throws {
        let repository = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repository.appendingPathComponent(
                "forzadvisor/ContentView+SavedWorkflow.swift"
            ),
            encoding: .utf8
        )
        let start = try XCTUnwrap(
            source.range(
                of: "catch ContentWorkflowError.staleBetaMission"
            )
        )
        let end = try XCTUnwrap(
            source.range(
                of: "} catch {",
                range: start.upperBound..<source.endIndex
            )
        )
        let staleBranch = String(
            source[start.lowerBound..<end.lowerBound]
        )

        XCTAssertTrue(staleBranch.contains(
            "ValidationMissionReturnOutcome.stale.message"
        ))
        XCTAssertTrue(staleBranch.contains("rootSheet = .betaMissions"))
        XCTAssertFalse(staleBranch.contains("errorMessage ="))
    }
}
