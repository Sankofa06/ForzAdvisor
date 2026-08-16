import Foundation

enum GarageRemovalCommitResult: Equatable, Sendable {
    case committed(savedTuneID: UUID)
    case rolledBack(savedTuneID: UUID, message: String)
}

typealias GarageRemovalCommitCallback = @MainActor @Sendable (
    GarageRemovalCommitResult
) -> Void

enum TuneResultSaveOutcome: Equatable, Sendable {
    case saved(savedTuneID: UUID)
    case failed(message: String)
}

enum RootStepGuideEntryPresentation: Equatable, Sendable {
    case garageBody
    case compactToolbar
    case firstSaveHandoff
}

struct RootStepGuideEntryPolicy {
    func presentation(
        for step: WorkflowStep,
        firstSaveHandoffPresented: Bool = false
    ) -> RootStepGuideEntryPresentation {
        if case .home = step { return .garageBody }
        if firstSaveHandoffPresented { return .firstSaveHandoff }
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
