import SwiftData
import XCTest
@testable import forzadvisor

final class FH5ControlledExperimentPersistenceTests: FH5ResearchTestCase {
    @MainActor
    func testControlledExperimentPersistenceIsolatedAndCannotUnlockNumeric() async throws {
        let plan = try await makePlan(upgradeBuild: "3.688.109.0")
        let research = try FH5ResearchObservationFactory().make(
            tune: plan,
            savedTune: plan,
            isStreaming: false,
            capture: validCapture(
                drivetrain: plan.request.car.drivetrain,
                gearCount: 6,
                availability: .adjustable
            ),
            capturedAt: capturedAt
        )
        let experiment = try FH5ControlledExperimentFactory().make(
            tune: plan,
            savedTune: plan,
            isStreaming: false,
            researchRecords: [research],
            capture: experimentCapture(
                field: try XCTUnwrap(research.controls.first?.field),
                candidate: 49
            ),
            createdAt: capturedAt.addingTimeInterval(60)
        )
        let registration = try makeExperimentalRegistration()
        let registry = try FH5TrustedNumericRulesetRegistry(
            validating: [registration]
        )
        let boundExperiment = try FH5ControlledExperimentFactory()
            .makeCandidateBoundForTesting(
                tune: plan,
                savedTune: plan,
                isStreaming: false,
                researchRecords: [research],
                capture: experimentCapture(
                    field: try XCTUnwrap(research.controls.first?.field),
                    candidate: 49
                ),
                candidateAlgorithmID: registration.algorithmID,
                registry: registry,
                createdAt: capturedAt.addingTimeInterval(120)
            )
        let directory = FileManager.default.temporaryDirectory
            .appending(
                path: "forzadvisor-fh5-outcome-\(UUID().uuidString)",
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
            let saved = try SavedTune(tune: plan)
            context.insert(saved)
            try saved.appendFH5ResearchObservationRecord(research)
            try saved.appendFH5ControlledExperimentRecord(experiment)
            try saved.appendFH5ControlledExperimentRecord(experiment)
            try saved.appendFH5ControlledExperimentRecord(boundExperiment)
            try context.save()
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
            XCTAssertEqual(
                saved.fh5ControlledExperimentRecords(
                    matching: plan,
                    researchRecord: research
                ),
                [experiment, boundExperiment]
            )
            XCTAssertEqual(saved.tuneResult?.purpose, .fh5BuildPlan)
            XCTAssertTrue(saved.tuneResult?.sections.isEmpty == true)
            XCTAssertNil(saved.tuneResult?.providerInfo)
            XCTAssertNil(saved.tuneResult?.rulesetReference)
            XCTAssertTrue(
                try saved.deleteFH5ControlledExperimentRecord(
                    id: experiment.recordID
                )
            )
            XCTAssertTrue(
                try saved.deleteFH5ControlledExperimentRecord(
                    id: boundExperiment.recordID
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
                context.fetch(FetchDescriptor<SavedTune>()).first
            )
            XCTAssertTrue(saved.fh5ControlledExperimentRecords.isEmpty)
            XCTAssertEqual(
                saved.fh5ResearchObservationRecords(matching: plan),
                [research]
            )
            let tuneBeforeCorruption = saved.tuneResult
            let researchBeforeCorruption =
                saved.fh5ResearchObservationRecords(matching: plan)
            try saved.appendFH5ControlledExperimentRecord(experiment)
            saved.replaceFH5ControlledExperimentRecordsDataForTesting(
                Data("corrupt experiment storage".utf8)
            )
            XCTAssertTrue(saved.fh5ControlledExperimentRecords.isEmpty)
            XCTAssertThrowsError(
                try saved.appendFH5ControlledExperimentRecord(experiment)
            ) {
                XCTAssertEqual(
                    $0 as? SavedTuneFH5ControlledExperimentError,
                    .corruptStorage
                )
            }
            XCTAssertThrowsError(
                try saved.deleteFH5ControlledExperimentRecord(
                    id: experiment.recordID
                )
            ) {
                XCTAssertEqual(
                    $0 as? SavedTuneFH5ControlledExperimentError,
                    .corruptStorage
                )
            }
            XCTAssertEqual(saved.tuneResult, tuneBeforeCorruption)
            XCTAssertEqual(
                saved.fh5ResearchObservationRecords(matching: plan),
                researchBeforeCorruption
            )
        }

        let report = FH5ControlledExperimentFactory().outcomePolicyReport(
            records: [experiment],
            tune: plan,
            researchRecord: research
        )
        XCTAssertEqual(report.matchingRecordCount, 1)
        XCTAssertFalse(report.passes)
        let readiness = FH5NumericReadinessPolicy().assess(
            tune: plan,
            researchRecords: [research],
            reviewReport: .empty,
            controlledOutcomeReport: report
        )
        XCTAssertFalse(readiness.canGenerateNumeric)
        XCTAssertEqual(
            readiness.items.first { $0.gate == .controlledOutcomes }?.state,
            .blocked
        )
        XCTAssertTrue(
            readiness.items.first { $0.gate == .controlledOutcomes }?.detail
                .contains("1 matching paired experiment") ?? false
        )
    }
}
