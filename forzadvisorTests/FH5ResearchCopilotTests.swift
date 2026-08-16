import SwiftData
import XCTest
@testable import forzadvisor

final class FH5ResearchCopilotTests: FH5ResearchTestCase {
    @MainActor
    func testCopilotResearchEligibilityUsesPersistedCurrentRevisionAndFailsClosed() async throws {
        let plan = try await makePlan()
        let factory = CopilotContextFactory()
        let step = WorkflowStep.result(
            plan,
            savedTuneID: plan.id,
            adjustmentChanges: [],
            thumbnailData: nil,
            playerNotes: ""
        )

        XCTAssertTrue(factory.fh5ResearchLabEligibility(
            for: plan,
            persistedTune: plan,
            isStreaming: false
        ))
        XCTAssertFalse(factory.fh5ResearchLabEligibility(
            for: plan,
            persistedTune: nil,
            isStreaming: false
        ))
        XCTAssertFalse(factory.make(
            step: step,
            savedTuneCount: 1,
            catalogCarCount: 1
        ).projection?.fh5ResearchLabEligible ?? true)

        var stale = plan
        stale.generatedAt = stale.generatedAt.addingTimeInterval(1)
        XCTAssertFalse(factory.fh5ResearchLabEligibility(
            for: plan,
            persistedTune: stale,
            isStreaming: false
        ))

        var differentRevision = plan
        let reference = try XCTUnwrap(differentRevision.request.car.catalogReference)
        let changedReference = CatalogCarReference(
            entryID: reference.entryID,
            revision: "\(reference.revision)-different",
            reviewedAt: reference.reviewedAt,
            verificationStatus: reference.verificationStatus,
            sources: reference.sources
        )
        differentRevision.request.car.catalogReference = changedReference
        differentRevision.request.buildSnapshot?.car.catalogReference = changedReference
        XCTAssertFalse(factory.fh5ResearchLabEligibility(
            for: plan,
            persistedTune: differentRevision,
            isStreaming: false
        ))

        let fh6 = try await makeTune(game: .fh6)
        XCTAssertFalse(factory.fh5ResearchLabEligibility(
            for: fh6,
            persistedTune: fh6,
            isStreaming: false
        ))

        let corrupt = try SavedTune(tune: plan)
        corrupt.replaceTuneDataForTesting(Data("corrupt tuneData".utf8))
        XCTAssertNil(corrupt.tuneResult)
        XCTAssertFalse(factory.fh5ResearchLabEligibility(
            for: plan,
            persistedTune: corrupt.tuneResult,
            isStreaming: false
        ))
    }
    func testCopilotTreatsRecordedObservationAsEvidenceRatherThanTuneReadiness() async throws {
        let plan = try await makePlan()
        let factory = CopilotContextFactory()
        let step = WorkflowStep.result(
            plan,
            savedTuneID: plan.id,
            adjustmentChanges: [],
            thumbnailData: nil,
            playerNotes: ""
        )
        let available = factory.make(
            step: step,
            savedTuneCount: 1,
            catalogCarCount: 1,
            fh5ResearchLabEligible: true
        )
        let recorded = factory.make(
            step: step,
            savedTuneCount: 1,
            catalogCarCount: 1,
            fh5ResearchLabEligible: true,
            fh5ObservationRecorded: true
        )
        let engine = CopilotEngine()

        XCTAssertEqual(available.projection?.resultPurpose, .fh5BuildPlan)
        XCTAssertEqual(available.projection?.readyCount, 0)
        XCTAssertEqual(available.projection?.fh5ResearchLabEligible, true)
        XCTAssertTrue(
            engine.response(to: .nextStep, in: available).message
                .contains("Open FH5 Research Lab")
        )

        XCTAssertEqual(recorded.projection?.readyCount, 0)
        XCTAssertEqual(recorded.projection?.fh5ObservationRecorded, true)
        for intent in [CopilotIntent.nextStep, .trust, .missing] {
            let message = engine.response(to: intent, in: recorded).message.lowercased()
            XCTAssertTrue(
                message.contains("evidence"),
                "\(intent.rawValue) must identify the record as evidence: \(message)"
            )
            XCTAssertTrue(
                message.contains("not a tune") || message.contains("numeric"),
                "\(intent.rawValue) must preserve the numeric-tune boundary: \(message)"
            )
        }
    }
}
