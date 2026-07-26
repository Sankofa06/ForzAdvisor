//
//  CopilotSheet.swift
//  forzadvisor
//
//  Transient, root-owned deterministic guidance for the current workflow phase.
//

import SwiftUI

enum ModalCopilotDestination: Sendable {
    case settings
    case stockCatalogContribution
    case betaMissions(savedSetupCount: Int)
    case fh6ValidationReview(
        carDisplayName: String,
        gameTitle: String,
        disciplineTitle: String
    )
    case fh6CommunityOutcomeReview(
        carDisplayName: String,
        gameTitle: String,
        disciplineTitle: String
    )
    case fh5ResearchReview(
        carDisplayName: String,
        gameTitle: String
    )
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
        case .settings, .stockCatalogContribution,
                .fh6ValidationReview:
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
        case .fh6CommunityOutcomeReview(
            let carDisplayName,
            let gameTitle,
            let disciplineTitle
        ):
            CopilotContext(
                phase: phase,
                carDisplayName: carDisplayName,
                gameTitle: gameTitle,
                disciplineTitle: disciplineTitle,
                savedTuneCount: nil,
                catalogCarCount: nil,
                projection: nil,
                cannotSeeUnsavedEdits: true
            )
        case .fh5ResearchReview(let carDisplayName, let gameTitle):
            CopilotContext(
                phase: phase,
                carDisplayName: carDisplayName,
                gameTitle: gameTitle,
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

    var buttonIdentifier: String {
        "copilotButton-\(phase.rawValue)"
    }

    private func phaseOnlyContext(
        cannotSeeUnsavedEdits: Bool
    ) -> CopilotContext {
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
            Image(systemName: "sparkles")
                .frame(minWidth: 44, minHeight: 44)
        }
        .accessibilityLabel("Open contextual Copilot")
        .accessibilityHint(destination.accessibilityHint)
        .accessibilityIdentifier(destination.buttonIdentifier)
    }
}

private struct ModalCopilotNavigationDestination: View {
    let destination: ModalCopilotDestination

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        CopilotSheet(
            context: destination.context,
            onClose: { dismiss() }
        )
    }
}

struct CopilotSheet: View {
    let context: CopilotContext
    let onAction: ((CopilotAction) -> Void)?
    let onClose: () -> Void

    @State private var question = ""
    @State private var response: CopilotResponse

    private let engine = CopilotEngine()

    init(
        context: CopilotContext,
        onAction: ((CopilotAction) -> Void)? = nil,
        onClose: @escaping () -> Void
    ) {
        self.context = context
        self.onAction = onAction
        self.onClose = onClose
        _response = State(
            initialValue: CopilotEngine().defaultResponse(in: context)
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                contextSection
                responseCard(response)
                suggestions
                askField
            }
            .padding()
        }
        .background(ForzAdvisorTheme.screenBackground.ignoresSafeArea())
        .accessibilityIdentifier("copilotSheet")
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onChange(of: context) { _, _ in
            question = ""
            response = engine.defaultResponse(in: context)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            ForzAdvisorIcon(systemName: "sparkles", size: 40)
            VStack(alignment: .leading, spacing: 4) {
                Text("Copilot")
                    .font(.title2.bold())
                Text(context.phase.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            Button("Close", action: onClose)
                .accessibilityIdentifier("copilotCloseButton")
        }
    }

    private var contextSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Current context")
                .font(.headline)
            if context.facts.isEmpty {
                Text("Copilot only knows that you are on the \(context.phase.title) step.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(context.facts) { fact in
                    LabeledContent(fact.label, value: fact.value)
                        .font(.subheadline)
                }
            }
        }
        .padding()
        .background(ForzAdvisorTheme.surface, in: RoundedRectangle(cornerRadius: 14))
    }

    private var suggestions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ask about this step")
                .font(.headline)
            ForEach(CopilotIntent.allCases, id: \.rawValue) { intent in
                Button {
                    question = intent.title
                    response = engine.response(to: intent, in: context)
                } label: {
                    HStack {
                        Text(intent.title)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier(intent.suggestionIdentifier)
            }
        }
    }

    private var askField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Or type one of those questions")
                .font(.headline)
            HStack(alignment: .center, spacing: 8) {
                TextField("Ask Copilot", text: $question)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1)
                    .submitLabel(.send)
                    .onSubmit(ask)
                    .accessibilityIdentifier("copilotQuestionField")
                Button(action: ask) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Ask Copilot")
                .accessibilityIdentifier("copilotAskButton")
            }
        }
    }

    private func responseCard(_ response: CopilotResponse) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(response.title)
                .font(.headline)
            Text(response.message)
                .fixedSize(horizontal: false, vertical: true)
            if let action = response.action, let onAction {
                Button {
                    onAction(action)
                    onClose()
                } label: {
                    Text(action.title)
                        .frame(
                            maxWidth: .infinity,
                            minHeight: 44
                        )
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("copilotResponseActionButton")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(ForzAdvisorTheme.mutedSurface, in: RoundedRectangle(cornerRadius: 14))
        .accessibilityIdentifier("copilotResponse")
    }

    private func ask() {
        response = engine.response(to: question, in: context)
    }
}
