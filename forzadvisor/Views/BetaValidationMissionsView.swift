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

                Section("Optional Next Steps") {
                    if board.missions.isEmpty {
                        ContentUnavailableView(
                            "No optional steps available",
                            systemImage: "checkmark.seal",
                            description: Text(
                                "Current saved setups have no eligible evidence gaps. New game builds or saved cars can create more missions."
                            )
                        )
                    } else {
                        ForEach(starterMissions) { mission in
                            missionButton(mission, recommended: false)
                        }
                        ForEach(groupedMissions) { group in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(group.carDisplayName).font(.headline)
                                if let discipline = group.disciplineTitle {
                                    Text(discipline).font(.caption).foregroundStyle(.secondary)
                                }
                                ForEach(group.missions, id: \.mission.id) { item in
                                    missionButton(item.mission, recommended: item.isRecommended)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .forzAdvisorRowBackground()

                Section(
                    FH6CommunityResearchPartnerInvite.sectionTitle
                ) {
                    Text(
                        FH6CommunityResearchPartnerInvite
                            .sectionSummary
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    ShareLink(
                        item:
                            FH6CommunityResearchPartnerInvite
                            .current.text,
                        subject: Text(
                            FH6CommunityResearchPartnerInvite
                                .current.subject
                        )
                    ) {
                        Label(
                            FH6CommunityResearchPartnerInvite
                                .shareButtonTitle,
                            systemImage: "person.badge.plus"
                        )
                    }
                    .accessibilityIdentifier(
                        FH6CommunityResearchPartnerInvite
                            .shareButtonIdentifier
                    )
                }
                .forzAdvisorRowBackground()

                Section("FH5 Research Partners") {
                    Text("Invite an FH5 player to join the Research Partners TestFlight group and coordinate one exact, permission-bound Candidate Trial. Apple controls external beta availability.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ShareLink(
                        item: FH5ResearchPartnerInvite.current.text,
                        subject: Text(
                            FH5ResearchPartnerInvite.current.subject
                        )
                    ) {
                        Label(
                            "Share Research Partner Invite",
                            systemImage: "person.badge.plus"
                        )
                    }
                    .accessibilityIdentifier(
                        "shareFH5ResearchPartnerInvite"
                    )
                    Link(
                        destination:
                            FH5ResearchPartnerInvite.testFlightURL
                    ) {
                        Label(
                            "Open FH5 Research Partners TestFlight",
                            systemImage: "arrow.up.right.square"
                        )
                    }
                    .accessibilityIdentifier(
                        "openFH5ResearchPartnersTestFlight"
                    )
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
                ToolbarItemGroup(placement: .topBarTrailing) {
                    ModalCopilotToolbarLink(
                        destination: .betaMissions(
                            savedSetupCount:
                                board.progress.savedSetupCount
                        )
                    )
                    Button("Done") {
                        dismiss()
                    }
                    .accessibilityIdentifier("closeBetaValidationMissions")
                }
            }
        }
    }

    private var starterMissions: [BetaValidationMission] {
        board.missions.filter { $0.savedTuneID == nil }
    }

    private var groupedMissions: [GroupedValidationMissionSummary] {
        GroupedValidationMissionSummary.make(
            missions: board.missions,
            evidenceBySavedTuneID: [:]
        )
    }

    private func missionButton(
        _ mission: BetaValidationMission,
        recommended: Bool
    ) -> some View {
        Button { onSelect(mission) } label: {
            HStack(alignment: .top, spacing: 12) {
                ForzAdvisorIcon(
                    systemName: mission.kind.systemImage,
                    tint: mission.game == .fh5
                        ? ForzAdvisorTheme.warmAccent
                        : ForzAdvisorTheme.accent
                )
                VStack(alignment: .leading, spacing: 5) {
                    if recommended {
                        Text("Recommended next optional step")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(ForzAdvisorTheme.accent)
                    }
                    Text(mission.title).font(.headline).foregroundStyle(.primary)
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
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("betaMission-\(mission.id)")
        .accessibilityHint("Optional. Opens the \(mission.title) workflow.")
    }
}
