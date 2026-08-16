//
//  ForzAdvisorTheme.swift
//  forzadvisor
//
//  Shared SwiftUI theme primitives for the garage, capture, tuning, and
//  settings screens. Views import these helpers to keep the visual language
//  consistent without changing workflow ownership.
//

import SwiftUI
import UIKit

enum ForzAdvisorTheme {
    static let minimumTouchTarget: CGFloat = 44

    static let accent = adaptive(
        light: UIColor(red: 0.00, green: 0.38, blue: 0.36, alpha: 1),
        dark: UIColor(red: 0.35, green: 0.85, blue: 0.81, alpha: 1)
    )
    static let warmAccent = adaptive(
        light: UIColor(red: 0.70, green: 0.20, blue: 0.055, alpha: 1),
        dark: UIColor(red: 1.00, green: 0.58, blue: 0.32, alpha: 1)
    )
    static let warning = adaptive(
        light: UIColor(red: 0.49, green: 0.27, blue: 0.00, alpha: 1),
        dark: UIColor(red: 1.00, green: 0.72, blue: 0.29, alpha: 1)
    )
    static let success = adaptive(
        light: UIColor(red: 0.07, green: 0.42, blue: 0.20, alpha: 1),
        dark: UIColor(red: 0.39, green: 0.84, blue: 0.55, alpha: 1)
    )
    static let destructive = adaptive(
        light: UIColor(red: 0.70, green: 0.10, blue: 0.08, alpha: 1),
        dark: UIColor(red: 1.00, green: 0.51, blue: 0.48, alpha: 1)
    )
    static let primaryText = adaptive(
        light: UIColor(red: 0.07, green: 0.08, blue: 0.08, alpha: 1),
        dark: UIColor(red: 0.95, green: 0.97, blue: 0.96, alpha: 1)
    )
    static let secondaryText = adaptive(
        light: UIColor(red: 0.23, green: 0.29, blue: 0.28, alpha: 1),
        dark: UIColor(red: 0.73, green: 0.79, blue: 0.77, alpha: 1)
    )
    static let onStrongColorText = adaptive(
        light: .white,
        dark: UIColor(red: 0.04, green: 0.055, blue: 0.05, alpha: 1)
    )

    static let screenBackground = Color(uiColor: UIColor { traits in
        if traits.userInterfaceStyle == .dark {
            return UIColor(red: 0.05, green: 0.055, blue: 0.065, alpha: 1)
        } else {
            return UIColor(red: 0.95, green: 0.965, blue: 0.955, alpha: 1)
        }
    })

    static let surface = Color(uiColor: UIColor { traits in
        if traits.userInterfaceStyle == .dark {
            return UIColor(red: 0.095, green: 0.10, blue: 0.115, alpha: 1)
        } else {
            return UIColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 1)
        }
    })

    static let mutedSurface = Color(uiColor: UIColor { traits in
        if traits.userInterfaceStyle == .dark {
            return UIColor(red: 0.13, green: 0.135, blue: 0.15, alpha: 1)
        } else {
            return UIColor(red: 0.90, green: 0.93, blue: 0.92, alpha: 1)
        }
    })

    static let separator = Color(uiColor: UIColor { traits in
        if traits.userInterfaceStyle == .dark {
            return UIColor(red: 0.41, green: 0.46, blue: 0.44, alpha: 1)
        } else {
            return UIColor(red: 0.46, green: 0.51, blue: 0.49, alpha: 1)
        }
    })

    static let heroRowBackground = LinearGradient(
        colors: [
            accent.opacity(0.18),
            warmAccent.opacity(0.12),
            surface
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static func disciplineColor(_ discipline: DrivingDiscipline) -> Color {
        switch discipline {
        case .road: accent
        case .touge: warmAccent
        case .drift:
            adaptive(
                light: UIColor(red: 0.40, green: 0.17, blue: 0.55, alpha: 1),
                dark: UIColor(red: 0.82, green: 0.58, blue: 0.96, alpha: 1)
            )
        case .dirt:
            adaptive(
                light: UIColor(red: 0.36, green: 0.28, blue: 0.06, alpha: 1),
                dark: UIColor(red: 0.88, green: 0.75, blue: 0.39, alpha: 1)
            )
        case .crossCountry: success
        case .drag: destructive
        }
    }

    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}

struct ForzAdvisorScreenChrome: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(ForzAdvisorTheme.screenBackground.ignoresSafeArea())
            .tint(ForzAdvisorTheme.accent)
    }
}

extension View {
    func forzAdvisorScreenChrome() -> some View {
        modifier(ForzAdvisorScreenChrome())
    }

    func forzAdvisorRowBackground() -> some View {
        listRowBackground(ForzAdvisorTheme.surface)
    }

    func forzAdvisorMinimumTouchTarget() -> some View {
        frame(
            minWidth: ForzAdvisorTheme.minimumTouchTarget,
            minHeight: ForzAdvisorTheme.minimumTouchTarget
        )
        .contentShape(Rectangle())
    }
}

struct ForzAdvisorIcon: View {
    let systemName: String
    var tint: Color = ForzAdvisorTheme.accent
    var size: CGFloat = 34

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tint.opacity(0.15))

            Image(systemName: systemName)
                .font(.system(size: max(size * 0.45, 14), weight: .semibold))
                .foregroundStyle(tint)
        }
        .frame(width: size, height: size)
    }
}

struct ForzAdvisorScreenHeader: View {
    let title: String
    let subtitle: String
    let systemImage: String
    var tint: Color = ForzAdvisorTheme.accent

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ForzAdvisorIcon(systemName: systemImage, tint: tint, size: 40)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.title2.weight(.bold))
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 6)
    }
}

struct ForzAdvisorPill: View {
    let title: String
    var tint: Color = ForzAdvisorTheme.accent

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(tint.opacity(0.13), in: Capsule())
    }
}
