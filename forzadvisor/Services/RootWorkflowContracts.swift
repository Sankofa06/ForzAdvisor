import Foundation

enum GarageRemovalCommitResult: Equatable, Sendable {
    case committed(savedTuneID: UUID)
    case rolledBack(savedTuneID: UUID, message: String)
}

typealias GarageRemovalCommitCallback = @MainActor @Sendable (
    GarageRemovalCommitResult
) -> Void

enum RootStepGuideEntryPresentation: Equatable, Sendable {
    case garageBody
    case compactToolbar
}

struct RootStepGuideEntryPolicy {
    func presentation(for step: WorkflowStep) -> RootStepGuideEntryPresentation {
        if case .home = step { return .garageBody }
        return .compactToolbar
    }
}

struct TuneResultRootActions {
    let refinementProposal: TuneRefinementProposal?
    let canUndoRefinement: Bool
    let onApplyRefinement: () -> Void
    let onDiscardRefinement: () -> Void
    let onUndoRefinement: () -> Void
    let onCancelStreaming: () -> Void
}
