//
//  BetaValidationMissionTests.swift
//  forzadvisorTests
//
//  Deterministic contracts for the local beta-testing mission board.
//

import XCTest
@testable import forzadvisor

final class BetaValidationMissionTests: XCTestCase {
    private let fh5ID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private let fh6ID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!

    func testEmptyGarageOffersOneStarterMissionForEachGame() {
        let board = BetaValidationMissionPlanner().makeBoard(setups: [])

        XCTAssertEqual(
            board.missions.map(\.kind),
            [.startFH5Plan, .startFH6Tune]
        )
        XCTAssertEqual(
            board.missions.map(\.destination),
            [.catalog(.fh5), .catalog(.fh6)]
        )
        XCTAssertEqual(
            board.progress,
            BetaValidationProgress(
                savedSetupCount: 0,
                evidenceRecordCount: 0,
                exactUpgradePathSetupCount: 0,
                availableMissionCount: 2
            )
        )
    }

    func testEligibleSavedSetupsProduceStableOrderedMissionsAndProgress() {
        let setups = [
            facts(
                id: fh6ID,
                game: .fh6,
                name: "Zulu Sentinel",
                research: false,
                tires: true,
                upgrades: true,
                testDrive: true,
                evidence: 3,
                exactPaths: true
            ),
            facts(
                id: fh5ID,
                game: .fh5,
                name: "Alpha Sentinel",
                research: true,
                tires: false,
                upgrades: true,
                testDrive: false,
                evidence: 2,
                exactPaths: false
            )
        ]

        let board = BetaValidationMissionPlanner().makeBoard(setups: setups)

        XCTAssertEqual(
            board.missions.map(\.kind),
            [
                .recordFH5Research,
                .verifyTireRanges,
                .verifyUpgradeParts,
                .verifyUpgradeParts,
                .recordTestDrive
            ]
        )
        XCTAssertEqual(
            board.missions.filter { $0.kind == .verifyUpgradeParts }.map(\.savedTuneID),
            [fh5ID, fh6ID]
        )
        XCTAssertEqual(
            board.progress,
            BetaValidationProgress(
                savedSetupCount: 2,
                evidenceRecordCount: 5,
                exactUpgradePathSetupCount: 1,
                availableMissionCount: 5
            )
        )
        XCTAssertEqual(
            BetaValidationMissionPlanner().makeBoard(setups: Array(setups.reversed())).missions,
            board.missions
        )
        XCTAssertEqual(Set(board.missions.map(\.id)).count, board.missions.count)
    }

    func testCompletedSetupsNeedNoMissionsButStillCountTowardProgress() {
        let board = BetaValidationMissionPlanner().makeBoard(setups: [
            facts(
                id: fh5ID,
                game: .fh5,
                name: "FH5",
                research: false,
                tires: false,
                upgrades: false,
                testDrive: false,
                evidence: 4,
                exactPaths: true
            ),
            facts(
                id: fh6ID,
                game: .fh6,
                name: "FH6",
                research: false,
                tires: false,
                upgrades: false,
                testDrive: false,
                evidence: 6,
                exactPaths: true
            )
        ])

        XCTAssertTrue(board.missions.isEmpty)
        XCTAssertEqual(board.progress.savedSetupCount, 2)
        XCTAssertEqual(board.progress.evidenceRecordCount, 10)
        XCTAssertEqual(board.progress.exactUpgradePathSetupCount, 2)
        XCTAssertEqual(board.progress.availableMissionCount, 0)
    }

    func testOneGameGarageOffersOnlyTheMissingGameStarter() {
        let fh5Only = BetaValidationMissionPlanner().makeBoard(setups: [
            facts(
                id: fh5ID,
                game: .fh5,
                name: "FH5",
                research: false,
                tires: false,
                upgrades: false,
                testDrive: false,
                evidence: 0,
                exactPaths: false
            )
        ])
        let fh6Only = BetaValidationMissionPlanner().makeBoard(setups: [
            facts(
                id: fh6ID,
                game: .fh6,
                name: "FH6",
                research: false,
                tires: false,
                upgrades: false,
                testDrive: false,
                evidence: 0,
                exactPaths: false
            )
        ])

        XCTAssertEqual(fh5Only.missions.map(\.kind), [.startFH6Tune])
        XCTAssertEqual(fh6Only.missions.map(\.kind), [.startFH5Plan])
    }

    func testProgressShareIsDeterministicAggregateOnlyAndUsesMarketingURL() {
        let privateTokens = [
            "SECRET-CAR-NAME",
            "SECRET-DISCIPLINE",
            "11111111-1111-1111-1111-111111111111",
            "29.5 PSI",
            "garage-note",
            "provider-id"
        ]
        let board = BetaValidationMissionPlanner().makeBoard(setups: [
            facts(
                id: fh5ID,
                game: .fh5,
                name: privateTokens[0],
                discipline: privateTokens[1],
                research: true,
                tires: false,
                upgrades: true,
                testDrive: false,
                evidence: 7,
                exactPaths: true
            )
        ])

        let first = board.progressShare
        let second = board.progressShare

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.subject, "ForzAdvisor Beta Validation Progress")
        XCTAssertTrue(first.text.contains("Saved setups: 1"))
        XCTAssertTrue(first.text.contains("Permission-bound evidence records: 7"))
        XCTAssertTrue(first.text.contains("Setups with exact upgrade paths: 1"))
        XCTAssertTrue(first.text.contains("Validation missions ready: 3"))
        XCTAssertTrue(first.text.contains("https://Sankofa06.github.io/ForzAdvisor/"))
        for token in privateTokens {
            XCTAssertFalse(first.text.localizedCaseInsensitiveContains(token), token)
        }
    }

    @MainActor
    func testSavedFH5PlanUsesProductionEligibilityAndCorruptStorageFailsClosed() async throws {
        let plan = try await makeFH5Plan()
        let saved = try SavedTune(tune: plan)

        let board = BetaValidationMissionPlanner().makeBoard(savedTunes: [saved])

        XCTAssertEqual(board.progress.savedSetupCount, 1)
        XCTAssertEqual(board.progress.evidenceRecordCount, 0)
        XCTAssertEqual(board.progress.exactUpgradePathSetupCount, 0)
        XCTAssertEqual(
            board.missions.map(\.kind),
            [.startFH6Tune, .recordFH5Research, .verifyUpgradeParts]
        )
        XCTAssertTrue(board.missions.dropFirst().allSatisfy { $0.savedTuneID == saved.id })

        saved.replaceTuneDataForTesting(Data("corrupt".utf8))
        let corruptBoard = BetaValidationMissionPlanner().makeBoard(savedTunes: [saved])
        XCTAssertEqual(
            corruptBoard.missions.map(\.kind),
            [.startFH5Plan, .startFH6Tune]
        )
        XCTAssertEqual(corruptBoard.progress.savedSetupCount, 0)
        XCTAssertEqual(corruptBoard.progress.evidenceRecordCount, 0)
    }

    @MainActor
    func testCorruptEvidenceBlobsExcludeSetupAndProgressFailClosed() async throws {
        let plan = try await makeFH5Plan()

        for evidenceKind in 0..<3 {
            let saved = try SavedTune(tune: plan)
            switch evidenceKind {
            case 0:
                saved.replaceValidationRecordsDataForTesting(Data("corrupt".utf8))
            case 1:
                saved.replaceFH5ResearchObservationRecordsDataForTesting(
                    Data("corrupt".utf8)
                )
            default:
                saved.replaceFH5ResearchReviewEntriesDataForTesting(
                    Data("corrupt".utf8)
                )
            }

            let board = BetaValidationMissionPlanner().makeBoard(savedTunes: [saved])

            XCTAssertEqual(
                board.missions.map(\.kind),
                [.startFH5Plan, .startFH6Tune]
            )
            XCTAssertEqual(board.progress.savedSetupCount, 0)
            XCTAssertEqual(board.progress.evidenceRecordCount, 0)
        }
    }

    private func makeFH5Plan() async throws -> TuneResult {
        let catalog = try BundledCarCatalog.load().get()
        let entry = try XCTUnwrap(catalog.entries.first { $0.game == .fh5 })
        let selection = catalog.selection(for: entry)
        let request = TuneRequest(
            car: selection.carInput,
            discipline: .road,
            buildSnapshot: selection.capabilityOnlyBuildSnapshot(
                capturedAt: Date(timeIntervalSinceReferenceDate: 500)
            )
        )
        return try await CapabilityProjectingTuneProvider(base: CompositeTuneProvider())
            .generateTune(for: request)
    }

    private func facts(
        id: UUID,
        game: ForzaGame,
        name: String,
        discipline: String = "Road",
        research: Bool,
        tires: Bool,
        upgrades: Bool,
        testDrive: Bool,
        evidence: Int,
        exactPaths: Bool
    ) -> BetaValidationSetupFacts {
        BetaValidationSetupFacts(
            savedTuneID: id,
            game: game,
            carDisplayName: name,
            disciplineTitle: discipline,
            canRecordFH5Research: research,
            canVerifyTireRanges: tires,
            canVerifyUpgradeParts: upgrades,
            canRecordTestDrive: testDrive,
            evidenceRecordCount: evidence,
            hasExactUpgradePaths: exactPaths
        )
    }
}
