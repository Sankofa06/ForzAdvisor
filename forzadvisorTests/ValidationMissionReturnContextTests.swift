import XCTest
@testable import forzadvisor

final class ValidationMissionReturnContextTests: XCTestCase {
    func testMissionContextBindsIdentityKindTuneAndDestination() {
        let tuneID = UUID()
        let mission = BetaValidationMission(
            kind: .recordTestDrive,
            game: .fh6,
            savedTuneID: tuneID,
            carDisplayName: "Car",
            disciplineTitle: "Road"
        )
        let context = ValidationMissionReturnContext(mission: mission)

        XCTAssertEqual(context.missionID, mission.id)
        XCTAssertEqual(context.kind, .recordTestDrive)
        XCTAssertEqual(context.returnDestination, .betaMissions)
        XCTAssertTrue(context.isBound(to: tuneID))
        XCTAssertFalse(context.isBound(to: UUID()))
    }

    func testOutcomeCopyDistinguishesLocalReuseAndBack() {
        XCTAssertTrue(
            ValidationMissionReturnOutcome.completedLocalOnly.message
                .contains("reuse is still off")
        )
        XCTAssertTrue(
            ValidationMissionReturnOutcome.completedOnDevice.message
                .contains("on this device")
        )
        XCTAssertTrue(
            ValidationMissionReturnOutcome.draftPreserved.message
                .contains("not completed")
        )
        XCTAssertTrue(
            ValidationMissionReturnOutcome.stale.message
                .contains("no longer available")
        )
    }

    func testDirectFlowHasNoMissionReturnAndDeletedTuneFailsClosed() {
        let policy = ValidationMissionReturnPolicy()
        XCTAssertNil(policy.resolve(
            active: nil,
            expected: nil,
            requested: .completedOnDevice,
            savedTuneExists: true
        ))

        let mission = BetaValidationMission(
            kind: .recordTestDrive,
            game: .fh6,
            savedTuneID: UUID(),
            carDisplayName: "Car",
            disciplineTitle: "Road"
        )
        let context = ValidationMissionReturnContext(mission: mission)
        XCTAssertEqual(
            policy.resolve(
                active: context,
                expected: context,
                requested: .completedLocalOnly,
                savedTuneExists: false
            ),
            .stale
        )
    }
}
