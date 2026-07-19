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
}
