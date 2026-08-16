import XCTest
@testable import forzadvisor

final class SupportedInputOriginSnapshotTests: XCTestCase {
    func testManualFactsCreateUserConfirmedBoundaryWithoutCatalogFacts() throws {
        let car = confirmedCar()
        let snapshot = try XCTUnwrap(
            InputOrigin.manual(car).buildSnapshot(matching: car)
        )

        XCTAssertEqual(snapshot.inputFactsSource, .userConfirmedManual)
        XCTAssertTrue(snapshot.hasConfirmedInputFacts)
        XCTAssertNil(snapshot.car.catalogReference)
        XCTAssertTrue(snapshot.capabilityProfile.parts.isEmpty)
        XCTAssertTrue(snapshot.capabilityProfile.stockAdjustableSettings.isEmpty)
        XCTAssertTrue(snapshot.constraints.isEmpty)
        XCTAssertTrue(snapshot.isValid)
    }

    func testOCRAndPhotoFactsRequireCompletedReview() throws {
        var draft = confirmedOCRDraft()
        let car = try XCTUnwrap(draft.confirmedCarInput())
        let snapshot = try XCTUnwrap(
            InputOrigin.ocr(draft).buildSnapshot(matching: car)
        )

        XCTAssertEqual(snapshot.inputFactsSource, .userConfirmedOCR)
        XCTAssertNil(snapshot.car.catalogReference)
        XCTAssertTrue(snapshot.hasConfirmedInputFacts)

        draft.thumbnailData = Data([0x89, 0x50, 0x4e, 0x47])
        let photoCar = try XCTUnwrap(draft.confirmedCarInput())
        let photoSnapshot = try XCTUnwrap(
            InputOrigin.ocr(draft).buildSnapshot(matching: photoCar)
        )
        XCTAssertEqual(photoSnapshot.inputFactsSource, .userConfirmedOCR)

        var unresolved = draft
        unresolved.reviewStates[.weightPounds] = .needsCheck
        XCTAssertNil(
            InputOrigin.ocr(unresolved).buildSnapshot(matching: photoCar)
        )
    }

    func testMissingYearCannotCrossManualOrOCRConfirmationBoundary() {
        var manual = ManualEntryDraft(car: confirmedCar())
        manual.year = nil
        XCTAssertEqual(manual.validationIssues.first, .missingYear)
        XCTAssertNil(manual.confirmedCarInput())

        var ocr = confirmedOCRDraft()
        ocr.year = nil
        XCTAssertEqual(ocr.firstUnresolvedField, .year)
        XCTAssertNil(ocr.confirmedCarInput())
    }

    func testManualSnapshotProvidesConfirmedCommunityAssociationWithoutCatalog() async throws {
        let tune = try await supportedTune(source: .userConfirmedManual)
        let association = try XCTUnwrap(
            FH6CommunityReferenceCandidateAssociation.confirmed(for: tune)
        )

        XCTAssertEqual(association.catalogID, "input-source:userConfirmedManual")
        XCTAssertTrue(association.confirmed)
        XCTAssertNil(tune.request.car.catalogReference)
        XCTAssertEqual(
            try XCTUnwrap(readyCommunityDraft().capture(candidate: association))
                .referenceCandidate,
            association
        )
    }

    func testOCRSnapshotProvidesConfirmedCommunityAssociationWithoutCatalog() async throws {
        let tune = try await supportedTune(source: .userConfirmedOCR)
        let association = try XCTUnwrap(
            FH6CommunityReferenceCandidateAssociation.confirmed(for: tune)
        )

        XCTAssertEqual(association.catalogID, "input-source:userConfirmedOCR")
        XCTAssertTrue(association.confirmed)
        XCTAssertNil(tune.request.car.catalogReference)
        XCTAssertEqual(
            try XCTUnwrap(readyCommunityDraft().capture(candidate: association))
                .referenceCandidate,
            association
        )
    }

    func testLegacyCatalogSnapshotInfersReviewedCatalogBoundary() throws {
        let selection = try catalogSelection()
        let current = selection.capabilityOnlyBuildSnapshot()
        let encoded = try JSONEncoder().encode(current)
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        object.removeValue(forKey: "inputFactsSource")
        let legacy = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(
            VehicleBuildSnapshot.self,
            from: legacy
        )

        XCTAssertEqual(decoded.inputFactsSource, .reviewedCatalog)
        XCTAssertTrue(decoded.hasConfirmedInputFacts)
        XCTAssertEqual(decoded.car.catalogReference, selection.carInput.catalogReference)
    }

    private func confirmedCar() -> CarInput {
        CarInput(
            game: .fh6,
            year: 2020,
            make: "Toyota",
            model: "Supra",
            weightPounds: 3_400,
            frontWeightPercent: 52,
            performanceIndex: 700,
            performanceClass: .a,
            drivetrain: .rwd,
            peakHorsepower: 382,
            peakTorqueFootPounds: 368
        )
    }

    private func confirmedOCRDraft() -> OCRConfirmationDraft {
        var draft = OCRConfirmationDraft(
            game: .fh6,
            year: 2020,
            make: "Toyota",
            model: "Supra",
            weightPounds: 3_400,
            frontWeightPercent: 52,
            performanceIndex: 700,
            performanceClass: .a,
            drivetrain: .rwd,
            peakHorsepower: 382,
            peakTorqueFootPounds: 368
        )
        for field in OCRConfirmationDraft.requiredFields {
            draft.evidence[field] = OCRFieldEvidence(
                rawText: field.title,
                confidence: 1
            )
            draft.confirm(field)
        }
        return draft
    }

    private func catalogSelection() throws -> CatalogCarSelection {
        SyntheticLegacyTuneFixtureFactory.selection(
            reviewedAt: Date(timeIntervalSinceReferenceDate: 42)
        )
    }

    private func supportedTune(
        source: VehicleInputFactsSource
    ) async throws -> TuneResult {
        var tune = try await SyntheticLegacyTuneFixtureFactory
            .eligibleValidationTune(capturedAt: Date(timeIntervalSince1970: 1_700_000_000))
        var snapshot = try XCTUnwrap(tune.request.buildSnapshot)
        snapshot.car.catalogReference = nil
        snapshot.car.catalogValuesModified = false
        snapshot.inputFactsSource = source
        snapshot.capabilityProfile.vehicle.catalogID = "input-source:\(source.rawValue)"
        tune.request.car = snapshot.car
        tune.request.buildSnapshot = snapshot
        XCTAssertTrue(snapshot.isValid)
        XCTAssertTrue(snapshot.hasConfirmedInputFacts)
        return tune
    }

    private func readyCommunityDraft() -> FH6CommunityReferenceTrialDraft {
        var draft = FH6CommunityReferenceTrialDraft()
        draft.kind = .youtube
        draft.contentURL = "https://www.youtube.com/watch?v=supported-flow"
        draft.publisherDisplayName = "Fixture Publisher"
        draft.courseType = .testTrack
        draft.surface = .dry
        draft.input = .controller
        draft.runs = draft.runs.map {
            .init(role: $0.role, completed: true, correctTuneConfirmed: true)
        }
        draft.outcome = .generatedPreferred
        draft.sameRouteAndConditionsConfirmed = true
        draft.sameAssistsAndInputConfirmed = true
        draft.candidateSettingsAppliedConfirmed = true
        draft.communityIdentityConfirmed = true
        draft.finalCandidateRestoredConfirmed = true
        draft.firstPartyAuthorshipConfirmed = true
        draft.localStoragePermitted = true
        return draft
    }
}
