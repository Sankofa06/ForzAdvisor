import SwiftUI
import UIKit

struct CopilotSheet: View {
    let context: CopilotContext
    let onAction: ((StepGuideAction) -> StepGuideActionResult)?
    let onClose: () -> Void

    @State private var response: StepGuideResponse
    @State private var actionRejection: StepGuideActionRejection?
    @State private var rejectedAction: StepGuideAction?

    private let engine = StepGuideEngine()

    init(
        context: CopilotContext,
        onAction: ((StepGuideAction) -> StepGuideActionResult)? = nil,
        onClose: @escaping () -> Void
    ) {
        self.context = context
        self.onAction = onAction
        self.onClose = onClose
        _response = State(
            initialValue: StepGuideEngine().defaultResponse(in: context)
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                boundaryCard
                contextSection
                StepGuideResponseCard(
                    response: response,
                    hiddenAction: rejectedAction,
                    rejection: actionRejection,
                    onAction: performAction
                )
                choices
            }
            .padding()
        }
        .background(ForzAdvisorTheme.screenBackground.ignoresSafeArea())
        .accessibilityIdentifier("copilotSheet")
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onChange(of: context) { _, _ in
            actionRejection = nil
            rejectedAction = nil
            response = engine.defaultResponse(in: context)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            ForzAdvisorIcon(systemName: "list.bullet.rectangle", size: 40)
            VStack(alignment: .leading, spacing: 4) {
                Text(StepGuideContract.title)
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

    private var boundaryCard: some View {
        Label(StepGuideContract.boundary, systemImage: "lock.shield")
            .font(.subheadline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(
                ForzAdvisorTheme.surface,
                in: RoundedRectangle(cornerRadius: 14)
            )
            .accessibilityIdentifier("stepGuideBoundary")
    }

    private var contextSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Current context")
                .font(.headline)
            if context.facts.isEmpty {
                Text("Step Guide only knows that you are on the \(context.phase.title) step.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(context.facts) { fact in
                    LabeledContent(
                        fact.label,
                        value: fact.value.replacingOccurrences(
                            of: "Copilot",
                            with: StepGuideContract.title
                        )
                    )
                        .font(.subheadline)
                }
            }
        }
        .padding()
        .background(ForzAdvisorTheme.surface, in: RoundedRectangle(cornerRadius: 14))
    }

    private var choices: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Choose guidance")
                .font(.headline)
            ForEach(StepGuideContract.intents, id: \.rawValue) { intent in
                Button {
                    actionRejection = nil
                    rejectedAction = nil
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
        .accessibilityIdentifier("stepGuideChoices")
    }

    private func performAction(_ action: StepGuideAction) {
        guard let onAction else { return }
        let result = onAction(action)
        if result.shouldDismiss {
            onClose()
            return
        }
        guard let rejection = result.rejection else { return }
        rejectedAction = action
        actionRejection = rejection
        UIAccessibility.post(
            notification: .announcement,
            argument: rejection.message
        )
    }
}
