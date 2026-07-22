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

    func testVerifiedAndBuildPlanExportsFailClosedWithoutProjectionEvidence() async throws {
        let raw = try await LocalSampleTuneProvider().generateTune(
            for: TuneRequest(car: SampleTuningData.starterCar, discipline: .road)
        )

        XCTAssertNil(TuneClipboardFormatter.verifiedSettingsText(for: raw))
        XCTAssertNil(TuneClipboardFormatter.buildPlanText(for: raw))
    }

    func testVerifiedExportReprojectsAndDropsInjectedLines() throws {
        let catalog = try BundledCarCatalog.load().get()
        let entry = try XCTUnwrap(catalog.entries.first { $0.id == "fh6-2020-toyota-gr-supra" })
        let selection = catalog.selection(for: entry)
        var snapshot = selection.capabilityOnlyBuildSnapshot()
        let evidence = TuneDataProvenance(
            id: "rules.fh6.clipboard-fixture",
            game: .fh6,
            gameBuildVersion: nil,
            scope: .gameGlobal,
            source: "forzadvisor.test-fixture",
            version: "1",
            capturedAt: Date(timeIntervalSinceReferenceDate: 1),
            confidence: .high,
            usagePermission: .permitted
        )
        snapshot.evidenceSources = [evidence]
        snapshot.constraints = [TuneFieldConstraint(
            field: .frontTirePressure,
            minimum: 15,
            maximum: 40,
            step: 0.1,
            defaultValue: 30,
            currentValue: 30,
            unit: .psi,
            scope: .gameGlobal,
            verification: .productionEligible,
            evidenceIDs: [evidence.id]
        )]
        let request = TuneRequest(car: selection.carInput, discipline: .road, buildSnapshot: snapshot)
        let candidate = TuneResult(
            request: request,
            sections: [TuneSection(title: "Tires", symbolName: "circle.dashed", lines: [
                TuneLine(label: "Front pressure", value: "30.0", unit: "PSI", fieldID: .frontTirePressure)
            ])],
            notes: TuneNotes(bias: "", ifPushesWide: "", ifSnapsOnLift: "", retuneTrigger: "")
        )
        var projected = TuneOutputProjector().project(candidate)
        projected.sections[0].lines.append(
            TuneLine(label: "Injected rear", value: "999.9", unit: "PSI", fieldID: .rearTirePressure)
        )

        let export = try XCTUnwrap(TuneClipboardFormatter.verifiedSettingsText(for: projected))
        XCTAssertTrue(export.contains("Front tire pressure: 30.0 PSI"))
        XCTAssertFalse(export.contains("999.9"))
        XCTAssertFalse(export.contains("Injected rear"))
    }
}
