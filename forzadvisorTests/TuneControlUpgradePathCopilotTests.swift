//
//  TuneControlUpgradePathCopilotTests.swift
//  forzadvisorTests
//
//  Count-only Copilot guidance for exact path copy controls.
//

import XCTest
@testable import forzadvisor

final class TuneControlUpgradePathCopilotTests: XCTestCase {
    func testExactPathGuidanceIsCountOnlyForBothGames() {
        let fh5 = response(
            purpose: .fh5BuildPlan,
            readyCount: 0
        )
        let fh6 = response(
            purpose: .numericTune,
            readyCount: 2
        )

        XCTAssertTrue(fh5.contains("Copy This Path"))
        XCTAssertTrue(fh5.contains("3 exact FH5 paths"))
        XCTAssertTrue(fh6.contains("Copy This Path"))
        XCTAssertTrue(fh6.contains("3 exact FH6 paths"))
        for message in [fh5, fh6] {
            XCTAssertTrue(message.contains(
                "alternatives are not cumulative"
            ))
            XCTAssertTrue(message.contains(
                "Copilot does not choose between them"
            ))
            for forbidden in [
                "Race", "Sport", "Rally", "Offroad",
                "Transmission", "Differential", "cost", "credits",
                "PI "
            ] {
                XCTAssertFalse(message.contains(forbidden), forbidden)
            }
        }
    }

    func testFH5HigherPriorityWorkStillWins() {
        let candidate = response(
            purpose: .fh5BuildPlan,
            readyCount: 0,
            candidateTrial: true
        )
        let observation = response(
            purpose: .fh5BuildPlan,
            readyCount: 0,
            observationRecorded: true
        )
        let research = response(
            purpose: .fh5BuildPlan,
            readyCount: 0,
            researchLab: true
        )
        let upgrade = response(
            purpose: .fh5BuildPlan,
            readyCount: 0,
            upgradeLab: true
        )

        XCTAssertTrue(candidate.contains("Candidate Trial"))
        XCTAssertTrue(observation.contains("raw FH5"))
        XCTAssertTrue(research.contains("Research Lab"))
        XCTAssertTrue(upgrade.contains("Upgrade Lab"))
        for message in [candidate, observation, research, upgrade] {
            XCTAssertFalse(message.contains("Copy This Path"))
        }
    }

    func testFH6HigherPriorityWorkStillWins() {
        let expectations: [(String, String)] = [
            (
                response(
                    purpose: .numericTune,
                    readyCount: 2,
                    tuneMenuLab: true
                ),
                "Tune Menu Lab"
            ),
            (
                response(
                    purpose: .numericTune,
                    readyCount: 2,
                    tireLab: true
                ),
                "Tire Lab"
            ),
            (
                response(
                    purpose: .numericTune,
                    readyCount: 2,
                    upgradeLab: true
                ),
                "Upgrade Lab"
            ),
            (
                response(
                    purpose: .numericTune,
                    readyCount: 2,
                    testDrive: true
                ),
                "Record Test Drive"
            ),
            (
                response(
                    purpose: .numericTune,
                    readyCount: 2,
                    community: true
                ),
                "Community Reference Comparison"
            )
        ]

        for (message, expected) in expectations {
            XCTAssertTrue(message.contains(expected), expected)
            XCTAssertFalse(message.contains("Copy This Path"))
        }
    }

    private func response(
        purpose: TuneResultPurpose,
        readyCount: Int,
        tuneMenuLab: Bool = false,
        tireLab: Bool = false,
        upgradeLab: Bool = false,
        researchLab: Bool = false,
        observationRecorded: Bool = false,
        candidateTrial: Bool = false,
        testDrive: Bool = false,
        community: Bool = false
    ) -> String {
        let facts = CopilotProjectionFacts(
            resultPurpose: purpose,
            readyCount: readyCount,
            blockedByStatus: [],
            blockedByReason: [],
            tuneMenuLabEligible: tuneMenuLab,
            tireLabEligible: tireLab,
            upgradeLabEligible: upgradeLab,
            fh5ResearchLabEligible: researchLab,
            fh5ObservationRecorded: observationRecorded,
            fh5CandidateTrialAvailable: candidateTrial,
            fh6RecordTestDriveEligible: testDrive,
            fh6CommunityReferenceTrialEligible: community,
            exactUpgradePathCount: 3,
            isSaved: true,
            isStreaming: false
        )
        let context = CopilotContext(
            phase: .result,
            carDisplayName: "Not visible to Copilot",
            gameTitle: nil,
            disciplineTitle: nil,
            savedTuneCount: nil,
            catalogCarCount: nil,
            projection: facts,
            cannotSeeUnsavedEdits: false
        )
        return CopilotEngine().response(
            to: .nextStep,
            in: context
        ).message
    }
}
