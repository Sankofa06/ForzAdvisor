//
//  ForzaGamePicker.swift
//  forzadvisor
//
//  Shared explicit game selector for editable car-input workflows.
//

import SwiftUI

struct ForzaGamePicker: View {
    @Binding var selection: ForzaGame
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let accessibilityPrefix: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Game")
                .font(.subheadline)

            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: 8))
                : AnyLayout(HStackLayout(spacing: 8))
            layout {
                ForEach(ForzaGame.allCases) { game in
                    Button {
                        selection = game
                    } label: {
                        HStack(spacing: 8) {
                            Text(game.shortTitle)
                                .fixedSize(horizontal: false, vertical: true)
                            Image(systemName: selection == game ? "checkmark.circle.fill" : "circle")
                                .accessibilityHidden(true)
                        }
                            .font(.subheadline.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .foregroundStyle(selection == game ? ForzAdvisorTheme.accent : .secondary)
                            .background(
                                selection == game
                                    ? ForzAdvisorTheme.accent.opacity(0.16)
                                    : Color.secondary.opacity(0.08),
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                            )
                            .forzAdvisorMinimumTouchTarget()
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(game.title)
                    .accessibilityValue(selection == game ? "Selected" : "Not selected")
                    .accessibilityAddTraits(selection == game ? .isSelected : [])
                    .accessibilityIdentifier("\(accessibilityPrefix)-\(game.rawValue)")
                }
            }
        }
    }
}
