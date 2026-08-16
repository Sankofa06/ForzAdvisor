import SwiftUI

enum ModalCopilotDestination: Sendable {
    case settings
    case stockCatalogContribution
    case betaMissions(savedSetupCount: Int)
    case fh6ValidationReview(carDisplayName: String, gameTitle: String, disciplineTitle: String)
    case fh6CommunityOutcomeReview(carDisplayName: String, gameTitle: String, disciplineTitle: String)
    case fh5ResearchReview(carDisplayName: String, gameTitle: String)
    case fh5CandidateOutcomeReview

    var phase: CopilotPhase {
        switch self {
        case .settings: .settings
        case .stockCatalogContribution: .stockCatalogContribution
        case .betaMissions: .betaValidationMissions
        case .fh6ValidationReview: .fh6ValidationReview
        case .fh6CommunityOutcomeReview: .fh6CommunityOutcomeReview
        case .fh5ResearchReview: .fh5ResearchReview
        case .fh5CandidateOutcomeReview: .fh5CandidateOutcomeReview
        }
    }

    var context: CopilotContext {
        switch self {
        case .settings, .stockCatalogContribution, .fh6ValidationReview:
            phaseOnlyContext(cannotSeeUnsavedEdits: true)
        case .betaMissions(let savedSetupCount):
            CopilotContext(
                phase: phase,
                carDisplayName: nil,
                gameTitle: nil,
                disciplineTitle: nil,
                savedTuneCount: savedSetupCount,
                catalogCarCount: nil,
                projection: nil,
                cannotSeeUnsavedEdits: false
            )
        case .fh6CommunityOutcomeReview(let car, let game, let discipline):
            CopilotContext(
                phase: phase,
                carDisplayName: car,
                gameTitle: game,
                disciplineTitle: discipline,
                savedTuneCount: nil,
                catalogCarCount: nil,
                projection: nil,
                cannotSeeUnsavedEdits: true
            )
        case .fh5ResearchReview(let car, let game):
            CopilotContext(
                phase: phase,
                carDisplayName: car,
                gameTitle: game,
                disciplineTitle: nil,
                savedTuneCount: nil,
                catalogCarCount: nil,
                projection: nil,
                cannotSeeUnsavedEdits: true
            )
        case .fh5CandidateOutcomeReview:
            phaseOnlyContext(cannotSeeUnsavedEdits: true)
        }
    }

    var accessibilityHint: String {
        switch self {
        case .settings:
            "Shows local guidance for Settings without changing settings."
        case .stockCatalogContribution:
            "Shows guidance without reading or changing the contribution."
        case .betaMissions:
            "Shows local guidance for Beta Missions without selecting a mission."
        case .fh6ValidationReview:
            "Shows local guidance for FH6 Validation Review without changing the review."
        case .fh6CommunityOutcomeReview:
            "Shows local guidance for Community Outcome Review without changing the review."
        case .fh5ResearchReview:
            "Shows local guidance for FH5 Research Review without changing the review."
        case .fh5CandidateOutcomeReview:
            "Shows local guidance for Candidate Outcome Review without changing the review."
        }
    }

    var buttonIdentifier: String { "copilotButton-\(phase.rawValue)" }

    private func phaseOnlyContext(cannotSeeUnsavedEdits: Bool) -> CopilotContext {
        CopilotContext(
            phase: phase,
            carDisplayName: nil,
            gameTitle: nil,
            disciplineTitle: nil,
            savedTuneCount: nil,
            catalogCarCount: nil,
            projection: nil,
            cannotSeeUnsavedEdits: cannotSeeUnsavedEdits
        )
    }
}

struct ModalCopilotToolbarLink: View {
    let destination: ModalCopilotDestination

    var body: some View {
        NavigationLink {
            ModalCopilotNavigationDestination(destination: destination)
        } label: {
            Image(systemName: "list.bullet.rectangle")
                .frame(minWidth: 44, minHeight: 44)
        }
        .accessibilityLabel("Open Step Guide")
        .accessibilityHint(destination.accessibilityHint)
        .accessibilityIdentifier(destination.buttonIdentifier)
    }
}

private struct ModalCopilotNavigationDestination: View {
    let destination: ModalCopilotDestination

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        CopilotSheet(context: destination.context, onClose: { dismiss() })
    }
}
