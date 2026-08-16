import Combine
import Foundation

struct TuneRefinementProposal: Equatable, Sendable, Identifiable {
    let id: UUID
    let savedTuneID: UUID
    let baseline: TuneResult
    let candidate: TuneResult
    let feedback: TuneFeedback
    let changes: [TuneAdjustmentChange]

    init(
        id: UUID = UUID(),
        savedTuneID: UUID,
        baseline: TuneResult,
        result: TuneAdjustmentResult,
        feedback: TuneFeedback
    ) {
        self.id = id
        self.savedTuneID = savedTuneID
        self.baseline = baseline
        candidate = TuneResultBoundarySanitizer().sanitize(result.tune)
        self.feedback = feedback
        changes = result.changes
    }
}
struct AppliedTuneRefinement: Equatable, Sendable {
    let proposal: TuneRefinementProposal
    let appliedAt: Date
    let undoDeadline: Date
}

enum TuneRefinementProposalError: LocalizedError, Equatable {
    case noProposal
    case staleBaseline
    case undoExpired

    var errorDescription: String? {
        switch self {
        case .noProposal: "This refinement is no longer available."
        case .staleBaseline:
            "The saved tune changed. Generate a fresh refinement before applying."
        case .undoExpired: "The refinement undo window has expired."
        }
    }
}

@MainActor
final class TuneRefinementProposalStore: ObservableObject {
    @Published private(set) var proposal: TuneRefinementProposal?
    @Published private(set) var applied: AppliedTuneRefinement?

    func store(_ proposal: TuneRefinementProposal) {
        self.proposal = proposal
        applied = nil
    }

    func discard() {
        proposal = nil
    }

    func apply(
        currentPersistedTune: TuneResult,
        now: Date = .now,
        persist: (TuneResult) throws -> Void
    ) throws -> AppliedTuneRefinement {
        guard let proposal else {
            throw TuneRefinementProposalError.noProposal
        }
        guard currentPersistedTune == proposal.baseline else {
            throw TuneRefinementProposalError.staleBaseline
        }
        try persist(proposal.candidate)
        let applied = AppliedTuneRefinement(
            proposal: proposal,
            appliedAt: now,
            undoDeadline: now.addingTimeInterval(6)
        )
        self.applied = applied
        self.proposal = nil
        return applied
    }

    func undo(
        currentPersistedTune: TuneResult,
        now: Date = .now,
        persist: (TuneResult) throws -> Void
    ) throws -> TuneResult {
        guard let applied else {
            throw TuneRefinementProposalError.noProposal
        }
        guard now <= applied.undoDeadline else {
            self.applied = nil
            throw TuneRefinementProposalError.undoExpired
        }
        guard currentPersistedTune == applied.proposal.candidate else {
            throw TuneRefinementProposalError.staleBaseline
        }
        try persist(applied.proposal.baseline)
        self.applied = nil
        return applied.proposal.baseline
    }

    func expireUndo(now: Date = .now) {
        guard let applied, now > applied.undoDeadline else { return }
        self.applied = nil
    }
}
