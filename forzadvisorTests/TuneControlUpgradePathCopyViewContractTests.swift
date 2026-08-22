//
//  TuneControlUpgradePathCopyViewContractTests.swift
//  forzadvisorTests
//

import XCTest
@testable import forzadvisor

final class TuneControlUpgradePathCopyViewContractTests: XCTestCase {
    @MainActor
    func testEachRenderedPathOwnsOneIsolatedActionAndResolvesFreshText() {
        let paths = makePaths()
        var requestedPathIDs: [String] = []
        var clipboardWrites: [String] = []
        var announcements: [String] = []
        let view = TuneControlUpgradePathsView(
            paths: paths,
            resolveClipboardText: { pathID in
                requestedPathIDs.append(pathID)
                return "fresh-\(requestedPathIDs.count):\(pathID)"
            },
            writeClipboard: { clipboardWrites.append($0) },
            announce: { announcements.append($0) }
        )
        let actions = view.copyActions

        XCTAssertEqual(actions.count, paths.count)
        XCTAssertEqual(actions.map(\.id), paths.map(\.id))
        XCTAssertEqual(Set(actions.map(\.id)).count, paths.count)
        XCTAssertTrue(requestedPathIDs.isEmpty)

        for (index, action) in actions.enumerated() {
            XCTAssertEqual(
                action.perform(),
                .copied(
                    pathID: paths[index].id,
                    message: "Path \(index + 1) copied as a separate checklist."
                )
            )
        }

        XCTAssertEqual(requestedPathIDs, paths.map(\.id))
        XCTAssertEqual(clipboardWrites, paths.enumerated().map {
            "fresh-\($0.offset + 1):\($0.element.id)"
        })
        XCTAssertEqual(announcements, [
            "Path 1 copied as a separate checklist.",
            "Path 2 copied as a separate checklist."
        ])

        let repeatedOutcome = actions[0].perform()
        XCTAssertEqual(requestedPathIDs.last, paths[0].id)
        XCTAssertEqual(clipboardWrites.last, "fresh-3:\(paths[0].id)")
        XCTAssertEqual(
            repeatedOutcome,
            .copied(
                pathID: paths[0].id,
                message: "Path 1 copied as a separate checklist."
            )
        )
        XCTAssertFalse(clipboardWrites.last?.contains(paths[1].id) == true)
    }

    @MainActor
    func testRejectedFreshResolutionOnlyAnnouncesLocalFeedback() {
        let paths = makePaths()
        var requestedPathIDs: [String] = []
        var clipboardWrites: [String] = []
        var announcements: [String] = []
        let view = TuneControlUpgradePathsView(
            paths: paths,
            resolveClipboardText: {
                requestedPathIDs.append($0)
                return nil
            },
            writeClipboard: { clipboardWrites.append($0) },
            announce: { announcements.append($0) }
        )

        let outcome = view.copyActions[1].perform()
        let expectedMessage =
            "Path 2 could not be freshly verified. Nothing was copied; "
                + "reopen Upgrade Lab if its evidence changed."

        XCTAssertEqual(requestedPathIDs, [paths[1].id])
        XCTAssertTrue(clipboardWrites.isEmpty)
        XCTAssertEqual(announcements, [expectedMessage])
        XCTAssertEqual(outcome, .rejected(message: expectedMessage))
    }

    private func makePaths() -> [TuneControlUpgradePath] {
        let provenance = TuneControlUpgradePathProvenance(
            game: .fh6,
            gameBuildVersion: "test-build",
            snapshotID: UUID(
                uuidString: "11111111-2222-3333-4444-555555555555"
            )!,
            capturedAt: Date(timeIntervalSince1970: 1_784_900_123),
            source: "test"
        )
        return [
            (TunePartID.sportTransmission, TuneSetting.finalDrive),
            (TunePartID.raceSuspension, TuneSetting.alignment)
        ].map { partID, setting in
            TuneControlUpgradePath(
                items: [
                    .init(
                        part: TunePartCatalog.definition(for: partID),
                        unlocks: [setting]
                    )
                ],
                provenance: provenance
            )
        }
    }

}
