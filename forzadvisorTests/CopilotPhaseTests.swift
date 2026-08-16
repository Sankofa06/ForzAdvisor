import XCTest
@testable import forzadvisor

extension CopilotTests {
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

}
