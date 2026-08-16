import SwiftData
import XCTest
@testable import forzadvisor

final class FH5ResearchReviewTests: FH5ResearchTestCase {
    func testReviewIngestorRequiresExactCanonicalValidPermissionReadyExport() async throws {
        let plan = try await makePlan()
        let export = try makeReviewExport(plan: plan)
        let data = try FH5ResearchReviewIngestor.canonicalData(for: export)
        let ingestor = FH5ResearchReviewIngestor()

        let validated = try ingestor.validate(data)
        XCTAssertEqual(validated.export, export)
        XCTAssertTrue(ingestor.matchesSavedPlan(validated, tune: plan))

        XCTAssertThrowsError(try ingestor.validate(data + Data("\n".utf8))) {
            XCTAssertEqual($0 as? FH5ResearchReviewError, .nonCanonicalJSON)
        }
        XCTAssertThrowsError(try ingestor.validate(insertingTopLevel(
            "\"unexpected\" : true",
            into: data
        ))) {
            XCTAssertEqual($0 as? FH5ResearchReviewError, .nonCanonicalJSON)
        }
        XCTAssertThrowsError(try ingestor.validate(insertingTopLevel(
            "\"schemaVersion\" : 1",
            into: data
        ))) {
            XCTAssertEqual($0 as? FH5ResearchReviewError, .nonCanonicalJSON)
        }
        XCTAssertThrowsError(try ingestor.validate(
            Data(repeating: 0x20, count: FH5ResearchReviewIngestor.maximumPayloadBytes + 1)
        )) {
            XCTAssertEqual($0 as? FH5ResearchReviewError, .payloadTooLarge)
        }

        let badFingerprint = replacingReviewExport(
            export,
            contentFingerprint: String(repeating: "0", count: 64)
        )
        XCTAssertThrowsError(try ingestor.validate(
            FH5ResearchReviewIngestor.canonicalData(for: badFingerprint)
        )) {
            XCTAssertEqual($0 as? FH5ResearchReviewError, .invalidContentFingerprint)
        }

        let reuseOffAttestations = FH5ResearchObservationRecord.Attestations(
            exactUntouchedStock: true,
            allSlidersRestored: true,
            personallyReadFromGame: true,
            firstPartyAuthorship: true,
            localStoragePermitted: true,
            deidentifiedStructuredReusePermitted: false
        )
        let reuseOff = try replacingReviewExport(
            export,
            attestations: reuseOffAttestations,
            recomputingFingerprint: true
        )
        XCTAssertThrowsError(try ingestor.validate(
            FH5ResearchReviewIngestor.canonicalData(for: reuseOff)
        )) {
            XCTAssertEqual($0 as? FH5ResearchReviewError, .invalidStructure)
        }

        let reordered = try replacingReviewExport(
            export,
            controls: Array(export.controls.reversed()),
            recomputingFingerprint: true
        )
        XCTAssertThrowsError(try ingestor.validate(
            FH5ResearchReviewIngestor.canonicalData(for: reordered)
        )) {
            XCTAssertEqual($0 as? FH5ResearchReviewError, .invalidStructure)
        }
    }
    func testReviewPermissionQuarantineAndAdministrativeReplayFailClosed() async throws {
        let plan = try await makePlan()
        let first = try makeReviewExport(plan: plan)
        let firstData = try FH5ResearchReviewIngestor.canonicalData(for: first)
        let firstInput = try reviewInput(for: firstData)
        let evaluator = FH5ResearchReviewEvaluator()

        let quarantined = evaluator.evaluate([
            FH5ResearchReviewInput(exportJSON: firstData, permission: nil)
        ])
        XCTAssertEqual(quarantined.quarantinedCount, 1)
        XCTAssertEqual(quarantined.verifiedUniqueObservationCount, 0)

        let wrongPermission = FH5ResearchReviewPermission(
            submissionID: first.submissionID,
            permissionReceiptID: first.permissionReceiptID,
            consentVersion: first.consentVersion,
            canonicalExportDigest: String(repeating: "0", count: 64),
            contentFingerprint: first.contentFingerprint,
            locallyReviewedAt: capturedAt
        )
        XCTAssertEqual(evaluator.evaluate([
            FH5ResearchReviewInput(
                exportJSON: firstData,
                permission: wrongPermission
            )
        ]).quarantinedCount, 1)

        let sameSubmissionConflict = try replacingReviewExport(
            first,
            permissionReceiptID: UUID(),
            capturedAt: capturedAt.addingTimeInterval(60),
            recomputingFingerprint: true
        )
        let sameSubmissionInput = try reviewInput(
            for: FH5ResearchReviewIngestor.canonicalData(for: sameSubmissionConflict)
        )
        let submissionReport = evaluator.evaluate([firstInput, sameSubmissionInput])
        XCTAssertEqual(submissionReport.administrativeConflictCount, 2)
        XCTAssertEqual(submissionReport.verifiedUniqueObservationCount, 0)
        XCTAssertTrue(submissionReport.groups.isEmpty)

        let receiptReplay = try replacingReviewExport(
            first,
            submissionID: UUID(),
            capturedAt: capturedAt.addingTimeInterval(120),
            recomputingFingerprint: true
        )
        let receiptInput = try reviewInput(
            for: FH5ResearchReviewIngestor.canonicalData(for: receiptReplay)
        )
        let receiptReport = evaluator.evaluate([firstInput, receiptInput])
        XCTAssertEqual(receiptReport.administrativeConflictCount, 2)
        XCTAssertEqual(receiptReport.receiptReplayCount, 2)
        XCTAssertEqual(
            receiptReport,
            evaluator.evaluate([receiptInput, firstInput])
        )
    }
    func testReviewSuppressesAdministrativeCopiesButCountsDistinctCaptureSessions() async throws {
        let plan = try await makePlan()
        let first = try makeReviewExport(plan: plan)
        let administrativeCopy = try replacingReviewExport(
            first,
            submissionID: UUID(),
            permissionReceiptID: UUID(),
            recomputingFingerprint: true
        )
        let firstInput = try reviewInput(
            for: FH5ResearchReviewIngestor.canonicalData(for: first)
        )
        let copyInput = try reviewInput(
            for: FH5ResearchReviewIngestor.canonicalData(for: administrativeCopy)
        )
        let copiedReport = FH5ResearchReviewEvaluator().evaluate([
            firstInput,
            copyInput
        ])
        XCTAssertEqual(copiedReport.verifiedUniqueObservationCount, 1)
        XCTAssertEqual(copiedReport.duplicateCount, 1)
        XCTAssertEqual(copiedReport.groups.first?.status, .insufficient)

        let secondSession = try replacingReviewExport(
            first,
            submissionID: UUID(),
            permissionReceiptID: UUID(),
            capturedAt: capturedAt.addingTimeInterval(60),
            recomputingFingerprint: true
        )
        let secondInput = try reviewInput(
            for: FH5ResearchReviewIngestor.canonicalData(for: secondSession)
        )
        let replicated = FH5ResearchReviewEvaluator().evaluate([
            firstInput,
            secondInput
        ])
        XCTAssertEqual(replicated.verifiedUniqueObservationCount, 2)
        XCTAssertEqual(replicated.groups.count, 1)
        XCTAssertEqual(replicated.groups.first?.status, .replicated)
        XCTAssertEqual(replicated.groups.first?.measurementVariantCount, 1)
    }
    func testReviewUsesExactConflictsAndNeverMergesBuildsOrPlatforms() async throws {
        let plan = try await makePlan()
        let first = try makeReviewExport(plan: plan)
        var changedControls = first.controls
        let changed = changedControls[0]
        changedControls[0] = FH5TuneFieldObservation(
            field: changed.field,
            availability: .shownLocked,
            current: 50,
            unit: changed.field.expectedUnit
        )
        let conflicting = try replacingReviewExport(
            first,
            submissionID: UUID(),
            permissionReceiptID: UUID(),
            capturedAt: capturedAt.addingTimeInterval(60),
            controls: changedControls,
            recomputingFingerprint: true
        )
        let conflictReport = FH5ResearchReviewEvaluator().evaluate([
            try reviewInput(for: FH5ResearchReviewIngestor.canonicalData(for: first)),
            try reviewInput(for: FH5ResearchReviewIngestor.canonicalData(for: conflicting))
        ])
        XCTAssertEqual(conflictReport.groups.count, 1)
        XCTAssertEqual(conflictReport.groups.first?.status, .conflicted)
        XCTAssertEqual(conflictReport.groups.first?.measurementVariantCount, 2)

        let otherBuild = try replacingReviewExport(
            first,
            submissionID: UUID(),
            permissionReceiptID: UUID(),
            capturedAt: capturedAt.addingTimeInterval(120),
            gameVersion: "different-build",
            recomputingFingerprint: true
        )
        let otherPlatform = try replacingReviewExport(
            first,
            submissionID: UUID(),
            permissionReceiptID: UUID(),
            capturedAt: capturedAt.addingTimeInterval(180),
            platform: .steamPC,
            recomputingFingerprint: true
        )
        let boundaryReport = FH5ResearchReviewEvaluator().evaluate([
            try reviewInput(for: FH5ResearchReviewIngestor.canonicalData(for: first)),
            try reviewInput(for: FH5ResearchReviewIngestor.canonicalData(for: otherBuild)),
            try reviewInput(for: FH5ResearchReviewIngestor.canonicalData(for: otherPlatform))
        ])
        XCTAssertEqual(boundaryReport.groups.count, 3)
        XCTAssertTrue(boundaryReport.groups.allSatisfy { $0.status == .insufficient })
    }

    @MainActor
    func testReviewPersistencePlanScopeCorruptionAndNonPromotion() async throws {
        let plan = try await makePlan()
        let export = try makeReviewExport(plan: plan)
        let data = try FH5ResearchReviewIngestor.canonicalData(for: export)
        let entry = try FH5ResearchReviewEntry.locallyReviewed(
            canonicalExportJSON: data,
            reviewerConfirmedDirectReceiptAndReusePermission: true,
            now: capturedAt
        )
        let container = try ModelContainer(
            for: SavedTune.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let saved = try SavedTune(tune: plan)
        context.insert(saved)
        try saved.appendFH5ResearchReviewEntry(entry)
        try context.save()

        XCTAssertEqual(saved.fh5ResearchReviewEntries(matching: plan), [entry])
        XCTAssertEqual(
            saved.fh5ResearchReviewReport(matching: plan).groups.first?.status,
            .insufficient
        )
        let persisted = try XCTUnwrap(saved.tuneResult)
        XCTAssertEqual(persisted.id, plan.id)
        XCTAssertTrue(persisted.sections.isEmpty)
        XCTAssertNil(persisted.providerInfo)
        XCTAssertNil(persisted.rulesetReference)
        XCTAssertEqual(persisted.projectionReport?.readyCount, 0)
        XCTAssertTrue(plan.sections.isEmpty)
        XCTAssertNil(plan.providerInfo)
        XCTAssertNil(plan.rulesetReference)
        XCTAssertEqual(plan.projectionReport?.readyCount, 0)
        XCTAssertFalse(plan.request.buildSnapshot?.constraints.contains {
            $0.verification == .productionEligible
        } ?? true)

        let reopened = try XCTUnwrap(
            context.fetch(FetchDescriptor<SavedTune>()).first
        )
        XCTAssertEqual(reopened.fh5ResearchReviewEntries(matching: plan), [entry])
        XCTAssertTrue(try reopened.deleteFH5ResearchReviewEntry(id: entry.id))
        XCTAssertTrue(reopened.fh5ResearchReviewEntries.isEmpty)

        let otherPlan = try await makePlan(fh5EntryOffset: 1)
        let otherExport = try makeReviewExport(plan: otherPlan)
        let otherEntry = try FH5ResearchReviewEntry.locallyReviewed(
            canonicalExportJSON: FH5ResearchReviewIngestor.canonicalData(for: otherExport),
            reviewerConfirmedDirectReceiptAndReusePermission: true
        )
        XCTAssertThrowsError(try reopened.appendFH5ResearchReviewEntry(otherEntry)) {
            XCTAssertEqual($0 as? FH5ResearchReviewError, .planMismatch)
        }

        let inconsistentReviewTimeEntry = FH5ResearchReviewEntry(
            canonicalExportJSON: data,
            permission: FH5ResearchReviewPermission(
                submissionID: export.submissionID,
                permissionReceiptID: export.permissionReceiptID,
                consentVersion: export.consentVersion,
                canonicalExportDigest:
                    try FH5ResearchReviewIngestor().validate(data).canonicalExportDigest,
                contentFingerprint: export.contentFingerprint,
                locallyReviewedAt: capturedAt.addingTimeInterval(1)
            )
        )
        XCTAssertThrowsError(
            try reopened.appendFH5ResearchReviewEntry(inconsistentReviewTimeEntry)
        ) {
            XCTAssertEqual($0 as? FH5ResearchReviewError, .permissionNotConfirmed)
        }

        reopened.replaceFH5ResearchReviewEntriesDataForTesting(Data("corrupt".utf8))
        XCTAssertTrue(reopened.fh5ResearchReviewEntries.isEmpty)
        XCTAssertThrowsError(try reopened.appendFH5ResearchReviewEntry(entry)) {
            XCTAssertEqual($0 as? FH5ResearchReviewError, .corruptStorage)
        }
        let stillPersisted = try XCTUnwrap(reopened.tuneResult)
        XCTAssertEqual(stillPersisted.id, plan.id)
        XCTAssertTrue(stillPersisted.sections.isEmpty)
        XCTAssertNil(stillPersisted.providerInfo)
        XCTAssertNil(stillPersisted.rulesetReference)
        XCTAssertTrue(reopened.fh5ResearchObservationRecords.isEmpty)
    }
}
