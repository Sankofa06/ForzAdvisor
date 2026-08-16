//
//  ForzAdvisorFeedbackViews.swift
//  forzadvisor
//
//  Shared controls for selection, inline feedback, and reversible actions.
//

import SwiftUI

enum ForzAdvisorMessageKind: String, CaseIterable, Sendable {
    case information
    case success
    case warning
    case error

    var title: String {
        switch self {
        case .information: "Information"
        case .success: "Success"
        case .warning: "Warning"
        case .error: "Error"
        }
    }

    var systemImage: String {
        switch self {
        case .information: "info.circle.fill"
        case .success: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .error: "xmark.octagon.fill"
        }
    }

    var tint: Color {
        switch self {
        case .information: ForzAdvisorTheme.accent
        case .success: ForzAdvisorTheme.success
        case .warning: ForzAdvisorTheme.warning
        case .error: ForzAdvisorTheme.destructive
        }
    }
}

struct ForzAdvisorInlineMessage: View {
    let title: String
    var message: String?
    var kind: ForzAdvisorMessageKind = .information

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: kind.systemImage)
                .foregroundStyle(kind.tint)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ForzAdvisorTheme.primaryText)

                if let message, !message.isEmpty {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(ForzAdvisorTheme.secondaryText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(kind.tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(kind.tint, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(kind.title): \(title)")
        .accessibilityValue(message ?? "")
    }
}

struct ForzAdvisorInlineValidation: View {
    let fieldName: String
    let message: String

    var body: some View {
        ForzAdvisorInlineMessage(
            title: "Check \(fieldName)",
            message: message,
            kind: .error
        )
        .accessibilityIdentifier("validation.\(fieldName.accessibilityIdentifierComponent)")
    }
}

struct ForzAdvisorUndoBanner: View {
    let message: String
    let undo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.uturn.backward.circle.fill")
                .foregroundStyle(ForzAdvisorTheme.accent)
                .accessibilityHidden(true)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(ForzAdvisorTheme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button("Undo", action: undo)
                .buttonStyle(.bordered)
                .forzAdvisorMinimumTouchTarget()
                .accessibilityHint("Restores the previous state")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(ForzAdvisorTheme.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(ForzAdvisorTheme.separator, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(message)
    }
}

struct ForzAdvisorSelectionButton: View {
    let title: String
    var subtitle: String?
    var systemImage: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.title3.weight(.semibold))
                        .accessibilityHidden(true)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.body.weight(.semibold))
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(ForzAdvisorTheme.secondaryText)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .accessibilityHidden(true)
            }
            .foregroundStyle(isSelected ? ForzAdvisorTheme.accent : ForzAdvisorTheme.primaryText)
            .padding(.horizontal, 12)
            .forzAdvisorMinimumTouchTarget()
            .background(ForzAdvisorTheme.surface, in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? ForzAdvisorTheme.accent : ForzAdvisorTheme.separator,
                        lineWidth: isSelected ? 2 : 1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint(isSelected ? "Currently selected" : "Selects this option")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

enum ForzAdvisorActionKind: Equatable, Sendable {
    case primary
    case secondary
    case destructive
}

struct ForzAdvisorActionButtonStyle: ButtonStyle {
    var kind: ForzAdvisorActionKind = .primary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity)
            .forzAdvisorMinimumTouchTarget()
            .padding(.horizontal, 12)
            .foregroundStyle(foregroundColor)
            .background(backgroundColor.opacity(configuration.isPressed ? 0.78 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                if kind == .secondary {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(ForzAdvisorTheme.accent, lineWidth: 1)
                }
            }
    }

    private var foregroundColor: Color {
        kind == .secondary
            ? ForzAdvisorTheme.accent
            : ForzAdvisorTheme.onStrongColorText
    }

    private var backgroundColor: Color {
        switch kind {
        case .primary: ForzAdvisorTheme.accent
        case .secondary: ForzAdvisorTheme.surface
        case .destructive: ForzAdvisorTheme.destructive
        }
    }
}

private extension String {
    var accessibilityIdentifierComponent: String {
        lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
    }
}
