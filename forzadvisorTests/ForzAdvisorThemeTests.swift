//
//  ForzAdvisorThemeTests.swift
//  forzadvisorTests
//
//  Verifies the shared palette and interaction-size contract.
//

import SwiftUI
import UIKit
import XCTest
@testable import forzadvisor

final class ForzAdvisorThemeTests: XCTestCase {
    func testSemanticTextColorsMeetNormalTextContrastInBothAppearances() {
        let semanticColors = [
            ForzAdvisorTheme.accent,
            ForzAdvisorTheme.warmAccent,
            ForzAdvisorTheme.warning,
            ForzAdvisorTheme.success,
            ForzAdvisorTheme.destructive
        ]

        for style in [UIUserInterfaceStyle.light, .dark] {
            let traits = UITraitCollection(userInterfaceStyle: style)
            let surface = resolved(ForzAdvisorTheme.surface, traits: traits)

            for color in semanticColors {
                XCTAssertGreaterThanOrEqual(
                    contrastRatio(resolved(color, traits: traits), surface),
                    4.5,
                    "Semantic color failed normal-text contrast in \(style) appearance"
                )
            }
        }
    }

    func testPrimaryAndSecondaryTextMeetNormalTextContrast() {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let traits = UITraitCollection(userInterfaceStyle: style)
            let surface = resolved(ForzAdvisorTheme.surface, traits: traits)

            XCTAssertGreaterThanOrEqual(
                contrastRatio(resolved(ForzAdvisorTheme.primaryText, traits: traits), surface),
                4.5
            )
            XCTAssertGreaterThanOrEqual(
                contrastRatio(resolved(ForzAdvisorTheme.secondaryText, traits: traits), surface),
                4.5
            )
        }
    }

    func testControlBoundariesAndStrongColorLabelsMeetContrast() {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let traits = UITraitCollection(userInterfaceStyle: style)
            let surface = resolved(ForzAdvisorTheme.surface, traits: traits)
            let strongText = resolved(ForzAdvisorTheme.onStrongColorText, traits: traits)

            XCTAssertGreaterThanOrEqual(
                contrastRatio(resolved(ForzAdvisorTheme.separator, traits: traits), surface),
                3
            )
            XCTAssertGreaterThanOrEqual(
                contrastRatio(strongText, resolved(ForzAdvisorTheme.accent, traits: traits)),
                4.5
            )
            XCTAssertGreaterThanOrEqual(
                contrastRatio(strongText, resolved(ForzAdvisorTheme.destructive, traits: traits)),
                4.5
            )
        }
    }

    func testSharedControlsUseAppleMinimumTouchTarget() {
        XCTAssertGreaterThanOrEqual(ForzAdvisorTheme.minimumTouchTarget, 44)
    }

    private func resolved(_ color: Color, traits: UITraitCollection) -> UIColor {
        UIColor(color).resolvedColor(with: traits)
    }

    private func contrastRatio(_ lhs: UIColor, _ rhs: UIColor) -> CGFloat {
        let first = relativeLuminance(lhs)
        let second = relativeLuminance(rhs)
        return (max(first, second) + 0.05) / (min(first, second) + 0.05)
    }

    private func relativeLuminance(_ color: UIColor) -> CGFloat {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        XCTAssertTrue(color.getRed(&red, green: &green, blue: &blue, alpha: &alpha))

        func linearized(_ component: CGFloat) -> CGFloat {
            component <= 0.03928
                ? component / 12.92
                : pow((component + 0.055) / 1.055, 2.4)
        }

        return 0.2126 * linearized(red)
            + 0.7152 * linearized(green)
            + 0.0722 * linearized(blue)
    }
}
