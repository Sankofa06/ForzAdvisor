import XCTest
@testable import forzadvisor

extension CopilotTests {
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

}
