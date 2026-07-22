//
//  ForzaGamePicker.swift
//  forzadvisor
//
//  Shared explicit game selector for editable car-input workflows.
//

import SwiftUI

struct ForzaGamePicker: View {
    @Binding var selection: ForzaGame

    let accessibilityPrefix: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Game")
                .font(.subheadline)

            HStack(spacing: 8) {
                ForEach(ForzaGame.allCases) { game in
                    Button {
                        selection = game
                    } label: {
                        Text(game.shortTitle)
                            .font(.subheadline.weight(.semibold))
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
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(game.title)
                    .accessibilityValue(selection == game ? "Selected" : "Not selected")
                    .accessibilityIdentifier("\(accessibilityPrefix)-\(game.rawValue)")
                }
            }
        }
    }
}
