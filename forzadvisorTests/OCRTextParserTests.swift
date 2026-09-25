//
//  OCRTextParserTests.swift
//  forzadvisorTests
//
//  Parser coverage for converting Vision text observations into editable
//  confirmation drafts without needing camera or Vision runtime access.
//

import XCTest
@testable import forzadvisor

final class OCRTextParserTests: XCTestCase {
    func testParserExtractsRequiredPerformanceFields() {
        let draft = OCRTextParser.confirmationDraft(from: [
            OCRTextObservation(text: "Class S1 750", confidence: 0.92),
            OCRTextObservation(text: "Weight 3,340 LB", confidence: 0.88),
            OCRTextObservation(text: "Front 53.0%", confidence: 0.81),
            OCRTextObservation(text: "Drivetrain RWD", confidence: 0.94)
        ])

        XCTAssertEqual(draft.weightPounds, 3_340)
        XCTAssertEqual(draft.frontWeightPercent, 53.0)
        XCTAssertEqual(draft.performanceIndex, 750)
        XCTAssertEqual(draft.performanceClass, .s1)
        XCTAssertEqual(draft.drivetrain, .rwd)
        XCTAssertTrue(draft.fieldsNeedingReview.isEmpty)
    }

    func testParserConvertsKilogramsToPounds() {
        let draft = OCRTextParser.confirmationDraft(from: [
            OCRTextObservation(text: "Weight 1515 kg", confidence: 0.9)
        ])

        XCTAssertEqual(draft.weightPounds, 3_340)
    }

    func testParserPairsNearbyLabelsAndValues() {
        let draft = OCRTextParser.confirmationDraft(from: [
            OCRTextObservation(text: "Weight", confidence: 0.91),
            OCRTextObservation(text: "3,210 lb", confidence: 0.88),
            OCRTextObservation(text: "Front", confidence: 0.86),
            OCRTextObservation(text: "52%", confidence: 0.84),
            OCRTextObservation(text: "PI", confidence: 0.89),
            OCRTextObservation(text: "S1 842", confidence: 0.9),
            OCRTextObservation(text: "Drivetrain", confidence: 0.9),
            OCRTextObservation(text: "Rear Wheel Drive", confidence: 0.87)
        ])

        XCTAssertEqual(draft.weightPounds, 3_210)
        XCTAssertEqual(draft.frontWeightPercent, 52)
        XCTAssertEqual(draft.performanceClass, .s1)
        XCTAssertEqual(draft.performanceIndex, 842)
        XCTAssertEqual(draft.drivetrain, .rwd)
    }

    func testParserRepairsCommonForzaOCRLabelMistakes() {
        let draft = OCRTextParser.confirmationDraft(from: [
            OCRTextObservation(text: "Wait 2,998 LB", confidence: 0.82),
            OCRTextObservation(text: "Fr0nt weight 49.5%", confidence: 0.81),
            OCRTextObservation(text: "P1 A 701", confidence: 0.8),
            OCRTextObservation(text: "allwheel drive", confidence: 0.78),
            OCRTextObservation(text: "Power 480 hp", confidence: 0.93),
            OCRTextObservation(text: "Torque 410 ft-lb", confidence: 0.91)
        ])

        XCTAssertEqual(draft.weightPounds, 2_998)
        XCTAssertEqual(draft.frontWeightPercent, 49.5)
        XCTAssertEqual(draft.performanceClass, .a)
        XCTAssertEqual(draft.performanceIndex, 701)
        XCTAssertEqual(draft.drivetrain, .awd)
        XCTAssertEqual(draft.peakHorsepower, 480)
        XCTAssertEqual(draft.peakTorqueFootPounds, 410)
        XCTAssertEqual(draft.evidence[.horsepower]?.sourceUnit, .horsepower)
        XCTAssertEqual(draft.evidence[.horsepower]?.sourceValue, "480")
        XCTAssertEqual(draft.evidence[.horsepower]?.normalizedValue, "480")
        XCTAssertEqual(draft.evidence[.torque]?.sourceUnit, .poundFeet)
        XCTAssertEqual(draft.evidence[.torque]?.sourceValue, "410")
    }

    func testParserConvertsMetricPowerAndTorqueToTheDraftUnits() {
        var draft = OCRTextParser.confirmationDraft(from: [
            OCRTextObservation(text: "Power 100 kW", confidence: 0.93),
            OCRTextObservation(text: "Torque 400 Nm", confidence: 0.92)
        ])

        XCTAssertEqual(draft.peakHorsepower, 134)
        XCTAssertEqual(draft.peakTorqueFootPounds, 295)
        XCTAssertEqual(draft.evidence[.horsepower]?.rawText, "Power 100 kW")
        XCTAssertEqual(draft.evidence[.torque]?.rawText, "Torque 400 Nm")
        XCTAssertEqual(draft.evidence[.horsepower]?.sourceValue, "100")
        XCTAssertEqual(draft.evidence[.horsepower]?.sourceUnit, .kilowatts)
        XCTAssertEqual(draft.evidence[.horsepower]?.normalizedValue, "134")
        XCTAssertEqual(draft.evidence[.torque]?.sourceValue, "400")
        XCTAssertEqual(draft.evidence[.torque]?.sourceUnit, .newtonMeters)
        XCTAssertEqual(draft.evidence[.torque]?.normalizedValue, "295")
        XCTAssertTrue(draft.evidence[.horsepower]?.needsReview == true)
        XCTAssertTrue(draft.evidence[.torque]?.needsReview == true)

        fillRequiredFields(in: &draft)
        for field in OCRConfirmationDraft.requiredFields {
            draft.confirm(field)
        }
        XCTAssertEqual(draft.firstUnresolvedField, .horsepower)
        draft.confirm(.horsepower)
        XCTAssertEqual(draft.firstUnresolvedField, .torque)
        draft.confirm(.torque)
        XCTAssertNil(draft.firstUnresolvedField)
    }

    func testParserRejectsUnitlessMeasurementsAndRequiresManualCorrection() {
        var draft = OCRTextParser.confirmationDraft(from: [
            OCRTextObservation(text: "Power 480", confidence: 0.93),
            OCRTextObservation(text: "Torque 410", confidence: 0.92)
        ])

        XCTAssertNil(draft.peakHorsepower)
        XCTAssertNil(draft.peakTorqueFootPounds)
        XCTAssertEqual(draft.evidence[.horsepower]?.sourceValue, "480")
        XCTAssertEqual(draft.evidence[.horsepower]?.sourceUnit, .ambiguous)
        XCTAssertEqual(draft.evidence[.torque]?.sourceValue, "410")
        XCTAssertEqual(draft.evidence[.torque]?.sourceUnit, .ambiguous)
        XCTAssertTrue(draft.candidates(for: .horsepower).isEmpty)
        XCTAssertTrue(draft.evidence[.horsepower]?.requiresManualCorrection == true)

        fillRequiredFields(in: &draft)
        for field in OCRConfirmationDraft.requiredFields {
            draft.confirm(field)
        }
        XCTAssertEqual(draft.firstUnresolvedField, .horsepower)
        draft.confirm(.horsepower)
        XCTAssertEqual(draft.firstUnresolvedField, .horsepower)

        draft.peakHorsepower = 480
        draft.markCorrected(.horsepower)
        XCTAssertEqual(draft.firstUnresolvedField, .torque)
        draft.peakTorqueFootPounds = 410
        draft.markCorrected(.torque)
        XCTAssertNil(draft.firstUnresolvedField)
    }

    func testParserRejectsMeasurementsWithAnIncompatibleUnit() {
        let draft = OCRTextParser.confirmationDraft(from: [
            OCRTextObservation(text: "Power 300 Nm", confidence: 0.93),
            OCRTextObservation(text: "Torque 300 hp", confidence: 0.92)
        ])

        XCTAssertNil(draft.peakHorsepower)
        XCTAssertNil(draft.peakTorqueFootPounds)
        XCTAssertEqual(draft.evidence[.horsepower]?.sourceUnit, .ambiguous)
        XCTAssertEqual(draft.evidence[.torque]?.sourceUnit, .ambiguous)
        XCTAssertTrue(draft.evidence[.horsepower]?.requiresManualCorrection == true)
        XCTAssertTrue(draft.evidence[.torque]?.requiresManualCorrection == true)
    }

    func testParserRejectsMetricConversionWhenOCRAlternativesDisagreeOnUnit() {
        let draft = OCRTextParser.confirmationDraft(from: [
            OCRTextObservation(
                text: "Power 100 kW",
                confidence: 0.93,
                candidates: ["Power 100 hp"]
            )
        ])

        XCTAssertNil(draft.peakHorsepower)
        XCTAssertEqual(draft.evidence[.horsepower]?.sourceUnit, .ambiguous)
        XCTAssertNil(draft.evidence[.horsepower]?.normalizedValue)
        XCTAssertTrue(draft.evidence[.horsepower]?.requiresManualCorrection == true)
    }

    func testParserRejectsMeasurementsWhenOCRAlternativesDisagreeOnValue() {
        let draft = OCRTextParser.confirmationDraft(from: [
            OCRTextObservation(
                text: "Power 100 kW",
                confidence: 0.93,
                candidates: ["Power 110 kW"]
            ),
            OCRTextObservation(
                text: "Torque 400 Nm",
                confidence: 0.92,
                candidates: ["Torque 410 Nm"]
            )
        ])

        XCTAssertNil(draft.peakHorsepower)
        XCTAssertNil(draft.peakTorqueFootPounds)
        XCTAssertEqual(draft.evidence[.horsepower]?.sourceUnit, .ambiguous)
        XCTAssertEqual(draft.evidence[.torque]?.sourceUnit, .ambiguous)
        XCTAssertNil(draft.evidence[.horsepower]?.normalizedValue)
        XCTAssertNil(draft.evidence[.torque]?.normalizedValue)
        XCTAssertTrue(draft.evidence[.horsepower]?.requiresManualCorrection == true)
        XCTAssertTrue(draft.evidence[.torque]?.requiresManualCorrection == true)
    }

    func testParserRejectsConflictingMeasurementValuesAcrossObservations() {
        let draft = OCRTextParser.confirmationDraft(from: [
            OCRTextObservation(text: "Power 480 hp", confidence: 0.93),
            OCRTextObservation(text: "Power 520 hp", confidence: 0.91),
            OCRTextObservation(text: "Torque 400 lb-ft", confidence: 0.92),
            OCRTextObservation(text: "Torque 430 lb-ft", confidence: 0.9)
        ])

        XCTAssertNil(draft.peakHorsepower)
        XCTAssertNil(draft.peakTorqueFootPounds)
        XCTAssertEqual(draft.evidence[.horsepower]?.sourceUnit, .ambiguous)
        XCTAssertEqual(draft.evidence[.torque]?.sourceUnit, .ambiguous)
        XCTAssertTrue(draft.evidence[.horsepower]?.requiresManualCorrection == true)
        XCTAssertTrue(draft.evidence[.torque]?.requiresManualCorrection == true)
    }

    func testParserValidatesMetricMeasurementRangeAfterConversion() {
        let draft = OCRTextParser.confirmationDraft(from: [
            OCRTextObservation(text: "Power 1800 kW", confidence: 0.93),
            OCRTextObservation(text: "Torque 3390 Nm", confidence: 0.92)
        ])

        XCTAssertEqual(draft.peakHorsepower, 2_414)
        XCTAssertNil(draft.peakTorqueFootPounds)
        XCTAssertNil(draft.evidence[.torque])
    }

    func testParserFlagsLowConfidenceRequiredFieldsForReview() {
        let draft = OCRTextParser.confirmationDraft(from: [
            OCRTextObservation(text: "Class A 701", confidence: 0.58),
            OCRTextObservation(text: "Weight 2998 lb", confidence: 0.95),
            OCRTextObservation(text: "Front 49%", confidence: 0.57),
            OCRTextObservation(text: "AWD", confidence: 0.8)
        ])

        XCTAssertEqual(draft.performanceClass, .a)
        XCTAssertEqual(draft.performanceIndex, 701)
        XCTAssertEqual(draft.drivetrain, .awd)
        XCTAssertEqual(draft.fieldsNeedingReview, [.frontWeightPercent, .performanceIndex, .performanceClass])
    }

    func testConfirmedCarInputRequiresEditableNameAndAllRequiredValues() {
        var draft = OCRTextParser.confirmationDraft(from: [
            OCRTextObservation(text: "S1 750", confidence: 0.92),
            OCRTextObservation(text: "Weight 3340 lb", confidence: 0.92),
            OCRTextObservation(text: "53% front", confidence: 0.92),
            OCRTextObservation(text: "RWD", confidence: 0.92)
        ])

        XCTAssertNil(draft.confirmedCarInput())

        draft.year = 2019
        draft.make = "Toyota"
        draft.model = "Supra"

        let car = draft.confirmedCarInput()
        XCTAssertEqual(car?.displayName, "2019 Toyota Supra")
        XCTAssertEqual(car?.performanceClass, .s1)
    }

    func testManualFallbackPreservesParsedValues() {
        let draft = OCRTextParser.confirmationDraft(from: [
            OCRTextObservation(text: "Weight 3600 lb", confidence: 0.9),
            OCRTextObservation(text: "Front 51%", confidence: 0.9)
        ])

        let fallback = draft.manualEntryFallback()

        XCTAssertEqual(fallback.weightPounds, 3_600)
        XCTAssertEqual(fallback.frontWeightPercent, 51)
        XCTAssertEqual(fallback.make, "")
        XCTAssertEqual(fallback.model, "")
        XCTAssertNil(fallback.performanceIndex)
        XCTAssertNil(fallback.performanceClass)
        XCTAssertNil(fallback.drivetrain)
        XCTAssertNil(fallback.confirmedCarInput())
        XCTAssertTrue(fallback.validationIssues.contains(.missingName))
        XCTAssertTrue(fallback.validationIssues.contains(.missingPerformanceIndex))
        XCTAssertTrue(fallback.validationIssues.contains(.missingPerformanceClass))
        XCTAssertTrue(fallback.validationIssues.contains(.missingDrivetrain))
    }

    func testManualFallbackClearsFieldsStillNeedingOCRReview() {
        var draft = OCRConfirmationDraft(
            year: 2020,
            make: "Toyota",
            model: "Supra",
            weightPounds: 3_400,
            frontWeightPercent: 52,
            performanceIndex: 700,
            performanceClass: .a,
            drivetrain: .rwd,
            peakHorsepower: 400,
            peakTorqueFootPounds: 350
        )
        for field in OCRConfirmationDraft.requiredFields + [.horsepower, .torque] {
            draft.evidence[field] = OCRFieldEvidence(
                rawText: field.title,
                confidence: 0.4
            )
        }
        draft.confirm(.weightPounds)
        draft.markCorrected(.performanceClass)
        draft.confirm(.horsepower)

        let fallback = draft.manualEntryFallback()
        XCTAssertEqual(fallback.game, .fh6)
        XCTAssertEqual(fallback.year, 2020)
        XCTAssertEqual(fallback.make, "Toyota")
        XCTAssertEqual(fallback.model, "Supra")
        XCTAssertEqual(fallback.weightPounds, 3_400)
        XCTAssertNil(fallback.frontWeightPercent)
        XCTAssertNil(fallback.performanceIndex)
        XCTAssertEqual(fallback.performanceClass, .a)
        XCTAssertNil(fallback.drivetrain)
        XCTAssertEqual(fallback.peakHorsepower, 400)
        XCTAssertNil(fallback.peakTorqueFootPounds)
    }

    func testConfirmedCarInputDropsOptionalValuesStillNeedingOCRReview() {
        var draft = OCRConfirmationDraft(
            year: 2020,
            make: "Toyota",
            model: "Supra",
            weightPounds: 3_400,
            frontWeightPercent: 52,
            performanceIndex: 700,
            performanceClass: .a,
            drivetrain: .rwd,
            peakHorsepower: 400,
            peakTorqueFootPounds: 350
        )
        draft.reviewStates[.horsepower] = .needsCheck
        draft.reviewStates[.torque] = .needsCheck

        let car = draft.confirmedCarInput()

        XCTAssertNotNil(car)
        XCTAssertNil(car?.peakHorsepower)
        XCTAssertNil(car?.peakTorqueFootPounds)
    }

    func testParserRejectsAmbiguousAndUnsupportedPowerTorqueUnits() {
        let draft = OCRTextParser.confirmationDraft(from: [
            OCRTextObservation(text: "Power 350 kW", confidence: 0.95),
            OCRTextObservation(text: "Torque 500 Nm", confidence: 0.95),
            OCRTextObservation(text: "Power 480", confidence: 0.95),
            OCRTextObservation(text: "Torque 410", confidence: 0.95)
        ])

        XCTAssertNil(draft.peakHorsepower)
        XCTAssertNil(draft.peakTorqueFootPounds)
        XCTAssertTrue(draft.candidates(for: .horsepower).isEmpty)
        XCTAssertTrue(draft.candidates(for: .torque).isEmpty)
    }

    func testSelectedGameControlsOCRValidationAndSurvivesWorkflowTransitions() throws {
        var draft = OCRConfirmationDraft()
        draft.game = .fh5
        draft.year = 2020
        draft.make = "Toyota"
        draft.model = "GR Supra"
        draft.weightPounds = 3_397
        draft.frontWeightPercent = 51
        draft.performanceClass = .r
        draft.performanceIndex = 950
        draft.drivetrain = .rwd

        XCTAssertNil(draft.confirmedCarInput())

        draft.performanceClass = .a
        draft.performanceIndex = 731
        let input = try XCTUnwrap(draft.confirmedCarInput())
        XCTAssertEqual(input.game, .fh5)
        XCTAssertEqual(draft.manualEntryFallback().game, .fh5)

        guard case .ocrReview(let restoredDraft) = InputOrigin.ocr(draft).previousStep(thumbnailData: nil) else {
            return XCTFail("OCR origin did not restore OCR review.")
        }
        XCTAssertEqual(restoredDraft.game, .fh5)
        XCTAssertEqual(restoredDraft.confirmedCarInput()?.game, .fh5)
    }

    private func fillRequiredFields(in draft: inout OCRConfirmationDraft) {
        draft.year = 2020
        draft.make = "Toyota"
        draft.model = "Supra"
        draft.weightPounds = 3_400
        draft.frontWeightPercent = 51
        draft.performanceClass = .a
        draft.performanceIndex = 650
        draft.drivetrain = .rwd
    }
}
