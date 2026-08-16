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
        let snapshot = try BundledCarCatalog.load().get()
        let entry = try XCTUnwrap(snapshot.entries.first)
        return snapshot.selection(for: entry)
    }
}
