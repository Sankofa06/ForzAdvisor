import XCTest
@testable import forzadvisor

final class NewTuneInputStateTests: XCTestCase {
    func testPristineManualDraftShowsGuidanceWithoutErrors() {
        let state = ManualEntryFormState()

        XCTAssertTrue(state.visibleIssues(for: .empty).isEmpty)
        XCTAssertFalse(state.hasAttemptedSubmission)
    }

    func testTouchedManualFieldShowsOnlyItsIssue() {
        var state = ManualEntryFormState()
        state.markTouched(.weight)

        XCTAssertEqual(state.visibleIssues(for: .empty), [.missingWeight])
    }

    func testSubmissionNamesFirstUnresolvedManualField() {
        var state = ManualEntryFormState()
        state.markSubmitted()

        XCTAssertEqual(state.firstUnresolvedField(in: .empty), .identity)
        XCTAssertEqual(state.firstUnresolvedField(in: .empty)?.title, "Make or model")
        XCTAssertEqual(state.visibleIssues(for: .empty), ManualEntryDraft.empty.validationIssues)
    }

    func testOCRReviewStatesAreActionableRatherThanConfidenceLabels() {
        var draft = completeOCRDraft(confidence: 0.4)

        XCTAssertEqual(draft.reviewState(for: .weightPounds), .needsCheck)
        draft.confirm(.weightPounds)
        XCTAssertEqual(draft.reviewState(for: .weightPounds), .confirmed)
        draft.markCorrected(.weightPounds)
        XCTAssertEqual(draft.reviewState(for: .weightPounds), .corrected)
    }

    func testLowEvidenceRequiresReviewBeforeConfirmation() {
        var draft = completeOCRDraft(confidence: 0.4)

        XCTAssertNil(draft.confirmedCarInput())
        OCRConfirmationDraft.requiredFields.forEach { draft.confirm($0) }
        XCTAssertNotNil(draft.confirmedCarInput())
    }

    func testFirstOCRIssueNamesIdentityThenRequiredReview() {
        var draft = completeOCRDraft(confidence: 0.9)
        draft.make = ""
        draft.model = ""
        XCTAssertEqual(draft.firstUnresolvedField, .identity)

        draft.make = "Toyota"
        draft.evidence[.frontWeightPercent] = .missing
        XCTAssertEqual(draft.firstUnresolvedField, .frontWeightPercent)
    }

    func testCorruptSourceImageDoesNotBlockOtherwiseValidReview() {
        var draft = completeOCRDraft(confidence: 0.9)
        draft.thumbnailData = Data([0x00, 0x01])

        XCTAssertNotNil(draft.confirmedCarInput())
    }

    private func completeOCRDraft(confidence: Double) -> OCRConfirmationDraft {
        var draft = OCRConfirmationDraft(
            make: "Toyota",
            model: "Supra",
            weightPounds: 3_400,
            frontWeightPercent: 52,
            performanceIndex: 700,
            performanceClass: .a,
            drivetrain: .rwd
        )
        for field in OCRConfirmationDraft.requiredFields {
            draft.evidence[field] = OCRFieldEvidence(
                rawText: field.title,
                confidence: confidence
            )
        }
        return draft
    }
}
