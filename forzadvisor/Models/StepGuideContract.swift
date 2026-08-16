import Foundation

typealias StepGuidePhase = CopilotPhase
typealias StepGuideIntent = CopilotIntent
typealias StepGuideAction = CopilotAction
typealias StepGuideContext = CopilotContext

enum StepGuideContract {
    static let title = "Step Guide"
    static let boundary =
        "Local deterministic guidance. No model, network, or transcript."

    static let intents: [StepGuideIntent] = [
        .nextStep,
        .trust,
        .missing,
        .privacy
    ]
}

struct StepGuideResponse: Equatable, Sendable {
    let title: String
    let message: String
    let intent: StepGuideIntent?
    let action: StepGuideAction?

    init(_ response: CopilotResponse) {
        title = response.title.replacingCopilotWithStepGuide
        message = response.message.replacingCopilotWithStepGuide
        intent = response.intent
        action = response.action
    }
}

struct StepGuideEngine {
    private let engine = CopilotEngine()

    func defaultResponse(in context: StepGuideContext) -> StepGuideResponse {
        StepGuideResponse(engine.defaultResponse(in: context))
    }

    func response(
        to intent: StepGuideIntent,
        in context: StepGuideContext
    ) -> StepGuideResponse {
        StepGuideResponse(engine.response(to: intent, in: context))
    }
}

enum StepGuideActionRejectionReason: String, Equatable, Sendable {
    case staleContext
    case unavailable
}

struct StepGuideActionRejection: Equatable, Sendable {
    let reason: StepGuideActionRejectionReason
    let message: String
}

enum StepGuideActionResult: Equatable, Sendable {
    case accepted
    case rejected(StepGuideActionRejection)

    var shouldDismiss: Bool {
        if case .accepted = self {
            return true
        }
        return false
    }

    var rejection: StepGuideActionRejection? {
        guard case .rejected(let rejection) = self else {
            return nil
        }
        return rejection
    }
}

private extension String {
    var replacingCopilotWithStepGuide: String {
        replacingOccurrences(of: "Copilot", with: "Step Guide")
    }
}
