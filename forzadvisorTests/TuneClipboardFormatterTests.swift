//
//  TuneClipboardFormatterTests.swift
//  forzadvisorTests
//
//  Verifies the pasteboard export text used by the tune result screen remains
//  deterministic and easy to scan outside the app.
//

import XCTest
@testable import forzadvisor

final class TuneClipboardFormatterTests: XCTestCase {
    func testFullTuneTextIncludesHeaderSectionsAndNotes() async throws {
        let tune = try await LocalSampleTuneProvider().generateTune(
            for: TuneRequest(car: SampleTuningData.starterCar, discipline: .touge)
        )

        let text = TuneClipboardFormatter.fullTuneText(
            for: tune,
            playerNotes: "Lower rear tire pressure after long downhill runs."
        )

        XCTAssertTrue(text.hasPrefix("2019 Toyota Supra\nTouge | S1 750 | RWD"))
        XCTAssertTrue(text.contains("\nTires\nFront pressure:"))
        XCTAssertTrue(text.contains("\nDifferential\nAccel:"))
        XCTAssertTrue(text.contains("\nNotes\nBias:"))
        XCTAssertTrue(text.contains("\nGarage notes\nLower rear tire pressure after long downhill runs."))
    }

    func testSectionTextDoesNotAddTrailingSpaceForBlankUnits() {
        let section = TuneSection(title: "Gearing", symbolName: "gearshape.2", lines: [
            TuneLine(label: "Final drive", value: "4.05", unit: "", detail: nil),
            TuneLine(label: "Front pressure", value: "29.0", unit: "PSI", detail: nil)
        ])

        XCTAssertEqual(
            TuneClipboardFormatter.sectionText(for: section),
            """
            Gearing
            Final drive: 4.05
            Front pressure: 29.0 PSI
            """
        )
    }
}
