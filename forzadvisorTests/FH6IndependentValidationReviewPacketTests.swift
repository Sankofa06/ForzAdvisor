//
//  FH6IndependentValidationReviewPacketTests.swift
//  forzadvisorTests
//

import CryptoKit
import SwiftData
import XCTest
@testable import forzadvisor

final class FH6IndependentValidationReviewPacketTests:
    XCTestCase {
    private let capturedAt =
        Date(timeIntervalSince1970: 1_800_000_000)

    func testCanonicalPacketIsDeterministicAndRoundTrips()
        async throws {
        let fixture = try await makeFixture()
        let exporter =
            FH6IndependentValidationReviewPacketExporter()
        let first = try exporter.makeArtifact(
            candidate: fixture.tune,
            persistedCandidate: fixture.tune,
            isStreaming: false,
            firstPartyTestDrives: [fixture.validation],
            localCommunityOutcomes: [fixture.community],
            reviewedCommunityOutcomes: []
        )
        let second = try exporter.makeArtifact(
            candidate: fixture.tune,
            persistedCandidate: fixture.tune,
            isStreaming: false,
            firstPartyTestDrives: [fixture.validation],
            localCommunityOutcomes: [fixture.community],
            reviewedCommunityOutcomes: []
        )

        XCTAssertEqual(first.canonicalJSON, second.canonicalJSON)
        XCTAssertEqual(
            try exporter.validate(
                first.canonicalJSON,
                candidate: fixture.tune,
                persistedCandidate: fixture.tune,
                isStreaming: false
            ),
            first.packet
        )
        XCTAssertEqual(first.packet.evidence.count, 2)
        XCTAssertFalse(first.packet.accuracyClaimEstablished)
        XCTAssertFalse(
            first.packet.automaticPromotionPermitted
        )
        XCTAssertTrue(
            first.packet.independentHumanReviewRequired
        )
    }

    @MainActor
    func testReceiverAvailabilityDoesNotRequireLocalEvidence()
        async throws {
        let fixture = try await makeFixture()
        let eligibility =
            FH6IndependentValidationReviewReceiverEligibility()

        XCTAssertEqual(
            eligibility.candidateRevisionFingerprint(
                candidate: fixture.tune,
                persistedCandidate: fixture.tune,
                isStreaming: false
            ),
            FirstPartyValidationRecordFactory()
                .revisionFingerprint(for: fixture.tune)
        )
        XCTAssertNil(
            eligibility.candidateRevisionFingerprint(
                candidate: fixture.tune,
                persistedCandidate: fixture.tune,
                isStreaming: true
            )
        )
        var stale = fixture.tune
        stale.generatedAt =
            fixture.tune.generatedAt.addingTimeInterval(1)
        XCTAssertNil(
            eligibility.candidateRevisionFingerprint(
                candidate: stale,
                persistedCandidate: fixture.tune,
                isStreaming: false
            )
        )
        XCTAssertThrowsError(
            try FH6IndependentValidationReviewPacketExporter()
                .makeArtifact(
                    candidate: fixture.tune,
                    persistedCandidate: fixture.tune,
                    isStreaming: false,
                    firstPartyTestDrives: [],
                    localCommunityOutcomes: [],
                    reviewedCommunityOutcomes: []
                )
        ) {
            XCTAssertEqual(
                $0 as?
                    FH6IndependentValidationReviewPacketError,
                .missingFirstPartyTestDrive
            )
        }
    }

    @MainActor
    func testReceiverRefetchesPersistedCandidateAndNeverMutatesIt()
        async throws {
        let fixture = try await makeFixture()
        let artifact = try packet(
            fixture: fixture,
            extraCommunity: []
        )
        let container = try ModelContainer(
            for: SavedTune.self,
            configurations:
                ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let writer = ModelContext(container)
        writer.autosaveEnabled = false
        let savedTune = try SavedTune(tune: fixture.tune)
        writer.insert(savedTune)
        try savedTune.appendValidationRecord(
            fixture.validation
        )
        try savedTune.appendFH6CommunityReferenceTrialRecord(
            fixture.community
        )
        try writer.save()
        let before = try persistedContentBytes(savedTune)
        let receiver =
            FH6IndependentValidationReviewPacketReceiver()

        var staleDisplayedTune = fixture.tune
        staleDisplayedTune.generatedAt =
            fixture.tune.generatedAt.addingTimeInterval(1)
        XCTAssertThrowsError(
            try receiver.validate(
                data: artifact.canonicalJSON,
                displayedTune: staleDisplayedTune,
                savedTuneID: savedTune.id,
                in: container
            )
        ) {
            XCTAssertEqual(
                $0 as?
                    FH6IndependentValidationReviewPacketError,
                .ineligibleCandidate
            )
        }

        var changedPersistedTune = fixture.tune
        changedPersistedTune.generatedAt =
            fixture.tune.generatedAt.addingTimeInterval(2)
        try savedTune.update(with: changedPersistedTune)
        XCTAssertEqual(
            savedTune.tuneResult,
            changedPersistedTune
        )
        XCTAssertTrue(writer.hasChanges)

        XCTAssertEqual(
            try receiver.validate(
                data: artifact.canonicalJSON,
                displayedTune: fixture.tune,
                savedTuneID: savedTune.id,
                in: container
            ),
            artifact.packet
        )
        XCTAssertEqual(
            savedTune.tuneResult,
            changedPersistedTune
        )
        XCTAssertTrue(writer.hasChanges)

        let verificationContext = ModelContext(container)
        let savedTuneID = savedTune.id
        var descriptor = FetchDescriptor<SavedTune>(
            predicate: #Predicate<SavedTune> { tune in
                tune.id == savedTuneID
            }
        )
        descriptor.includePendingChanges = false
        let verifiedSavedTune = try XCTUnwrap(
            verificationContext.fetch(descriptor).first
        )
        XCTAssertEqual(
            try persistedContentBytes(verifiedSavedTune),
            before
        )

        try writer.save()
        XCTAssertThrowsError(
            try receiver.validate(
                data: artifact.canonicalJSON,
                displayedTune: fixture.tune,
                savedTuneID: savedTune.id,
                in: container
            )
        ) {
            XCTAssertEqual(
                $0 as?
                    FH6IndependentValidationReviewPacketError,
                .ineligibleCandidate
            )
        }
    }

    func testPermissionBoundReviewedCommunityOutcomeCanQualify()
        async throws {
        let fixture = try await makeFixture()
        let data = try fixture.community.deterministicJSON()
        let reviewed = try FH6CommunityOutcomeReviewEntry
            .locallyReviewed(
                canonicalExportJSON: data,
                expectedTune: fixture.tune,
                reviewerConfirmedDirectReceipt: true,
                reviewerConfirmedStructuredReusePermission: true,
                now: capturedAt
            )
        let artifact =
            try FH6IndependentValidationReviewPacketExporter()
            .makeArtifact(
                candidate: fixture.tune,
                persistedCandidate: fixture.tune,
                isStreaming: false,
                firstPartyTestDrives: [fixture.validation],
                localCommunityOutcomes: [],
                reviewedCommunityOutcomes: [reviewed]
            )

        XCTAssertEqual(
            artifact.packet.counts
                .includedReviewedCommunityOutcomeCount,
            1
        )
        XCTAssertEqual(
            artifact.packet.evidence.map(\.kind),
            [.firstPartyTestDrive, .reviewedCommunityOutcome]
        )
    }

    func testPacketContainsOnlyPublicExportsAndDisclosures()
        async throws {
        let fixture = try await makeFixture()
        let reviewed = try FH6CommunityOutcomeReviewEntry
            .locallyReviewed(
                canonicalExportJSON:
                    fixture.community.deterministicJSON(),
                expectedTune: fixture.tune,
                reviewerConfirmedDirectReceipt: true,
                reviewerConfirmedStructuredReusePermission: true,
                id: uuid(90),
                now: capturedAt
            )
        let artifact =
            try FH6IndependentValidationReviewPacketExporter()
            .makeArtifact(
                candidate: fixture.tune,
                persistedCandidate: fixture.tune,
                isStreaming: false,
                firstPartyTestDrives: [fixture.validation],
                localCommunityOutcomes: [],
                reviewedCommunityOutcomes: [reviewed]
            )
        let text = try XCTUnwrap(
            String(
                data: artifact.canonicalJSON,
                encoding: .utf8
            )
        )
        for forbidden in [
            "recordID", "tuneID", "candidateTuneID",
            "candidateProof", "proofFingerprint",
            "importedAt", "locallyReviewedAt",
            reviewed.id.uuidString
        ] {
            XCTAssertFalse(text.contains(forbidden), forbidden)
        }
        XCTAssertTrue(
            artifact.packet.reviewBoundary.contains(
                "do not authenticate"
            )
        )
        XCTAssertTrue(
            artifact.packet.reviewBoundary.contains(
                "does not prove"
            )
        )
        XCTAssertTrue(
            artifact.packet.reviewBoundary.contains(
                "no accuracy, validation, ranking"
            )
        )
    }

    func testExactPersistedNonStreamingCandidateIsRequired()
        async throws {
        let fixture = try await makeFixture()
        let exporter =
            FH6IndependentValidationReviewPacketExporter()
        XCTAssertThrowsError(
            try exporter.makeArtifact(
                candidate: fixture.tune,
                persistedCandidate: nil,
                isStreaming: false,
                firstPartyTestDrives: [fixture.validation],
                localCommunityOutcomes: [fixture.community],
                reviewedCommunityOutcomes: []
            )
        )
        XCTAssertThrowsError(
            try exporter.makeArtifact(
                candidate: fixture.tune,
                persistedCandidate: fixture.tune,
                isStreaming: true,
                firstPartyTestDrives: [fixture.validation],
                localCommunityOutcomes: [fixture.community],
                reviewedCommunityOutcomes: []
            )
        )
        var stale = fixture.tune
        stale.generatedAt = capturedAt.addingTimeInterval(1)
        XCTAssertThrowsError(
            try exporter.makeArtifact(
                candidate: fixture.tune,
                persistedCandidate: stale,
                isStreaming: false,
                firstPartyTestDrives: [fixture.validation],
                localCommunityOutcomes: [fixture.community],
                reviewedCommunityOutcomes: []
            )
        )
    }

    func testBothEvidenceKindsAndReusePermissionsAreRequired()
        async throws {
        let fixture = try await makeFixture()
        let exporter =
            FH6IndependentValidationReviewPacketExporter()
        XCTAssertThrowsError(
            try exporter.makeArtifact(
                candidate: fixture.tune,
                persistedCandidate: fixture.tune,
                isStreaming: false,
                firstPartyTestDrives: [],
                localCommunityOutcomes: [fixture.community],
                reviewedCommunityOutcomes: []
            )
        ) {
            XCTAssertEqual(
                $0 as?
                    FH6IndependentValidationReviewPacketError,
                .missingFirstPartyTestDrive
            )
        }
        XCTAssertThrowsError(
            try exporter.makeArtifact(
                candidate: fixture.tune,
                persistedCandidate: fixture.tune,
                isStreaming: false,
                firstPartyTestDrives: [fixture.validation],
                localCommunityOutcomes: [],
                reviewedCommunityOutcomes: []
            )
        ) {
            XCTAssertEqual(
                $0 as?
                    FH6IndependentValidationReviewPacketError,
                .missingCommunityOutcome
            )
        }

        let noReuseCommunity = try makeCommunity(
            tune: fixture.tune,
            validation: fixture.validation,
            reuse: false
        )
        XCTAssertThrowsError(
            try exporter.makeArtifact(
                candidate: fixture.tune,
                persistedCandidate: fixture.tune,
                isStreaming: false,
                firstPartyTestDrives: [fixture.validation],
                localCommunityOutcomes: [noReuseCommunity],
                reviewedCommunityOutcomes: []
            )
        ) {
            XCTAssertEqual(
                $0 as?
                    FH6IndependentValidationReviewPacketError,
                .missingCommunityOutcome
            )
        }
    }

    func testForgedReviewedPermissionFailsClosed()
        async throws {
        let fixture = try await makeFixture()
        let data = try fixture.community.deterministicJSON()
        let validated = try FH6CommunityOutcomeReviewIngestor()
            .validate(data)
        let forged = FH6CommunityOutcomeReviewEntry(
            importedAt: capturedAt,
            canonicalExportJSON: data,
            permission: .init(
                submissionID: validated.export.submissionID,
                permissionReceiptID:
                    validated.export.permissionReceiptID,
                consentVersion:
                    validated.export.consentVersion,
                protocolVersion:
                    validated.export.protocolVersion,
                canonicalExportDigest:
                    validated.canonicalExportDigest,
                contentFingerprint:
                    validated.export.contentFingerprint,
                candidateFingerprint:
                    validated.export.candidateAssociation
                    .candidateFingerprint,
                directReceiptConfirmed: true,
                structuredReusePermissionConfirmed: false,
                locallyReviewedAt: capturedAt
            )
        )
        XCTAssertThrowsError(
            try FH6IndependentValidationReviewPacketExporter()
                .makeArtifact(
                    candidate: fixture.tune,
                    persistedCandidate: fixture.tune,
                    isStreaming: false,
                    firstPartyTestDrives: [fixture.validation],
                    localCommunityOutcomes: [],
                    reviewedCommunityOutcomes: [forged]
                )
        ) {
            XCTAssertEqual(
                $0 as?
                    FH6IndependentValidationReviewPacketError,
                .missingCommunityOutcome
            )
        }
    }

    func testDuplicatesAreDeterministicallyCollapsed()
        async throws {
        let fixture = try await makeFixture()
        let exporter =
            FH6IndependentValidationReviewPacketExporter()
        let artifact = try exporter.makeArtifact(
            candidate: fixture.tune,
            persistedCandidate: fixture.tune,
            isStreaming: false,
            firstPartyTestDrives: [
                fixture.validation, fixture.validation
            ],
            localCommunityOutcomes: [
                fixture.community, fixture.community
            ],
            reviewedCommunityOutcomes: []
        )
        let reversed = try exporter.makeArtifact(
            candidate: fixture.tune,
            persistedCandidate: fixture.tune,
            isStreaming: false,
            firstPartyTestDrives: Array([
                fixture.validation, fixture.validation
            ].reversed()),
            localCommunityOutcomes: Array([
                fixture.community, fixture.community
            ].reversed()),
            reviewedCommunityOutcomes: []
        )
        XCTAssertEqual(artifact.canonicalJSON, reversed.canonicalJSON)
        XCTAssertEqual(
            artifact.packet.counts.includedEvidenceCount,
            2
        )
    }

    func testConflictsAndReceiptReplaysAreQuarantined()
        async throws {
        let fixture = try await makeFixture()
        let sharedSubmission = uuid(700)
        let conflictA = try makeValidation(
            tune: fixture.tune,
            verdict: .keep,
            submissionID: sharedSubmission,
            permissionReceiptID: uuid(701)
        )
        let conflictB = try makeValidation(
            tune: fixture.tune,
            verdict: .adjust,
            submissionID: sharedSubmission,
            permissionReceiptID: uuid(702)
        )
        let clean = try makeValidation(
            tune: fixture.tune,
            verdict: .keep,
            submissionID: uuid(703),
            permissionReceiptID: uuid(704)
        )
        let artifact =
            try FH6IndependentValidationReviewPacketExporter()
            .makeArtifact(
                candidate: fixture.tune,
                persistedCandidate: fixture.tune,
                isStreaming: false,
                firstPartyTestDrives: [
                    conflictA, conflictB, clean
                ],
                localCommunityOutcomes: [fixture.community],
                reviewedCommunityOutcomes: []
            )
        XCTAssertEqual(
            artifact.packet.counts
                .includedFirstPartyTestDriveCount,
            1
        )
        XCTAssertFalse(
            submissionIDs(in: artifact.packet)
                .contains(sharedSubmission)
        )

        let replayA = try makeValidation(
            tune: fixture.tune,
            verdict: .keep,
            submissionID: uuid(710),
            permissionReceiptID: uuid(799)
        )
        let replayB = try makeValidation(
            tune: fixture.tune,
            verdict: .adjust,
            submissionID: uuid(711),
            permissionReceiptID: uuid(799)
        )
        let replayArtifact =
            try FH6IndependentValidationReviewPacketExporter()
            .makeArtifact(
                candidate: fixture.tune,
                persistedCandidate: fixture.tune,
                isStreaming: false,
                firstPartyTestDrives: [
                    replayA, replayB, clean
                ],
                localCommunityOutcomes: [fixture.community],
                reviewedCommunityOutcomes: []
            )
        XCTAssertFalse(
            permissionReceiptIDs(in: replayArtifact.packet)
                .contains(uuid(799))
        )
    }

    func testPreparedInputStateFingerprintCoversFullInputsAndPermissions()
        async throws {
        let fixture = try await makeFixture()
        let exporter =
            FH6IndependentValidationReviewPacketExporter()
        let baseline = try exporter.preparedInputStateFingerprint(
            candidate: fixture.tune,
            persistedCandidate: fixture.tune,
            isStreaming: false,
            firstPartyTestDrives: [fixture.validation],
            localCommunityOutcomes: [fixture.community],
            reviewedCommunityOutcomes: []
        )
        XCTAssertEqual(
            baseline,
            try exporter.preparedInputStateFingerprint(
                candidate: fixture.tune,
                persistedCandidate: fixture.tune,
                isStreaming: false,
                firstPartyTestDrives: [fixture.validation],
                localCommunityOutcomes: [fixture.community],
                reviewedCommunityOutcomes: []
            )
        )

        var changedPermission = fixture.validation
        changedPermission.permissionReceiptID = uuid(999)
        XCTAssertNotEqual(
            baseline,
            try exporter.preparedInputStateFingerprint(
                candidate: fixture.tune,
                persistedCandidate: fixture.tune,
                isStreaming: false,
                firstPartyTestDrives: [changedPermission],
                localCommunityOutcomes: [fixture.community],
                reviewedCommunityOutcomes: []
            )
        )

        let differentCandidate = try await eligibleTune(
            discipline: .dirt
        )
        XCTAssertNotEqual(
            FirstPartyValidationRecordFactory()
                .revisionFingerprint(for: fixture.tune),
            FirstPartyValidationRecordFactory()
                .revisionFingerprint(for: differentCandidate)
        )
        XCTAssertNotEqual(
            baseline,
            try exporter.preparedInputStateFingerprint(
                candidate: differentCandidate,
                persistedCandidate: differentCandidate,
                isStreaming: false,
                firstPartyTestDrives: [fixture.validation],
                localCommunityOutcomes: [fixture.community],
                reviewedCommunityOutcomes: []
            )
        )
    }

    func testFullFirstPartyInputExcludesInvalidSiblingFromPacket()
        async throws {
        let fixture = try await makeFixture()
        var invalid = fixture.validation
        invalid.deidentifiedReusePermitted = false
        let artifact =
            try FH6IndependentValidationReviewPacketExporter()
                .makeArtifact(
                    candidate: fixture.tune,
                    persistedCandidate: fixture.tune,
                    isStreaming: false,
                    firstPartyTestDrives: [
                        fixture.validation, invalid
                    ],
                    localCommunityOutcomes: [
                        fixture.community
                    ],
                    reviewedCommunityOutcomes: []
                )
        XCTAssertEqual(
            artifact.packet.counts
                .includedFirstPartyTestDriveCount,
            1
        )
        XCTAssertEqual(
            artifact.packet.counts.includedEvidenceCount,
            2
        )
        let packetText = try XCTUnwrap(
            String(
                data: artifact.canonicalJSON,
                encoding: .utf8
            )
        )
        XCTAssertFalse(
            packetText.contains(
                invalid.recordID.uuidString
            )
        )
        XCTAssertFalse(
            packetText.contains(invalid.tuneID.uuidString)
        )
        XCTAssertFalse(packetText.contains("receivedInputManifest"))
        XCTAssertFalse(packetText.contains("quarantinedCount"))
        XCTAssertTrue(
            artifact.packet.reviewBoundary.contains(
                "does not attest, enumerate, or validate omitted"
            )
        )

        let savedTune = try SavedTune(tune: fixture.tune)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        savedTune.replaceValidationRecordsDataForTesting(
            try encoder.encode([fixture.validation, invalid])
        )
        XCTAssertEqual(
            try savedTune.allFirstPartyValidationRecords().count,
            2
        )
        XCTAssertThrowsError(
            try savedTune.validValidationRecords(
                matching: fixture.tune
            )
        )
    }

    func testCrossKindSubmissionConflictAndReceiptReplayQuarantine()
        async throws {
        let fixture = try await makeFixture()
        let conflictingValidation = try makeValidation(
            tune: fixture.tune,
            verdict: .adjust,
            submissionID: uuid(800),
            permissionReceiptID: uuid(801)
        )
        let conflictingCommunity = try makeCommunity(
            tune: fixture.tune,
            validation: fixture.validation,
            reuse: true,
            contentURL:
                "https://www.youtube.com/watch?v=conflict",
            recordID: uuid(802),
            submissionID: uuid(800),
            permissionReceiptID: uuid(803)
        )
        let conflictArtifact =
            try FH6IndependentValidationReviewPacketExporter()
                .makeArtifact(
                    candidate: fixture.tune,
                    persistedCandidate: fixture.tune,
                    isStreaming: false,
                    firstPartyTestDrives: [
                        fixture.validation,
                        conflictingValidation
                    ],
                    localCommunityOutcomes: [
                        fixture.community,
                        conflictingCommunity
                    ],
                    reviewedCommunityOutcomes: []
                )
        XCTAssertFalse(
            submissionIDs(in: conflictArtifact.packet)
                .contains(uuid(800))
        )

        let receiptValidation = try makeValidation(
            tune: fixture.tune,
            verdict: .adjust,
            submissionID: uuid(810),
            permissionReceiptID: uuid(899)
        )
        let receiptCommunity = try makeCommunity(
            tune: fixture.tune,
            validation: fixture.validation,
            reuse: true,
            contentURL:
                "https://www.youtube.com/watch?v=receipt",
            recordID: uuid(812),
            submissionID: uuid(811),
            permissionReceiptID: uuid(899)
        )
        let receiptArtifact =
            try FH6IndependentValidationReviewPacketExporter()
                .makeArtifact(
                    candidate: fixture.tune,
                    persistedCandidate: fixture.tune,
                    isStreaming: false,
                    firstPartyTestDrives: [
                        fixture.validation,
                        receiptValidation
                    ],
                    localCommunityOutcomes: [
                        fixture.community,
                        receiptCommunity
                    ],
                    reviewedCommunityOutcomes: []
                )
        XCTAssertFalse(
            permissionReceiptIDs(in: receiptArtifact.packet)
                .contains(uuid(899))
        )
    }

    func testCommunityConflictsReceiptAndSessionReplaysQuarantine()
        async throws {
        let fixture = try await makeFixture()
        let conflictA = try makeCommunity(
            tune: fixture.tune,
            validation: fixture.validation,
            reuse: true,
            outcome: .generatedPreferred,
            recordID: uuid(900),
            submissionID: uuid(910),
            permissionReceiptID: uuid(911),
            createdAt: capturedAt.addingTimeInterval(100)
        )
        let conflictB = try makeCommunity(
            tune: fixture.tune,
            validation: fixture.validation,
            reuse: true,
            outcome: .referencePreferred,
            recordID: uuid(901),
            submissionID: uuid(910),
            permissionReceiptID: uuid(912),
            createdAt: capturedAt.addingTimeInterval(100)
        )
        let conflictArtifact = try packet(
            fixture: fixture,
            extraCommunity: [conflictA, conflictB]
        )
        XCTAssertFalse(
            submissionIDs(in: conflictArtifact.packet)
                .contains(uuid(910))
        )

        let receiptA = try makeCommunity(
            tune: fixture.tune,
            validation: fixture.validation,
            reuse: true,
            outcome: .generatedPreferred,
            recordID: uuid(920),
            submissionID: uuid(921),
            permissionReceiptID: uuid(929),
            createdAt: capturedAt.addingTimeInterval(200)
        )
        let receiptB = try makeCommunity(
            tune: fixture.tune,
            validation: fixture.validation,
            reuse: true,
            outcome: .referencePreferred,
            recordID: uuid(922),
            submissionID: uuid(923),
            permissionReceiptID: uuid(929),
            createdAt: capturedAt.addingTimeInterval(200)
        )
        let receiptArtifact = try packet(
            fixture: fixture,
            extraCommunity: [receiptA, receiptB]
        )
        XCTAssertFalse(
            permissionReceiptIDs(in: receiptArtifact.packet)
                .contains(uuid(929))
        )

        let sessionA = try makeCommunity(
            tune: fixture.tune,
            validation: fixture.validation,
            reuse: true,
            outcome: .generatedPreferred,
            recordID: uuid(930),
            submissionID: uuid(931),
            permissionReceiptID: uuid(932),
            createdAt: capturedAt.addingTimeInterval(300)
        )
        let sessionB = try makeCommunity(
            tune: fixture.tune,
            validation: fixture.validation,
            reuse: true,
            outcome: .referencePreferred,
            recordID: uuid(933),
            submissionID: uuid(934),
            permissionReceiptID: uuid(935),
            createdAt: capturedAt.addingTimeInterval(300)
        )
        let sessionArtifact = try packet(
            fixture: fixture,
            extraCommunity: [sessionA, sessionB]
        )
        XCTAssertFalse(
            submissionIDs(in: sessionArtifact.packet)
                .contains(uuid(931))
        )
        XCTAssertFalse(
            submissionIDs(in: sessionArtifact.packet)
                .contains(uuid(934))
        )
    }

    func testForgedRecomputedCountsFingerprintStillFails()
        async throws {
        let fixture = try await makeFixture()
        let exporter =
            FH6IndependentValidationReviewPacketExporter()
        let artifact = try packet(
            fixture: fixture,
            extraCommunity: []
        )
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: artifact.canonicalJSON
            ) as? [String: Any]
        )
        var forgedCounts = try XCTUnwrap(
            object["counts"] as? [String: Any]
        )
        forgedCounts["includedEvidenceCount"] = 3
        object["counts"] = forgedCounts
        object["artifactFingerprint"] = ""
        let unsigned = try canonicalJSON(object)
        var fingerprintPayload = Data(
            "forzadvisor.fh6-independent-review.packet.v1".utf8
        )
        fingerprintPayload.append(0)
        fingerprintPayload.append(unsigned)
        object["artifactFingerprint"] = SHA256.hash(
            data: fingerprintPayload
        ).map { String(format: "%02x", $0) }.joined()
        let forged = try canonicalJSON(object)

        XCTAssertThrowsError(
            try exporter.validate(
                forged,
                candidate: fixture.tune,
                persistedCandidate: fixture.tune,
                isStreaming: false
            )
        ) {
            XCTAssertEqual(
                $0 as?
                    FH6IndependentValidationReviewPacketError,
                .invalidStructure
            )
        }
    }

    func testFabricatedHistoryFieldCannotBeAppendedOrRelabeled()
        async throws {
        let fixture = try await makeFixture()
        let exporter =
            FH6IndependentValidationReviewPacketExporter()
        let artifact = try packet(
            fixture: fixture,
            extraCommunity: []
        )
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: artifact.canonicalJSON
            ) as? [String: Any]
        )
        object["receivedInputManifest"] = [[
            "kind": "reviewedCommunityOutcome",
            "status": "quarantined",
            "reason": "submissionConflict"
        ]]
        object["artifactFingerprint"] = ""
        let unsigned = try canonicalJSON(object)
        var fingerprintPayload = Data(
            "forzadvisor.fh6-independent-review.packet.v1".utf8
        )
        fingerprintPayload.append(0)
        fingerprintPayload.append(unsigned)
        object["artifactFingerprint"] = SHA256.hash(
            data: fingerprintPayload
        ).map { String(format: "%02x", $0) }.joined()

        XCTAssertThrowsError(
            try exporter.validate(
                canonicalJSON(object),
                candidate: fixture.tune,
                persistedCandidate: fixture.tune,
                isStreaming: false
            )
        ) {
            XCTAssertEqual(
                $0 as?
                    FH6IndependentValidationReviewPacketError,
                .unknownFields
            )
        }
    }

    func testValidationRejectsForeignCandidateTamperUnknownAndSize()
        async throws {
        let fixture = try await makeFixture()
        let exporter =
            FH6IndependentValidationReviewPacketExporter()
        let artifact = try exporter.makeArtifact(
            candidate: fixture.tune,
            persistedCandidate: fixture.tune,
            isStreaming: false,
            firstPartyTestDrives: [fixture.validation],
            localCommunityOutcomes: [fixture.community],
            reviewedCommunityOutcomes: []
        )
        var foreign = fixture.tune
        foreign.generatedAt =
            fixture.tune.generatedAt.addingTimeInterval(1)
        XCTAssertThrowsError(
            try exporter.validate(
                artifact.canonicalJSON,
                candidate: foreign,
                persistedCandidate: foreign,
                isStreaming: false
            )
        )

        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: artifact.canonicalJSON
            ) as? [String: Any]
        )
        object["unknown"] = true
        let unknown = try JSONSerialization.data(
            withJSONObject: object,
            options: [
                .prettyPrinted, .sortedKeys,
                .withoutEscapingSlashes
            ]
        )
        XCTAssertThrowsError(
            try exporter.validate(
                unknown,
                candidate: fixture.tune,
                persistedCandidate: fixture.tune,
                isStreaming: false
            )
        ) {
            XCTAssertEqual(
                $0 as?
                    FH6IndependentValidationReviewPacketError,
                .unknownFields
            )
        }

        object.removeValue(forKey: "unknown")
        object["artifactFingerprint"] =
            String(repeating: "0", count: 64)
        let tampered = try JSONSerialization.data(
            withJSONObject: object,
            options: [
                .prettyPrinted, .sortedKeys,
                .withoutEscapingSlashes
            ]
        )
        XCTAssertThrowsError(
            try exporter.validate(
                tampered,
                candidate: fixture.tune,
                persistedCandidate: fixture.tune,
                isStreaming: false
            )
        ) {
            XCTAssertEqual(
                $0 as?
                    FH6IndependentValidationReviewPacketError,
                .invalidFingerprint
            )
        }

        let compact = try JSONSerialization.data(
            withJSONObject: JSONSerialization.jsonObject(
                with: artifact.canonicalJSON
            ),
            options: [.sortedKeys]
        )
        XCTAssertThrowsError(
            try exporter.validate(
                compact,
                candidate: fixture.tune,
                persistedCandidate: fixture.tune,
                isStreaming: false
            )
        ) {
            XCTAssertEqual(
                $0 as?
                    FH6IndependentValidationReviewPacketError,
                .nonCanonicalJSON
            )
        }

        XCTAssertThrowsError(
            try exporter.validate(
                Data(
                    repeating: 0x20,
                    count:
                        FH6IndependentValidationReviewPacketExporter
                        .maximumPayloadBytes + 1
                ),
                candidate: fixture.tune,
                persistedCandidate: fixture.tune,
                isStreaming: false
            )
        ) {
            XCTAssertEqual(
                $0 as?
                    FH6IndependentValidationReviewPacketError,
                .payloadTooLarge
            )
        }
    }

    // MARK: - Fixtures

    private typealias Fixture = (
        tune: TuneResult,
        validation: FirstPartyValidationRecord,
        community: FH6CommunityReferenceTrialRecord
    )

    private func makeFixture() async throws -> Fixture {
        let tune = try await eligibleTune()
        let validation = try makeValidation(
            tune: tune,
            verdict: .keep,
            submissionID: uuid(1),
            permissionReceiptID: uuid(2)
        )
        return (
            tune,
            validation,
            try makeCommunity(
                tune: tune,
                validation: validation,
                reuse: true
            )
        )
    }

    private func eligibleTune(
        discipline: DrivingDiscipline = .road
    ) async throws -> TuneResult {
        try await SyntheticLegacyTuneFixtureFactory.eligibleValidationTune(
            capturedAt: capturedAt,
            discipline: discipline
        )
    }

    private func makeValidation(
        tune: TuneResult,
        verdict: ValidationVerdict,
        submissionID: UUID,
        permissionReceiptID: UUID
    ) throws -> FirstPartyValidationRecord {
        try FirstPartyValidationRecordFactory().make(
            tune: tune,
            savedTune: tune,
            isStreaming: false,
            capture: .init(
                courseType: .testTrack,
                surface: .dry,
                input: .controller,
                runCount: verdict == .keep ? 2 : 3,
                verdict: verdict,
                feedback:
                    verdict == .keep ? [] : [.pushesWide],
                exactSetupConfirmed: true,
                allExportedSettingsApplied: true,
                firstPartyAuthorshipConfirmed: true,
                deidentifiedReusePermitted: true
            ),
            recordID: UUID(),
            submissionID: submissionID,
            permissionReceiptID: permissionReceiptID,
            createdAt: capturedAt
        )
    }

    private func makeCommunity(
        tune: TuneResult,
        validation: FirstPartyValidationRecord,
        reuse: Bool,
        contentURL: String =
            "https://www.youtube.com/watch?v=abc123",
        outcome: FH6CommunityReferenceTrialOutcome =
            .noClearDifference,
        recordID: UUID? = nil,
        submissionID: UUID? = nil,
        permissionReceiptID: UUID? = nil,
        createdAt: Date? = nil
    ) throws -> FH6CommunityReferenceTrialRecord {
        let factory = FH6CommunityReferenceTrialFactory()
        let sourceID = try XCTUnwrap(
            factory.sourceID(
                for: contentURL,
                kind: .youtube
            )
        )
        let capture = FH6CommunityReferenceTrialCapture(
            source: .init(
                kind: .youtube,
                contentURL: contentURL,
                publisherDisplayName: "Community Tuner",
                sourceID: sourceID,
                retrievedAt: capturedAt
            ),
            referenceCandidate: .init(
                catalogID: try XCTUnwrap(
                    tune.request.car.catalogReference?.entryID
                ),
                performanceClass:
                    tune.request.car.performanceClass,
                performanceIndex:
                    tune.request.car.performanceIndex,
                confirmed: true
            ),
            context: .init(
                courseType: .testTrack,
                surface: .dry,
                input: .controller
            ),
            runs:
                FH6CommunityReferenceTrialRecord.requiredRoles
                .map {
                    .init(
                        role: $0,
                        completed: true,
                        correctTuneConfirmed: true
                    )
                },
            outcome: outcome,
            candidateDeficiencySymptoms:
                outcome == .referencePreferred
                ? [.pushesWide]
                : [],
            sameRouteAndConditionsConfirmed: true,
            sameAssistsAndInputConfirmed: true,
            candidateSettingsAppliedConfirmed: true,
            communityIdentityConfirmed: true,
            finalCandidateRestoredConfirmed: true,
            firstPartyAuthorshipConfirmed: true,
            localStoragePermitted: true,
            deidentifiedOutcomeReusePermitted: reuse
        )
        return try factory.make(
            tune: tune,
            savedTune: tune,
            isStreaming: false,
            validationRecords: [validation],
            capture: capture,
            recordID: recordID ?? uuid(20),
            submissionID: submissionID ?? uuid(21),
            permissionReceiptID:
                permissionReceiptID ?? uuid(22),
            createdAt: createdAt ?? capturedAt
        )
    }

    private func packet(
        fixture: Fixture,
        extraCommunity:
            [FH6CommunityReferenceTrialRecord]
    ) throws -> FH6IndependentValidationReviewPacketArtifact {
        try FH6IndependentValidationReviewPacketExporter()
            .makeArtifact(
                candidate: fixture.tune,
                persistedCandidate: fixture.tune,
                isStreaming: false,
                firstPartyTestDrives: [fixture.validation],
                localCommunityOutcomes:
                    [fixture.community] + extraCommunity,
                reviewedCommunityOutcomes: []
            )
    }

    private func submissionIDs(
        in packet: FH6IndependentValidationReviewPacket
    ) -> Set<UUID> {
        Set(packet.evidence.compactMap {
            $0.firstPartyTestDrive?.submissionID
                ?? $0.communityOutcome?.submissionID
        })
    }

    private func permissionReceiptIDs(
        in packet: FH6IndependentValidationReviewPacket
    ) -> Set<UUID> {
        Set(packet.evidence.compactMap {
            $0.firstPartyTestDrive?.permissionReceiptID
                ?? $0.communityOutcome?.permissionReceiptID
        })
    }

    @MainActor
    private func persistedContentBytes(
        _ savedTune: SavedTune
    ) throws -> [Data] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return [
            try encoder.encode(
                XCTUnwrap(savedTune.tuneResult)
            ),
            try encoder.encode(
                savedTune.allFirstPartyValidationRecords()
            ),
            try encoder.encode(
                savedTune
                    .allFH6CommunityReferenceTrialRecords()
            ),
            try encoder.encode(
                savedTune
                    .allFH6CommunityOutcomeReviewEntries()
            )
        ]
    }

    private func canonicalJSON(
        _ object: [String: Any]
    ) throws -> Data {
        try JSONSerialization.data(
            withJSONObject: object,
            options: [
                .prettyPrinted,
                .sortedKeys,
                .withoutEscapingSlashes
            ]
        )
    }

    private func uuid(_ value: Int) -> UUID {
        UUID(
            uuidString: String(
                format: "00000000-0000-0000-0000-%012d",
                value
            )
        )!
    }
}
