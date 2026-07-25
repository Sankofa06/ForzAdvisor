//
//  FH6CommunityReferenceTrialTests.swift
//  forzadvisorTests
//

import XCTest
@testable import forzadvisor

final class FH6CommunityReferenceTrialTests: XCTestCase {
    private let capturedAt = Date(timeIntervalSince1970: 1_800_000_000)
    private let recordID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private let submissionID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    private let permissionID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!

    func testHappyPathUsesExactCandidateWithoutMutatingInput() async throws {
        let tune = try await eligibleTune()
        let before = tune
        let capture = try validCapture(for: tune, reuse: true)

        let record = try FH6CommunityReferenceTrialFactory().make(
            tune: tune,
            savedTune: tune,
            isStreaming: false,
            capture: capture,
            recordID: recordID,
            submissionID: submissionID,
            permissionReceiptID: permissionID,
            createdAt: capturedAt
        )

        XCTAssertEqual(tune, before)
        XCTAssertEqual(record.game, .fh6)
        XCTAssertEqual(record.protocolVersion, "fh6-community-abba-v1")
        XCTAssertEqual(record.runs.map(\.role), [.a1, .b1, .b2, .a2])
        XCTAssertEqual(record.candidateAssociation.catalogID, tune.request.car.catalogReference?.entryID)
        XCTAssertEqual(record.candidateAssociation.performanceClass, tune.request.car.performanceClass)
        XCTAssertEqual(record.candidateAssociation.performanceIndex, tune.request.car.performanceIndex)
        XCTAssertTrue(record.candidateAssociation.confirmed)
        XCTAssertEqual(record.candidateAssociation.candidateFingerprint.count, 64)
        XCTAssertEqual(record.source.usageScope, .metadataOnly)
        XCTAssertEqual(record.source.permissionBasis, .publicAvailability)
        XCTAssertEqual(record.source.publisherIdentityFingerprint.count, 64)
        XCTAssertEqual(record.source.contentIdentityFingerprint.count, 64)
        XCTAssertEqual(record.contentFingerprint.count, 64)
        XCTAssertTrue(FH6CommunityReferenceTrialFactory().isValid(record))
        XCTAssertLessThanOrEqual(try record.deterministicJSON().count, 256 * 1_024)
    }

    func testCandidateFingerprintBindsAppliedValuesAndRulesetWithoutPublicDetails() async throws {
        let tune = try await eligibleTune()
        let factory = FH6CommunityReferenceTrialFactory()
        let base = try factory.make(
            tune: tune,
            savedTune: tune,
            isStreaming: false,
            capture: validCapture(for: tune, reuse: true)
        )

        var changedValueTune = tune
        let lineIndex = try XCTUnwrap(
            changedValueTune.sections[0].lines.firstIndex {
                $0.fieldID == .frontTirePressure
            }
        )
        let oldValue = try XCTUnwrap(
            Double(changedValueTune.sections[0].lines[lineIndex].value)
        )
        changedValueTune.sections[0].lines[lineIndex].value =
            String(format: "%.1f", oldValue + 0.5)
        changedValueTune = TuneOutputProjector().project(changedValueTune)
        let changedValue = try factory.make(
            tune: changedValueTune,
            savedTune: changedValueTune,
            isStreaming: false,
            capture: validCapture(for: changedValueTune, reuse: true)
        )
        XCTAssertEqual(
            coreAssociation(base.candidateAssociation),
            coreAssociation(changedValue.candidateAssociation)
        )
        XCTAssertNotEqual(
            base.candidateAssociation.candidateFingerprint,
            changedValue.candidateAssociation.candidateFingerprint
        )
        XCTAssertNotEqual(base.contentFingerprint, changedValue.contentFingerprint)

        var alternateRulesetTune = tune
        let tireEvidence = try XCTUnwrap(
            alternateRulesetTune.request.buildSnapshot?.tireCompound?.evidenceIDs
        )
        alternateRulesetTune.rulesetReference = try XCTUnwrap(
            FH6LocalTirePressureRuleset.reference(
                provenanceIDs: tireEvidence.sorted()
            )
        )
        let alternateRuleset = try factory.make(
            tune: alternateRulesetTune,
            savedTune: alternateRulesetTune,
            isStreaming: false,
            capture: validCapture(for: alternateRulesetTune, reuse: true)
        )
        XCTAssertEqual(
            coreAssociation(base.candidateAssociation),
            coreAssociation(alternateRuleset.candidateAssociation)
        )
        XCTAssertNotEqual(
            base.candidateProof.ruleset,
            alternateRuleset.candidateProof.ruleset
        )
        XCTAssertNotEqual(
            base.candidateAssociation.candidateFingerprint,
            alternateRuleset.candidateAssociation.candidateFingerprint
        )
        XCTAssertNotEqual(base.contentFingerprint, alternateRuleset.contentFingerprint)

        var forgedAssociation = base
        forgedAssociation.candidateAssociation.candidateFingerprint =
            String(repeating: "0", count: 64)
        XCTAssertFalse(factory.isValid(forgedAssociation))
        XCTAssertThrowsError(try forgedAssociation.deterministicJSON()) {
            XCTAssertEqual($0 as? FH6CommunityReferenceTrialIssue, .invalidStoredRecord)
        }
    }

    func testSemanticFingerprintIgnoresAdministrativeIDsAndTimestamps() async throws {
        let tune = try await eligibleTune()
        var firstCapture = try validCapture(for: tune, reuse: true)
        var secondCapture = firstCapture
        secondCapture.source.retrievedAt = capturedAt.addingTimeInterval(10_000)
        firstCapture.candidateDeficiencySymptoms = [.pushesWide, .needsMorePull]
        secondCapture.candidateDeficiencySymptoms = [.needsMorePull, .pushesWide]

        let factory = FH6CommunityReferenceTrialFactory()
        let first = try factory.make(
            tune: tune,
            savedTune: tune,
            isStreaming: false,
            capture: firstCapture,
            recordID: recordID,
            submissionID: submissionID,
            permissionReceiptID: permissionID,
            createdAt: capturedAt
        )
        let second = try factory.make(
            tune: tune,
            savedTune: tune,
            isStreaming: false,
            capture: secondCapture,
            recordID: UUID(),
            submissionID: UUID(),
            permissionReceiptID: UUID(),
            createdAt: capturedAt.addingTimeInterval(20_000)
        )

        XCTAssertEqual(first.contentFingerprint, second.contentFingerprint)
        XCTAssertEqual(first.candidateDeficiencySymptoms, [.needsMorePull, .pushesWide])
        XCTAssertNotEqual(try first.deterministicJSON(), try second.deterministicJSON())
        let firstExport = try first.publicExport()
        XCTAssertEqual(firstExport.submissionID, submissionID)
        XCTAssertEqual(firstExport.permissionReceiptID, permissionID)
        XCTAssertEqual(firstExport.createdAt, capturedAt)
    }

    func testABBAOrderCompletionAndCorrectTuneAreMandatory() async throws {
        let tune = try await eligibleTune()
        let factory = FH6CommunityReferenceTrialFactory()

        let requiredRoles = FH6CommunityReferenceTrialRecord.requiredRoles
        for roles in permutations(of: requiredRoles) where roles != requiredRoles {
            var capture = try validCapture(for: tune)
            capture.runs = roles.map {
                .init(role: $0, completed: true, correctTuneConfirmed: true)
            }
            XCTAssertMakeThrows(factory, tune, capture, .invalidSequence)
        }

        let wrongLengthRoles: [[FH6CommunityReferenceTrialRole]] = [
            [.a1, .b1, .b2],
            [.a1, .b1, .b2, .a2, .a2]
        ]
        for roles in wrongLengthRoles {
            var capture = try validCapture(for: tune)
            capture.runs = roles.map {
                .init(role: $0, completed: true, correctTuneConfirmed: true)
            }
            XCTAssertMakeThrows(factory, tune, capture, .invalidSequence)
        }

        for index in 0..<4 {
            var incomplete = try validCapture(for: tune)
            incomplete.runs[index].completed = false
            XCTAssertMakeThrows(factory, tune, incomplete, .incompleteRun)

            var wrongTune = try validCapture(for: tune)
            wrongTune.runs[index].correctTuneConfirmed = false
            XCTAssertMakeThrows(factory, tune, wrongTune, .incompleteRun)
        }
    }

    func testEveryAttestationIsEnforcedExceptReuseAtLocalRecordCreation() async throws {
        let tune = try await eligibleTune()
        let factory = FH6CommunityReferenceTrialFactory()
        let mutations: [
            (inout FH6CommunityReferenceTrialCapture) -> Void
        ] = [
            { $0.attestations.sameRouteAndConditions = false },
            { $0.attestations.sameAssistsAndInput = false },
            { $0.attestations.candidateSettingsApplied = false },
            { $0.attestations.communityIdentityConfirmed = false },
            { $0.attestations.finalCandidateRestored = false },
            { $0.attestations.firstPartyAuthorship = false },
            { $0.attestations.localStoragePermitted = false }
        ]
        let issues: [FH6CommunityReferenceTrialIssue] = [
            .conditionsNotHeldConstant,
            .assistsOrInputChanged,
            .candidateSettingsNotApplied,
            .communityIdentityNotConfirmed,
            .candidateNotRestored,
            .authorshipNotConfirmed,
            .localStorageNotPermitted
        ]
        for (mutation, issue) in zip(mutations, issues) {
            var capture = try validCapture(for: tune)
            mutation(&capture)
            XCTAssertMakeThrows(factory, tune, capture, issue)
        }

        var local = try factory.make(
            tune: tune,
            savedTune: tune,
            isStreaming: false,
            capture: validCapture(for: tune)
        )
        XCTAssertTrue(factory.isValid(local))
        XCTAssertFalse(local.canExport)
        XCTAssertThrowsError(try local.deterministicJSON()) {
            XCTAssertEqual($0 as? FH6CommunityReferenceTrialIssue, .reuseNotPermitted)
        }
        let fingerprint = local.contentFingerprint
        local.attestations.deidentifiedOutcomeReusePermitted = true
        XCTAssertTrue(factory.isValid(local))
        XCTAssertTrue(local.canExport)
        XCTAssertEqual(local.contentFingerprint, fingerprint)
        XCTAssertNoThrow(try local.deterministicJSON())
    }

    func testOutcomeSymptomBoundarySortsAndRejectsContradictions() async throws {
        let tune = try await eligibleTune()
        let factory = FH6CommunityReferenceTrialFactory()
        var preferred = try validCapture(for: tune)
        preferred.candidateDeficiencySymptoms = [.pushesWide, .needsMorePull]
        let record = try factory.make(
            tune: tune,
            savedTune: tune,
            isStreaming: false,
            capture: preferred
        )
        XCTAssertEqual(record.candidateDeficiencySymptoms, [.needsMorePull, .pushesWide])

        var missing = try validCapture(for: tune)
        missing.candidateDeficiencySymptoms = []
        XCTAssertMakeThrows(factory, tune, missing, .missingCandidateDeficiency)

        for outcome in [
            FH6CommunityReferenceTrialOutcome.generatedPreferred,
            .noClearDifference,
            .inconclusive
        ] {
            var contradictory = try validCapture(for: tune)
            contradictory.outcome = outcome
            contradictory.candidateDeficiencySymptoms = [.pushesWide]
            XCTAssertMakeThrows(factory, tune, contradictory, .unexpectedCandidateDeficiency)
        }
    }

    func testEligibilityDelegatesSavedCurrentNonstreamingExactFH6Gate() async throws {
        let tune = try await eligibleTune()
        let factory = FH6CommunityReferenceTrialFactory()
        XCTAssertFailure(
            factory.eligibility(for: tune, savedTune: nil, isStreaming: false),
            .ineligibleCandidate(.notSaved)
        )
        XCTAssertFailure(
            factory.eligibility(for: tune, savedTune: tune, isStreaming: true),
            .ineligibleCandidate(.streaming)
        )
        var stale = tune
        stale.generatedAt = capturedAt.addingTimeInterval(1)
        XCTAssertFailure(
            factory.eligibility(for: tune, savedTune: stale, isStreaming: false),
            .ineligibleCandidate(.staleSavedRevision)
        )
        var legacy = tune
        legacy.projectionReport = nil
        XCTAssertFailure(
            factory.eligibility(for: legacy, savedTune: legacy, isStreaming: false),
            .ineligibleCandidate(.legacyTune)
        )
    }

    func testReferenceContextMustExactlyMatchCandidate() async throws {
        let tune = try await eligibleTune()
        let factory = FH6CommunityReferenceTrialFactory()
        var capture = try validCapture(for: tune)
        capture.referenceCandidate.performanceIndex += 1
        XCTAssertMakeThrows(factory, tune, capture, .referenceContextMismatch)

        capture = try validCapture(for: tune)
        capture.referenceCandidate.performanceClass = .x
        XCTAssertMakeThrows(factory, tune, capture, .referenceContextMismatch)

        capture = try validCapture(for: tune)
        capture.referenceCandidate.catalogID += ".other"
        XCTAssertMakeThrows(factory, tune, capture, .referenceContextMismatch)

        capture = try validCapture(for: tune)
        capture.referenceCandidate.confirmed = false
        XCTAssertMakeThrows(factory, tune, capture, .referenceContextMismatch)
    }

    func testSourceNormalizationBoundsKindControlAndDerivativeRules() async throws {
        let tune = try await eligibleTune()
        let factory = FH6CommunityReferenceTrialFactory()
        var capture = try validCapture(for: tune)
        capture.source.contentURL =
            "https://WWW.YouTube.com/watch?utm_source=x&v=abc&feature=share"
        let normalized = try factory.make(
            tune: tune, savedTune: tune, isStreaming: false, capture: capture
        )
        XCTAssertEqual(
            normalized.source.canonicalContentURL,
            "https://youtube.com/watch?v=abc"
        )

        for url in [
            "http://youtube.com/watch?v=abc",
            "https://user:pass@youtube.com/watch?v=abc",
            "https://youtube.com/watch?v=abc#settings",
            "https://reddit.com/r/ForzaOpenTunes/comments/abc",
            "https://youtube.com.evil.example/watch?v=abc",
            "https://127.0.0.1/watch?v=abc",
            "https://youtube.com/redirect?event=video_description",
            "https://l.youtube.com/?q=https://example.com",
            "https://out.reddit.com/t3_example",
            "https://youtube.com",
            "https://youtube.com/feed/trending",
            "https://youtube.com/watch",
            "https://youtube.com/watch?v=",
            "https://youtube.com/watch?v=abc&v=def",
            "https://youtube.com/watch?v=abc&list=playlist",
            "https://youtu.be",
            "https://youtu.be/abc/extra",
            "https://reddit.com",
            "https://reddit.com/search?q=forza",
            "https://reddit.com/user/tuner",
            "https://reddit.com/r/ForzaOpenTunes",
            "https://reddit.com/r/ForzaOpenTunes/comments",
            "https://reddit.com/r/ForzaOpenTunes/comments/abc/slug/extra",
            "https://redd.it",
            "https://redd.it/abc/extra"
        ] {
            var invalid = try validCapture(for: tune)
            invalid.source.contentURL = url
            XCTAssertMakeThrows(factory, tune, invalid, .invalidSourceURL)
        }

        var oversized = try validCapture(for: tune)
        oversized.source.publisherDisplayName = String(repeating: "x", count: 121)
        XCTAssertMakeThrows(factory, tune, oversized, .invalidSourceMetadata)

        var control = try validCapture(for: tune)
        control.source.sourceID = "video\nsecret"
        XCTAssertMakeThrows(factory, tune, control, .invalidSourceMetadata)

        var selfDerivative = try validCapture(for: tune)
        selfDerivative.source.derivativeOfSourceID = selfDerivative.source.sourceID
        XCTAssertMakeThrows(factory, tune, selfDerivative, .selfDerivative)

        var forward = try validCapture(for: tune)
        forward.source.contentURL =
            "https://youtube.com/watch?utm_source=x&v=abc&feature=share"
        var reverse = forward
        reverse.source.contentURL =
            "https://youtube.com/watch?feature=share&v=abc&utm_source=x"
        let forwardRecord = try factory.make(
            tune: tune, savedTune: tune, isStreaming: false, capture: forward
        )
        let reverseRecord = try factory.make(
            tune: tune, savedTune: tune, isStreaming: false, capture: reverse
        )
        XCTAssertEqual(
            forwardRecord.source.contentIdentityFingerprint,
            reverseRecord.source.contentIdentityFingerprint
        )
        XCTAssertEqual(forwardRecord.contentFingerprint, reverseRecord.contentFingerprint)

        for (kind, url, expected) in [
            (
                FH6CommunityReferenceKind.youtube,
                "https://youtu.be/abc_123",
                "https://youtu.be/abc_123"
            ),
            (
                .reddit,
                "https://www.reddit.com/r/ForzaOpenTunes/comments/abc123/a_tune/?utm_source=x",
                "https://reddit.com/r/ForzaOpenTunes/comments/abc123/a_tune"
            ),
            (
                .reddit,
                "https://redd.it/abc123",
                "https://redd.it/abc123"
            )
        ] {
            XCTAssertEqual(factory.normalizedContentURL(url, kind: kind), expected)
        }
        let rejectedShapes: [(FH6CommunityReferenceKind, String)] = [
            (.youtube, "https://youtube.com"),
            (.youtube, "https://youtube.com/shorts/abc"),
            (.youtube, "https://youtube.com/watch"),
            (.youtube, "https://youtube.com/watch?v=abc&v=def"),
            (.youtube, "https://youtu.be/abc/extra"),
            (.reddit, "https://reddit.com"),
            (.reddit, "https://reddit.com/search?q=forza"),
            (.reddit, "https://reddit.com/user/tuner"),
            (.reddit, "https://reddit.com/r/ForzaOpenTunes"),
            (.reddit, "https://reddit.com/r/ForzaOpenTunes/comments"),
            (.reddit, "https://reddit.com/r/ForzaOpenTunes/comments/abc/slug/extra"),
            (.reddit, "https://redd.it/abc/extra")
        ]
        for (kind, url) in rejectedShapes {
            XCTAssertNil(factory.normalizedContentURL(url, kind: kind), url)
        }
    }

    func testPublicJSONHasExplicitSourceAllowListAndNoCandidateOrCommunitySettings() async throws {
        let tune = try await eligibleTune()
        let record = try FH6CommunityReferenceTrialFactory().make(
            tune: tune,
            savedTune: tune,
            isStreaming: false,
            capture: validCapture(for: tune, reuse: true),
            recordID: recordID,
            submissionID: submissionID,
            permissionReceiptID: permissionID,
            createdAt: capturedAt
        )
        let data = try record.deterministicJSON()
        XCTAssertEqual(data, try record.deterministicJSON())
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        XCTAssertNil(object["recordID"])
        XCTAssertEqual(object["submissionID"] as? String, submissionID.uuidString)
        XCTAssertEqual(object["permissionReceiptID"] as? String, permissionID.uuidString)
        XCTAssertNotNil(object["createdAt"] as? String)
        XCTAssertNil(object["candidateTuneID"])
        XCTAssertNil(object["candidateProof"])
        XCTAssertNil(object["appliedFields"])
        XCTAssertNil(object["shopParts"])
        XCTAssertNil(object["providerInfo"])
        XCTAssertNil(object["ruleset"])
        let association = try XCTUnwrap(
            object["candidateAssociation"] as? [String: Any]
        )
        XCTAssertEqual(
            Set(association.keys),
            Set([
                "catalogID",
                "performanceClass",
                "performanceIndex",
                "confirmed",
                "candidateFingerprint"
            ])
        )
        XCTAssertEqual(
            association["candidateFingerprint"] as? String,
            record.candidateAssociation.candidateFingerprint
        )
        let source = try XCTUnwrap(object["source"] as? [String: Any])
        XCTAssertEqual(
            Set(source.keys),
            Set([
                "kind",
                "canonicalContentURL",
                "publisherDisplayName",
                "sourceID",
                "publisherIdentityFingerprint",
                "contentIdentityFingerprint",
                "retrievedAt",
                "derivativeOfSourceID",
                "usageScope",
                "permissionBasis"
            ])
        )
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertFalse(json.contains("frontTirePressure"))
        XCTAssertFalse(json.contains("\"value\""))
        XCTAssertFalse(json.contains("\"unit\""))
        XCTAssertFalse(json.contains("shareCode"))
    }

    func testTamperingSortednessAndFingerprintsFailClosed() async throws {
        let tune = try await eligibleTune()
        let factory = FH6CommunityReferenceTrialFactory()
        let valid = try factory.make(
            tune: tune,
            savedTune: tune,
            isStreaming: false,
            capture: validCapture(for: tune, reuse: true)
        )

        var sourceHash = valid
        sourceHash.source.contentIdentityFingerprint = String(repeating: "A", count: 64)
        XCTAssertFalse(factory.isValid(sourceHash))

        var proof = valid
        proof.candidateProof.appliedFields.reverse()
        XCTAssertFalse(factory.isValid(proof))

        var duplicatePart = valid
        duplicatePart.candidateProof.shopParts[1] = duplicatePart.candidateProof.shopParts[0]
        XCTAssertFalse(factory.isValid(duplicatePart))

        var outcome = valid
        outcome.outcome = .generatedPreferred
        XCTAssertFalse(factory.isValid(outcome))

        var fingerprint = valid
        fingerprint.contentFingerprint = String(repeating: "0", count: 64)
        XCTAssertFalse(factory.isValid(fingerprint))
        XCTAssertThrowsError(try fingerprint.deterministicJSON()) {
            XCTAssertEqual($0 as? FH6CommunityReferenceTrialIssue, .invalidStoredRecord)
        }
    }

    func testMaterialMetadataAndOutcomeChangesAlterFingerprints() async throws {
        let tune = try await eligibleTune()
        let factory = FH6CommunityReferenceTrialFactory()
        let base = try factory.make(
            tune: tune,
            savedTune: tune,
            isStreaming: false,
            capture: validCapture(for: tune)
        )

        var publisherCapture = try validCapture(for: tune)
        publisherCapture.source.publisherDisplayName = "Another Publisher"
        let publisher = try factory.make(
            tune: tune, savedTune: tune, isStreaming: false, capture: publisherCapture
        )
        XCTAssertNotEqual(
            base.source.publisherIdentityFingerprint,
            publisher.source.publisherIdentityFingerprint
        )
        XCTAssertNotEqual(base.contentFingerprint, publisher.contentFingerprint)

        var contentCapture = try validCapture(for: tune)
        contentCapture.source.sourceID = "youtube:xyz"
        let content = try factory.make(
            tune: tune, savedTune: tune, isStreaming: false, capture: contentCapture
        )
        XCTAssertNotEqual(
            base.source.contentIdentityFingerprint,
            content.source.contentIdentityFingerprint
        )

        var outcomeCapture = try validCapture(for: tune)
        outcomeCapture.outcome = .generatedPreferred
        outcomeCapture.candidateDeficiencySymptoms = []
        let outcome = try factory.make(
            tune: tune, savedTune: tune, isStreaming: false, capture: outcomeCapture
        )
        XCTAssertNotEqual(base.contentFingerprint, outcome.contentFingerprint)
    }

    private func eligibleTune() async throws -> TuneResult {
        let catalog = try BundledCarCatalog.load().get()
        let entry = try XCTUnwrap(catalog.entries.first { $0.game == .fh6 })
        let selection = catalog.selection(for: entry)
        let capability = selection.capabilityOnlyBuildSnapshot(capturedAt: capturedAt)
        let parts = try UpgradePartCapture(
            gameBuildVersion: "test-build",
            parts: TunePartID.allCases.map {
                UpgradePartCaptureValue(partID: $0, status: .offered)
            },
            exactStockBuildConfirmed: true,
            localUsePermitted: true
        ).verifiedSnapshot(upgrading: capability, capturedAt: capturedAt)
        let exact = try TirePressureCapture(
            gameBuildVersion: "test-build",
            tireCompound: "Stock",
            gearCount: 6,
            front: .init(
                minimumPSI: 15,
                maximumPSI: 40,
                stepPSI: 0.5,
                currentPSI: 30
            ),
            rear: .init(
                minimumPSI: 15,
                maximumPSI: 40,
                stepPSI: 0.5,
                currentPSI: 30
            ),
            exactStockBuildConfirmed: true,
            localUsePermitted: true
        ).exactBuildSnapshot(
            upgrading: parts,
            capturedAt: capturedAt,
            evidenceID: "local-tire"
        )
        let request = TuneRequest(
            car: exact.car,
            discipline: .road,
            buildSnapshot: exact
        )
        var tune = try await CapabilityProjectingTuneProvider(
            base: LocalSampleTuneProvider()
        ).generateTune(for: request)
        tune.generatedAt = capturedAt
        return tune
    }

    private func coreAssociation(
        _ association: FH6CommunityReferenceCandidateAssociation
    ) -> String {
        [
            association.catalogID,
            association.performanceClass.rawValue,
            String(association.performanceIndex),
            String(association.confirmed)
        ].joined(separator: "|")
    }

    private func validCapture(
        for tune: TuneResult,
        reuse: Bool = false
    ) throws -> FH6CommunityReferenceTrialCapture {
        let catalogID = try XCTUnwrap(tune.request.car.catalogReference?.entryID)
        return .init(
            source: .init(
                kind: .youtube,
                contentURL: "https://www.youtube.com/watch?v=abc123",
                publisherDisplayName: "Community Tuner",
                sourceID: "youtube:abc123",
                retrievedAt: capturedAt,
                derivativeOfSourceID: "youtube:parent"
            ),
            referenceCandidate: .init(
                catalogID: catalogID,
                performanceClass: tune.request.car.performanceClass,
                performanceIndex: tune.request.car.performanceIndex,
                confirmed: true
            ),
            context: .init(
                courseType: .testTrack,
                surface: .dry,
                input: .controller
            ),
            runs: FH6CommunityReferenceTrialRecord.requiredRoles.map {
                .init(role: $0, completed: true, correctTuneConfirmed: true)
            },
            outcome: .referencePreferred,
            candidateDeficiencySymptoms: [.pushesWide],
            sameRouteAndConditionsConfirmed: true,
            sameAssistsAndInputConfirmed: true,
            candidateSettingsAppliedConfirmed: true,
            communityIdentityConfirmed: true,
            finalCandidateRestoredConfirmed: true,
            firstPartyAuthorshipConfirmed: true,
            localStoragePermitted: true,
            deidentifiedOutcomeReusePermitted: reuse
        )
    }

    private func XCTAssertFailure(
        _ result: Result<TuneResult, FH6CommunityReferenceTrialIssue>,
        _ expected: FH6CommunityReferenceTrialIssue,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case .failure(let actual) = result else {
            return XCTFail("Expected \(expected), got \(result)", file: file, line: line)
        }
        XCTAssertEqual(actual, expected, file: file, line: line)
    }

    private func permutations<T>(of values: [T]) -> [[T]] {
        guard let first = values.first else { return [[]] }
        return permutations(of: Array(values.dropFirst())).flatMap { permutation in
            (0...permutation.count).map { index in
                var result = permutation
                result.insert(first, at: index)
                return result
            }
        }
    }

    private func XCTAssertMakeThrows(
        _ factory: FH6CommunityReferenceTrialFactory,
        _ tune: TuneResult,
        _ capture: FH6CommunityReferenceTrialCapture,
        _ expected: FH6CommunityReferenceTrialIssue,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(
            try factory.make(
                tune: tune,
                savedTune: tune,
                isStreaming: false,
                capture: capture
            ),
            file: file,
            line: line
        ) {
            XCTAssertEqual(
                $0 as? FH6CommunityReferenceTrialIssue,
                expected,
                file: file,
                line: line
            )
        }
    }
}
