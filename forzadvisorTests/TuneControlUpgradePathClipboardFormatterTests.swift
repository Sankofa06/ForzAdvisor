//
//  TuneControlUpgradePathClipboardFormatterTests.swift
//  forzadvisorTests
//
//  Fail-closed contracts for copying one exact upgrade-shop path.
//

import XCTest
@testable import forzadvisor

final class TuneControlUpgradePathClipboardFormatterTests:
    XCTestCase {
    private let capturedAt = Date(
        timeIntervalSince1970: 1_784_900_123
    )
    private let snapshotID = UUID(
        uuidString: "11111111-2222-3333-4444-555555555555"
    )!

    func testSelectedPathIsIsolatedSafeAndGameCorrect()
        throws {
        for game in ForzaGame.allCases {
            let tune = try trustedTune(game: game)
            let paths = TuneControlUpgradePlanner().paths(for: tune)
            XCTAssertEqual(paths.count, 3)
            let selectedIndex = 1
            let selected = paths[selectedIndex]
            let text = try XCTUnwrap(
                TuneControlUpgradePathClipboardFormatter.text(
                    for: tune,
                    displayedPathID: selected.id
                )
            )

            XCTAssertTrue(
                text.hasPrefix("Path \(selectedIndex + 1) of 3\n")
            )
            XCTAssertTrue(text.contains(
                "Pick one path; the alternatives are not cumulative."
            ))
            for line in selected.provenance.stableClipboardLines {
                XCTAssertTrue(text.contains(line), line)
            }
            for item in selected.items {
                XCTAssertTrue(text.contains(
                    "\(item.part.category.label) > "
                        + "\(item.part.slot.label) > \(item.part.label)"
                ))
                XCTAssertTrue(text.contains(
                    "Unlocks: "
                        + item.unlocks.map(\.projectionLabel)
                        .joined(separator: ", ")
                ))
            }
            let selectedIDs = Set(selected.items.map(\.part.id))
            let unselectedUnique = Set(
                paths.enumerated()
                    .filter { $0.offset != selectedIndex }
                    .flatMap { $0.element.items.map(\.part.id) }
            ).subtracting(selectedIDs)
            for partID in unselectedUnique {
                XCTAssertFalse(
                    text.contains(
                        TunePartCatalog.definition(for: partID).label
                    ),
                    partID.rawValue
                )
            }
            XCTAssertTrue(text.contains(
                "does not predict PI, cost, credits, entitlement, performance, or installation order"
            ))
            assertPrivateTuneDataAbsent(
                from: text,
                tune: tune
            )
        }
    }

    func testSelectionIsDeterministicAfterJSONRoundTrip()
        throws {
        for game in ForzaGame.allCases {
            let tune = try trustedTune(game: game)
            let pathID = try XCTUnwrap(
                TuneControlUpgradePlanner().paths(for: tune)
                    .last?.id
            )
            let first = try XCTUnwrap(
                TuneControlUpgradePathClipboardFormatter.text(
                    for: tune,
                    displayedPathID: pathID
                )
            )
            let decoded = try JSONDecoder().decode(
                TuneResult.self,
                from: JSONEncoder().encode(tune)
            )
            let second = try XCTUnwrap(
                TuneControlUpgradePathClipboardFormatter.text(
                    for: decoded,
                    displayedPathID: pathID
                )
            )

            XCTAssertEqual(first, second)
            XCTAssertEqual(
                first.data(using: .utf8),
                second.data(using: .utf8)
            )
        }
    }

    func testUnknownStaleDetachedAndMismatchedInputsFailClosed()
        throws {
        let tune = try trustedTune()
        let pathID = try XCTUnwrap(
            TuneControlUpgradePlanner().paths(for: tune).first?.id
        )
        XCTAssertNil(
            TuneControlUpgradePathClipboardFormatter.text(
                for: tune,
                displayedPathID: "forged-path-id"
            )
        )

        var stale = tune
        stale.projectionReport?.fields.removeLast()
        assertNoText(stale, pathID: pathID)

        var detached = tune
        detached.projectionReport?.purchasePlan = []
        assertNoText(detached, pathID: pathID)

        var mismatched = tune
        mismatched.request.car.model = "Different Car"
        assertNoText(mismatched, pathID: pathID)

        var wrongSnapshot = tune
        wrongSnapshot.request.buildSnapshot?.id = UUID()
        assertNoText(wrongSnapshot, pathID: pathID)
    }

    func testIncompleteLowConfidenceAndUnpermittedEvidenceFailsClosed()
        throws {
        let tune = try trustedTune()
        let pathID = try XCTUnwrap(
            TuneControlUpgradePlanner().paths(for: tune).first?.id
        )

        var incomplete = tune
        incomplete.request.buildSnapshot?
            .capabilityProfile.parts.removeLast()
        assertNoText(incomplete, pathID: pathID)

        var lowConfidence = tune
        lowConfidence.request.buildSnapshot?
            .capabilityProfile.parts[0].evidence.confidence = .low
        assertNoText(lowConfidence, pathID: pathID)

        var unpermitted = tune
        unpermitted.request.buildSnapshot?
            .capabilityProfile.parts[0].evidence
            .usagePermission = .prohibited
        assertNoText(unpermitted, pathID: pathID)
    }

    func testNoTrustedPathsReturnsNil() throws {
        let tune = try trustedTune(status: .notOffered)

        XCTAssertTrue(
            TuneControlUpgradePlanner().paths(for: tune).isEmpty
        )
        XCTAssertNil(
            TuneControlUpgradePathClipboardFormatter.text(
                for: tune,
                displayedPathID: "anything"
            )
        )
    }

    func testWholeBuildPlanBytesAndAllPathsStayUnchanged()
        throws {
        let tune = try trustedTune()
        let paths = TuneControlUpgradePlanner().paths(for: tune)
        let before = try XCTUnwrap(
            TuneClipboardFormatter.buildPlanText(for: tune)
        )

        _ = TuneControlUpgradePathClipboardFormatter.text(
            for: tune,
            displayedPathID: try XCTUnwrap(paths.first?.id)
        )
        let after = try XCTUnwrap(
            TuneClipboardFormatter.buildPlanText(for: tune)
        )

        XCTAssertEqual(before, after)
        XCTAssertEqual(
            before.data(using: .utf8),
            after.data(using: .utf8)
        )
        for index in paths.indices {
            XCTAssertTrue(before.contains("Path \(index + 1)"))
        }
    }

    private func trustedTune(
        game: ForzaGame = .fh6,
        status: UpgradePartCaptureStatus = .offered
    ) throws -> TuneResult {
        let catalog = try BundledCarCatalog.load().get()
        let entry = try XCTUnwrap(
            catalog.entries.first { $0.game == game }
        )
        let selection = catalog.selection(for: entry)
        let snapshot = try UpgradePartCapture(
            gameBuildVersion: "selected-path-build",
            parts: TunePartID.allCases.map {
                UpgradePartCaptureValue(
                    partID: $0,
                    status: status
                )
            },
            exactStockBuildConfirmed: true,
            localUsePermitted: true
        ).verifiedSnapshot(
            upgrading: selection.capabilityOnlyBuildSnapshot(
                capturedAt: capturedAt
            ),
            capturedAt: capturedAt,
            snapshotID: snapshotID
        )
        var tune = TuneOutputProjector().project(TuneResult(
            request: TuneRequest(
                car: snapshot.car,
                discipline: .road,
                buildSnapshot: snapshot
            ),
            sections: [],
            notes: emptyNotes
        ))
        tune.notes = TuneNotes(
            bias: "PRIVATE-NOTE-SENTINEL",
            ifPushesWide: "PRIVATE-NOTE-SENTINEL",
            ifSnapsOnLift: "PRIVATE-NOTE-SENTINEL",
            retuneTrigger: "PRIVATE-NOTE-SENTINEL"
        )
        tune.providerInfo = .fallback(
            requestedMode: .anthropicAPI,
            reason: .missingAPIKey
        )
        return tune
    }

    private func assertNoText(
        _ tune: TuneResult,
        pathID: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertNil(
            TuneControlUpgradePathClipboardFormatter.text(
                for: tune,
                displayedPathID: pathID
            ),
            file: file,
            line: line
        )
    }

    private func assertPrivateTuneDataAbsent(
        from text: String,
        tune: TuneResult,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let snapshot = tune.request.buildSnapshot
        for forbidden in [
            "PRIVATE",
            "Anthropic",
            "API key",
            snapshot?.id.uuidString ?? "",
            snapshot?.capabilityProfile.vehicle.catalogID ?? "",
            UpgradePartCapture.provenanceSource,
            "\(tune.request.car.performanceClass.rawValue) "
                + "\(tune.request.car.performanceIndex)",
            tune.request.car.drivetrain.rawValue,
            "31.375"
        ] where !forbidden.isEmpty {
            XCTAssertFalse(
                text.localizedCaseInsensitiveContains(forbidden),
                forbidden,
                file: file,
                line: line
            )
        }
    }

    private var emptyNotes: TuneNotes {
        TuneNotes(
            bias: "",
            ifPushesWide: "",
            ifSnapsOnLift: "",
            retuneTrigger: ""
        )
    }
}
