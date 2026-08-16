import SwiftData
import XCTest
@testable import forzadvisor

final class FH5CandidateOutcomePersistenceTests: FH5ResearchTestCase {
    func testCandidateOutcomeReportIgnoresUnrelatedHistoricalAssociation()
        async throws {
        let sharedSubmissionID = UUID()
        let sharedReceiptID = UUID()
        let current = try await makeCandidateOutcomeFixture(
            reusePermitted: true,
            submissionID: sharedSubmissionID,
            permissionReceiptID: sharedReceiptID,
            createdAt: capturedAt
        )
        let historical = try await makeCandidateOutcomeFixture(
            reusePermitted: true,
            submissionID: sharedSubmissionID,
            permissionReceiptID: sharedReceiptID,
            createdAt: capturedAt,
            fh5EntryOffset: 1
        )
        let exchange = FH5CandidateOutcomeExchange()
        let currentAssociation = try exchange
            .associationFingerprint(for: current.artifact)
        XCTAssertNotEqual(
            currentAssociation,
            try exchange.associationFingerprint(
                for: historical.artifact
            )
        )
        let baseline = FH5CandidateOutcomeCollectionEvaluator()
            .evaluate(
                localRecords: [current.record],
                reviewedEntries: [],
                matchingAssociationFingerprint: currentAssociation
            )
        let historicalData = try exchange.makeExport(
            from: historical.record,
            explicitShareConfirmed: true
        ).deterministicJSON()
        let historicalEntry =
            try FH5CandidateOutcomeReviewEntry.locallyReviewed(
                canonicalExportJSON: historicalData,
                expectedArtifact: historical.artifact,
                reviewerConfirmedDirectReceiptAndReusePermission:
                    true,
                now: capturedAt
            )
        let withHistory =
            FH5CandidateOutcomeCollectionEvaluator().evaluate(
                localRecords: [
                    current.record, historical.record
                ],
                reviewedEntries: [historicalEntry],
                matchingAssociationFingerprint: currentAssociation
            )

        XCTAssertEqual(baseline.receivedCount, 1)
        XCTAssertEqual(baseline.verifiedUniqueSessionCount, 1)
        XCTAssertEqual(withHistory, baseline)
        XCTAssertEqual(withHistory.conflictCount, 0)
        XCTAssertEqual(withHistory.receiptReplayCount, 0)
        XCTAssertEqual(withHistory.semanticReplayCount, 0)
        XCTAssertEqual(withHistory.quarantinedCount, 0)
    }
    func testSavedTuneCandidateOutcomeReviewQueueIsScopedDeletableAndFailClosed()
        async throws {
        let fixture = try await makeCandidateOutcomeFixture(
            reusePermitted: true
        )
        let data = try FH5CandidateOutcomeExchange()
            .makeExport(
                from: fixture.record,
                explicitShareConfirmed: true
            ).deterministicJSON()
        let entry = try FH5CandidateOutcomeReviewEntry
            .locallyReviewed(
                canonicalExportJSON: data,
                expectedArtifact: fixture.artifact,
                reviewerConfirmedDirectReceiptAndReusePermission:
                    true,
                now: capturedAt
            )
        let configuration = ModelConfiguration(
            isStoredInMemoryOnly: true
        )
        let container = try ModelContainer(
            for: SavedTune.self,
            configurations: configuration
        )
        let context = ModelContext(container)
        let saved = try SavedTune(tune: fixture.plan)
        context.insert(saved)
        try persistCandidatePrerequisites(
            fixture: fixture,
            in: saved
        )

        XCTAssertTrue(
            saved.fh5CandidateOutcomeReviewEntries.isEmpty
        )
        try saved.appendFH5CandidateOutcomeReviewEntry(entry)
        try saved.appendFH5CandidateOutcomeReviewEntry(entry)
        XCTAssertEqual(
            try saved.fh5CandidateOutcomeReviewEntries(
                matching: fixture.artifact
            ),
            [entry]
        )
        XCTAssertEqual(
            try saved.fh5CandidateOutcomeCollectionReport(
                matching: fixture.artifact
            ).verifiedUniqueSessionCount,
            1
        )
        XCTAssertEqual(
            try saved.allFH5CandidateOutcomeReviewEntries(),
            [entry]
        )
        let historicalArtifact = try FH5CandidateTrialCoordinator()
            .generate(
                tune: fixture.plan,
                savedTune: fixture.plan,
                isStreaming: false,
                researchRecords: [fixture.research],
                reviewInputs: fixture.reviewInputs,
                input: .wheel,
                surface: .dry
            )
        XCTAssertTrue(
            try saved.fh5CandidateOutcomeReviewEntries(
                matching: historicalArtifact
            ).isEmpty
        )
        XCTAssertEqual(
            try saved.allFH5CandidateOutcomeReviewEntries(),
            [entry]
        )
        let readiness = FH5NumericReadinessPolicy().assess(
            tune: fixture.plan,
            researchRecords: [fixture.research],
            reviewReport: .empty,
            controlledOutcomeReport: .empty
        )
        XCTAssertFalse(readiness.canGenerateNumeric)
        XCTAssertEqual(
            readiness.items.first {
                $0.gate == .controlledOutcomes
            }?.state,
            .blocked
        )
        let projected = TuneOutputProjector().project(
            fixture.plan
        )
        XCTAssertEqual(projected.purpose, .fh5BuildPlan)
        XCTAssertTrue(projected.sections.isEmpty)
        XCTAssertNil(projected.providerInfo)
        XCTAssertNil(projected.rulesetReference)
        XCTAssertNil(
            TuneClipboardFormatter.verifiedSettingsText(
                for: projected
            )
        )
        XCTAssertTrue(
            try saved.deleteFH5CandidateOutcomeReviewEntry(
                id: entry.id
            )
        )
        XCTAssertTrue(
            saved.fh5CandidateOutcomeReviewEntries.isEmpty
        )

        saved.replaceFH5CandidateOutcomeReviewEntriesDataForTesting(
            Data("corrupt candidate review".utf8)
        )
        XCTAssertTrue(
            saved.fh5CandidateOutcomeReviewEntries.isEmpty
        )
        XCTAssertThrowsError(
            try saved.fh5CandidateOutcomeReviewEntries(
                matching: fixture.artifact
            )
        ) {
            XCTAssertEqual(
                $0 as? FH5CandidateOutcomeExchangeError,
                .corruptStorage
            )
        }
        XCTAssertEqual(
            saved.tuneResult?.id,
            fixture.plan.id
        )
        XCTAssertEqual(
            saved.tuneResult?.request,
            fixture.plan.request
        )
        XCTAssertTrue(saved.tuneResult?.sections.isEmpty == true)
        XCTAssertNil(saved.tuneResult?.providerInfo)
        XCTAssertNil(saved.tuneResult?.rulesetReference)
        XCTAssertTrue(
            FH5TrustedNumericRulesetRegistry.production.isEmpty
        )
    }
    func testSavedTuneCandidateOutcomeImportRegeneratesFromPersistedEvidence()
        async throws {
        let fixture = try await makeCandidateOutcomeFixture(
            reusePermitted: true
        )
        let data = try FH5CandidateOutcomeExchange()
            .makeExport(
                from: fixture.record,
                explicitShareConfirmed: true
            ).deterministicJSON()
        let entry = try FH5CandidateOutcomeReviewEntry
            .locallyReviewed(
                canonicalExportJSON: data,
                expectedArtifact: fixture.artifact,
                reviewerConfirmedDirectReceiptAndReusePermission:
                    true,
                now: capturedAt
            )
        let staleResearch = try SavedTune(tune: fixture.plan)
        try persistCandidatePrerequisites(
            fixture: fixture,
            in: staleResearch
        )
        staleResearch
            .replaceFH5ResearchObservationRecordsDataForTesting(nil)
        let researchUpdatedAt = staleResearch.updatedAt
        XCTAssertThrowsError(
            try staleResearch
                .appendFH5CandidateOutcomeReviewEntry(entry)
        ) {
            XCTAssertEqual(
                $0 as? FH5CandidateOutcomeExchangeError,
                .candidateMismatch
            )
        }
        XCTAssertTrue(
            try staleResearch
                .allFH5CandidateOutcomeReviewEntries().isEmpty
        )
        XCTAssertEqual(staleResearch.updatedAt, researchUpdatedAt)

        let staleReview = try SavedTune(tune: fixture.plan)
        try persistCandidatePrerequisites(
            fixture: fixture,
            in: staleReview
        )
        staleReview.replaceFH5ResearchReviewEntriesDataForTesting(nil)
        let reviewUpdatedAt = staleReview.updatedAt
        XCTAssertThrowsError(
            try staleReview
                .appendFH5CandidateOutcomeReviewEntry(entry)
        ) {
            XCTAssertEqual(
                $0 as? FH5CandidateOutcomeExchangeError,
                .candidateMismatch
            )
        }
        XCTAssertTrue(
            try staleReview
                .allFH5CandidateOutcomeReviewEntries().isEmpty
        )
        XCTAssertEqual(staleReview.updatedAt, reviewUpdatedAt)

        let foreignFixture = try await makeCandidateOutcomeFixture(
            reusePermitted: true,
            fh5EntryOffset: 1
        )
        let foreignSaved = try SavedTune(
            tune: foreignFixture.plan
        )
        try persistCandidatePrerequisites(
            fixture: foreignFixture,
            in: foreignSaved
        )
        let foreignUpdatedAt = foreignSaved.updatedAt
        XCTAssertThrowsError(
            try foreignSaved
                .appendFH5CandidateOutcomeReviewEntry(entry)
        ) {
            XCTAssertEqual(
                $0 as? FH5CandidateOutcomeExchangeError,
                .candidateMismatch
            )
        }
        XCTAssertTrue(
            try foreignSaved
                .allFH5CandidateOutcomeReviewEntries().isEmpty
        )
        XCTAssertEqual(foreignSaved.updatedAt, foreignUpdatedAt)
    }
}
