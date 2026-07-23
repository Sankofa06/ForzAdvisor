//
//  FH6ValidationReviewTests.swift
//  forzadvisorTests
//
//  Fail-closed contracts for locally reviewed FH6 validation exports.
//

import SwiftData
import XCTest
@testable import forzadvisor

final class FH6ValidationReviewTests: XCTestCase {
    private let date = Date(timeIntervalSinceReferenceDate: 24_680)

    @MainActor
    func testEntryRequiresDirectReceiptAndReuseConfirmation() async throws {
        let tune = try await eligibleTune()
        let fixture = try makeFixture(tune: tune)

        XCTAssertThrowsError(try FH6ValidationReviewEntry.locallyReviewed(
            canonicalExportJSON: fixture.data,
            reviewerConfirmedDirectReceiptAndReusePermission: false,
            now: date
        )) { error in
            XCTAssertEqual(error as? FH6ValidationReviewError, .permissionNotConfirmed)
        }

        let entry = try reviewedEntry(data: fixture.data, now: date)
        XCTAssertTrue(entry.hasConsistentLocalReviewTimestamp)
        XCTAssertEqual(entry.importedAt, date)
        XCTAssertEqual(entry.permission.locallyReviewedAt, date)
        XCTAssertEqual(
            FH6ValidationReviewEvaluator().evaluate([entry])
                .verifiedUniqueSessionCount,
            1
        )

        var reuseDenied = fixture.record.publicExport
        reuseDenied.deidentifiedReusePermitted = false
        reuseDenied.contentFingerprint =
            try FH6ValidationReviewIngestor.contentFingerprint(for: reuseDenied)
        let reuseDeniedData =
            try FH6ValidationReviewIngestor.canonicalData(for: reuseDenied)
        XCTAssertThrowsError(try FH6ValidationReviewEntry.locallyReviewed(
            canonicalExportJSON: reuseDeniedData,
            reviewerConfirmedDirectReceiptAndReusePermission: true,
            now: date
        )) { error in
            XCTAssertEqual(error as? FH6ValidationReviewError, .invalidStructure)
        }

        let inconsistent = FH6ValidationReviewEntry(
            importedAt: date.addingTimeInterval(1),
            canonicalExportJSON: fixture.data,
            permission: entry.permission
        )
        let saved = try SavedTune(tune: tune)
        XCTAssertThrowsError(
            try saved.appendFH6ValidationReviewEntry(inconsistent)
        ) { error in
            XCTAssertEqual(
                error as? FH6ValidationReviewError,
                .permissionNotConfirmed
            )
        }
    }

    @MainActor
    func testValidatedExportMatchesExactCurrentSavedAndProjectedTuneOnly() async throws {
        let tune = try await eligibleTune()
        let fixture = try makeFixture(tune: tune)
        let ingestor = FH6ValidationReviewIngestor()
        let validated = try ingestor.validate(fixture.data)

        XCTAssertTrue(ingestor.matchesSavedTune(validated, tune: tune))
        XCTAssertTrue(ingestor.matchesSavedTune(
            validated,
            tune: TuneOutputProjector().project(tune)
        ))

        var administrativeRewrite = tune
        administrativeRewrite.id = UUID()
        administrativeRewrite.generatedAt =
            administrativeRewrite.generatedAt.addingTimeInterval(300)
        XCTAssertTrue(ingestor.matchesSavedTune(
            validated,
            tune: administrativeRewrite
        ))

        var differentDiscipline = tune
        differentDiscipline.request.discipline = .dirt
        XCTAssertFalse(ingestor.matchesSavedTune(
            validated,
            tune: differentDiscipline
        ))

        var differentRuleset = tune
        let ruleset = try XCTUnwrap(tune.rulesetReference)
        differentRuleset.rulesetReference = try XCTUnwrap(TuneRulesetReference(
            descriptor: TuneRulesetDescriptor(
                id: ruleset.id,
                game: ruleset.game,
                schemaVersion: ruleset.schemaVersion,
                algorithmVersion: ruleset.algorithmVersion,
                knowledgeRevision: "different-knowledge-revision",
                validationStatus: ruleset.validationStatus,
                provenanceIDs: ruleset.provenanceIDs
            )
        ))
        XCTAssertFalse(ingestor.matchesSavedTune(
            validated,
            tune: differentRuleset
        ))

        let saved = try SavedTune(tune: tune)
        let entry = try reviewedEntry(data: fixture.data)
        try saved.appendFH6ValidationReviewEntry(entry)
        XCTAssertEqual(
            try saved.fh6ValidationReviewEntries(matching: tune),
            [entry]
        )
        XCTAssertTrue(
            try saved.fh6ValidationReviewEntries(
                matching: differentDiscipline
            ).isEmpty
        )
    }

    func testCrossDeviceIdentityIgnoresBuildCaptureTimeButBindsExactBuildAndSettings()
        async throws {
        let tune = try await eligibleTune()
        let fixture = try makeFixture(tune: tune)
        let ingestor = FH6ValidationReviewIngestor()
        let original = try ingestor.validate(fixture.data)

        var laterCapture = fixture.record.publicExport
        laterCapture.submissionID = UUID()
        laterCapture.permissionReceiptID = UUID()
        laterCapture.buildCapturedAt =
            laterCapture.buildCapturedAt.addingTimeInterval(86_400)
        let laterCaptureFixture = try rehashed(laterCapture)
        let laterCaptureValidated =
            try ingestor.validate(laterCaptureFixture.data)
        XCTAssertTrue(ingestor.matchesSavedTune(
            laterCaptureValidated,
            tune: tune
        ))
        XCTAssertEqual(
            laterCaptureValidated.testedTuneFingerprint,
            original.testedTuneFingerprint
        )
        let sameBuildEntries = [
            try reviewedEntry(data: fixture.data),
            try reviewedEntry(data: laterCaptureFixture.data)
        ]
        let sameBuildReport =
            FH6ValidationReviewEvaluator().evaluate(sameBuildEntries)
        XCTAssertEqual(
            sameBuildReport,
            FH6ValidationReviewEvaluator()
                .evaluate(Array(sameBuildEntries.reversed()))
        )
        XCTAssertEqual(sameBuildReport.verifiedUniqueSessionCount, 2)
        XCTAssertEqual(sameBuildReport.groups.count, 1)
        XCTAssertEqual(sameBuildReport.groups.first?.sessionCount, 2)
        XCTAssertEqual(
            sameBuildReport.groups.first?.associationContext.buildCapturedAt,
            fixture.record.publicExport.buildCapturedAt
        )

        var differentBuild = laterCaptureFixture.export
        differentBuild.submissionID = UUID()
        differentBuild.permissionReceiptID = UUID()
        differentBuild.gameBuildVersion = "different-build"
        let differentBuildFixture = try rehashed(differentBuild)
        let differentBuildValidated =
            try ingestor.validate(differentBuildFixture.data)
        XCTAssertFalse(ingestor.matchesSavedTune(
            differentBuildValidated,
            tune: tune
        ))
        XCTAssertNotEqual(
            differentBuildValidated.testedTuneFingerprint,
            original.testedTuneFingerprint
        )

        var differentParts = laterCaptureFixture.export
        differentParts.submissionID = UUID()
        differentParts.permissionReceiptID = UUID()
        differentParts.shopParts[0].availability =
            differentParts.shopParts[0].availability == .available
                ? .unavailable
                : .available
        let differentPartsFixture = try rehashed(differentParts)
        let differentPartsValidated =
            try ingestor.validate(differentPartsFixture.data)
        XCTAssertFalse(ingestor.matchesSavedTune(
            differentPartsValidated,
            tune: tune
        ))
        XCTAssertNotEqual(
            differentPartsValidated.testedTuneFingerprint,
            original.testedTuneFingerprint
        )

        var differentFields = laterCaptureFixture.export
        differentFields.submissionID = UUID()
        differentFields.permissionReceiptID = UUID()
        differentFields.appliedFields[0].value += 0.5
        let differentFieldsFixture = try rehashed(differentFields)
        let differentFieldsValidated =
            try ingestor.validate(differentFieldsFixture.data)
        XCTAssertFalse(ingestor.matchesSavedTune(
            differentFieldsValidated,
            tune: tune
        ))
        XCTAssertNotEqual(
            differentFieldsValidated.testedTuneFingerprint,
            original.testedTuneFingerprint
        )

        let mixedReport = FH6ValidationReviewEvaluator().evaluate([
            try reviewedEntry(data: fixture.data),
            try reviewedEntry(data: laterCaptureFixture.data),
            try reviewedEntry(data: differentBuildFixture.data),
            try reviewedEntry(data: differentPartsFixture.data),
            try reviewedEntry(data: differentFieldsFixture.data)
        ])
        XCTAssertEqual(mixedReport.groups.count, 4)
    }

    func testProductionIngestorRejectsFH5EvenWithRecomputedFingerprint() async throws {
        let tune = try await eligibleTune()
        let fixture = try makeFixture(tune: tune)
        var fh5 = fixture.record.publicExport
        fh5.game = .fh5
        fh5.contentFingerprint =
            try FH6ValidationReviewIngestor.contentFingerprint(for: fh5)

        XCTAssertThrowsError(try FH6ValidationReviewIngestor().validate(
            FH6ValidationReviewIngestor.canonicalData(for: fh5)
        )) { error in
            XCTAssertEqual(error as? FH6ValidationReviewError, .invalidStructure)
        }
    }

    func testProductionIngestorRejectsAdversarialPayloadsAndStaleContracts()
        async throws {
        let tune = try await eligibleTune()
        let fixture = try makeFixture(tune: tune)
        let ingestor = FH6ValidationReviewIngestor()

        let oversized = Data(
            repeating: 0x20,
            count: FH6ValidationReviewIngestor.maximumPayloadBytes + 1
        )
        XCTAssertThrowsError(try ingestor.validate(oversized)) { error in
            XCTAssertEqual(error as? FH6ValidationReviewError, .payloadTooLarge)
        }

        XCTAssertThrowsError(try ingestor.validate(insertingTopLevel(
            "\"unknownReviewField\" : true",
            into: fixture.data
        ))) { error in
            XCTAssertEqual(error as? FH6ValidationReviewError, .nonCanonicalJSON)
        }

        var badShopHash = fixture.record.publicExport
        badShopHash.shopAvailabilityFingerprint = String(repeating: "0", count: 64)
        badShopHash.contentFingerprint =
            try FH6ValidationReviewIngestor.contentFingerprint(for: badShopHash)
        XCTAssertThrowsError(try ingestor.validate(
            FH6ValidationReviewIngestor.canonicalData(for: badShopHash)
        )) { error in
            XCTAssertEqual(
                error as? FH6ValidationReviewError,
                .invalidShopAvailabilityFingerprint
            )
        }

        var badContentHash = fixture.record.publicExport
        badContentHash.contentFingerprint = String(repeating: "f", count: 64)
        XCTAssertThrowsError(try ingestor.validate(
            FH6ValidationReviewIngestor.canonicalData(for: badContentHash)
        )) { error in
            XCTAssertEqual(
                error as? FH6ValidationReviewError,
                .invalidContentFingerprint
            )
        }

        var staleSchema = fixture.record.publicExport
        staleSchema.schemaVersion += 1
        XCTAssertThrowsError(try ingestor.validate(
            FH6ValidationReviewIngestor.canonicalData(for: staleSchema)
        )) { error in
            XCTAssertEqual(error as? FH6ValidationReviewError, .invalidStructure)
        }

        var staleConsent = fixture.record.publicExport
        staleConsent.consentVersion = "first-party-validation-stale"
        XCTAssertThrowsError(try ingestor.validate(
            FH6ValidationReviewIngestor.canonicalData(for: staleConsent)
        )) { error in
            XCTAssertEqual(error as? FH6ValidationReviewError, .invalidStructure)
        }

        var staleRuleset = fixture.record.publicExport
        staleRuleset.ruleset.knowledgeRevision = "stale-knowledge-revision"
        staleRuleset.contentFingerprint =
            try FH6ValidationReviewIngestor.contentFingerprint(for: staleRuleset)
        XCTAssertThrowsError(try ingestor.validate(
            FH6ValidationReviewIngestor.canonicalData(for: staleRuleset)
        )) { error in
            XCTAssertEqual(error as? FH6ValidationReviewError, .invalidStructure)
        }
    }

    @MainActor
    func testLocalEvidenceTrustCannotBeHiddenBehindIdenticalPublicSetup()
        async throws {
        let tune = try await eligibleTune()
        let fixture = try makeFixture(tune: tune)
        let entry = try reviewedEntry(data: fixture.data)
        let validated = try FH6ValidationReviewIngestor().validate(fixture.data)
        XCTAssertTrue(
            FH6ValidationReviewIngestor().matchesSavedTune(
                validated,
                tune: tune
            )
        )

        var changedSource = tune
        changedSource.request.buildSnapshot?
            .capabilityProfile.parts[0].evidence.source =
                "local.untrusted-upgrade-source"
        XCTAssertEqual(changedSource.sections, tune.sections)
        XCTAssertEqual(changedSource.rulesetReference, tune.rulesetReference)
        XCTAssertEqual(changedSource.projectionReport, tune.projectionReport)

        var prohibitedPermission = tune
        prohibitedPermission.request.buildSnapshot?
            .capabilityProfile.parts[0].evidence.usagePermission = .prohibited
        XCTAssertEqual(prohibitedPermission.sections, tune.sections)
        XCTAssertEqual(prohibitedPermission.rulesetReference, tune.rulesetReference)
        XCTAssertEqual(prohibitedPermission.projectionReport, tune.projectionReport)

        var lowConfidence = tune
        lowConfidence.request.buildSnapshot?
            .capabilityProfile.parts[0].evidence.confidence = .low
        XCTAssertEqual(lowConfidence.sections, tune.sections)
        XCTAssertEqual(lowConfidence.rulesetReference, tune.rulesetReference)
        XCTAssertEqual(lowConfidence.projectionReport, tune.projectionReport)

        for localTune in [changedSource, prohibitedPermission, lowConfidence] {
            XCTAssertFalse(FH6ValidationReviewIngestor().matchesSavedTune(
                validated,
                tune: localTune
            ))
            let saved = try SavedTune(tune: localTune)
            let original = try XCTUnwrap(saved.tuneResult)
            XCTAssertThrowsError(
                try saved.appendFH6ValidationReviewEntry(entry)
            ) { error in
                XCTAssertEqual(error as? FH6ValidationReviewError, .tuneMismatch)
            }
            XCTAssertEqual(saved.tuneResult, original)
        }
    }

    func testEvaluatorDedupeOrderAndOutcomeDistributionsAreDeterministic() async throws {
        let tune = try await eligibleTune()
        let duplicateA = try makeFixture(
            tune: tune,
            capture: capture(
                verdict: .adjust,
                feedback: [.pushesWide]
            ),
            createdAt: date
        )
        let duplicateB = try makeFixture(
            tune: tune,
            capture: capture(
                verdict: .adjust,
                feedback: [.pushesWide]
            ),
            createdAt: date.addingTimeInterval(60)
        )
        XCTAssertEqual(
            duplicateA.record.contentFingerprint,
            duplicateB.record.contentFingerprint
        )
        XCTAssertNotEqual(duplicateA.data, duplicateB.data)

        let duplicateEntries = [
            try reviewedEntry(data: duplicateA.data, now: date),
            try reviewedEntry(
                data: duplicateB.data,
                now: date.addingTimeInterval(60)
            )
        ]
        let duplicateForward =
            FH6ValidationReviewEvaluator().evaluate(duplicateEntries)
        let duplicateReversed = FH6ValidationReviewEvaluator()
            .evaluate(Array(duplicateEntries.reversed()))
        XCTAssertEqual(duplicateForward, duplicateReversed)
        XCTAssertEqual(duplicateForward.receivedCount, 2)
        XCTAssertEqual(duplicateForward.verifiedUniqueSessionCount, 1)
        XCTAssertEqual(duplicateForward.duplicateCount, 1)
        XCTAssertEqual(duplicateForward.groups.first?.sessionCount, 1)

        let kept = try makeFixture(
            tune: tune,
            capture: capture(
                courseType: .streetRace,
                surface: .wet,
                input: .wheel,
                verdict: .keep,
                feedback: []
            ),
            createdAt: date.addingTimeInterval(120)
        )
        let rejected = try makeFixture(
            tune: tune,
            capture: capture(
                courseType: .sprint,
                surface: .mixed,
                input: .keyboard,
                verdict: .reject,
                feedback: [.pushesWide, .snapsOnLift]
            ),
            createdAt: date.addingTimeInterval(180)
        )
        let aggregateEntries = [
            duplicateEntries[0],
            try reviewedEntry(
                data: kept.data,
                now: date.addingTimeInterval(120)
            ),
            try reviewedEntry(
                data: rejected.data,
                now: date.addingTimeInterval(180)
            )
        ]
        let aggregate = FH6ValidationReviewEvaluator().evaluate(aggregateEntries)
        let reversed = FH6ValidationReviewEvaluator()
            .evaluate(Array(aggregateEntries.reversed()))
        XCTAssertEqual(aggregate, reversed)
        XCTAssertEqual(aggregate.groups.count, 1)
        let group = try XCTUnwrap(aggregate.groups.first)
        XCTAssertEqual(group.sessionCount, 3)
        XCTAssertEqual(group.keepCount, 1)
        XCTAssertEqual(group.adjustCount, 1)
        XCTAssertEqual(group.rejectCount, 1)
        XCTAssertEqual(group.acceptanceRate, 1.0 / 3.0, accuracy: 0.000_1)
        XCTAssertEqual(group.handlingSymptomCounts, [
            .init(value: TuneFeedback.pushesWide.rawValue, count: 2),
            .init(value: TuneFeedback.snapsOnLift.rawValue, count: 1)
        ])
        XCTAssertEqual(group.courseTypeCounts, [
            .init(value: ValidationCourseType.sprint.rawValue, count: 1),
            .init(value: ValidationCourseType.streetRace.rawValue, count: 1),
            .init(value: ValidationCourseType.testTrack.rawValue, count: 1)
        ])
        XCTAssertEqual(group.surfaceCounts, [
            .init(value: ValidationSurface.dry.rawValue, count: 1),
            .init(value: ValidationSurface.mixed.rawValue, count: 1),
            .init(value: ValidationSurface.wet.rawValue, count: 1)
        ])
        XCTAssertEqual(group.inputCounts, [
            .init(value: ValidationInput.controller.rawValue, count: 1),
            .init(value: ValidationInput.keyboard.rawValue, count: 1),
            .init(value: ValidationInput.wheel.rawValue, count: 1)
        ])

        let summary = aggregate.sessionSummary.lowercased()
        XCTAssertFalse(summary.contains("accuracy score"))
        XCTAssertFalse(summary.contains("community consensus"))
        XCTAssertFalse(summary.contains("reference target"))
    }

    func testSubmissionConflictAndReceiptReplayAreQuarantinedBeforeAggregation()
        async throws {
        let tune = try await eligibleTune()
        let sharedSubmission = UUID()
        let conflictA = try makeFixture(
            tune: tune,
            capture: capture(verdict: .adjust, feedback: [.pushesWide]),
            submissionID: sharedSubmission,
            permissionReceiptID: UUID(),
            createdAt: date
        )
        let conflictB = try makeFixture(
            tune: tune,
            capture: capture(
                surface: .wet,
                verdict: .reject,
                feedback: [.snapsOnLift]
            ),
            submissionID: sharedSubmission,
            permissionReceiptID: UUID(),
            createdAt: date.addingTimeInterval(60)
        )
        let conflictEntries = [
            try reviewedEntry(data: conflictA.data),
            try reviewedEntry(data: conflictB.data)
        ]
        let conflictForward =
            FH6ValidationReviewEvaluator().evaluate(conflictEntries)
        XCTAssertEqual(
            conflictForward,
            FH6ValidationReviewEvaluator()
                .evaluate(Array(conflictEntries.reversed()))
        )
        XCTAssertEqual(conflictForward.conflictCount, 2)
        XCTAssertEqual(conflictForward.receiptReplayCount, 0)
        XCTAssertEqual(conflictForward.verifiedUniqueSessionCount, 0)
        XCTAssertTrue(conflictForward.groups.isEmpty)

        let sharedReceipt = UUID()
        let replayA = try makeFixture(
            tune: tune,
            capture: capture(verdict: .adjust, feedback: [.pushesWide]),
            submissionID: UUID(),
            permissionReceiptID: sharedReceipt,
            createdAt: date
        )
        let replayB = try makeFixture(
            tune: tune,
            capture: capture(
                surface: .mixed,
                verdict: .reject,
                feedback: [.snapsOnLift]
            ),
            submissionID: UUID(),
            permissionReceiptID: sharedReceipt,
            createdAt: date.addingTimeInterval(60)
        )
        let replayEntries = [
            try reviewedEntry(data: replayA.data),
            try reviewedEntry(data: replayB.data)
        ]
        let replayForward = FH6ValidationReviewEvaluator().evaluate(replayEntries)
        XCTAssertEqual(
            replayForward,
            FH6ValidationReviewEvaluator()
                .evaluate(Array(replayEntries.reversed()))
        )
        XCTAssertEqual(replayForward.conflictCount, 2)
        XCTAssertEqual(replayForward.receiptReplayCount, 2)
        XCTAssertEqual(replayForward.verifiedUniqueSessionCount, 0)
        XCTAssertTrue(replayForward.groups.isEmpty)
    }

    @MainActor
    func testSeparatePersistenceReopenDeleteDedupeAndCorruptIsolation() async throws {
        let tune = try await eligibleTune()
        let fixture = try makeFixture(tune: tune)
        let entry = try reviewedEntry(data: fixture.data, now: date)
        let directory = FileManager.default.temporaryDirectory
            .appending(
                path: "forzadvisor-fh6-validation-review-\(UUID().uuidString)",
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

        do {
            let container = try ModelContainer(
                for: SavedTune.self,
                configurations: configuration
            )
            let context = ModelContext(container)
            let saved = try SavedTune(tune: tune)
            context.insert(saved)
            try saved.appendValidationRecord(fixture.record)
            try saved.appendFH6ValidationReviewEntry(entry)
            try saved.appendFH6ValidationReviewEntry(entry)
            try context.save()
            XCTAssertEqual(
                try saved.fh6ValidationReviewEntries(matching: tune),
                [entry]
            )
            XCTAssertEqual(saved.firstPartyValidationRecords, [fixture.record])
        }

        do {
            let container = try ModelContainer(
                for: SavedTune.self,
                configurations: configuration
            )
            let context = ModelContext(container)
            let saved = try XCTUnwrap(
                context.fetch(FetchDescriptor<SavedTune>()).first
            )
            let originalTune = try XCTUnwrap(saved.tuneResult)
            XCTAssertEqual(
                try saved.fh6ValidationReviewEntries(matching: tune),
                [entry]
            )
            XCTAssertEqual(
                try saved.fh6ValidationReviewReport(matching: tune)
                    .verifiedUniqueSessionCount,
                1
            )
            XCTAssertEqual(saved.firstPartyValidationRecords, [fixture.record])
            XCTAssertEqual(saved.tuneResult, originalTune)

            XCTAssertTrue(try saved.deleteFH6ValidationReviewEntry(id: entry.id))
            XCTAssertFalse(try saved.deleteFH6ValidationReviewEntry(id: entry.id))
            XCTAssertTrue(
                try saved.fh6ValidationReviewEntries(matching: tune).isEmpty
            )
            XCTAssertEqual(saved.firstPartyValidationRecords, [fixture.record])
            XCTAssertEqual(saved.tuneResult, originalTune)

            saved.replaceFH6ValidationReviewEntriesDataForTesting(
                Data("corrupt-review-blob".utf8)
            )
            XCTAssertThrowsError(
                try saved.fh6ValidationReviewEntries(matching: tune)
            ) { error in
                XCTAssertEqual(
                    error as? FH6ValidationReviewError,
                    .corruptStorage
                )
            }
            XCTAssertThrowsError(
                try saved.appendFH6ValidationReviewEntry(entry)
            ) { error in
                XCTAssertEqual(
                    error as? FH6ValidationReviewError,
                    .corruptStorage
                )
            }
            XCTAssertThrowsError(
                try saved.deleteFH6ValidationReviewEntry(id: entry.id)
            ) { error in
                XCTAssertEqual(
                    error as? FH6ValidationReviewError,
                    .corruptStorage
                )
            }
            XCTAssertEqual(saved.firstPartyValidationRecords, [fixture.record])
            XCTAssertEqual(saved.tuneResult, originalTune)
        }
    }

    @MainActor
    func testImportReportAndDeleteNeverMutateTuneRulesetProjectionOrSnapshot()
        async throws {
        let tune = try await eligibleTune()
        let fixture = try makeFixture(tune: tune)
        let entry = try reviewedEntry(data: fixture.data)
        let saved = try SavedTune(tune: tune)
        let original = try XCTUnwrap(saved.tuneResult)
        let originalRuleset = original.rulesetReference
        let originalProjection = original.projectionReport
        let originalSnapshot = original.request.buildSnapshot
        let originalProvider = original.providerInfo

        try saved.appendFH6ValidationReviewEntry(entry)
        let report = try saved.fh6ValidationReviewReport(matching: tune)
        XCTAssertEqual(report.verifiedUniqueSessionCount, 1)
        XCTAssertEqual(saved.tuneResult, original)
        XCTAssertEqual(saved.tuneResult?.rulesetReference, originalRuleset)
        XCTAssertEqual(saved.tuneResult?.projectionReport, originalProjection)
        XCTAssertEqual(saved.tuneResult?.request.buildSnapshot, originalSnapshot)
        XCTAssertEqual(saved.tuneResult?.providerInfo, originalProvider)

        XCTAssertTrue(try saved.deleteFH6ValidationReviewEntry(id: entry.id))
        XCTAssertEqual(saved.tuneResult, original)
        XCTAssertEqual(saved.tuneResult?.rulesetReference, originalRuleset)
        XCTAssertEqual(saved.tuneResult?.projectionReport, originalProjection)
        XCTAssertEqual(saved.tuneResult?.request.buildSnapshot, originalSnapshot)
        XCTAssertEqual(saved.tuneResult?.providerInfo, originalProvider)
    }

    private func eligibleTune() async throws -> TuneResult {
        let catalog = try BundledCarCatalog.load().get()
        let entry = try XCTUnwrap(catalog.entries.first { $0.game == .fh6 })
        let selection = catalog.selection(for: entry)
        let capability = selection.capabilityOnlyBuildSnapshot(capturedAt: date)
        let parts = try UpgradePartCapture(
            gameBuildVersion: "test-build",
            parts: TunePartID.allCases.map {
                UpgradePartCaptureValue(partID: $0, status: .offered)
            },
            exactStockBuildConfirmed: true,
            localUsePermitted: true
        ).verifiedSnapshot(upgrading: capability, capturedAt: date)
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
            capturedAt: date,
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
        tune.generatedAt = date
        return tune
    }

    private func makeFixture(
        tune: TuneResult,
        capture: FirstPartyValidationCapture? = nil,
        recordID: UUID = UUID(),
        submissionID: UUID = UUID(),
        permissionReceiptID: UUID = UUID(),
        createdAt: Date? = nil
    ) throws -> (record: FirstPartyValidationRecord, data: Data) {
        let record = try FirstPartyValidationRecordFactory().make(
            tune: tune,
            savedTune: tune,
            isStreaming: false,
            capture: capture ?? self.capture(
                verdict: .adjust,
                feedback: [.pushesWide]
            ),
            recordID: recordID,
            submissionID: submissionID,
            permissionReceiptID: permissionReceiptID,
            createdAt: createdAt ?? date
        )
        return (record, try record.deterministicJSON())
    }

    private func reviewedEntry(
        data: Data,
        id: UUID = UUID(),
        now: Date? = nil
    ) throws -> FH6ValidationReviewEntry {
        try FH6ValidationReviewEntry.locallyReviewed(
            canonicalExportJSON: data,
            reviewerConfirmedDirectReceiptAndReusePermission: true,
            id: id,
            now: now ?? date
        )
    }

    private func rehashed(
        _ export: FirstPartyValidationExport
    ) throws -> (export: FirstPartyValidationExport, data: Data) {
        var export = export
        export.shopAvailabilityFingerprint =
            try FH6ValidationReviewIngestor.shopAvailabilityFingerprint(
                for: export.shopParts
            )
        export.contentFingerprint =
            try FH6ValidationReviewIngestor.contentFingerprint(for: export)
        return (
            export,
            try FH6ValidationReviewIngestor.canonicalData(for: export)
        )
    }

    private func insertingTopLevel(_ member: String, into data: Data) -> Data {
        let json = String(decoding: data, as: UTF8.self)
        precondition(json.first == "{")
        return Data(("{\n  \(member)," + json.dropFirst()).utf8)
    }

    private func capture(
        courseType: ValidationCourseType = .testTrack,
        surface: ValidationSurface = .dry,
        input: ValidationInput = .controller,
        verdict: ValidationVerdict,
        feedback: Set<TuneFeedback>
    ) -> FirstPartyValidationCapture {
        FirstPartyValidationCapture(
            courseType: courseType,
            surface: surface,
            input: input,
            runCount: 3,
            verdict: verdict,
            feedback: feedback,
            exactSetupConfirmed: true,
            allExportedSettingsApplied: true,
            firstPartyAuthorshipConfirmed: true,
            deidentifiedReusePermitted: true
        )
    }
}
