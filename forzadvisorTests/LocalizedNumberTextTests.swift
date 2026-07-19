//
//  LocalizedNumberTextTests.swift
//  forzadvisorTests
//

import XCTest
@testable import forzadvisor

final class LocalizedNumberTextTests: XCTestCase {
    private let germanLocale = Locale(identifier: "de_DE")
    private let usLocale = Locale(identifier: "en_US")

    func testGermanFormattingAndParsingUseDecimalComma() throws {
        let text = LocalizedNumberText.format(29, fractionDigits: 1, locale: germanLocale)

        XCTAssertEqual(text, "29,0")
        XCTAssertEqual(try XCTUnwrap(LocalizedNumberText.parse(text, locale: germanLocale)), 29, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(LocalizedNumberText.parse("53,5", locale: germanLocale)), 53.5, accuracy: 0.0001)
    }

    func testGermanParsingRecognizesLocalizedGroupingSeparator() throws {
        XCTAssertEqual(try XCTUnwrap(LocalizedNumberText.parse("1.200", locale: germanLocale)), 1_200, accuracy: 0.0001)
    }

    func testGermanParsingFallsBackToInvariantDecimalDot() throws {
        XCTAssertEqual(try XCTUnwrap(LocalizedNumberText.parse("53.25", locale: germanLocale)), 53.25, accuracy: 0.0001)
    }

    func testUSFormattingAndParsingPreserveExistingBehavior() throws {
        XCTAssertEqual(LocalizedNumberText.format(29, fractionDigits: 1, locale: usLocale), "29.0")
        XCTAssertEqual(LocalizedNumberText.format(1_200, fractionDigits: 0, locale: usLocale), "1,200")
        XCTAssertEqual(try XCTUnwrap(LocalizedNumberText.parse("1,200", locale: usLocale)), 1_200, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(LocalizedNumberText.parse("53.5", locale: usLocale)), 53.5, accuracy: 0.0001)
    }
}
