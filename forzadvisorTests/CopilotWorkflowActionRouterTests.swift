import SwiftData
import XCTest
@testable import forzadvisor

final class CopilotWorkflowActionRouterTests: XCTestCase {
    let router = CopilotWorkflowActionRouter()
    let savedTuneID = UUID(
        uuidString: "D16AFEB1-5E7D-4F15-942F-54377261C977"
    )!
    let thumbnailData = Data("copilot-thumbnail".utf8)
    let playerNotes = "Preserve these player notes exactly."

    func testValidRoutesPreserveExactLiveResultPayload() throws {
        for (action, route) in [
            (CopilotAction.openFH6TuneMenuLab, Route.tuneMenu),
            (.openTireLab, .tire),
            (.openUpgradeLab, .upgrade)
        ] {
            let tune = try eligibleTune(for: route)
            let current = resultStep(tune)
            let freshThumbnail =
                Data("fresh-\(route)-thumbnail".utf8)
            let freshNotes = "Fresh \(route) notes"
            let destination = try XCTUnwrap(
                router.destination(
                    for: action,
                    from: current,
                    authoritativeSnapshot:
                        actionSnapshot(
                            tune,
                            thumbnailData: freshThumbnail,
                            playerNotes: freshNotes
                        )
                )
            )

            assertDestination(
                destination,
                route: route,
                expectedTune: tune,
                expectedThumbnailData: freshThumbnail,
                expectedPlayerNotes: freshNotes
            )
        }
    }

    func testTuneMenuPrioritySuppressesTireAndUpgradeActions() throws {
        let tune = try eligibleTune(for: .tuneMenu)
        let current = resultStep(tune)

        XCTAssertNotNil(
            router.destination(
                for: .openFH6TuneMenuLab,
                from: current,
                authoritativeSnapshot: actionSnapshot(tune)
            )
        )
        XCTAssertNil(
            router.destination(
                for: .openTireLab,
                from: current,
                authoritativeSnapshot: actionSnapshot(tune)
            )
        )
        XCTAssertNil(
            router.destination(
                for: .openUpgradeLab,
                from: current,
                authoritativeSnapshot: actionSnapshot(tune)
            )
        )
    }

    func testRouterRejectsStaleWrongNonResultAndIneligibleActions() throws {
        let tune = try eligibleTune(for: .tuneMenu)

        XCTAssertNil(
            router.destination(
                for: .openFH6TuneMenuLab,
                from: .home,
                authoritativeSnapshot: actionSnapshot(tune)
            )
        )
        XCTAssertNil(
            router.destination(
                for: .openTireLab,
                from: resultStep(tune),
                authoritativeSnapshot: actionSnapshot(tune)
            )
        )
        XCTAssertNil(
            router.destination(
                for: .openFH6TuneMenuLab,
                from: resultStep(tune),
                authoritativeSnapshot: nil
            )
        )

        var noProjection = tune
        noProjection.projectionReport = nil
        XCTAssertNil(
            router.destination(
                for: .openFH6TuneMenuLab,
                from: resultStep(noProjection),
                authoritativeSnapshot:
                    actionSnapshot(noProjection)
            )
        )

        var noReadyValues = tune
        noReadyValues.projectionReport?.fields.removeAll {
            $0.status == .ready
        }
        XCTAssertNil(
            router.destination(
                for: .openFH6TuneMenuLab,
                from: resultStep(noReadyValues),
                authoritativeSnapshot:
                    actionSnapshot(noReadyValues)
            )
        )

        var edited = tune
        edited.request.car.weightPounds += 1
        XCTAssertNil(
            router.destination(
                for: .openFH6TuneMenuLab,
                from: resultStep(edited),
                authoritativeSnapshot: actionSnapshot(tune)
            )
        )
    }

}
