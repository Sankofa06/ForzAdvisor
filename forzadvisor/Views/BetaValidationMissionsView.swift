//
//  BetaValidationMissionsView.swift
//  forzadvisor
//
//  Local beta-testing hub. It renders derived mission availability and a
//  user-initiated aggregate progress share without persisting mission state.
//

import SwiftUI

struct BetaValidationMissionsView: View {
    let board: BetaValidationMissionBoard
    let onSelect: (BetaValidationMission) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForzAdvisorScreenHeader(
                        title: "Beta Validation Missions",
                        subtitle: "Turn your saved setups into useful first-party evidence.",
                        systemImage: "checklist",
                        tint: ForzAdvisorTheme.warmAccent
                    )
                }
                .listRowBackground(ForzAdvisorTheme.heroRowBackground)

                Section("Local Progress") {
                    LabeledContent(
                        "Saved setups",
                        value: "\(board.progress.savedSetupCount)"
                    )
                    LabeledContent(
                        "Permission-bound evidence records",
                        value: "\(board.progress.evidenceRecordCount)"
                    )
                    LabeledContent(
                        "Setups with exact upgrade paths",
                        value: "\(board.progress.exactUpgradePathSetupCount)"
                    )
                    LabeledContent(
                        "Missions ready",
                        value: "\(board.progress.availableMissionCount)"
                    )
                }
                .forzAdvisorRowBackground()

                Section("Next Missions") {
                    if board.missions.isEmpty {
                        ContentUnavailableView(
                            "No missions ready",
                            systemImage: "checkmark.seal",
                            description: Text(
                                "Current saved setups have no eligible evidence gaps. New game builds or saved cars can create more missions."
                            )
                        )
                    } else {
                        ForEach(board.missions) { mission in
                            Button {
                                onSelect(mission)
                            } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    ForzAdvisorIcon(
                                        systemName: mission.kind.systemImage,
                                        tint: mission.game == .fh5
                                            ? ForzAdvisorTheme.warmAccent
                                            : ForzAdvisorTheme.accent
                                    )
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(mission.title)
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                        Text(mission.detail)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .multilineTextAlignment(.leading)
                                    }
                                    Spacer(minLength: 8)
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier(
                                "betaMission-\(mission.id)"
                            )
                            .accessibilityHint(
                                "Opens the existing \(mission.title) workflow."
                            )
                        }
                    }
                }
                .forzAdvisorRowBackground()

                Section("Invite More Testing") {
                    Text("Share aggregate progress to show that you are helping test ForzAdvisor. Sharing is always your choice.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ShareLink(
                        item: board.progressShare.text,
                        subject: Text(board.progressShare.subject)
                    ) {
                        Label("Share Beta Progress", systemImage: "square.and.arrow.up")
                    }
                    .accessibilityIdentifier("shareBetaValidationProgress")
                }
                .forzAdvisorRowBackground()

                Section("Privacy And Accuracy Boundary") {
                    Text("Missions are derived on this device from current saved setups. ForzAdvisor does not upload mission progress, use analytics, or create evidence until you explicitly complete an existing validated workflow.")
                        .font(.caption)
                    Text("The shared progress summary contains aggregate counts only. It includes no car names, tune values, notes, identifiers, screenshots, JSON, fingerprints, receipts, provider details, or ruleset details.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .forzAdvisorRowBackground()
            }
            .navigationTitle("Beta Missions")
            .forzAdvisorScreenChrome()
            .accessibilityIdentifier("betaValidationMissions")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .accessibilityIdentifier("closeBetaValidationMissions")
                }
            }
        }
    }
}
