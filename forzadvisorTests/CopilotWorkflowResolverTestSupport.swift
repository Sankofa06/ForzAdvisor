import SwiftData
import XCTest
@testable import forzadvisor

extension CopilotWorkflowActionRouterTests {
    func assertDestination(
        _ destination: WorkflowStep,
        route: Route,
        expectedTune: TuneResult,
        expectedThumbnailData: Data?,
        expectedPlayerNotes: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let payload: (
            tune: TuneResult,
            savedTuneID: UUID?,
            thumbnailData: Data?,
            playerNotes: String
        )
        switch (route, destination) {
        case let (
            .tuneMenu,
            .fh6TuneMenuCapture(
                tune,
                savedTuneID,
                thumbnailData,
                playerNotes
            )
        ),
        let (
            .tire,
            .tirePressureCapture(
                tune,
                savedTuneID,
                thumbnailData,
                playerNotes
            )
        ),
        let (
            .upgrade,
            .upgradePartCapture(
                tune,
                savedTuneID,
                thumbnailData,
                playerNotes
            )
        ):
            payload = (
                tune,
                savedTuneID,
                thumbnailData,
                playerNotes
            )
        case let (
            .research,
            .fh5ResearchCapture(
                tune,
                savedTuneID,
                thumbnailData,
                playerNotes
            )
        ):
            payload = (
                tune,
                Optional(savedTuneID),
                thumbnailData,
                playerNotes
            )
        default:
            return XCTFail(
                "Unexpected destination for \(route)",
                file: file,
                line: line
            )
        }

        XCTAssertEqual(payload.tune, expectedTune, file: file, line: line)
        XCTAssertEqual(
            payload.savedTuneID,
            savedTuneID,
            file: file,
            line: line
        )
        XCTAssertEqual(
            payload.thumbnailData,
            expectedThumbnailData,
            file: file,
            line: line
        )
        XCTAssertEqual(
            payload.playerNotes,
            expectedPlayerNotes,
            file: file,
            line: line
        )
    }

    func readyField(_ field: TuneFieldID) -> TuneFieldProjection {
        TuneFieldProjection(
            field: field,
            status: .ready,
            requiredPurchaseIDs: [],
            unresolvedPartIDs: [],
            reason: nil
        )
    }

    func constrainedField(
        _ field: TuneFieldID
    ) -> TuneFieldProjection {
        TuneFieldProjection(
            field: field,
            status: .needsConstraint,
            requiredPurchaseIDs: [],
            unresolvedPartIDs: [],
            reason: .missingProductionConstraint
        )
    }

    func partConfirmationField(
        _ field: TuneFieldID
    ) -> TuneFieldProjection {
        TuneFieldProjection(
            field: field,
            status: .needsPartConfirmation,
            requiredPurchaseIDs: [],
            unresolvedPartIDs: [.sportTransmission],
            reason: .partAvailabilityUnknown
        )
    }

    var finalDriveConfirmation: TuneSettingConfirmation {
        TuneSettingConfirmation(
            setting: .finalDrive,
            candidateParts: [
                TunePartCatalog.definition(for: .sportTransmission)
            ]
        )
    }

    func validFH5ResearchCapture(
        for tune: TuneResult
    ) -> FH5ResearchCapture {
        let gearCount = 6
        return FH5ResearchCapture(
            platform: .xboxSeries,
            gameVersion: "test-build",
            tireCompoundDisplayName: "Stock",
            forwardGearCount: gearCount,
            controls: TuneFieldID.expectedFields(
                drivetrain: tune.request.car.drivetrain,
                gearCount: gearCount
            ).map {
                FH5TuneFieldObservation(
                    field: $0,
                    availability: .notShown
                )
            },
            exactUntouchedStockConfirmed: true,
            allSlidersRestoredConfirmed: true,
            personallyReadFromGameConfirmed: true,
            firstPartyAuthorshipConfirmed: true,
            localStoragePermitted: true
        )
    }

    func validValidationCapture()
        -> FirstPartyValidationCapture {
        .init(
            courseType: .testTrack,
            surface: .dry,
            input: .controller,
            runCount: 3,
            verdict: .keep,
            feedback: [],
            exactSetupConfirmed: true,
            allExportedSettingsApplied: true,
            firstPartyAuthorshipConfirmed: true,
            deidentifiedReusePermitted: true
        )
    }

    enum Route {
        case tuneMenu
        case tire
        case upgrade
        case research
    }
}
