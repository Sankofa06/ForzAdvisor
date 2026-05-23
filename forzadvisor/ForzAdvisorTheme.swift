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
    static let accent = Color(red: 0.00, green: 0.62, blue: 0.58)
    static let warmAccent = Color(red: 0.95, green: 0.42, blue: 0.17)
    static let warning = Color(red: 0.93, green: 0.53, blue: 0.11)
    static let success = Color(red: 0.20, green: 0.62, blue: 0.38)

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
            return UIColor(white: 1, alpha: 0.09)
        } else {
            return UIColor(white: 0, alpha: 0.08)
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
        case .drift: Color(red: 0.73, green: 0.28, blue: 0.70)
        case .dirt: Color(red: 0.58, green: 0.47, blue: 0.22)
        case .crossCountry: Color(red: 0.24, green: 0.57, blue: 0.30)
        case .drag: Color(red: 0.78, green: 0.18, blue: 0.16)
        }
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
