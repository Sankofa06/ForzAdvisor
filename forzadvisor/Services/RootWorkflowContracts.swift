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

enum ValidationEvidenceReuseActionResult: Equatable, Sendable {
    case reusable(ValidationEvidenceAuthorizationEnvelope)
    case localOnly
    case exportBlockedRecoveryPending
}

enum ValidationEvidenceDeleteActionResult: Equatable, Sendable {
    case deleted
    case retainedReusable
    case retainedLocalOnly
    case deletedAuthorizationCleanupPending
    case exportBlockedRecoveryPending
}

struct ValidationEvidenceActionPresentation: Equatable, Sendable {
    let message: String
    let announcement: String

    static func grant(
        _ result: ValidationEvidenceReuseActionResult
    ) -> Self {
        switch result {
        case .reusable:
            make("Future explicit export is now allowed for this exact observation.")
        case .localOnly:
            make("Evidence remains local only. Future export is blocked.")
        case .exportBlockedRecoveryPending:
            make("Future export is blocked. Evidence recovery is still pending on this device.")
        }
    }

    static func revoke(
        _ result: ValidationEvidenceReuseActionResult
    ) -> Self {
        switch result {
        case .reusable:
            make("Future reuse remains allowed because revocation did not complete.")
        case .localOnly:
            make("Future export is blocked. Previously shared files cannot be recalled.")
        case .exportBlockedRecoveryPending:
            make("Future export is blocked. Local evidence recovery is still pending.")
        }
    }

    static func delete(
        _ result: ValidationEvidenceDeleteActionResult
    ) -> Self {
        switch result {
        case .deleted:
            make("Evidence record deleted from this device.")
        case .retainedReusable:
            make("Evidence could not be deleted. Future reuse remains allowed.")
        case .retainedLocalOnly:
            make("Future export is blocked, but the local evidence record could not be deleted.")
        case .deletedAuthorizationCleanupPending:
            make("Evidence was deleted. Authorization cleanup is still pending, and no evidence can be exported.")
        case .exportBlockedRecoveryPending:
            make("Future export is blocked. Evidence deletion recovery is still pending.")
        }
    }

    private static func make(_ message: String) -> Self {
        Self(message: message, announcement: message)
    }
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
