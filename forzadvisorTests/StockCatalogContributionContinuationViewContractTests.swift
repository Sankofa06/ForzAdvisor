//
//  StockCatalogContributionContinuationViewContractTests.swift
//  forzadvisorTests
//
//  Static wiring checks for continuation authority around persistence.
//

import Foundation
import XCTest

final class StockCatalogContributionContinuationViewContractTests:
    XCTestCase {
    func testViewMintsOnlyAfterPersistAndContinuationNeverSaves()
        throws {
        let source = try contributionViewSource()
        let save = try XCTUnwrap(
            source.range(of: "private func saveContribution()")
        )
        let continuation = try XCTUnwrap(
            source.range(of: "private func chooseAnotherOfficialCar()")
        )
        let importStart = try XCTUnwrap(
            source.range(of: "private func importContribution()")
        )
        let saveSource = String(
            source[save.lowerBound..<continuation.lowerBound]
        )
        let continuationSource = String(
            source[continuation.lowerBound..<importStart.lowerBound]
        )

        XCTAssertLessThan(
            try XCTUnwrap(saveSource.range(of: "clearForSaveAttempt()"))
                .lowerBound,
            try XCTUnwrap(saveSource.range(of: "guard let platform"))
                .lowerBound
        )
        XCTAssertLessThan(
            try XCTUnwrap(saveSource.range(of: "if persist(")).lowerBound,
            try XCTUnwrap(saveSource.range(of: "recordSuccessfulSave("))
                .lowerBound
        )
        XCTAssertLessThan(
            try XCTUnwrap(
                saveSource.range(of: "captureConfirmations.reset()")
            ).lowerBound,
            try XCTUnwrap(saveSource.range(of: "recordSuccessfulSave("))
                .lowerBound
        )
        XCTAssertEqual(
            source.components(separatedBy: "recordSuccessfulSave(").count,
            2
        )
        XCTAssertFalse(continuationSource.contains("saveContribution()"))
        XCTAssertFalse(continuationSource.contains("persist("))
        XCTAssertFalse(
            continuationSource.contains("snapshot.captured.append")
        )
        XCTAssertFalse(continuationSource.contains("deleteCaptured("))
        for protectedState in [
            "snapshot =",
            "pastedJSON",
            "reviewConfirmations",
            "maintainerReviewConfirmed",
            "preparedMaintainerPacket",
            "selectedCurationCandidate",
            "curationChoices",
            "preparedCurationPreflight"
        ] {
            XCTAssertFalse(
                continuationSource.contains(protectedState),
                protectedState
            )
        }
        XCTAssertFalse(
            saveSource.contains(
                "draft = StockCatalogContributionDraft"
            )
        )
    }

    private func contributionViewSource() throws -> String {
        let repository = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(
            contentsOf: repository.appendingPathComponent(
                "forzadvisor/Views/StockCatalogContributionView.swift"
            ),
            encoding: .utf8
        )
    }
}
