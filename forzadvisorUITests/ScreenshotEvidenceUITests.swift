import XCTest
import UIKit

final class ScreenshotEvidenceUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSupportedManualFlowScreenshotEvidence() {
        let app = launchApp()

        assertEmptyGarage(in: app)
        capture("01-empty-garage-light", in: app)

        openNewTune(in: app)
        capture("02-new-tune-source-light", in: app)

        openValidationReadyManualEntry(in: app)
        capture("03-manual-entry-validation-ready-light", in: app)

        openDisciplinePreflight(in: app)
        capture("04-discipline-provider-preflight-light", in: app)

        openResult(in: app)
        capture("05-result-top-light", in: app)

        let availableSettings = app.descendants(matching: .any)[
            "availableSettingsSection"
        ].firstMatch
        scrollToHittable(availableSettings, in: app)
        XCTAssertTrue(
            app.staticTexts[
                "Numeric values are withheld until more game evidence is confirmed. This plan keeps the next in-game step explicit."
            ].waitForExistence(timeout: 5)
        )
        capture("06-result-available-settings-light", in: app)

        let evidenceSummary = app.staticTexts.matching(
            NSPredicate(
                format: "label == %@",
                "Optional Validation & Research"
            )
        ).firstMatch
        scrollToHittable(evidenceSummary, in: app)
        let evidenceExplanation = app.staticTexts.matching(
            NSPredicate(
                format: "label == %@",
                "Use Evidence Hub later if you want to record on-device observations, choose future reuse, or review shared evidence. It never changes available settings automatically."
            )
        ).firstMatch
        scrollToHittable(evidenceExplanation, in: app)
        capture("07-result-evidence-summary-light", in: app)

        saveResult(in: app)
        let openEvidenceHub = app.buttons["openTuneEvidenceHubButton"]
        scrollToHittable(openEvidenceHub, in: app)
        openEvidenceHub.tap()

        let evidenceHub = app.descendants(matching: .any)["tuneEvidenceHub"]
            .firstMatch
        XCTAssertTrue(evidenceHub.waitForExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["Evidence Hub"].exists)
        capture("08-evidence-hub-light", in: app)
    }

    @MainActor
    func testSettingsAndStepGuideScreenshotEvidence() {
        let app = launchApp()
        assertEmptyGarage(in: app)

        let settings = app.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.descendants(matching: .any)["providerPreference-offlineFormula"]
                .firstMatch.waitForExistence(timeout: 5)
        )
        capture("09-settings-provider-card-light", in: app)

        app.navigationBars["Settings"].buttons["Done"].tap()
        let stepGuide = app.buttons["garageStepGuideButton"]
        XCTAssertTrue(stepGuide.waitForExistence(timeout: 5))
        stepGuide.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["copilotSheet"]
                .firstMatch.waitForExistence(timeout: 5)
        )
        XCTAssertTrue(app.staticTexts[
            "Local deterministic guidance. No model, network, or transcript."
        ].exists)
        for label in [
            "Next step",
            "What can I trust?",
            "What is missing?",
            "Privacy"
        ] {
            XCTAssertTrue(app.buttons[label].exists)
        }
        capture("10-step-guide-choices-light", in: app)
    }

    @MainActor
    func testDarkModeGarageNewTuneAndResultScreenshotEvidence() {
        let app = launchApp(arguments: ["-ui-test-dark-appearance"])

        assertEmptyGarage(in: app)
        assertDarkAppearanceRendered(in: app)
        capture("11-empty-garage-dark", in: app)
        openNewTune(in: app)
        capture("12-new-tune-source-dark", in: app)
        openValidationReadyManualEntry(in: app)
        openDisciplinePreflight(in: app)
        openResult(in: app)
        capture("13-result-top-dark", in: app)
    }

    @MainActor
    func testAccessibilityXXXLGarageNewTuneAndResultScreenshotEvidence() {
        let app = launchApp(arguments: ["-ui-test-accessibility-xxxl"])

        assertEmptyGarage(in: app)
        capture("14-empty-garage-accessibility-xxxl", in: app)
        openNewTune(in: app)
        capture("15-new-tune-source-accessibility-xxxl", in: app)
        openValidationReadyManualEntry(in: app)
        openDisciplinePreflight(in: app, verifyProviderLabels: false)
        openResult(in: app)
        capture("16-result-top-accessibility-xxxl", in: app)

        let withheldTitle = app.staticTexts["withheldSettingsTitle"]
        let resultList = app.collectionViews.firstMatch
        let scrollStart = resultList.coordinate(
            withNormalizedOffset: CGVector(dx: 0.5, dy: 0.72)
        )
        let scrollEnd = resultList.coordinate(
            withNormalizedOffset: CGVector(dx: 0.5, dy: 0.68)
        )
        // The target follows the oversized setup-plan description. Small,
        // slow drags reveal it without centering the whole section or
        // flinging past the row.
        for _ in 0..<24 where !withheldTitle.exists {
            scrollStart.press(
                forDuration: 0.05,
                thenDragTo: scrollEnd,
                withVelocity: .slow,
                thenHoldForDuration: 0
            )
        }

        XCTAssertTrue(withheldTitle.waitForExistence(timeout: 5))
        centerInInteractionViewport(withheldTitle, using: resultList, in: app)
        XCTAssertTrue(
            withheldTitle.isHittable,
            "The withheld-settings title should be visible in the XXXL result screenshot."
        )
        XCTAssertEqual(
            withheldTitle.label,
            "Settings withheld — more game evidence needed"
        )
        XCTAssertGreaterThan(
            withheldTitle.frame.height,
            80,
            "The withheld-settings title should wrap at XXXL text size."
        )
        capture("17-result-withheld-settings-title-accessibility-xxxl", in: app)

        let withheldExplanation = app.staticTexts["withheldSettingsExplanation"]
        scrollToHittable(withheldExplanation, in: app)
        XCTAssertTrue(
            withheldExplanation.isHittable,
            "The withheld-settings explanation should be visible in its XXXL result screenshot."
        )
        XCTAssertEqual(
            withheldExplanation.label,
            "Use the setup plan and confirm the missing parts or tuning-menu ranges in game. Then generate again when the evidence is ready."
        )
        capture("18-result-withheld-settings-explanation-accessibility-xxxl", in: app)
    }

    @MainActor
    private func assertDarkAppearanceRendered(
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let image = app.screenshot().image.cgImage else {
            XCTFail(
                "The app screenshot did not contain a CGImage.",
                file: file,
                line: line
            )
            return
        }

        let sampleX = image.width / 100
        let sampleY = image.height / 2
        var pixel = [UInt8](repeating: 0, count: 4)
        let sampledColor = pixel.withUnsafeMutableBytes { bytes
            -> (red: UInt8, green: UInt8, blue: UInt8)? in
            guard let data = bytes.baseAddress,
                  let context = CGContext(
                    data: data,
                    width: 1,
                    height: 1,
                    bitsPerComponent: 8,
                    bytesPerRow: 4,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo:
                        CGImageAlphaInfo.premultipliedLast.rawValue
                        | CGBitmapInfo.byteOrder32Big.rawValue
                  )
            else {
                return nil
            }

            context.translateBy(
                x: -CGFloat(sampleX),
                y: -CGFloat(sampleY)
            )
            context.draw(
                image,
                in: CGRect(
                    x: 0,
                    y: 0,
                    width: CGFloat(image.width),
                    height: CGFloat(image.height)
                )
            )
            return (bytes[0], bytes[1], bytes[2])
        }

        guard let sampledColor else {
            XCTFail(
                "The app screenshot background pixel could not be read.",
                file: file,
                line: line
            )
            return
        }

        let luminance =
            0.2126 * Double(sampledColor.red) / 255
            + 0.7152 * Double(sampledColor.green) / 255
            + 0.0722 * Double(sampledColor.blue) / 255
        XCTAssertLessThan(
            luminance,
            0.25,
            "The captured screen background should use the dark palette.",
            file: file,
            line: line
        )
    }

}
