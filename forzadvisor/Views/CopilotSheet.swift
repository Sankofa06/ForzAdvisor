//
//  CopilotSheet.swift
//  forzadvisor
//
//  Transient, root-owned deterministic guidance for the current workflow phase.
//

import SwiftUI

struct CopilotSheet: View {
    let context: CopilotContext
    let onClose: () -> Void

    @State private var question = ""
    @State private var response: CopilotResponse?

    private let engine = CopilotEngine()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                contextSection
                suggestions
                askField
                if let response {
                    responseCard(response)
                }
            }
            .padding()
        }
        .background(ForzAdvisorTheme.screenBackground.ignoresSafeArea())
        .accessibilityIdentifier("copilotSheet")
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onChange(of: context) { _, _ in
            question = ""
            response = nil
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
