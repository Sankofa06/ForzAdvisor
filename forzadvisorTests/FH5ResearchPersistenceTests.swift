import SwiftData
import XCTest
@testable import forzadvisor

final class FH5ResearchPersistenceTests: FH5ResearchTestCase {
    @MainActor
    func testSeparateSwiftDataBlobAppendDedupeReopenDeleteAndCorruptIsolation() async throws {
        let plan = try await makePlan()
        let capture = validCapture(
            drivetrain: plan.request.car.drivetrain,
            gearCount: 6,
            availability: .notShown,
            reuse: true
        )
        let record = try FH5ResearchObservationFactory().make(
            tune: plan,
            savedTune: plan,
            isStreaming: false,
            capture: capture,
            recordID: recordID,
            submissionID: submissionID,
            permissionReceiptID: permissionID,
            capturedAt: capturedAt,
            snapshotID: snapshotID
        )
        let duplicateContent = try FH5ResearchObservationFactory().make(
            tune: plan,
            savedTune: plan,
            isStreaming: false,
            capture: capture,
            recordID: UUID(),
            submissionID: UUID(),
            permissionReceiptID: UUID(),
            capturedAt: capturedAt,
            snapshotID: UUID()
        )
        XCTAssertEqual(record.contentFingerprint, duplicateContent.contentFingerprint)

        let container = try ModelContainer(
            for: SavedTune.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let saved = try SavedTune(tune: plan)
        context.insert(saved)
        try context.save()
        XCTAssertTrue(saved.fh5ResearchObservationRecords.isEmpty)
        let originalTune = try XCTUnwrap(saved.tuneResult)
        let validationBlob = try JSONEncoder().encode([FirstPartyValidationRecord]())
        saved.replaceValidationRecordsDataForTesting(validationBlob)

        try saved.appendFH5ResearchObservationRecord(record)
        try saved.appendFH5ResearchObservationRecord(record)
        try saved.appendFH5ResearchObservationRecord(duplicateContent)
        try context.save()
        XCTAssertEqual(saved.fh5ResearchObservationRecords, [record])
        XCTAssertEqual(saved.tuneResult, originalTune)
        XCTAssertTrue(saved.firstPartyValidationRecords.isEmpty)

        let reopened = try XCTUnwrap(
            context.fetch(FetchDescriptor<SavedTune>()).first
        )
        XCTAssertEqual(reopened.fh5ResearchObservationRecords, [record])
        XCTAssertEqual(reopened.tuneResult, originalTune)

        XCTAssertTrue(try reopened.deleteFH5ResearchObservationRecord(id: recordID))
        XCTAssertTrue(reopened.fh5ResearchObservationRecords.isEmpty)
        XCTAssertEqual(reopened.tuneResult, originalTune)

        reopened.replaceFH5ResearchObservationRecordsDataForTesting(Data("corrupt".utf8))
        XCTAssertTrue(reopened.fh5ResearchObservationRecords.isEmpty)
        XCTAssertEqual(reopened.tuneResult, originalTune)
        XCTAssertTrue(reopened.firstPartyValidationRecords.isEmpty)
        XCTAssertThrowsError(try reopened.appendFH5ResearchObservationRecord(record)) {
            XCTAssertEqual($0 as? SavedTuneFH5ResearchRecordError, .corruptStorage)
        }
        XCTAssertEqual(reopened.tuneResult, originalTune)
    }

    @MainActor
    func testStoredHistoryOnlySurfacesRecordsMatchingCurrentSavedPlan() async throws {
        let plan = try await makePlan()
        let record = try FH5ResearchObservationFactory().make(
            tune: plan,
            savedTune: plan,
            isStreaming: false,
            capture: validCapture(
                drivetrain: plan.request.car.drivetrain,
                gearCount: 6,
                availability: .notShown,
                reuse: true
            ),
            capturedAt: capturedAt
        )
        let saved = try SavedTune(tune: plan)
        try saved.appendFH5ResearchObservationRecord(record)
        XCTAssertEqual(saved.fh5ResearchObservationRecords(matching: plan), [record])

        var revisedCatalog = plan
        let reference = try XCTUnwrap(revisedCatalog.request.car.catalogReference)
        let revisedReference = CatalogCarReference(
            entryID: reference.entryID,
            revision: "\(reference.revision)-new",
            reviewedAt: reference.reviewedAt.addingTimeInterval(1),
            verificationStatus: reference.verificationStatus,
            sources: reference.sources
        )
        revisedCatalog.request.car.catalogReference = revisedReference
        revisedCatalog.request.buildSnapshot?.car.catalogReference = revisedReference
        revisedCatalog.generatedAt = revisedCatalog.generatedAt.addingTimeInterval(1)
        try saved.update(with: revisedCatalog)
        XCTAssertEqual(saved.fh5ResearchObservationRecords, [record])
        XCTAssertTrue(saved.fh5ResearchObservationRecords(matching: revisedCatalog).isEmpty)

        let otherFH5Car = try await makePlan(fh5EntryOffset: 1)
        try saved.update(with: otherFH5Car)
        XCTAssertEqual(saved.fh5ResearchObservationRecords, [record])
        XCTAssertTrue(saved.fh5ResearchObservationRecords(matching: otherFH5Car).isEmpty)

        let fh6Tune = try await makeTune(game: .fh6)
        try saved.update(with: fh6Tune)
        XCTAssertEqual(saved.fh5ResearchObservationRecords, [record])
        XCTAssertTrue(saved.fh5ResearchObservationRecords(matching: fh6Tune).isEmpty)

        let recorded = !saved.fh5ResearchObservationRecords(matching: fh6Tune).isEmpty
        let context = CopilotContextFactory().make(
            step: .result(
                fh6Tune,
                savedTuneID: saved.id,
                adjustmentChanges: [],
                thumbnailData: nil,
                playerNotes: ""
            ),
            savedTuneCount: 1,
            catalogCarCount: 1,
            fh5ObservationRecorded: recorded
        )
        XCTAssertFalse(recorded)
        XCTAssertNotEqual(context.projection?.fh5ObservationRecorded, true)
        XCTAssertFalse(context.facts.contains { $0.label == "FH5 stock evidence" })
    }
    func testDetachedSnapshotRejectsIndividuallyValidSemanticTampering() async throws {
        let plan = try await makePlan(upgradeBuild: "matching-build")
        let record = try FH5ResearchObservationFactory().make(
            tune: plan,
            savedTune: plan,
            isStreaming: false,
            capture: validCapture(
                drivetrain: plan.request.car.drivetrain,
                gearCount: 6,
                availability: .adjustable,
                build: "matching-build",
                reuse: true
            ),
            capturedAt: capturedAt,
            snapshotID: snapshotID
        )
        let factory = FH5ResearchObservationFactory()

        var carTamper = record.internalValidationSnapshot
        carTamper.car.weightPounds += 1
        XCTAssertTrue(carTamper.isValid)
        XCTAssertFalse(factory.isValid(replacing(record, snapshot: carTamper)))

        var constraintTamper = record.internalValidationSnapshot
        constraintTamper.constraints[0].minimum -= constraintTamper.constraints[0].step
        XCTAssertTrue(constraintTamper.isValid)
        XCTAssertFalse(factory.isValid(replacing(record, snapshot: constraintTamper)))

        var evidenceTamper = record.internalValidationSnapshot
        let forgedEvidenceID = "fh5-research.forged-but-valid"
        evidenceTamper.evidenceSources[0].id = forgedEvidenceID
        for index in evidenceTamper.constraints.indices {
            evidenceTamper.constraints[index].evidenceIDs = [forgedEvidenceID]
        }
        evidenceTamper.tireCompound?.evidenceIDs = [forgedEvidenceID]
        XCTAssertTrue(evidenceTamper.isValid)
        XCTAssertFalse(factory.isValid(replacing(record, snapshot: evidenceTamper)))

        var tireTamper = record.internalValidationSnapshot
        tireTamper.tireCompound?.id = "different-valid-tire-id"
        XCTAssertTrue(tireTamper.isValid)
        XCTAssertFalse(factory.isValid(replacing(record, snapshot: tireTamper)))

        var stockSettingTamper = record.internalValidationSnapshot
        stockSettingTamper.capabilityProfile.stockAdjustableSettings[0].evidence.version =
            "different-valid-build"
        XCTAssertTrue(stockSettingTamper.isValid)
        XCTAssertFalse(factory.isValid(replacing(record, snapshot: stockSettingTamper)))

        var partTamper = record.internalValidationSnapshot
        partTamper.capabilityProfile.parts[0].availability =
            partTamper.capabilityProfile.parts[0].availability == .available
                ? .unavailable
                : .available
        XCTAssertTrue(partTamper.isValid)
        XCTAssertFalse(factory.isValid(replacing(record, snapshot: partTamper)))
    }
    func testDetachedSnapshotCannotPromoteOrMutateFH5PlanBoundary() async throws {
        let plan = try await makePlan()
        let record = try FH5ResearchObservationFactory().make(
            tune: plan,
            savedTune: plan,
            isStreaming: false,
            capture: validCapture(
                drivetrain: plan.request.car.drivetrain,
                gearCount: 6,
                availability: .adjustable,
                reuse: true
            ),
            capturedAt: capturedAt
        )
        var adversarial = plan
        adversarial.request.buildSnapshot = record.internalValidationSnapshot
        let projected = TuneResultBoundarySanitizer().sanitize(adversarial)

        XCTAssertEqual(projected.purpose, .fh5BuildPlan)
        XCTAssertTrue(projected.sections.isEmpty)
        XCTAssertNil(projected.providerInfo)
        XCTAssertNil(projected.rulesetReference)
        XCTAssertEqual(projected.projectionReport?.readyCount, 0)
        XCTAssertNil(TuneClipboardFormatter.verifiedSettingsText(for: projected))
        XCTAssertNil(VerifiedBuildShareCardFactory().make(for: projected, isStreaming: false))
        XCTAssertNil(TirePressureCaptureEligibility().snapshot(for: projected))
        XCTAssertNil(UpgradePartCaptureEligibility().snapshot(for: projected))
        XCTAssertFailure(
            FirstPartyValidationRecordFactory().eligibility(
                for: projected,
                savedTune: projected,
                isStreaming: false
            ),
            .incompleteStockContext
        )
    }

}
