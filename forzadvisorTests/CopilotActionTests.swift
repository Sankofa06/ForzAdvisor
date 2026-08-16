import XCTest
@testable import forzadvisor

extension CopilotTests {
    func testNextStepActionMatchesFH6LabMessagePriority() {
        let engine = CopilotEngine()
        let tuneMenu = CopilotProjectionFacts(
            readyCount: 2,
            blockedByStatus: [],
            blockedByReason: [],
            tuneMenuLabEligible: true,
            tireLabEligible: true,
            upgradeLabEligible: true,
            exactUpgradePathCount: 0,
            isSaved: true,
            isStreaming: false
        )
        let tire = CopilotProjectionFacts(
            readyCount: 2,
            blockedByStatus: [],
            blockedByReason: [],
            tuneMenuLabEligible: false,
            tireLabEligible: true,
            upgradeLabEligible: true,
            exactUpgradePathCount: 0,
            isSaved: true,
            isStreaming: false
        )
        let upgrade = CopilotProjectionFacts(
            readyCount: 2,
            blockedByStatus: [],
            blockedByReason: [],
            tuneMenuLabEligible: false,
            tireLabEligible: false,
            upgradeLabEligible: true,
            exactUpgradePathCount: 0,
            isSaved: true,
            isStreaming: false
        )
        let community = CopilotProjectionFacts(
            readyCount: 2,
            blockedByStatus: [],
            blockedByReason: [],
            tuneMenuLabEligible: false,
            tireLabEligible: false,
            upgradeLabEligible: false,
            fh6RecordTestDriveEligible: false,
            fh6CommunityReferenceTrialEligible: true,
            exactUpgradePathCount: 0,
            isSaved: true,
            isStreaming: false
        )
        let recordTestDrive = CopilotProjectionFacts(
            readyCount: 2,
            blockedByStatus: [],
            blockedByReason: [],
            tuneMenuLabEligible: false,
            tireLabEligible: false,
            upgradeLabEligible: false,
            fh6RecordTestDriveEligible: true,
            fh6CommunityReferenceTrialEligible: true,
            exactUpgradePathCount: 0,
            isSaved: true,
            isStreaming: false
        )

        XCTAssertEqual(
            engine.defaultResponse(in: resultContext(tuneMenu)).action,
            .openFH6TuneMenuLab
        )
        XCTAssertEqual(
            engine.defaultResponse(in: resultContext(tire)).action,
            .openTireLab
        )
        XCTAssertEqual(
            engine.defaultResponse(in: resultContext(upgrade)).action,
            .openUpgradeLab
        )
        XCTAssertEqual(
            engine.defaultResponse(
                in: resultContext(recordTestDrive)
            ).action,
            .openRecordTestDrive
        )
        XCTAssertEqual(
            engine.defaultResponse(in: resultContext(community)).action,
            .openFH6CommunityReferenceTrial
        )
        XCTAssertTrue(
            engine.defaultResponse(
                in: resultContext(recordTestDrive)
            ).message.contains("first-party validation")
        )
        XCTAssertTrue(
            engine.defaultResponse(in: resultContext(community))
                .message.contains("not validation")
        )
    }

    func testCopilotActionsRequireCompletedEligiblePersistedResult() {
        let engine = CopilotEngine()
        let eligible = CopilotProjectionFacts(
            readyCount: 2,
            blockedByStatus: [],
            blockedByReason: [],
            tuneMenuLabEligible: true,
            tireLabEligible: true,
            upgradeLabEligible: true,
            exactUpgradePathCount: 0,
            isSaved: true,
            isStreaming: false
        )
        let streaming = CopilotProjectionFacts(
            readyCount: 2,
            blockedByStatus: [],
            blockedByReason: [],
            tuneMenuLabEligible: true,
            tireLabEligible: true,
            upgradeLabEligible: true,
            exactUpgradePathCount: 0,
            isSaved: true,
            isStreaming: true
        )
        let withheld = CopilotProjectionFacts(
            readyCount: 0,
            blockedByStatus: [],
            blockedByReason: [],
            tuneMenuLabEligible: true,
            tireLabEligible: true,
            upgradeLabEligible: true,
            exactUpgradePathCount: 0,
            isSaved: false,
            isStreaming: false
        )
        let fh5Eligible = CopilotProjectionFacts(
            resultPurpose: .fh5BuildPlan,
            readyCount: 0,
            blockedByStatus: [],
            blockedByReason: [],
            tuneMenuLabEligible: false,
            tireLabEligible: false,
            upgradeLabEligible: true,
            fh5ResearchLabEligible: false,
            fh5ObservationRecorded: false,
            fh5CandidateTrialAvailable: false,
            exactUpgradePathCount: 0,
            isSaved: true,
            isStreaming: false
        )
        let fh5Unsaved = CopilotProjectionFacts(
            resultPurpose: .fh5BuildPlan,
            readyCount: 0,
            blockedByStatus: [],
            blockedByReason: [],
            tuneMenuLabEligible: false,
            tireLabEligible: false,
            upgradeLabEligible: true,
            fh5ResearchLabEligible: true,
            fh5ObservationRecorded: false,
            fh5CandidateTrialAvailable: false,
            exactUpgradePathCount: 0,
            isSaved: false,
            isStreaming: false
        )
        let fh5Streaming = CopilotProjectionFacts(
            resultPurpose: .fh5BuildPlan,
            readyCount: 0,
            blockedByStatus: [],
            blockedByReason: [],
            tuneMenuLabEligible: nil,
            tireLabEligible: nil,
            upgradeLabEligible: nil,
            exactUpgradePathCount: nil,
            isSaved: nil,
            isStreaming: true
        )
        let fh5Ineligible = CopilotProjectionFacts(
            resultPurpose: .fh5BuildPlan,
            readyCount: 0,
            blockedByStatus: [],
            blockedByReason: [],
            tuneMenuLabEligible: false,
            tireLabEligible: false,
            upgradeLabEligible: false,
            exactUpgradePathCount: 0,
            isSaved: true,
            isStreaming: false
        )

        for intent in [CopilotIntent.trust, .missing, .privacy] {
            XCTAssertNil(
                engine.response(to: intent, in: resultContext(eligible)).action
            )
        }
        XCTAssertNil(
            engine.defaultResponse(in: resultContext(streaming)).action
        )
        XCTAssertNil(
            engine.defaultResponse(in: resultContext(withheld)).action
        )
        let fh5Context = resultContext(fh5Eligible)
        XCTAssertEqual(
            engine.defaultResponse(in: fh5Context).action,
            .openUpgradeLab
        )
        XCTAssertEqual(
            engine.response(to: .nextStep, in: fh5Context).action,
            .openUpgradeLab
        )
        XCTAssertTrue(
            engine.defaultResponse(in: fh5Context)
                .message.contains("Open Upgrade Lab")
        )
        let higherPriorityCases: [
            (
                facts: CopilotProjectionFacts,
                expectedCopy: String,
                expectedAction: CopilotAction?
            )
        ] = [
            (
                CopilotProjectionFacts(
                    resultPurpose: .fh5BuildPlan,
                    readyCount: 0,
                    blockedByStatus: [],
                    blockedByReason: [],
                    tuneMenuLabEligible: false,
                    tireLabEligible: false,
                    upgradeLabEligible: true,
                    fh5ResearchLabEligible: true,
                    fh5ObservationRecorded: true,
                    fh5CandidateTrialAvailable: true,
                    exactUpgradePathCount: 0,
                    isSaved: true,
                    isStreaming: false
                ),
                "experimental FH5 Candidate Trial",
                nil
            ),
            (
                CopilotProjectionFacts(
                    resultPurpose: .fh5BuildPlan,
                    readyCount: 0,
                    blockedByStatus: [],
                    blockedByReason: [],
                    tuneMenuLabEligible: false,
                    tireLabEligible: false,
                    upgradeLabEligible: true,
                    fh5ResearchLabEligible: true,
                    fh5ObservationRecorded: true,
                    fh5CandidateTrialAvailable: false,
                    exactUpgradePathCount: 0,
                    isSaved: true,
                    isStreaming: false
                ),
                "raw FH5 stock-menu evidence",
                nil
            ),
            (
                CopilotProjectionFacts(
                    resultPurpose: .fh5BuildPlan,
                    readyCount: 0,
                    blockedByStatus: [],
                    blockedByReason: [],
                    tuneMenuLabEligible: false,
                    tireLabEligible: false,
                    upgradeLabEligible: true,
                    fh5ResearchLabEligible: true,
                    fh5ObservationRecorded: false,
                    fh5CandidateTrialAvailable: false,
                    exactUpgradePathCount: 0,
                    isSaved: true,
                    isStreaming: false
                ),
                "Open FH5 Research Lab",
                .openFH5ResearchLab
            )
        ]
        for item in higherPriorityCases {
            let response = engine.defaultResponse(
                in: resultContext(item.facts)
            )
            XCTAssertTrue(
                response.message.contains(item.expectedCopy)
            )
            XCTAssertFalse(
                response.message.contains("Open Upgrade Lab")
            )
            XCTAssertEqual(response.action, item.expectedAction)
        }
        for intent in [
            CopilotIntent.trust, .missing, .privacy
        ] {
            XCTAssertNil(
                engine.response(to: intent, in: fh5Context).action
            )
        }
        XCTAssertNil(
            engine.defaultResponse(
                in: resultContext(fh5Unsaved)
            ).action
        )
        XCTAssertNil(
            engine.defaultResponse(
                in: resultContext(fh5Streaming)
            ).action
        )
        XCTAssertNil(
            engine.defaultResponse(
                in: resultContext(fh5Ineligible)
            ).action
        )
        let eligibleContext = resultContext(eligible)
        let missingProjection = CopilotContext(
            phase: .result,
            carDisplayName: eligibleContext.carDisplayName,
            gameTitle: eligibleContext.gameTitle,
            disciplineTitle: eligibleContext.disciplineTitle,
            savedTuneCount: nil,
            catalogCarCount: nil,
            projection: nil,
            cannotSeeUnsavedEdits: false
        )
        XCTAssertNil(
            engine.defaultResponse(in: missingProjection).action
        )
        XCTAssertNil(
            engine.defaultResponse(
                in: syntheticContext(for: .recordTestDrive)
            ).action
        )
    }

}
