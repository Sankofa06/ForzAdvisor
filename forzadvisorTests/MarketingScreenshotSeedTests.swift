#if DEBUG && targetEnvironment(simulator)
import SwiftData
import XCTest
@testable import forzadvisor

@MainActor
final class MarketingScreenshotSeedTests: XCTestCase {
    func testDedicatedArgumentAndUITestingAreBothRequired() {
        XCTAssertFalse(MarketingScreenshotSeed.isEnabled(arguments: []))
        XCTAssertFalse(MarketingScreenshotSeed.isEnabled(arguments: ["-ui-testing"]))
        XCTAssertFalse(MarketingScreenshotSeed.isEnabled(
            arguments: [MarketingScreenshotSeed.launchArgument]
        ))
        XCTAssertTrue(MarketingScreenshotSeed.isEnabled(arguments: [
            "-ui-testing", MarketingScreenshotSeed.launchArgument
        ]))
    }

    func testNormalTestLaunchDoesNotPopulateStore() throws {
        XCTAssertFalse(MarketingScreenshotSeed.isEnabled)
        let container = try ModelContainer(
            for: SavedTune.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        try MarketingScreenshotSeed.install(in: container)
        XCTAssertEqual(
            try container.mainContext.fetchCount(FetchDescriptor<SavedTune>()), 0
        )
    }

    func testManualExampleCannotUnlockNumericSettings() throws {
        let car = try XCTUnwrap(
            MarketingScreenshotSeed.manualDraft.confirmedCarInput()
        )
        XCTAssertNil(car.catalogReference)
        let request = TuneRequest(car: car, discipline: .road)
        let projected = TuneOutputProjector().project(TuneResult(
            request: request,
            sections: [],
            notes: TuneNotes(
                bias: "Demo", ifPushesWide: "Confirm build",
                ifSnapsOnLift: "Confirm ranges", retuneTrigger: "Confirm evidence"
            )
        ), for: request)
        XCTAssertNil(projected.request.buildSnapshot)
        XCTAssertTrue(projected.sections.isEmpty)
        XCTAssertEqual(projected.projectionReport?.readyCount, 0)
        XCTAssertEqual(projected.projectionReport?.contextStatus, .missingSnapshot)
    }
}
#endif
