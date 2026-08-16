import SwiftData
import XCTest
@testable import forzadvisor

final class FH5NumericPromotionCoordinatorTests: FH5ResearchTestCase {
    func testNumericPromotionPreparedStateTracksForeignCandidateShapedInput()
        async throws {
        let fixture = try await makeCandidateOutcomeFixture(
            reusePermitted: true
        )
        let records = try makePromotionReviewRecords(
            fixture: fixture,
            outcomes: Array(
                repeating: .variantPreferred,
                count: 10
            )
        )
        let foreign = try await makeCandidateOutcomeFixture(
            reusePermitted: true,
            fh5EntryOffset: 1
        )
        let exporter = FH5NumericPromotionReviewPacketExporter()
        let baseline = try exporter.prepare(
            candidateArtifact: fixture.artifact,
            localRecords: records,
            reviewedEntries: []
        )
        let withHistory = try exporter.prepare(
            candidateArtifact: fixture.artifact,
            localRecords: records + [foreign.record],
            reviewedEntries: []
        )

        XCTAssertEqual(baseline.evidence, withHistory.evidence)
        XCTAssertEqual(baseline.counts, withHistory.counts)
        XCTAssertNotEqual(
            baseline.preparedInputStateFingerprint,
            withHistory.preparedInputStateFingerprint
        )
        XCTAssertNotEqual(
            try baseline.deterministicJSON(),
            try withHistory.deterministicJSON()
        )
        let invalid = copyExperiment(
            records[0],
            schemaVersion: records[0].schemaVersion,
            consentVersion: records[0].consentVersion,
            candidateBinding: records[0].candidateBinding,
            contentFingerprint: String(repeating: "b", count: 64)
        )
        XCTAssertNotEqual(
            baseline.preparedInputStateFingerprint,
            try exporter.preparedInputStateFingerprint(
                candidateArtifact: fixture.artifact,
                localRecords: records + [invalid],
                reviewedEntries: []
            )
        )
    }

    @MainActor
    func testNumericPromotionCommittedCoordinatorIgnoresPendingEvidenceAndDoesNotMutate()
        async throws {
        let fixture = try await makeCandidateOutcomeFixture(
            reusePermitted: true
        )
        let records = try makePromotionReviewRecords(
            fixture: fixture,
            outcomes: Array(
                repeating: .variantPreferred,
                count: 10
            )
        )
        let container = try ModelContainer(
            for: SavedTune.self,
            configurations: ModelConfiguration(
                isStoredInMemoryOnly: true
            )
        )
        let writer = ModelContext(container)
        writer.autosaveEnabled = false
        let saved = try SavedTune(tune: fixture.plan)
        writer.insert(saved)
        try persistCandidatePrerequisites(
            fixture: fixture,
            in: saved
        )
        for record in records {
            try saved.appendFH5ControlledExperimentRecord(record)
        }
        try writer.save()

        let coordinator =
            FH5NumericPromotionReviewCommittedCoordinator()
        let baselineFingerprint = try coordinator
            .preparedInputStateFingerprint(
                displayedTune: fixture.plan,
                displayedArtifact: fixture.artifact,
                savedTuneID: saved.id,
                in: container
            )
        saved.replaceFH5ControlledExperimentRecordsDataForTesting(
            Data("pending corrupt evidence".utf8)
        )

        let packetJSON = try coordinator.prepare(
            displayedTune: fixture.plan,
            displayedArtifact: fixture.artifact,
            savedTuneID: saved.id,
            in: container
        )
        let packet = try coordinator.validate(
            Data(packetJSON.utf8),
            displayedTune: fixture.plan,
            displayedArtifact: fixture.artifact,
            savedTuneID: saved.id,
            in: container
        )

        XCTAssertEqual(
            packet.preparedInputStateFingerprint,
            baselineFingerprint
        )
        XCTAssertEqual(packet.counts.uniqueSessionCount, 10)
        XCTAssertEqual(
            packet,
            try FH5NumericPromotionReviewPacketExporter()
                .validate(
                    Data(packetJSON.utf8),
                    candidateArtifact: fixture.artifact
                )
        )
        XCTAssertEqual(
            try coordinator.preparedInputStateFingerprint(
                displayedTune: fixture.plan,
                displayedArtifact: fixture.artifact,
                savedTuneID: saved.id,
                in: container
            ),
            baselineFingerprint
        )
    }

    @MainActor
    func testNumericPromotionReceiverNeedsCommittedCandidateButNotLocalThresholdCorpus()
        async throws {
        let fixture = try await makeCandidateOutcomeFixture(
            reusePermitted: true
        )
        let records = try makePromotionReviewRecords(
            fixture: fixture,
            outcomes: Array(
                repeating: .variantPreferred,
                count: 10
            )
        )
        let packet = try FH5NumericPromotionReviewPacketExporter()
            .prepare(
                candidateArtifact: fixture.artifact,
                localRecords: records,
                reviewedEntries: []
            )
        let data = try packet.deterministicJSON()
        let container = try ModelContainer(
            for: SavedTune.self,
            configurations: ModelConfiguration(
                isStoredInMemoryOnly: true
            )
        )
        let context = ModelContext(container)
        let saved = try SavedTune(tune: fixture.plan)
        context.insert(saved)
        try persistCandidatePrerequisites(
            fixture: fixture,
            in: saved
        )
        try context.save()

        let received =
            try FH5NumericPromotionReviewCommittedCoordinator()
                .validate(
                    data,
                    displayedTune: fixture.plan,
                    displayedArtifact: fixture.artifact,
                    savedTuneID: saved.id,
                    in: container
                )

        XCTAssertEqual(received, packet)
        let check = ModelContext(container)
        let savedTuneID = saved.id
        var descriptor = FetchDescriptor<SavedTune>(
            predicate: #Predicate<SavedTune> { tune in
                tune.id == savedTuneID
            }
        )
        descriptor.fetchLimit = 1
        descriptor.includePendingChanges = false
        let reloaded = try XCTUnwrap(
            try check.fetch(descriptor).first
        )
        XCTAssertTrue(
            try reloaded.allFH5ControlledExperimentRecords()
                .isEmpty
        )
        XCTAssertTrue(
            try reloaded
                .allFH5CandidateOutcomeReviewEntries().isEmpty
        )
    }

    @MainActor
    func testNumericPromotionCoordinatorRejectsForeignDisplayAndCorruptCommittedEvidence()
        async throws {
        let fixture = try await makeCandidateOutcomeFixture(
            reusePermitted: true
        )
        let foreign = try await makeCandidateOutcomeFixture(
            reusePermitted: true,
            fh5EntryOffset: 1
        )
        let container = try ModelContainer(
            for: SavedTune.self,
            configurations: ModelConfiguration(
                isStoredInMemoryOnly: true
            )
        )
        let context = ModelContext(container)
        let saved = try SavedTune(tune: fixture.plan)
        context.insert(saved)
        try persistCandidatePrerequisites(
            fixture: fixture,
            in: saved
        )
        saved.replaceFH5ControlledExperimentRecordsDataForTesting(
            Data("committed corrupt evidence".utf8)
        )
        try context.save()
        let coordinator =
            FH5NumericPromotionReviewCommittedCoordinator()

        XCTAssertThrowsError(
            try coordinator.prepare(
                displayedTune: fixture.plan,
                displayedArtifact: foreign.artifact,
                savedTuneID: saved.id,
                in: container
            )
        ) {
            XCTAssertEqual(
                $0 as? FH5NumericPromotionReviewPacketError,
                .staleOrForeignCandidate
            )
        }
        XCTAssertThrowsError(
            try coordinator.prepare(
                displayedTune: fixture.plan,
                displayedArtifact: fixture.artifact,
                savedTuneID: saved.id,
                in: container
            )
        ) {
            XCTAssertEqual(
                $0 as? SavedTuneFH5ControlledExperimentError,
                .corruptStorage
            )
        }
    }
}
