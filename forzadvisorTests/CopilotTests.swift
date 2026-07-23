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
        XCTAssertEqual(CopilotPhase.allCases.count, 16)

        for phase in CopilotPhase.allCases {
            let context = syntheticContext(for: phase)
            for intent in CopilotIntent.allCases {
                let response = engine.response(to: intent, in: context)
                XCTAssertEqual(response.intent, intent, "\(phase.rawValue) / \(intent.rawValue)")
                XCTAssertFalse(response.title.isEmpty, "\(phase.rawValue) / \(intent.rawValue)")
                XCTAssertFalse(response.message.isEmpty, "\(phase.rawValue) / \(intent.rawValue)")
            }
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
            (.tirePressureCapture(tune, savedTuneID: nil, thumbnailData: nil, playerNotes: ""), .tirePressureCapture),
            (.upgradePartCapture(tune, savedTuneID: nil, thumbnailData: nil, playerNotes: ""), .upgradePartCapture),
            (.recordTestDrive(tune, savedTuneID: UUID(), thumbnailData: nil, playerNotes: ""), .recordTestDrive),
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
            .tirePressureCapture(tune, savedTuneID: nil, thumbnailData: nil, playerNotes: ""),
            .upgradePartCapture(tune, savedTuneID: nil, thumbnailData: nil, playerNotes: ""),
            .recordTestDrive(tune, savedTuneID: UUID(), thumbnailData: nil, playerNotes: "secret-note"),
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
        XCTAssertNil(partial.projection?.tireLabEligible)
        XCTAssertNil(partial.projection?.upgradeLabEligible)
        XCTAssertNil(partial.projection?.exactUpgradePathCount)
        XCTAssertNil(partial.projection?.isSaved)
        XCTAssertFalse(partial.facts.contains { $0.label == "Tire Lab" })
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
        XCTAssertTrue(CopilotEngine().response(to: .nextStep, in: context).message.contains("Tire Lab"))
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
    }

    func testResultPriorityCoversStreamingWithheldUnsavedAndSavedStates() {
        let engine = CopilotEngine()
        var facts = projectionFacts(readyCount: 2, isSaved: false, isStreaming: true)
        XCTAssertTrue(engine.response(to: .nextStep, in: resultContext(facts)).message.contains("Wait"))

        facts = projectionFacts(readyCount: 0, isSaved: false, isStreaming: false)
        XCTAssertTrue(engine.response(to: .nextStep, in: resultContext(facts)).message.contains("withheld"))

        facts = projectionFacts(readyCount: 2, isSaved: false, isStreaming: false)
        XCTAssertTrue(engine.response(to: .nextStep, in: resultContext(facts)).message.contains("Save"))

        facts = projectionFacts(readyCount: 2, isSaved: true, isStreaming: false)
        XCTAssertTrue(engine.response(to: .nextStep, in: resultContext(facts)).message.contains("guided feedback"))
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
                .catalogEdit, .ocrReview, .manualEntry, .tirePressureCapture,
                .upgradePartCapture, .fh5ResearchCapture,
                .fh5ControlledExperimentCapture, .recordTestDrive,
                .editSavedTune
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
