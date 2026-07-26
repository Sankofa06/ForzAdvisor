//
//  FH6CommunityOutcomeReviewTests.swift
//  forzadvisorTests
//

import Compression
import CryptoKit
import SwiftData
import XCTest
@testable import forzadvisor

final class FH6CommunityOutcomeReviewTests: XCTestCase {
    private enum Build43FixtureError: Error, Equatable {
        case missingResource
        case provenanceMismatch
        case archiveHashMismatch
        case unsafePath
        case unexpectedKeys
        case invalidBase64
        case fileHashMismatch
        case decompressionFailed
    }

    private struct Build43FixtureProvenance: Decodable {
        let sourceCommit: String
        let generationProcess: [String]
        let compressedArchiveSHA256: String
        let decodedFileSHA256: [String: String]
    }

    private static let build43SourceCommit =
        "492663fe607c8e9445844e9e3810711e0ff0dc1f"
    private static let build43FixtureKeys: Set<String> = [
        "store.sqlite",
        "store.sqlite-wal",
        "store.sqlite-shm"
    ]

    private let capturedAt =
        Date(timeIntervalSince1970: 1_810_000_000)

    /// The fixture was emitted by the `SavedTune` model at commit 492663f,
    /// before `fh6CommunityOutcomeReviewEntriesData` existed.
    @MainActor
    func testBuild43StoreFromCommit492663fMigratesWithoutLosingEvidence()
        throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(
                path: "forzadvisor-build43-migration-\(UUID().uuidString)",
                directoryHint: .isDirectory
            )
        try materializeBuild43Fixture(at: directory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let configuration = ModelConfiguration(
            url: directory.appending(path: "store.sqlite")
        )

        var expectedTune: TuneResult?
        var expectedValidationFingerprint: String?
        var expectedCommunityFingerprint: String?
        do {
            let container = try ModelContainer(
                for: SavedTune.self,
                configurations: configuration
            )
            let context = ModelContext(container)
            let saved = try XCTUnwrap(
                context.fetch(FetchDescriptor<SavedTune>()).first
            )
            let tune = try XCTUnwrap(saved.tuneResult)
            let validation = try XCTUnwrap(
                saved.firstPartyValidationRecords.first
            )
            let community = try XCTUnwrap(
                saved.allFH6CommunityReferenceTrialRecords().first
            )

            XCTAssertEqual(saved.playerNotes, "build43 migration notes")
            XCTAssertEqual(
                saved.thumbnailData,
                Data("build43 migration thumbnail".utf8)
            )
            XCTAssertEqual(saved.firstPartyValidationRecords.count, 1)
            XCTAssertEqual(
                try saved.allFH6CommunityReferenceTrialRecords().count,
                1
            )
            XCTAssertTrue(
                try saved.allFH6CommunityOutcomeReviewEntries().isEmpty
            )

            let review = try reviewEntry(
                community.deterministicJSON(),
                tune: tune
            )
            try saved.appendFH6CommunityOutcomeReviewEntry(review)
            try context.save()

            expectedTune = tune
            expectedValidationFingerprint =
                validation.contentFingerprint
            expectedCommunityFingerprint =
                community.contentFingerprint
        }

        do {
            let container = try ModelContainer(
                for: SavedTune.self,
                configurations: configuration
            )
            let context = ModelContext(container)
            let reopened = try XCTUnwrap(
                context.fetch(FetchDescriptor<SavedTune>()).first
            )

            XCTAssertEqual(reopened.tuneResult, expectedTune)
            XCTAssertEqual(
                reopened.playerNotes,
                "build43 migration notes"
            )
            XCTAssertEqual(
                reopened.thumbnailData,
                Data("build43 migration thumbnail".utf8)
            )
            XCTAssertEqual(
                reopened.firstPartyValidationRecords
                    .map(\.contentFingerprint),
                [expectedValidationFingerprint]
            )
            XCTAssertEqual(
                try reopened
                    .allFH6CommunityReferenceTrialRecords()
                    .map(\.contentFingerprint),
                [expectedCommunityFingerprint]
            )
            XCTAssertEqual(
                try reopened
                    .allFH6CommunityOutcomeReviewEntries().count,
                1
            )
        }
    }

    func testBuild43FixtureRejectsUnsafeAndUnexpectedPaths()
        throws {
        let required = Self.build43FixtureKeys.reduce(
            into: [String: String]()
        ) {
            $0[$1] = Data().base64EncodedString()
        }
        let emptyHash = sha256(Data())
        let hashes = Dictionary(
            uniqueKeysWithValues:
                Self.build43FixtureKeys.map { ($0, emptyHash) }
        )

        var absolute = required
        absolute["/store.sqlite"] =
            absolute.removeValue(forKey: "store.sqlite")
        assertFixtureError(
            .unsafePath,
            files: absolute,
            expectedHashes: hashes
        )

        var parent = required
        parent["../store.sqlite"] =
            parent.removeValue(forKey: "store.sqlite")
        assertFixtureError(
            .unsafePath,
            files: parent,
            expectedHashes: hashes
        )

        var unexpected = required
        unexpected["other.sqlite"] =
            Data().base64EncodedString()
        assertFixtureError(
            .unexpectedKeys,
            files: unexpected,
            expectedHashes: hashes
        )

        var missing = required
        missing.removeValue(forKey: "store.sqlite-shm")
        assertFixtureError(
            .unexpectedKeys,
            files: missing,
            expectedHashes: hashes
        )
    }

    func testCanonicalRoundTripAndStrictParserAdversaries()
        async throws {
        let tune = try await eligibleTune()
        let record = try makeRecord(tune: tune)
        let data = try record.deterministicJSON()
        let ingestor = FH6CommunityOutcomeReviewIngestor()
        let validated = try ingestor.validate(data)

        XCTAssertEqual(validated.export, try record.publicExport())
        XCTAssertEqual(
            try FH6CommunityOutcomeReviewIngestor
                .canonicalData(for: validated.export),
            data
        )
        XCTAssertTrue(
            ingestor.matchesSavedTune(validated, tune: tune)
        )

        XCTAssertThrowsError(try ingestor.validate(Data())) {
            XCTAssertEqual(
                $0 as? FH6CommunityOutcomeReviewError,
                .emptyPayload
            )
        }
        XCTAssertThrowsError(
            try ingestor.validate(
                Data(
                    repeating: 0x20,
                    count:
                        FH6CommunityOutcomeReviewIngestor
                            .maximumPayloadBytes + 1
                )
            )
        ) {
            XCTAssertEqual(
                $0 as? FH6CommunityOutcomeReviewError,
                .payloadTooLarge
            )
        }
        let duplicateKey = inject(
            "\"schemaVersion\" : 1,",
            into: data
        )
        XCTAssertEqual(
            occurrences(
                of: "\"schemaVersion\"",
                in: duplicateKey
            ),
            2
        )
        for adversary in [
            Data("{".utf8),
            data + Data(" trailing".utf8),
            try compactJSON(data),
            inject(
                "\"unknownField\" : true,",
                into: data
            ),
            duplicateKey
        ] {
            XCTAssertThrowsError(
                try ingestor.validate(adversary)
            )
        }

        var tampered = validated.export
        tampered.outcome = .generatedPreferred
        XCTAssertThrowsError(
            try ingestor.validate(
                try canonicalData(tampered)
            )
        )
        tampered = validated.export
        tampered.game = .fh5
        XCTAssertThrowsError(
            try ingestor.validate(
                try canonicalData(tampered)
            )
        )
        tampered = validated.export
        tampered.attestations.finalCandidateRestored = false
        XCTAssertThrowsError(
            try ingestor.validate(
                try canonicalData(tampered)
            )
        )
        tampered = validated.export
        tampered.privacyExclusions = []
        XCTAssertThrowsError(
            try ingestor.validate(
                try canonicalData(tampered)
            )
        )
        tampered = validated.export
        tampered.source.contentIdentityFingerprint =
            String(repeating: "0", count: 64)
        XCTAssertThrowsError(
            try ingestor.validate(
                try canonicalData(tampered)
            )
        )
    }

    func testDualPermissionAndExactBindingAreIndependent()
        async throws {
        let tune = try await eligibleTune()
        let data = try makeRecord(tune: tune)
            .deterministicJSON()

        XCTAssertThrowsError(
            try FH6CommunityOutcomeReviewEntry.locallyReviewed(
                canonicalExportJSON: data,
                expectedTune: tune,
                reviewerConfirmedDirectReceipt: false,
                reviewerConfirmedStructuredReusePermission: true
            )
        ) {
            XCTAssertEqual(
                $0 as? FH6CommunityOutcomeReviewError,
                .directReceiptNotConfirmed
            )
        }
        XCTAssertThrowsError(
            try FH6CommunityOutcomeReviewEntry.locallyReviewed(
                canonicalExportJSON: data,
                expectedTune: tune,
                reviewerConfirmedDirectReceipt: true,
                reviewerConfirmedStructuredReusePermission: false
            )
        ) {
            XCTAssertEqual(
                $0 as? FH6CommunityOutcomeReviewError,
                .reusePermissionNotConfirmed
            )
        }

        let entry = try reviewEntry(data, tune: tune)
        XCTAssertTrue(
            entry.permission.directReceiptConfirmed
        )
        XCTAssertTrue(
            entry.permission
                .structuredReusePermissionConfirmed
        )
        XCTAssertTrue(
            FH6CommunityOutcomeReviewIngestor()
                .isValidReviewEntry(entry)
        )

        let invalid = entryWithPermission(
            entry,
            canonicalDigest:
                String(repeating: "0", count: 64)
        )
        XCTAssertFalse(
            FH6CommunityOutcomeReviewIngestor()
                .isValidReviewEntry(invalid)
        )
    }

    @MainActor
    func testFreshExactCandidateMatchRejectsChangedAndForeignTune()
        async throws {
        let tune = try await eligibleTune()
        let data = try makeRecord(tune: tune)
            .deterministicJSON()
        let validated =
            try FH6CommunityOutcomeReviewIngestor()
                .validate(data)

        var changed = tune
        let index = try XCTUnwrap(
            changed.sections[0].lines.firstIndex {
                $0.fieldID == .frontTirePressure
            }
        )
        let value = try XCTUnwrap(
            Double(changed.sections[0].lines[index].value)
        )
        changed.sections[0].lines[index].value =
            String(format: "%.1f", value + 0.5)
        changed = TuneOutputProjector().project(changed)
        XCTAssertEqual(
            tune.request.car.performanceIndex,
            changed.request.car.performanceIndex
        )
        XCTAssertFalse(
            FH6CommunityOutcomeReviewIngestor()
                .matchesSavedTune(validated, tune: changed)
        )

        var foreign = tune
        foreign.request.car.game = .fh5
        XCTAssertFalse(
            FH6CommunityOutcomeReviewIngestor()
                .matchesSavedTune(validated, tune: foreign)
        )
        XCTAssertThrowsError(
            try FH6CommunityOutcomeReviewEntry.locallyReviewed(
                canonicalExportJSON: data,
                expectedTune: changed,
                reviewerConfirmedDirectReceipt: true,
                reviewerConfirmedStructuredReusePermission: true
            )
        )

        let entry = try reviewEntry(data, tune: tune)
        let staleSaved = try SavedTune(tune: tune)
        try staleSaved.update(with: changed)
        let stalePersisted = staleSaved.tuneResult
        XCTAssertThrowsError(
            try FH6CommunityOutcomeReviewIngestor()
                .validateCurrentCandidate(
                    data,
                    displayedTune: tune,
                    persistedTune: stalePersisted
                )
        )
        XCTAssertThrowsError(
            try staleSaved
                .appendFH6CommunityOutcomeReviewEntry(
                    entry
                )
        )
        XCTAssertTrue(
            try staleSaved
                .allFH6CommunityOutcomeReviewEntries()
                .isEmpty
        )

        let unchangedSaved = try SavedTune(tune: tune)
        let unchangedPersisted = unchangedSaved.tuneResult
        XCTAssertNoThrow(
            try FH6CommunityOutcomeReviewIngestor()
                .validateCurrentCandidate(
                    data,
                    displayedTune: tune,
                    persistedTune: unchangedPersisted
                )
        )
        try unchangedSaved
            .appendFH6CommunityOutcomeReviewEntry(entry)
        XCTAssertEqual(
            try unchangedSaved
                .allFH6CommunityOutcomeReviewEntries()
                .count,
            1
        )
    }

    @MainActor
    func testFetchOnlyRootBoundaryRejectsDisplayedAndStoredDivergence()
        async throws {
        let displayedTune = try await eligibleTune()
        let data = try makeRecord(tune: displayedTune)
            .deterministicJSON()
        let reviewPreparedBeforeDivergence = try reviewEntry(
            data,
            tune: displayedTune
        )
        let directory = FileManager.default.temporaryDirectory
            .appending(
                path:
                    "forzadvisor-community-root-fetch-\(UUID().uuidString)",
                directoryHint: .isDirectory
            )
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }
        let configuration = ModelConfiguration(
            url: directory.appending(path: "store.sqlite")
        )
        let container = try ModelContainer(
            for: SavedTune.self,
            configurations: configuration
        )
        let writer = ModelContext(container)
        let stored = try SavedTune(tune: displayedTune)
        writer.insert(stored)
        try writer.save()

        var changed = displayedTune
        let index = try XCTUnwrap(
            changed.sections[0].lines.firstIndex {
                $0.fieldID == .frontTirePressure
            }
        )
        let value = try XCTUnwrap(
            Double(changed.sections[0].lines[index].value)
        )
        changed.sections[0].lines[index].value =
            String(format: "%.1f", value + 0.5)
        changed = TuneOutputProjector().project(changed)
        try stored.update(with: changed)
        try writer.save()

        let validationContext = ModelContext(container)
        let fetched = try XCTUnwrap(
            FH6CommunityOutcomeSavedTuneResolver()
                .fetch(
                    id: displayedTune.id,
                    from: validationContext
                )
        )
        XCTAssertEqual(fetched.tuneResult, changed)
        XCTAssertThrowsError(
            try FH6CommunityOutcomeReviewIngestor()
                .validateCurrentCandidate(
                    data,
                    displayedTune: displayedTune,
                    persistedTune: fetched.tuneResult
                )
        ) {
            XCTAssertEqual(
                $0 as? FH6CommunityOutcomeReviewError,
                .tuneMismatch
            )
        }

        XCTAssertThrowsError(
            try fetched.appendFH6CommunityOutcomeReviewEntry(
                reviewPreparedBeforeDivergence
            )
        )
        XCTAssertTrue(
            try fetched
                .allFH6CommunityOutcomeReviewEntries()
                .isEmpty
        )
    }

    func testCombinedEvaluatorUsesLocalPrecedenceAndAllDimensions()
        async throws {
        let tune = try await eligibleTune()
        let local = try makeRecord(
            tune: tune,
            outcome: .referencePreferred,
            symptoms: [.pushesWide],
            sourceKind: .youtube
        )
        let semanticDuplicate = try makeRecord(
            tune: tune,
            outcome: .referencePreferred,
            symptoms: [.pushesWide],
            sourceKind: .youtube,
            submissionID: UUID(),
            receiptID: UUID(),
            createdAt:
                capturedAt.addingTimeInterval(50)
        )
        XCTAssertEqual(
            local.contentFingerprint,
            semanticDuplicate.contentFingerprint
        )
        let reviewedDuplicate = try reviewEntry(
            semanticDuplicate.deterministicJSON(),
            tune: tune
        )
        let reviewedRecord = try makeRecord(
            tune: tune,
            outcome: .generatedPreferred,
            symptoms: [],
            sourceKind: .reddit,
            course: .sprint,
            surface: .wet,
            input: .wheel,
            submissionID: UUID(),
            receiptID: UUID(),
            createdAt:
                capturedAt.addingTimeInterval(100)
        )
        let reviewed = try reviewEntry(
            reviewedRecord.deterministicJSON(),
            tune: tune
        )
        let evaluator =
            FH6CommunityOutcomeCollectionEvaluator()
        let first = evaluator.evaluate(
            localRecords: [local],
            reviewedEntries: [
                reviewed,
                reviewedDuplicate
            ],
            tune: tune
        )
        let reversed = evaluator.evaluate(
            localRecords: [local],
            reviewedEntries: [
                reviewedDuplicate,
                reviewed
            ],
            tune: tune
        )

        XCTAssertEqual(first, reversed)
        XCTAssertEqual(first.receivedCount, 3)
        XCTAssertEqual(first.validLocalCount, 1)
        XCTAssertEqual(first.validReviewedCount, 1)
        XCTAssertEqual(first.verifiedUniqueSessionCount, 2)
        XCTAssertEqual(first.duplicateCount, 1)
        XCTAssertEqual(
            dictionary(
                first.localDimensions.platformCounts
            ),
            ["youtube": 1]
        )
        XCTAssertEqual(
            dictionary(
                first.localDimensions.outcomeCounts
            ),
            ["referencePreferred": 1]
        )
        XCTAssertEqual(
            dictionary(
                first.localDimensions.courseTypeCounts
            ),
            ["testTrack": 1]
        )
        XCTAssertEqual(
            dictionary(
                first.localDimensions.surfaceCounts
            ),
            ["dry": 1]
        )
        XCTAssertEqual(
            dictionary(
                first.localDimensions.inputCounts
            ),
            ["controller": 1]
        )
        XCTAssertEqual(
            dictionary(
                first.localDimensions
                    .candidateDeficiencySymptomCounts
            ),
            ["pushesWide": 1]
        )
        XCTAssertEqual(
            dictionary(
                first.reviewedDimensions.platformCounts
            ),
            ["reddit": 1]
        )
        XCTAssertEqual(
            dictionary(
                first.reviewedDimensions.outcomeCounts
            ),
            ["generatedPreferred": 1]
        )
        XCTAssertEqual(
            dictionary(
                first.reviewedDimensions.courseTypeCounts
            ),
            ["sprint": 1]
        )
        XCTAssertEqual(
            dictionary(
                first.reviewedDimensions.surfaceCounts
            ),
            ["wet": 1]
        )
        XCTAssertEqual(
            dictionary(
                first.reviewedDimensions.inputCounts
            ),
            ["wheel": 1]
        )
        XCTAssertTrue(
            first.reviewedDimensions
                .candidateDeficiencySymptomCounts.isEmpty
        )
        XCTAssertEqual(
            dictionary(
                first.combinedDimensions.platformCounts
            ),
            ["reddit": 1, "youtube": 1]
        )
        XCTAssertEqual(
            dictionary(
                first.combinedDimensions.outcomeCounts
            ),
            [
                "generatedPreferred": 1,
                "referencePreferred": 1
            ]
        )
        XCTAssertEqual(
            dictionary(
                first.combinedDimensions.courseTypeCounts
            ),
            ["sprint": 1, "testTrack": 1]
        )
        XCTAssertEqual(
            dictionary(
                first.combinedDimensions.surfaceCounts
            ),
            ["dry": 1, "wet": 1]
        )
        XCTAssertEqual(
            dictionary(
                first.combinedDimensions.inputCounts
            ),
            ["controller": 1, "wheel": 1]
        )
        XCTAssertEqual(
            dictionary(
                first.combinedDimensions
                    .candidateDeficiencySymptomCounts
            ),
            ["pushesWide": 1]
        )
    }

    func testSubmissionReceiptAndSessionReplaysQuarantine()
        async throws {
        let tune = try await eligibleTune()
        let sharedSubmission = UUID()
        let submissionA = try makeRecord(
            tune: tune,
            outcome: .generatedPreferred,
            symptoms: [],
            submissionID: sharedSubmission,
            receiptID: UUID()
        )
        let submissionB = try makeRecord(
            tune: tune,
            outcome: .noClearDifference,
            symptoms: [],
            submissionID: sharedSubmission,
            receiptID: UUID(),
            createdAt:
                capturedAt.addingTimeInterval(1)
        )
        var report = try report(
            tune: tune,
            records: [submissionA, submissionB]
        )
        XCTAssertEqual(report.conflictCount, 2)
        XCTAssertEqual(report.quarantinedCount, 2)
        XCTAssertEqual(report.verifiedUniqueSessionCount, 0)

        let sharedReceipt = UUID()
        let receiptA = try makeRecord(
            tune: tune,
            outcome: .generatedPreferred,
            symptoms: [],
            submissionID: UUID(),
            receiptID: sharedReceipt
        )
        let receiptB = try makeRecord(
            tune: tune,
            outcome: .noClearDifference,
            symptoms: [],
            submissionID: UUID(),
            receiptID: sharedReceipt,
            createdAt:
                capturedAt.addingTimeInterval(1)
        )
        report = try self.report(
            tune: tune,
            records: [receiptA, receiptB]
        )
        XCTAssertEqual(report.receiptReplayCount, 2)
        XCTAssertEqual(report.quarantinedCount, 2)

        let repeatedSessionA = try makeRecord(
            tune: tune,
            outcome: .generatedPreferred,
            symptoms: [],
            submissionID: UUID(),
            receiptID: UUID()
        )
        let repeatedSessionB = try makeRecord(
            tune: tune,
            outcome: .generatedPreferred,
            symptoms: [],
            submissionID: UUID(),
            receiptID: UUID()
        )
        XCTAssertEqual(
            repeatedSessionA.contentFingerprint,
            repeatedSessionB.contentFingerprint
        )
        let repeatedReviewed = try reviewEntry(
            repeatedSessionB.deterministicJSON(),
            tune: tune
        )
        report = FH6CommunityOutcomeCollectionEvaluator()
            .evaluate(
                localRecords: [repeatedSessionA],
                reviewedEntries: [repeatedReviewed],
                tune: tune
            )
        XCTAssertEqual(report.semanticReplayCount, 0)
        XCTAssertEqual(report.quarantinedCount, 0)
        XCTAssertEqual(report.duplicateCount, 1)
        XCTAssertEqual(report.validLocalCount, 1)
        XCTAssertEqual(report.validReviewedCount, 0)

        let exactEntry = try reviewEntry(
            repeatedSessionA.deterministicJSON(),
            tune: tune
        )
        report = FH6CommunityOutcomeCollectionEvaluator()
            .evaluate(
                localRecords: [],
                reviewedEntries: [exactEntry, exactEntry],
                tune: tune
            )
        XCTAssertEqual(report.semanticReplayCount, 0)
        XCTAssertEqual(report.quarantinedCount, 0)
        XCTAssertEqual(report.duplicateCount, 1)
        XCTAssertEqual(report.verifiedUniqueSessionCount, 1)

        let sessionA = try makeRecord(
            tune: tune,
            outcome: .generatedPreferred,
            symptoms: [],
            sourceKind: .youtube,
            submissionID: UUID(),
            receiptID: UUID()
        )
        let sessionB = try makeRecord(
            tune: tune,
            outcome: .noClearDifference,
            symptoms: [],
            sourceKind: .reddit,
            submissionID: UUID(),
            receiptID: UUID()
        )
        report = try self.report(
            tune: tune,
            records: [sessionA, sessionB]
        )
        XCTAssertEqual(report.semanticReplayCount, 2)
        XCTAssertEqual(report.quarantinedCount, 2)
    }

    @MainActor
    func testPersistenceReopenDeleteIsolationCorruptionAndNoMutation()
        async throws {
        let tune = try await eligibleTune()
        let validation = try FirstPartyValidationRecordFactory()
            .make(
                tune: tune,
                savedTune: tune,
                isStreaming: false,
                capture: validationCapture()
            )
        let record = try makeRecord(tune: tune)
        let entry = try reviewEntry(
            record.deterministicJSON(),
            tune: tune
        )
        let directory = FileManager.default
            .temporaryDirectory
            .appending(
                path:
                    "community-outcome-review-\(UUID().uuidString)",
                directoryHint: .isDirectory
            )
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let configuration = ModelConfiguration(
            url: directory.appending(path: "store.sqlite")
        )

        do {
            let container = try ModelContainer(
                for: SavedTune.self,
                configurations: configuration
            )
            let context = ModelContext(container)
            let saved = try SavedTune(
                tune: tune,
                playerNotes: "unchanged notes",
                thumbnailData:
                    Data("unchanged thumbnail".utf8)
            )
            context.insert(saved)
            try saved.appendValidationRecord(validation)
            try saved.appendFH6CommunityReferenceTrialRecord(
                record
            )
            try saved.appendFH6CommunityOutcomeReviewEntry(
                entry
            )
            try saved.appendFH6CommunityOutcomeReviewEntry(
                entry
            )
            try context.save()
        }

        do {
            let container = try ModelContainer(
                for: SavedTune.self,
                configurations: configuration
            )
            let context = ModelContext(container)
            let saved = try XCTUnwrap(
                context.fetch(
                    FetchDescriptor<SavedTune>()
                ).first
            )
            XCTAssertEqual(
                try saved
                    .allFH6CommunityOutcomeReviewEntries()
                    .count,
                1
            )
            XCTAssertEqual(saved.tuneResult, tune)
            XCTAssertEqual(
                saved.playerNotes,
                "unchanged notes"
            )
            XCTAssertEqual(
                saved.thumbnailData,
                Data("unchanged thumbnail".utf8)
            )
            XCTAssertEqual(
                saved.firstPartyValidationRecords
                    .map(\.contentFingerprint),
                [validation.contentFingerprint]
            )
            XCTAssertEqual(
                try saved
                    .fh6CommunityOutcomeCollectionReport(
                        matching: tune
                    ).validLocalCount,
                1
            )
            XCTAssertTrue(
                try saved
                    .deleteFH6CommunityOutcomeReviewEntry(
                        id: entry.id
                    )
            )
            try context.save()
        }

        do {
            let container = try ModelContainer(
                for: SavedTune.self,
                configurations: configuration
            )
            let context = ModelContext(container)
            let saved = try XCTUnwrap(
                context.fetch(
                    FetchDescriptor<SavedTune>()
                ).first
            )
            XCTAssertTrue(
                try saved
                    .allFH6CommunityOutcomeReviewEntries()
                    .isEmpty
            )
            XCTAssertEqual(saved.tuneResult, tune)
            XCTAssertEqual(
                saved.firstPartyValidationRecords
                    .map(\.contentFingerprint),
                [validation.contentFingerprint]
            )
        }
    }

    @MainActor
    func testInvalidSiblingIsQuarantinedButWholeBlobFailsClosed()
        async throws {
        let tune = try await eligibleTune()
        let valid = try reviewEntry(
            makeRecord(tune: tune).deterministicJSON(),
            tune: tune
        )
        let invalid = entryWithPermission(
            valid,
            canonicalDigest:
                String(repeating: "0", count: 64),
            id: UUID()
        )
        let second = try reviewEntry(
            makeRecord(
                tune: tune,
                outcome: .generatedPreferred,
                symptoms: [],
                submissionID: UUID(),
                receiptID: UUID(),
                createdAt:
                    capturedAt.addingTimeInterval(100)
            ).deterministicJSON(),
            tune: tune
        )
        let saved = try SavedTune(tune: tune)
        saved
            .replaceFH6CommunityOutcomeReviewEntriesDataForTesting(
                try storageData([invalid, valid])
            )
        XCTAssertEqual(
            try saved
                .allFH6CommunityOutcomeReviewEntries().count,
            2
        )
        let report = try saved
            .fh6CommunityOutcomeCollectionReport(
                matching: tune
            )
        XCTAssertEqual(report.invalidCount, 1)
        XCTAssertEqual(report.validReviewedCount, 1)
        try saved.appendFH6CommunityOutcomeReviewEntry(
            second
        )
        XCTAssertEqual(
            try saved
                .allFH6CommunityOutcomeReviewEntries().count,
            3
        )
        let afterAppend = try saved
            .fh6CommunityOutcomeCollectionReport(
                matching: tune
            )
        XCTAssertEqual(afterAppend.invalidCount, 1)
        XCTAssertEqual(afterAppend.validReviewedCount, 2)

        saved
            .replaceFH6CommunityOutcomeReviewEntriesDataForTesting(
                Data("not-json".utf8)
            )
        XCTAssertThrowsError(
            try saved
                .allFH6CommunityOutcomeReviewEntries()
        ) {
            XCTAssertEqual(
                $0 as? FH6CommunityOutcomeReviewError,
                .corruptStorage
            )
        }
        XCTAssertThrowsError(
            try saved
                .appendFH6CommunityOutcomeReviewEntry(valid)
        ) {
            XCTAssertEqual(
                $0 as? FH6CommunityOutcomeReviewError,
                .corruptStorage
            )
        }
        XCTAssertThrowsError(
            try saved
                .deleteFH6CommunityOutcomeReviewEntry(
                    id: valid.id
                )
        ) {
            XCTAssertEqual(
                $0 as? FH6CommunityOutcomeReviewError,
                .corruptStorage
            )
        }
    }

    @MainActor
    func testImportTimeRevalidationRejectsStaleRevisionAndHistoryIsScoped()
        async throws {
        let tune = try await eligibleTune()
        let record = try makeRecord(tune: tune)
        let entry = try reviewEntry(
            record.deterministicJSON(),
            tune: tune
        )
        let saved = try SavedTune(tune: tune)

        var changed = tune
        let index = try XCTUnwrap(
            changed.sections[0].lines.firstIndex {
                $0.fieldID == .frontTirePressure
            }
        )
        let value = try XCTUnwrap(
            Double(changed.sections[0].lines[index].value)
        )
        changed.sections[0].lines[index].value =
            String(format: "%.1f", value + 0.5)
        changed = TuneOutputProjector().project(changed)
        try saved.update(with: changed)

        XCTAssertThrowsError(
            try saved
                .appendFH6CommunityOutcomeReviewEntry(entry)
        ) {
            XCTAssertEqual(
                $0 as? FH6CommunityOutcomeReviewError,
                .tuneMismatch
            )
        }
        XCTAssertTrue(
            try saved
                .allFH6CommunityOutcomeReviewEntries()
                .isEmpty
        )

        try saved.update(with: tune)
        try saved.appendFH6CommunityOutcomeReviewEntry(entry)
        try saved.update(with: changed)
        XCTAssertTrue(
            try saved
                .fh6CommunityOutcomeReviewEntries(
                    matching: changed
                ).isEmpty
        )
        XCTAssertEqual(
            try saved
                .fh6CommunityOutcomeCollectionReport(
                    matching: changed
                ).verifiedUniqueSessionCount,
            0
        )
        XCTAssertEqual(
            try saved
                .allFH6CommunityOutcomeReviewEntries()
                .count,
            1
        )
    }

    private func report(
        tune: TuneResult,
        records: [FH6CommunityReferenceTrialRecord]
    ) throws -> FH6CommunityOutcomeCollectionReport {
        let entries = try records.map {
            try reviewEntry(
                $0.deterministicJSON(),
                tune: tune
            )
        }
        return FH6CommunityOutcomeCollectionEvaluator()
            .evaluate(
                localRecords: [],
                reviewedEntries: entries,
                tune: tune
            )
    }

    private func makeRecord(
        tune: TuneResult,
        outcome: FH6CommunityReferenceTrialOutcome =
            .referencePreferred,
        symptoms: Set<TuneFeedback> = [.pushesWide],
        sourceKind: FH6CommunityReferenceKind = .youtube,
        course: ValidationCourseType = .testTrack,
        surface: ValidationSurface = .dry,
        input: ValidationInput = .controller,
        submissionID: UUID = UUID(),
        receiptID: UUID = UUID(),
        createdAt: Date? = nil
    ) throws -> FH6CommunityReferenceTrialRecord {
        let url = sourceKind == .youtube
            ? "https://www.youtube.com/watch?v=abc123"
            : "https://reddit.com/r/ForzaOpenTunes/comments/abc123/a_tune"
        let sourceID = try XCTUnwrap(
            FH6CommunityReferenceTrialFactory()
                .sourceID(for: url, kind: sourceKind)
        )
        let catalogID = try XCTUnwrap(
            tune.request.car.catalogReference?.entryID
        )
        let capture = FH6CommunityReferenceTrialCapture(
            source: .init(
                kind: sourceKind,
                contentURL: url,
                publisherDisplayName: "Community Tuner",
                sourceID: sourceID,
                retrievedAt: capturedAt
            ),
            referenceCandidate: .init(
                catalogID: catalogID,
                performanceClass:
                    tune.request.car.performanceClass,
                performanceIndex:
                    tune.request.car.performanceIndex,
                confirmed: true
            ),
            context: .init(
                courseType: course,
                surface: surface,
                input: input
            ),
            runs:
                FH6CommunityReferenceTrialRecord
                    .requiredRoles.map {
                        .init(
                            role: $0,
                            completed: true,
                            correctTuneConfirmed: true
                        )
                    },
            outcome: outcome,
            candidateDeficiencySymptoms: symptoms,
            sameRouteAndConditionsConfirmed: true,
            sameAssistsAndInputConfirmed: true,
            candidateSettingsAppliedConfirmed: true,
            communityIdentityConfirmed: true,
            finalCandidateRestoredConfirmed: true,
            firstPartyAuthorshipConfirmed: true,
            localStoragePermitted: true,
            deidentifiedOutcomeReusePermitted: true
        )
        return try FH6CommunityReferenceTrialFactory().make(
            tune: tune,
            savedTune: tune,
            isStreaming: false,
            validationRecords: [
                try FirstPartyValidationRecordFactory().make(
                    tune: tune,
                    savedTune: tune,
                    isStreaming: false,
                    capture: validationCapture()
                )
            ],
            capture: capture,
            submissionID: submissionID,
            permissionReceiptID: receiptID,
            createdAt: createdAt ?? capturedAt
        )
    }

    private func reviewEntry(
        _ data: Data,
        tune: TuneResult
    ) throws -> FH6CommunityOutcomeReviewEntry {
        try FH6CommunityOutcomeReviewEntry.locallyReviewed(
            canonicalExportJSON: data,
            expectedTune: tune,
            reviewerConfirmedDirectReceipt: true,
            reviewerConfirmedStructuredReusePermission: true,
            now: capturedAt.addingTimeInterval(500)
        )
    }

    private func entryWithPermission(
        _ entry: FH6CommunityOutcomeReviewEntry,
        canonicalDigest: String,
        id: UUID? = nil
    ) -> FH6CommunityOutcomeReviewEntry {
        let permission = entry.permission
        return .init(
            id: id ?? entry.id,
            importedAt: entry.importedAt,
            canonicalExportJSON: entry.canonicalExportJSON,
            permission: .init(
                submissionID: permission.submissionID,
                permissionReceiptID:
                    permission.permissionReceiptID,
                consentVersion: permission.consentVersion,
                protocolVersion: permission.protocolVersion,
                canonicalExportDigest: canonicalDigest,
                contentFingerprint:
                    permission.contentFingerprint,
                candidateFingerprint:
                    permission.candidateFingerprint,
                directReceiptConfirmed: true,
                structuredReusePermissionConfirmed: true,
                locallyReviewedAt:
                    permission.locallyReviewedAt
            )
        )
    }

    private func eligibleTune() async throws -> TuneResult {
        let catalog = try BundledCarCatalog.load().get()
        let entry = try XCTUnwrap(
            catalog.entries.first { $0.game == .fh6 }
        )
        let selection = catalog.selection(for: entry)
        let capability =
            selection.capabilityOnlyBuildSnapshot(
                capturedAt: capturedAt
            )
        let parts = try UpgradePartCapture(
            gameBuildVersion: "test-build",
            parts: TunePartID.allCases.map {
                UpgradePartCaptureValue(
                    partID: $0,
                    status: .offered
                )
            },
            exactStockBuildConfirmed: true,
            localUsePermitted: true
        ).verifiedSnapshot(
            upgrading: capability,
            capturedAt: capturedAt
        )
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
            evidenceID: "community-outcome-review"
        )
        var tune = try await CapabilityProjectingTuneProvider(
            base: LocalSampleTuneProvider()
        ).generateTune(for: .init(
            car: exact.car,
            discipline: .road,
            buildSnapshot: exact
        ))
        tune.generatedAt = capturedAt
        return tune
    }

    private func validationCapture()
        -> FirstPartyValidationCapture {
        .init(
            courseType: .testTrack,
            surface: .dry,
            input: .controller,
            runCount: 3,
            verdict: .keep,
            feedback: [],
            exactSetupConfirmed: true,
            allExportedSettingsApplied: true,
            firstPartyAuthorshipConfirmed: true,
            deidentifiedReusePermitted: true
        )
    }

    private func compactJSON(_ data: Data) throws -> Data {
        let object = try JSONSerialization
            .jsonObject(with: data)
        return try JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys]
        )
    }

    private func inject(
        _ field: String,
        into data: Data
    ) -> Data {
        var source = String(decoding: data, as: UTF8.self)
        guard let range = source.range(of: "{\n") else {
            return data
        }
        source.replaceSubrange(
            range,
            with: "{\n  \(field)\n"
        )
        return Data(source.utf8)
    }

    private func occurrences(
        of needle: String,
        in data: Data
    ) -> Int {
        String(decoding: data, as: UTF8.self)
            .components(separatedBy: needle)
            .count - 1
    }

    private func canonicalData(
        _ export: FH6CommunityReferenceTrialExport
    ) throws -> Data {
        try FH6CommunityOutcomeReviewIngestor
            .canonicalData(for: export)
    }

    private func storageData(
        _ entries: [FH6CommunityOutcomeReviewEntry]
    ) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(entries)
    }

    private func materializeBuild43Fixture(
        at directory: URL
    ) throws {
        let bundle = Bundle(
            for: FH6CommunityOutcomeReviewTests.self
        )
        guard let fixtureURL = bundle.url(
            forResource:
                "build43-community-review-store.zlib",
            withExtension: "base64"
        ),
        let provenanceURL = bundle.url(
            forResource:
                "build43-community-review-store.provenance",
            withExtension: "json"
        ) else {
            throw Build43FixtureError.missingResource
        }
        let provenance = try JSONDecoder().decode(
            Build43FixtureProvenance.self,
            from: Data(contentsOf: provenanceURL)
        )
        guard provenance.sourceCommit
                == Self.build43SourceCommit,
              !provenance.generationProcess.isEmpty,
              Set(provenance.decodedFileSHA256.keys)
                == Self.build43FixtureKeys else {
            throw Build43FixtureError.provenanceMismatch
        }
        let fixtureText = String(
            decoding: try Data(contentsOf: fixtureURL),
            as: UTF8.self
        )
        let encoded = fixtureText.filter {
            !$0.isWhitespace
        }
        let compressed = try XCTUnwrap(
            Data(base64Encoded: encoded)
        )
        guard sha256(compressed)
                == provenance.compressedArchiveSHA256 else {
            throw Build43FixtureError.archiveHashMismatch
        }
        let json = try decompressZlib(compressed)
        let files = try JSONDecoder().decode(
            [String: String].self,
            from: json
        )
        let decodedFiles = try validatedFixtureFiles(
            files,
            expectedHashes:
                provenance.decodedFileSHA256
        )
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        for (relativePath, data) in decodedFiles {
            let destination = directory
                .appending(path: relativePath)
            try data.write(to: destination, options: .atomic)
        }
    }

    private func validatedFixtureFiles(
        _ files: [String: String],
        expectedHashes: [String: String]
    ) throws -> [String: Data] {
        for path in files.keys {
            let components = path.split(
                separator: "/",
                omittingEmptySubsequences: false
            )
            guard !path.hasPrefix("/"),
                  !components.contains(
                    where: { $0 == ".." }
                  ),
                  components.count == 1 else {
                throw Build43FixtureError.unsafePath
            }
        }
        guard Set(files.keys) == Self.build43FixtureKeys,
              Set(expectedHashes.keys)
                == Self.build43FixtureKeys else {
            throw Build43FixtureError.unexpectedKeys
        }
        var decoded: [String: Data] = [:]
        for key in Self.build43FixtureKeys {
            guard let encoded = files[key],
                  let data = Data(base64Encoded: encoded) else {
                throw Build43FixtureError.invalidBase64
            }
            guard sha256(data) == expectedHashes[key] else {
                throw Build43FixtureError.fileHashMismatch
            }
            decoded[key] = data
        }
        return decoded
    }

    private func decompressZlib(_ compressed: Data) throws -> Data {
        let capacity = max(compressed.count * 32, 1_000_000)
        var decoded = Data(count: capacity)
        let decodedCount = decoded.withUnsafeMutableBytes {
            destination in
            compressed.withUnsafeBytes { source in
                compression_decode_buffer(
                    destination.bindMemory(to: UInt8.self).baseAddress!,
                    capacity,
                    source.bindMemory(to: UInt8.self).baseAddress!,
                    compressed.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }
        guard decodedCount > 0 else {
            throw Build43FixtureError.decompressionFailed
        }
        decoded.count = decodedCount
        return decoded
    }

    private func sha256(_ data: Data) -> String {
        SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private func assertFixtureError(
        _ expected: Build43FixtureError,
        files: [String: String],
        expectedHashes: [String: String],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(
            try validatedFixtureFiles(
                files,
                expectedHashes: expectedHashes
            ),
            file: file,
            line: line
        ) {
            XCTAssertEqual(
                $0 as? Build43FixtureError,
                expected,
                file: file,
                line: line
            )
        }
    }

    private func dictionary(
        _ counts: [FH6CommunityOutcomeValueCount]
    ) -> [String: Int] {
        Dictionary(
            uniqueKeysWithValues:
                counts.map { ($0.value, $0.count) }
        )
    }
}
