//
//  CopilotTests.swift
//  forzadvisorTests
//
//  Closed-intent, phase coverage, and value-isolation tests for Copilot v1.
//

import XCTest
@testable import forzadvisor

final class CopilotTests: XCTestCase {
    func testFirstSavedSetupHandoffRequiresSuccessfulSaveFromEmptyGarage() {
        let savedTuneID = UUID()
        var state = FirstSavedSetupCopilotHandoffState()

        state.recordSaveResult(
            savedTuneID: nil,
            wasGarageEmpty: true
        )
        XCTAssertFalse(state.isPresented(for: savedTuneID))

        state.recordSaveResult(
            savedTuneID: savedTuneID,
            wasGarageEmpty: false
        )
        XCTAssertFalse(state.isPresented(for: savedTuneID))

        state.recordSaveResult(
            savedTuneID: savedTuneID,
            wasGarageEmpty: true
        )
        XCTAssertTrue(state.isPresented(for: savedTuneID))
    }

    func testFirstSavedSetupHandoffIsExactResultBoundAndConsumable() {
        let savedTuneID = UUID()
        var state = FirstSavedSetupCopilotHandoffState()
        state.recordSaveResult(
            savedTuneID: savedTuneID,
            wasGarageEmpty: true
        )

        XCTAssertTrue(state.isPresented(for: savedTuneID))
        XCTAssertFalse(state.isPresented(for: UUID()))
        XCTAssertFalse(state.isPresented(for: nil))

        state.consume()
        state.consume()

        XCTAssertFalse(state.isPresented(for: savedTuneID))
        XCTAssertNil(state.savedTuneID)
    }

    func testPreparingCopilotPresentationConsumesPendingHandoff() {
        let savedTuneID = UUID()
        var state = FirstSavedSetupCopilotHandoffState()
        state.recordSaveResult(
            savedTuneID: savedTuneID,
            wasGarageEmpty: true
        )

        state.prepareForCopilotPresentation()

        XCTAssertFalse(state.isPresented(for: savedTuneID))
        XCTAssertNil(state.savedTuneID)
    }

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
        XCTAssertEqual(CopilotPhase.allCases.count, 26)

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
            .stockCatalogContribution,
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

        let contribution = destinations[1].context
        XCTAssertEqual(
            destinations[1].buttonIdentifier,
            "copilotButton-stockCatalogContribution"
        )
        XCTAssertTrue(
            destinations[1].accessibilityHint.contains(
                "guidance without reading or changing the contribution"
            )
        )
        XCTAssertEqual(contribution.facts, [
            CopilotFact(
                label: "Unsaved fields",
                value: "Not visible to Copilot"
            )
        ])
        XCTAssertTrue(contribution.cannotSeeUnsavedEdits)
        XCTAssertNil(contribution.carDisplayName)
        XCTAssertNil(contribution.gameTitle)
        XCTAssertNil(contribution.disciplineTitle)
        XCTAssertNil(contribution.savedTuneCount)
        XCTAssertNil(contribution.catalogCarCount)
        XCTAssertNil(contribution.projection)
        XCTAssertNil(contribution.fh5CandidateTrialAvailable)

        let beta = destinations[2].context
        XCTAssertEqual(beta.savedTuneCount, 7)
        XCTAssertEqual(beta.facts, [
            CopilotFact(label: "Saved tunes", value: "7")
        ])
        XCTAssertFalse(beta.cannotSeeUnsavedEdits)

        let validationReview = destinations[3].context
        XCTAssertNil(validationReview.carDisplayName)
        XCTAssertNil(validationReview.gameTitle)
        XCTAssertNil(validationReview.disciplineTitle)
        XCTAssertEqual(
            validationReview.facts.map(\.label),
            ["Unsaved fields"]
        )
        XCTAssertTrue(
            validationReview.cannotSeeUnsavedEdits
        )

        let communityReview = destinations[4].context
        XCTAssertEqual(
            communityReview.carDisplayName,
            "Committed FH6 Car"
        )
        XCTAssertEqual(communityReview.gameTitle, "FH6")
        XCTAssertEqual(communityReview.disciplineTitle, "Road")
        XCTAssertEqual(
            communityReview.facts.map(\.label),
            ["Car", "Game", "Discipline", "Unsaved fields"]
        )
        XCTAssertTrue(communityReview.cannotSeeUnsavedEdits)

        let research = destinations[5].context
        XCTAssertEqual(research.carDisplayName, "Committed FH5 Car")
        XCTAssertEqual(research.gameTitle, "FH5")
        XCTAssertNil(research.disciplineTitle)
        XCTAssertEqual(
            research.facts.map(\.label),
            ["Car", "Game", "Unsaved fields"]
        )
        XCTAssertTrue(research.cannotSeeUnsavedEdits)

        let candidate = destinations[6].context
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
            .stockCatalogContribution,
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

    func testStockCatalogContributionContextIsPhaseOnlyAndPayloadFree()
        throws {
        let destination =
            ModalCopilotDestination.stockCatalogContribution
        let context = destination.context
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(context)
            ) as? [String: Any]
        )

        XCTAssertEqual(
            context.phase.title,
            "Stock Catalog Contribution"
        )
        XCTAssertEqual(
            Set(object.keys),
            ["phase", "cannotSeeUnsavedEdits"]
        )
        XCTAssertEqual(
            object["phase"] as? String,
            CopilotPhase.stockCatalogContribution.rawValue
        )
        XCTAssertEqual(object["cannotSeeUnsavedEdits"] as? Bool, true)

        let encoded = try XCTUnwrap(
            String(
                data: JSONEncoder().encode(context),
                encoding: .utf8
            )
        )
        for forbidden in [
            "gameVersion", "platform", "performanceIndex",
            "weightPounds", "fieldAttestations", "recordCount",
            "pastedJSON", "canonicalJSON", "permission", "payload",
            "rights", "confirmation"
        ] {
            XCTAssertFalse(
                encoded.localizedCaseInsensitiveContains(forbidden),
                "Encoded contribution context exposed \(forbidden)"
            )
        }
    }

    func testStockCatalogContributionGuidanceMatchesCollectionBoundary() {
        let context =
            ModalCopilotDestination.stockCatalogContribution.context
        let engine = CopilotEngine()
        let next = engine.response(to: .nextStep, in: context)

        XCTAssertEqual(engine.defaultResponse(in: context), next)
        for intent in CopilotIntent.allCases {
            let response = engine.response(to: intent, in: context)
            XCTAssertFalse(response.message.isEmpty)
            XCTAssertNil(response.action)
            XCTAssertTrue(
                response.message.contains(
                    "cannot see unsaved field edits"
                ),
                intent.rawValue
            )
        }

        for fragment in [
            "exact untouched-stock car identity",
            "current game build and platform",
            "performance index",
            "source screen",
            "personally read",
            "English units where relevant",
            "all four reuse rights",
            "save locally",
            "canonical export",
            "human collection review"
        ] {
            XCTAssertTrue(
                next.message.localizedCaseInsensitiveContains(fragment),
                fragment
            )
        }

        let trust = engine.response(to: .trust, in: context).message
        for fragment in [
            "structural validation",
            "canonical byte binding",
            "human collection review",
            "personal direct reading",
            "does not approve facts",
            "create or change a catalog entry",
            "activate a tune"
        ] {
            XCTAssertTrue(
                trust.localizedCaseInsensitiveContains(fragment),
                fragment
            )
        }

        let missing = engine.response(to: .missing, in: context).message
        for fragment in [
            "exact car identity",
            "game build and platform",
            "all stock facts",
            "source-screen attestation",
            "personally-read",
            "English-units-where-relevant",
            "local-storage permission",
            "canonical JSON",
            "direct-receipt confirmation",
            "reuse, curation, and redistribution rights"
        ] {
            XCTAssertTrue(
                missing.localizedCaseInsensitiveContains(fragment),
                fragment
            )
        }

        let privacy = engine.response(to: .privacy, in: context).message
        for fragment in [
            "only the Stock Catalog Contribution phase",
            "no access to draft values",
            "field or record counts",
            "pasted or canonical JSON",
            "permission state",
            "contribution payloads",
            "does not call a model or network service",
            "save a transcript",
            "offer an action",
            "stay local",
            "explicitly share",
            "does not alter the catalog or tuning"
        ] {
            XCTAssertTrue(
                privacy.localizedCaseInsensitiveContains(fragment),
                fragment
            )
        }
        for exclusion in
            StockCatalogContributionPolicy.privacyExclusions {
            XCTAssertTrue(privacy.contains(exclusion), exclusion)
        }
    }

    func testFH6ValidationReviewCopilotIsPhaseOnlyPayloadBlindAndActionFree()
        throws {
        let context = ModalCopilotDestination
            .fh6ValidationReview(
                carDisplayName: "Private Car",
                gameTitle: "FH6",
                disciplineTitle: "Road"
            )
            .context
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(context)
            ) as? [String: Any]
        )
        XCTAssertEqual(
            Set(object.keys),
            ["phase", "cannotSeeUnsavedEdits"]
        )
        XCTAssertEqual(
            context.phase,
            .fh6ValidationReview
        )

        let engine = CopilotEngine()
        for intent in CopilotIntent.allCases {
            XCTAssertNil(
                engine.response(to: intent, in: context).action,
                intent.rawValue
            )
        }

        let next = engine.response(
            to: .nextStep,
            in: context
        ).message
        for fragment in [
            "transiently inspect",
            "cannot see the pasted JSON",
            "accepted evidence counts",
            "permission identifiers",
            "fingerprints",
            "cannot validate, clear, import, save, apply, rank, or promote"
        ] {
            XCTAssertTrue(
                next.localizedCaseInsensitiveContains(fragment),
                fragment
            )
        }

        let privacy = engine.response(
            to: .privacy,
            in: context
        ).message
        for fragment in [
            "only the FH6 Validation Review phase",
            "cannot see pasted JSON",
            "accepted evidence counts",
            "permission identifiers",
            "candidate bindings",
            "packet fingerprints",
            "inspection status",
            "does not call a model or network service",
            "does not",
            "offer an action",
            "cannot validate, clear, import, save, apply, score, rank, or promote"
        ] {
            XCTAssertTrue(
                privacy.localizedCaseInsensitiveContains(fragment),
                fragment
            )
        }
    }

    func testFH5CandidateOutcomeReviewCopilotIsPacketBlindAndActionFree()
        throws {
        let context = ModalCopilotDestination
            .fh5CandidateOutcomeReview
            .context
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(context)
            ) as? [String: Any]
        )
        XCTAssertEqual(
            Set(object.keys),
            ["phase", "cannotSeeUnsavedEdits"]
        )
        XCTAssertEqual(context.phase, .fh5CandidateOutcomeReview)

        let engine = CopilotEngine()
        for intent in CopilotIntent.allCases {
            XCTAssertNil(
                engine.response(to: intent, in: context).action,
                intent.rawValue
            )
        }

        let next = engine.response(
            to: .nextStep,
            in: context
        ).message
        for fragment in [
            "prepare a canonical Numeric Promotion Review Packet",
            "transiently inspect",
            "cannot see pasted JSON",
            "accepted evidence counts",
            "candidate bindings",
            "packet fingerprints",
            "cannot validate, clear, import, save, apply, score, rank, promote, register, or activate"
        ] {
            XCTAssertTrue(
                next.localizedCaseInsensitiveContains(fragment),
                fragment
            )
        }

        let privacy = engine.response(
            to: .privacy,
            in: context
        ).message
        for fragment in [
            "only the FH5 Candidate Outcome Review phase",
            "cannot see pasted JSON",
            "accepted evidence counts",
            "permission identifiers",
            "candidate bindings",
            "packet fingerprints",
            "prepared-input fingerprints",
            "inspection status",
            "does not call a model or network service",
            "offer an action",
            "cannot validate, clear, import, save, apply, score, rank, promote, register, or activate"
        ] {
            XCTAssertTrue(
                privacy.localizedCaseInsensitiveContains(fragment),
                fragment
            )
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
        let car = try catalogSelection().carInput
        let tune = projectedTune(car: car)
        let draft = ManualEntryDraft(car: car)
        let steps: [WorkflowStep] = [
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

    func testRosterIdentityGuidanceKeepsVerificationBoundary() {
        let context = syntheticContext(
            for: .rosterIdentityStockEntry
        )
        let engine = CopilotEngine()
        let next = engine.response(to: .nextStep, in: context)
        let trust = engine.response(to: .trust, in: context)
        let missing = engine.response(to: .missing, in: context)
        let privacy = engine.response(to: .privacy, in: context)

        for fragment in [
            "official roster identity",
            "source-attributed context",
            "missing stock specification",
            "directly in-game",
            "Verify Stock Specs for Catalog",
            "separate local verification workspace"
        ] {
            XCTAssertTrue(
                next.message.localizedCaseInsensitiveContains(
                    fragment
                ),
                fragment
            )
        }
        XCTAssertTrue(
            trust.message.contains("Stock facts are not verified")
        )
        XCTAssertTrue(
            trust.message.contains("no verification claim")
        )
        XCTAssertTrue(
            missing.message.contains(
                "must be checked directly in-game"
            )
        )
        for fragment in [
            "source-attributed context",
            "stock facts are not verified",
            "cannot see the identity",
            "selected game",
            "draft values",
            "official PI or class",
            "stock or tune facts",
            "contribution payloads",
            "state, or counts",
            "identifiers",
            "fingerprints",
            "permissions",
            "no verification claim",
            "offers no action",
            "no model or network service",
            "stores no transcript"
        ] {
            XCTAssertTrue(
                privacy.message.localizedCaseInsensitiveContains(
                    fragment
                ),
                fragment
            )
        }
        for response in [next, trust, missing, privacy] {
            XCTAssertNil(response.action)
        }
    }

    func testRosterPhaseDoesNotAlterManualOrOCRGuidance() {
        let engine = CopilotEngine()

        XCTAssertEqual(
            engine.response(
                to: .nextStep,
                in: syntheticContext(for: .manualEntry)
            ).message,
            "Complete the required car facts and fix the validation messages before continuing. Copilot cannot see unsaved field edits."
        )
        XCTAssertEqual(
            engine.response(
                to: .nextStep,
                in: syntheticContext(for: .ocrReview)
            ).message,
            "Confirm every recognized fact against the screenshot, then continue from the underlying screen. Copilot cannot see unsaved field edits."
        )
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

    func testCopilotActionIsClosedPayloadFreeAndDoesNotExposeTuneValues() throws {
        XCTAssertEqual(
            CopilotAction.openFH5ResearchLab.title,
            "Open FH5 Research Lab"
        )
        XCTAssertEqual(
            Set(CopilotAction.allCases),
            Set([
                .openFH6TuneMenuLab,
                .openTireLab,
                .openUpgradeLab,
                .openFH5ResearchLab,
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
                .catalogEdit, .ocrReview, .manualEntry,
                .rosterIdentityStockEntry, .fh6TuneMenuCapture,
                .tirePressureCapture,
                .upgradePartCapture, .fh5ResearchCapture,
                .fh5ControlledExperimentCapture, .recordTestDrive,
                .editSavedTune, .settings, .fh6ValidationReview,
                .fh6CommunityOutcomeReview, .fh5ResearchReview,
                .fh5CandidateOutcomeReview
            ].contains(phase)
        )
    }

    private func rosterIdentity(
        game: ForzaGame,
        sentinel: String
    ) -> OfficialRosterCarIdentity {
        OfficialRosterCarIdentity(
            id: "\(sentinel)-id",
            game: game,
            year: game == .fh5 ? 1986 : 2554,
            make: game == .fh5 ? "" : "\(sentinel)-make",
            model: "\(sentinel)-model",
            officialDesignation:
                "\(sentinel)-official-designation",
            performanceIndex: game == .fh5 ? nil : 987,
            performanceClass: game == .fh5 ? nil : .s2
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
