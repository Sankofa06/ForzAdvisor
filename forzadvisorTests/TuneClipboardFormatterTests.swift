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
        XCTAssertTrue(text.contains("\nProvider: Offline formulas - Generated entirely on this device with deterministic formulas.\n"))
        XCTAssertTrue(text.contains("\nTires\nFront pressure:"))
        XCTAssertTrue(text.contains("\nDifferential\nAccel:"))
        XCTAssertTrue(text.contains("\nNotes\nBias:"))
        XCTAssertTrue(text.contains("\nGarage notes\nLower rear tire pressure after long downhill runs."))
    }

    func testFullTuneTextIncludesFallbackProviderStatus() async throws {
        let tune = try await LocalSampleTuneProvider().generateTune(
            for: TuneRequest(car: SampleTuningData.starterCar, discipline: .road)
        )
        .withProviderInfo(.fallback(requestedMode: .anthropicAPI, reason: .missingAPIKey))

        let text = TuneClipboardFormatter.fullTuneText(for: tune)

        XCTAssertTrue(text.contains(
            "\nProvider: Offline formulas fallback - API key was not configured, so offline formulas generated this tune.\n"
        ))
    }

    func testFullTuneTextUsesLegacyProviderCopyWhenProviderInfoIsMissing() {
        let tune = TuneResult(
            request: TuneRequest(car: SampleTuningData.starterCar, discipline: .road),
            sections: [],
            notes: TuneNotes(
                bias: "Legacy tune.",
                ifPushesWide: "Add front grip.",
                ifSnapsOnLift: "Calm rear rotation.",
                retuneTrigger: "Retune after major changes."
            ),
            providerInfo: nil
        )

        let text = TuneClipboardFormatter.fullTuneText(for: tune)

        XCTAssertTrue(text.contains(
            "\nProvider: Provider not recorded - This saved tune was created before provider tracking.\n"
        ))
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
