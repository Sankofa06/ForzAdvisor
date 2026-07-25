//
//  CopilotTests.swift
//  forzadvisorTests
//
//  Closed-intent, phase coverage, and value-isolation tests for Copilot v1.
//

import XCTest
@testable import forzadvisor

final class CopilotTests: XCTestCase {
    func testParserAcceptsOnlyClosedPhrasesAndExplicitSynonyms() {
        let accepted: [(String, CopilotIntent)] = [
            (" Next step ", .nextStep),
            ("WHAT SHOULD I DO NEXT", .nextStep),
            ("what do i do next", .nextStep),
            ("What can I trust?", .trust),
            ("what is verified", .trust),
            ("what's verified", .trust),
            ("What is missing?", .missing),
            ("what's missing", .missing),
            ("what still needs verification", .missing),
            ("Privacy", .privacy),
            ("is this private", .privacy),
            ("how is my data used", .privacy)
        ]
        for (question, intent) in accepted {
            XCTAssertEqual(CopilotIntent.parse(question), intent, question)
        }

        let rejected = [
            "",
            "next step and what can I trust",
            "what can I trust and what is missing",
            "blorp glorp",
            "give me 31.5 PSI",
            "set final drive to 3.80",
            "what PI should I use",
            "what will this cost",
            "how much performance will I gain",
            "which parts are available",
            "search the web",
            "compare Reddit tunes",
            "find a YouTube source",
            "give me general tuning advice",
            "what can i trust please"
        ]
        for question in rejected {
            XCTAssertNil(CopilotIntent.parse(question), question)
        }
    }

    func testEveryWorkflowPhaseAnswersEverySupportedIntent() {
        let engine = CopilotEngine()
        XCTAssertEqual(CopilotPhase.allCases.count, 24)

        for phase in CopilotPhase.allCases {
            let context = syntheticContext(for: phase)
            for intent in CopilotIntent.allCases {
                let response = engine.response(to: intent, in: context)
                XCTAssertEqual(response.intent, intent, "\(phase.rawValue) / \(intent.rawValue)")
                XCTAssertFalse(response.title.isEmpty, "\(phase.rawValue) / \(intent.rawValue)")
                XCTAssertFalse(response.message.isEmpty, "\(phase.rawValue) / \(intent.rawValue)")
                if intent != .nextStep || phase != .result {
                    XCTAssertNil(response.action, "\(phase.rawValue) / \(intent.rawValue)")
                }
            }
        }
    }

    func testModalCopilotDestinationsExposeOnlyAllowListedFacts() {
        let destinations: [ModalCopilotDestination] = [
            .settings,
            .betaMissions(savedSetupCount: 7),
            .fh6ValidationReview(
                carDisplayName: "Committed FH6 Car",
                gameTitle: "FH6",
                disciplineTitle: "Road"
            ),
            .fh6CommunityOutcomeReview(
                carDisplayName: "Committed FH6 Car",
                gameTitle: "FH6",
                disciplineTitle: "Road"
            ),
            .fh5ResearchReview(
                carDisplayName: "Committed FH5 Car",
                gameTitle: "FH5"
            ),
            .fh5CandidateOutcomeReview
        ]

        XCTAssertEqual(
            destinations.map(\.buttonIdentifier),
            destinations.map { "copilotButton-\($0.phase.rawValue)" }
        )
        XCTAssertEqual(
            Set(destinations.map(\.buttonIdentifier)).count,
            destinations.count
        )
        XCTAssertEqual(
            Set(destinations.map(\.phase)).count,
            destinations.count
        )
        XCTAssertTrue(destinations.allSatisfy {
            !$0.accessibilityHint.isEmpty
        })

        let settings = destinations[0].context
        XCTAssertEqual(settings.facts, [
            CopilotFact(
                label: "Unsaved fields",
                value: "Not visible to Copilot"
            )
        ])
        XCTAssertTrue(settings.cannotSeeUnsavedEdits)

        let beta = destinations[1].context
        XCTAssertEqual(beta.savedTuneCount, 7)
        XCTAssertEqual(beta.facts, [
            CopilotFact(label: "Saved tunes", value: "7")
        ])
        XCTAssertFalse(beta.cannotSeeUnsavedEdits)

        for context in destinations[2...3].map(\.context) {
            XCTAssertEqual(context.carDisplayName, "Committed FH6 Car")
            XCTAssertEqual(context.gameTitle, "FH6")
            XCTAssertEqual(context.disciplineTitle, "Road")
            XCTAssertEqual(
                context.facts.map(\.label),
                ["Car", "Game", "Discipline", "Unsaved fields"]
            )
            XCTAssertTrue(context.cannotSeeUnsavedEdits)
        }

        let research = destinations[4].context
        XCTAssertEqual(research.carDisplayName, "Committed FH5 Car")
        XCTAssertEqual(research.gameTitle, "FH5")
        XCTAssertNil(research.disciplineTitle)
        XCTAssertEqual(
            research.facts.map(\.label),
            ["Car", "Game", "Unsaved fields"]
        )
        XCTAssertTrue(research.cannotSeeUnsavedEdits)

        let candidate = destinations[5].context
        XCTAssertEqual(candidate.facts, [
            CopilotFact(
                label: "Unsaved fields",
                value: "Not visible to Copilot"
            )
        ])
        XCTAssertTrue(candidate.cannotSeeUnsavedEdits)

        for destination in destinations {
            let context = destination.context
            XCTAssertNil(context.catalogCarCount)
            XCTAssertNil(context.projection)
            XCTAssertNil(context.fh5CandidateTrialAvailable)
            for intent in CopilotIntent.allCases {
                XCTAssertNil(
                    CopilotEngine()
                        .response(to: intent, in: context)
                        .action,
                    "\(destination.phase.rawValue) / \(intent.rawValue)"
                )
            }
        }
    }

    func testModalCopilotContextsDoNotContainDraftOrCredentialFields()
        throws {
        let destinations: [ModalCopilotDestination] = [
            .settings,
            .betaMissions(savedSetupCount: 4),
            .fh6ValidationReview(
                carDisplayName: "Committed Car",
                gameTitle: "FH6",
                disciplineTitle: "Road"
            ),
            .fh6CommunityOutcomeReview(
                carDisplayName: "Committed Car",
                gameTitle: "FH6",
                disciplineTitle: "Road"
            ),
            .fh5ResearchReview(
                carDisplayName: "Committed Car",
                gameTitle: "FH5"
            ),
            .fh5CandidateOutcomeReview
        ]
        let forbidden = [
            "apiKey",
            "provider",
            "pastedJSON",
            "permission",
            "tuneValue",
            "notes",
            "thumbnail",
            "fingerprint",
            "draft"
        ]

        for destination in destinations {
            let encoded = try XCTUnwrap(
                String(
                    data: JSONEncoder().encode(destination.context),
                    encoding: .utf8
                )
            )
            for key in forbidden {
                XCTAssertFalse(
                    encoded.localizedCaseInsensitiveContains(key),
                    "\(destination.phase.rawValue) unexpectedly encoded \(key)"
                )
            }
        }
    }

    func testDefaultResponseExactlyMatchesNextStepForEveryWorkflowPhase() {
        let engine = CopilotEngine()

        for phase in CopilotPhase.allCases {
            let context = syntheticContext(for: phase)
            let response = engine.defaultResponse(in: context)

            XCTAssertEqual(
                response,
                engine.response(to: .nextStep, in: context),
                phase.rawValue
            )
            XCTAssertEqual(response.intent, .nextStep, phase.rawValue)
            XCTAssertFalse(response.title.isEmpty, phase.rawValue)
            XCTAssertFalse(response.message.isEmpty, phase.rawValue)
        }
    }

    func testEveryWorkflowStepMapsToItsTruthfulPhase() throws {
        let selection = try catalogSelection()
        let car = selection.carInput
        let draft = ManualEntryDraft(car: car)
        let request = TuneRequest(car: car, discipline: .road)
        let tune = projectedTune(car: car)
        let steps: [(WorkflowStep, CopilotPhase)] = [
            (.home, .home),
            (.newTune, .newTune),
            (.catalogPicker(), .catalogPicker),
            (.catalogReview(selection), .catalogReview),
            (.catalogEdit(selection), .catalogEdit),
            (.ocrReview(OCRConfirmationDraft()), .ocrReview),
            (.manualEntry(draft, thumbnailData: Data("hidden-image".utf8)), .manualEntry),
            (.discipline(car, origin: .manual(car), thumbnailData: nil), .discipline),
            (.loading(request, thumbnailData: nil, savedTuneID: nil, playerNotes: "", partialTune: nil), .loading),
            (.result(tune, savedTuneID: nil, adjustmentChanges: [], thumbnailData: nil, playerNotes: ""), .result),
            (.fh6TuneMenuCapture(tune, savedTuneID: nil, thumbnailData: nil, playerNotes: ""), .fh6TuneMenuCapture),
            (.tirePressureCapture(tune, savedTuneID: nil, thumbnailData: nil, playerNotes: ""), .tirePressureCapture),
            (.upgradePartCapture(tune, savedTuneID: nil, thumbnailData: nil, playerNotes: ""), .upgradePartCapture),
            (.recordTestDrive(tune, savedTuneID: UUID(), thumbnailData: nil, playerNotes: ""), .recordTestDrive),
            (.fh6CommunityReferenceTrialCapture(tune, savedTuneID: UUID(), thumbnailData: nil, playerNotes: ""), .fh6CommunityReferenceTrialCapture),
            (.editSavedTune(tune, savedTuneID: UUID(), playerNotes: "", thumbnailData: nil), .editSavedTune)
        ]
        let factory = CopilotContextFactory()

        for (step, expectedPhase) in steps {
            let context = factory.make(step: step, savedTuneCount: 7, catalogCarCount: 6)
            XCTAssertEqual(context.phase, expectedPhase)
        }
    }

    func testLiveFormContextsArePhaseOnlyAndDoNotCopyDraftOrTuneFacts() throws {
        let selection = try catalogSelection()
        let car = selection.carInput
        let tune = projectedTune(car: car)
        let draft = ManualEntryDraft(car: car)
        let steps: [WorkflowStep] = [
            .catalogEdit(selection),
            .ocrReview(OCRConfirmationDraft(make: "Secret Make", model: "Secret Model")),
            .manualEntry(draft, thumbnailData: Data("secret-image".utf8)),
            .fh6TuneMenuCapture(tune, savedTuneID: nil, thumbnailData: nil, playerNotes: ""),
            .tirePressureCapture(tune, savedTuneID: nil, thumbnailData: nil, playerNotes: ""),
            .upgradePartCapture(tune, savedTuneID: nil, thumbnailData: nil, playerNotes: ""),
            .recordTestDrive(tune, savedTuneID: UUID(), thumbnailData: nil, playerNotes: "secret-note"),
            .fh6CommunityReferenceTrialCapture(tune, savedTuneID: UUID(), thumbnailData: nil, playerNotes: "secret-note"),
            .editSavedTune(tune, savedTuneID: UUID(), playerNotes: "secret-note", thumbnailData: nil)
        ]

        for step in steps {
            let context = CopilotContextFactory().make(
                step: step,
                savedTuneCount: 0,
                catalogCarCount: 0
            )
            XCTAssertTrue(context.cannotSeeUnsavedEdits)
            XCTAssertNil(context.carDisplayName)
            XCTAssertNil(context.gameTitle)
            XCTAssertNil(context.disciplineTitle)
            XCTAssertNil(context.projection)
            XCTAssertTrue(CopilotEngine().response(to: .nextStep, in: context).message.contains("cannot see unsaved field edits"))
        }
    }

    func testResultAndPartialContextNeverSerializeOrRepeatRawTuneValues() throws {
        let selection = try catalogSelection()
        let tune = projectedTune(car: selection.carInput, rawSentinel: "31.375-secret")
        let result = CopilotContextFactory().make(
            step: .result(tune, savedTuneID: nil, adjustmentChanges: [], thumbnailData: nil, playerNotes: ""),
            savedTuneCount: 0,
            catalogCarCount: 0
        )
        let partial = CopilotContextFactory().make(
            step: .loading(
                tune.request,
                thumbnailData: Data("secret-image".utf8),
                savedTuneID: nil,
                playerNotes: "secret-note",
                partialTune: tune
            ),
            savedTuneCount: 0,
            catalogCarCount: 0
        )

        for context in [result, partial] {
            let encoded = try XCTUnwrap(String(data: JSONEncoder().encode(context), encoding: .utf8))
            XCTAssertFalse(encoded.contains("31.375-secret"))
            XCTAssertFalse(encoded.contains("secret-image"))
            XCTAssertFalse(encoded.contains("secret-note"))
            for intent in CopilotIntent.allCases {
                XCTAssertFalse(
                    CopilotEngine().response(to: intent, in: context).message.contains("31.375-secret")
                )
            }
        }
        XCTAssertEqual(partial.projection?.readyCount, tune.projectionReport?.readyCount)
        XCTAssertTrue(partial.projection?.isStreaming == true)
        XCTAssertNil(partial.projection?.tuneMenuLabEligible)
        XCTAssertNil(partial.projection?.tireLabEligible)
        XCTAssertNil(partial.projection?.upgradeLabEligible)
        XCTAssertNil(partial.projection?.exactUpgradePathCount)
        XCTAssertNil(partial.projection?.isSaved)
        XCTAssertFalse(partial.facts.contains { $0.label == "Tire Lab" })
        XCTAssertFalse(partial.facts.contains { $0.label == "FH6 Tune Menu Lab" })
        XCTAssertFalse(partial.facts.contains { $0.label == "Upgrade Lab" })
        XCTAssertFalse(partial.facts.contains { $0.label == "Exact upgrade paths" })
    }

    func testResultEligibilityAndPathCountsMatchExistingServices() throws {
        let tireTune = try tireEligibleTune()
        let context = CopilotContextFactory().make(
            step: .result(tireTune, savedTuneID: nil, adjustmentChanges: [], thumbnailData: nil, playerNotes: ""),
            savedTuneCount: 0,
            catalogCarCount: 0
        )

        XCTAssertEqual(
            context.projection?.tuneMenuLabEligible,
            FH6TuneMenuCaptureEligibility().snapshot(for: tireTune) != nil
        )
        XCTAssertEqual(
            context.projection?.tireLabEligible,
            TirePressureCaptureEligibility().snapshot(for: tireTune) != nil
        )
        XCTAssertEqual(
            context.projection?.upgradeLabEligible,
            UpgradePartCaptureEligibility().snapshot(for: tireTune) != nil
        )
        XCTAssertEqual(
            context.projection?.exactUpgradePathCount,
            TuneControlUpgradePlanner().paths(for: tireTune).count
        )
        XCTAssertTrue(CopilotEngine().response(to: .nextStep, in: context).message.contains("Tune Menu Lab"))
    }

    func testResultWithoutProjectionMakesNoReadyClaim() throws {
        let selection = try catalogSelection()
        var tune = projectedTune(car: selection.carInput)
        tune.projectionReport = nil
        let context = CopilotContextFactory().make(
            step: .result(tune, savedTuneID: nil, adjustmentChanges: [], thumbnailData: nil, playerNotes: ""),
            savedTuneCount: 0,
            catalogCarCount: 0
        )

        XCTAssertNil(context.projection)
        XCTAssertTrue(CopilotEngine().response(to: .trust, in: context).message.contains("no verified projection report"))
        XCTAssertTrue(CopilotEngine().response(to: .missing, in: context).message.contains("projection report is missing"))
    }

    func testUnsupportedQuestionReturnsStableNoActionResponse() {
        let context = syntheticContext(for: .result)
        let response = CopilotEngine().response(to: "set my tires to 28.5", in: context)

        XCTAssertEqual(response, .unsupported)
        XCTAssertNil(response.intent)
        XCTAssertNil(response.action)
    }

    func testResultPriorityCoversStreamingWithheldUnsavedAndSavedStates() {
        let engine = CopilotEngine()
        var facts = projectionFacts(readyCount: 2, isSaved: false, isStreaming: true)
        var response = engine.response(
            to: .nextStep,
            in: resultContext(facts)
        )
        XCTAssertTrue(response.message.contains("Wait"))
        XCTAssertNil(response.action)

        facts = projectionFacts(readyCount: 0, isSaved: false, isStreaming: false)
        response = engine.response(to: .nextStep, in: resultContext(facts))
        XCTAssertTrue(response.message.contains("withheld"))
        XCTAssertNil(response.action)

        facts = projectionFacts(readyCount: 2, isSaved: false, isStreaming: false)
        response = engine.response(to: .nextStep, in: resultContext(facts))
        XCTAssertTrue(response.message.contains("Save"))
        XCTAssertNil(response.action)

        facts = projectionFacts(readyCount: 2, isSaved: true, isStreaming: false)
        response = engine.response(to: .nextStep, in: resultContext(facts))
        XCTAssertTrue(response.message.contains("guided feedback"))
        XCTAssertNil(response.action)
    }

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

    func testCopilotActionsFailClosedOutsideCompletedEligibleFH6NextStep() {
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
        let fh5 = CopilotProjectionFacts(
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
        XCTAssertNil(
            engine.defaultResponse(in: resultContext(fh5)).action
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

    func testCopilotActionIsClosedPayloadFreeAndDoesNotExposeTuneValues() throws {
        XCTAssertEqual(
            Set(CopilotAction.allCases),
            Set([
                .openFH6TuneMenuLab,
                .openTireLab,
                .openUpgradeLab,
                .openRecordTestDrive,
                .openFH6CommunityReferenceTrial
            ])
        )
        for action in CopilotAction.allCases {
            let encoded = try JSONEncoder().encode(action)
            XCTAssertEqual(
                try JSONDecoder().decode(CopilotAction.self, from: encoded),
                action
            )
            XCTAssertFalse(
                try XCTUnwrap(String(data: encoded, encoding: .utf8))
                    .contains("31.375")
            )
        }
    }

    func testPrivacyExplainsOnlyExplicitActionTapChangesWorkflow() {
        let response = CopilotEngine().response(
            to: .privacy,
            in: syntheticContext(for: .result)
        )

        XCTAssertTrue(
            response.message.contains(
                "does not change your workflow unless you explicitly tap an action"
            )
        )
        XCTAssertNil(response.action)
    }

    func testCandidateTrialCopilotCopyKeepsHypothesisOutOfTuneOutput() throws {
        let facts = CopilotProjectionFacts(
            resultPurpose: .fh5BuildPlan,
            readyCount: 0,
            blockedByStatus: [],
            blockedByReason: [],
            tireLabEligible: false,
            upgradeLabEligible: false,
            fh5ResearchLabEligible: false,
            fh5ObservationRecorded: true,
            fh5CandidateTrialAvailable: true,
            exactUpgradePathCount: 1,
            isSaved: true,
            isStreaming: false
        )
        let result = resultContext(facts)
        let next = CopilotEngine().response(
            to: .nextStep,
            in: result
        ).message
        let missing = CopilotEngine().response(
            to: .missing,
            in: result
        ).message
        let genericCapture = syntheticContext(
            for: .fh5ControlledExperimentCapture
        )
        var candidateCapture = genericCapture
        candidateCapture.fh5CandidateTrialAvailable = true
        let genericCaptureNext = CopilotEngine().response(
            to: .nextStep,
            in: genericCapture
        ).message
        let candidateCaptureNext = CopilotEngine().response(
            to: .nextStep,
            in: candidateCapture
        ).message

        XCTAssertTrue(next.contains("experimental"))
        XCTAssertTrue(next.contains("not a tune"))
        XCTAssertTrue(missing.contains("Numeric FH5 tuning remains locked"))
        XCTAssertTrue(genericCaptureNext.contains("Complete the fixed A-B-B-A"))
        XCTAssertFalse(genericCaptureNext.contains("candidate"))
        XCTAssertTrue(
            candidateCaptureNext.contains("experimental hypothesis")
        )
        XCTAssertTrue(candidateCapture.facts.contains {
            $0.label == "FH5 Outcome Lab mode"
                && $0.value == "Experimental candidate trial"
        })
        XCTAssertFalse(genericCapture.facts.contains {
            $0.label == "FH5 Outcome Lab mode"
        })
        XCTAssertTrue(result.facts.contains {
            $0.label == "FH5 candidate trial"
                && $0.value == "Experimental hypothesis ready"
        })

        var encoded = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(candidateCapture)
            ) as? [String: Any]
        )
        encoded.removeValue(forKey: "fh5CandidateTrialAvailable")
        let legacyData = try JSONSerialization.data(withJSONObject: encoded)
        let decoded = try JSONDecoder().decode(
            CopilotContext.self,
            from: legacyData
        )
        XCTAssertNil(decoded.fh5CandidateTrialAvailable)
    }

    func testSamePhaseLoadingReportChangesAreResetDrivingContextChanges() throws {
        let selection = try catalogSelection()
        let firstTune = projectedTune(car: selection.carInput)
        var secondTune = firstTune
        secondTune.projectionReport?.fields.append(TuneFieldProjection(
            field: .rearTirePressure,
            status: .providerOmitted,
            requiredPurchaseIDs: [],
            unresolvedPartIDs: [],
            reason: .providerOmitted
        ))
        let factory = CopilotContextFactory()
        let first = factory.make(
            step: .loading(
                firstTune.request,
                thumbnailData: nil,
                savedTuneID: nil,
                playerNotes: "",
                partialTune: firstTune
            ),
            savedTuneCount: 0,
            catalogCarCount: 0
        )
        let second = factory.make(
            step: .loading(
                secondTune.request,
                thumbnailData: nil,
                savedTuneID: nil,
                playerNotes: "",
                partialTune: secondTune
            ),
            savedTuneCount: 0,
            catalogCarCount: 0
        )

        XCTAssertEqual(first.id, second.id, "The public context identity remains the same phase and request")
        XCTAssertNotEqual(first, second, "Full-context observation must reset a stale response")
        XCTAssertNotEqual(first.projection?.blockedByStatus, second.projection?.blockedByStatus)
        XCTAssertNotEqual(first.projection?.blockedByReason, second.projection?.blockedByReason)
    }

    func testSamePhaseResultSavedEligibilityAndPathFactsAreResetDrivingChanges() {
        let baseline = resultContext(projectionFacts(readyCount: 2, isSaved: false))
        let saved = resultContext(projectionFacts(readyCount: 2, isSaved: true))
        let eligible = resultContext(CopilotProjectionFacts(
            readyCount: 2,
            blockedByStatus: [],
            blockedByReason: [],
            tireLabEligible: true,
            upgradeLabEligible: true,
            exactUpgradePathCount: 3,
            isSaved: false,
            isStreaming: false
        ))

        XCTAssertEqual(baseline.id, saved.id)
        XCTAssertEqual(baseline.id, eligible.id)
        XCTAssertNotEqual(baseline, saved)
        XCTAssertNotEqual(baseline, eligible)
        XCTAssertNotEqual(saved, eligible)
    }

    func testLegacyProjectionFactsAndContextDecodeAsNumericTune() throws {
        let facts = projectionFacts(readyCount: 2, isSaved: true)
        var factsObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(facts)) as? [String: Any]
        )
        factsObject.removeValue(forKey: "resultPurpose")
        let legacyFactsData = try JSONSerialization.data(withJSONObject: factsObject)
        let decodedFacts = try JSONDecoder().decode(
            CopilotProjectionFacts.self,
            from: legacyFactsData
        )

        XCTAssertEqual(decodedFacts.resultPurpose, .numericTune)
        XCTAssertEqual(decodedFacts.readyCount, facts.readyCount)
        XCTAssertEqual(decodedFacts.isSaved, facts.isSaved)
        let reencodedFacts = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(decodedFacts)) as? [String: Any]
        )
        XCTAssertEqual(reencodedFacts["resultPurpose"] as? String, TuneResultPurpose.numericTune.rawValue)

        let context = resultContext(facts)
        var contextObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(context)) as? [String: Any]
        )
        var projectionObject = try XCTUnwrap(contextObject["projection"] as? [String: Any])
        projectionObject.removeValue(forKey: "resultPurpose")
        contextObject["projection"] = projectionObject
        let legacyContextData = try JSONSerialization.data(withJSONObject: contextObject)
        let decodedContext = try JSONDecoder().decode(CopilotContext.self, from: legacyContextData)

        XCTAssertEqual(decodedContext.projection?.resultPurpose, .numericTune)
        XCTAssertEqual(decodedContext.phase, context.phase)
        XCTAssertEqual(decodedContext.projection?.readyCount, facts.readyCount)
    }

    private func syntheticContext(for phase: CopilotPhase) -> CopilotContext {
        CopilotContext(
            phase: phase,
            carDisplayName: phase == .result ? "Test Car" : nil,
            gameTitle: phase == .result ? "FH6" : nil,
            disciplineTitle: phase == .result ? "Road" : nil,
            savedTuneCount: phase == .home ? 3 : nil,
            catalogCarCount: phase == .catalogPicker ? 6 : nil,
            projection: phase == .result ? projectionFacts(readyCount: 2, isSaved: true) : nil,
            cannotSeeUnsavedEdits: [
                .catalogEdit, .ocrReview, .manualEntry, .fh6TuneMenuCapture,
                .tirePressureCapture,
                .upgradePartCapture, .fh5ResearchCapture,
                .fh5ControlledExperimentCapture, .recordTestDrive,
                .editSavedTune, .settings, .fh6ValidationReview,
                .fh6CommunityOutcomeReview, .fh5ResearchReview,
                .fh5CandidateOutcomeReview
            ].contains(phase)
        )
    }

    private func resultContext(_ projection: CopilotProjectionFacts) -> CopilotContext {
        CopilotContext(
            phase: .result,
            carDisplayName: "Test Car",
            gameTitle: "FH6",
            disciplineTitle: "Road",
            savedTuneCount: nil,
            catalogCarCount: nil,
            projection: projection,
            cannotSeeUnsavedEdits: false
        )
    }

    private func projectionFacts(
        readyCount: Int,
        isSaved: Bool,
        isStreaming: Bool = false
    ) -> CopilotProjectionFacts {
        CopilotProjectionFacts(
            readyCount: readyCount,
            blockedByStatus: [],
            blockedByReason: [],
            tireLabEligible: false,
            upgradeLabEligible: false,
            exactUpgradePathCount: 0,
            isSaved: isSaved,
            isStreaming: isStreaming
        )
    }

    private func projectedTune(car: CarInput, rawSentinel: String = "31.375-secret") -> TuneResult {
        TuneResult(
            request: TuneRequest(car: car, discipline: .road),
            sections: [TuneSection(
                title: "Raw settings",
                symbolName: "slider.horizontal.3",
                lines: [TuneLine(label: "Front", value: rawSentinel, unit: "PSI")]
            )],
            notes: emptyNotes,
            projectionReport: TuneProjectionReport(
                schemaVersion: TuneProjectionReport.currentSchemaVersion,
                snapshotID: nil,
                contextStatus: .missingSnapshot,
                capabilityResolution: nil,
                fields: [TuneFieldProjection(
                    field: .frontTirePressure,
                    status: .needsConstraint,
                    requiredPurchaseIDs: [],
                    unresolvedPartIDs: [],
                    reason: .missingProductionConstraint
                )],
                purchasePlan: [],
                confirmations: [],
                diagnostics: []
            )
        )
    }

    private func tireEligibleTune() throws -> TuneResult {
        let selection = try catalogSelection(game: .fh6)
        let snapshot = selection.capabilityOnlyBuildSnapshot(
            capturedAt: Date(timeIntervalSinceReferenceDate: 42)
        )
        return TuneResult(
            request: TuneRequest(
                car: selection.carInput,
                discipline: .road,
                buildSnapshot: snapshot
            ),
            sections: [],
            notes: emptyNotes,
            projectionReport: TuneProjectionReport(
                schemaVersion: TuneProjectionReport.currentSchemaVersion,
                snapshotID: snapshot.id,
                contextStatus: .capabilityOnly,
                capabilityResolution: nil,
                fields: [
                    TuneFieldProjection(
                        field: .frontTirePressure,
                        status: .needsConstraint,
                        requiredPurchaseIDs: [],
                        unresolvedPartIDs: [],
                        reason: .missingProductionConstraint
                    ),
                    TuneFieldProjection(
                        field: .rearTirePressure,
                        status: .needsConstraint,
                        requiredPurchaseIDs: [],
                        unresolvedPartIDs: [],
                        reason: .missingProductionConstraint
                    )
                ],
                purchasePlan: [],
                confirmations: [],
                diagnostics: []
            )
        )
    }

    private func catalogSelection(game: ForzaGame? = nil) throws -> CatalogCarSelection {
        let catalog: CarCatalogSnapshot
        switch BundledCarCatalog.load() {
        case .success(let loaded):
            catalog = loaded
        case .failure(let error):
            throw error
        }
        let entry = try XCTUnwrap(catalog.entries.first { game == nil || $0.game == game })
        return catalog.selection(for: entry)
    }

    private var emptyNotes: TuneNotes {
        TuneNotes(bias: "", ifPushesWide: "", ifSnapsOnLift: "", retuneTrigger: "")
    }
}
