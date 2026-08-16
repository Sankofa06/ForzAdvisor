import Foundation

struct GaragePendingRemoval: Equatable, Sendable {
    let id: UUID
    let carName: String
}

struct GarageRemovalState: Equatable, Sendable {
    private(set) var pending: GaragePendingRemoval?
    private(set) var committingTuneIDs = Set<UUID>()
    private(set) var failureMessage: String?

    var hiddenTuneIDs: Set<UUID> {
        committingTuneIDs.union(pending.map { [$0.id] } ?? [])
    }

    mutating func stage(id: UUID, carName: String) -> UUID? {
        guard pending?.id != id else { return nil }
        let priorID = pending?.id
        if let priorID { committingTuneIDs.insert(priorID) }
        pending = GaragePendingRemoval(id: id, carName: carName)
        failureMessage = nil
        return priorID
    }

    mutating func undo() -> GaragePendingRemoval? {
        defer { pending = nil }
        return pending
    }

    mutating func beginPendingCommit(matching expectedID: UUID? = nil) -> UUID? {
        guard let pending, expectedID == nil || pending.id == expectedID else { return nil }
        self.pending = nil
        committingTuneIDs.insert(pending.id)
        return pending.id
    }

    @discardableResult
    mutating func resolve(_ result: GarageRemovalCommitResult) -> Bool {
        let id: UUID
        switch result {
        case .committed(let savedTuneID):
            id = savedTuneID
            failureMessage = nil
        case .rolledBack(let savedTuneID, let message):
            id = savedTuneID
            failureMessage = message
        }
        return committingTuneIDs.remove(id) != nil
    }
}
