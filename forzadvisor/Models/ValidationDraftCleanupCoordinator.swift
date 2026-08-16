import Foundation

struct ValidationDraftCleanupTask: Codable, Equatable {
    let kind: ValidationDraftKind
    let savedTuneID: UUID
}

struct ValidationDraftCleanupCoordinator {
    let pendingURL: URL
    let deleteDraft: (ValidationDraftKind, UUID) throws -> Void

    init(
        pendingURL: URL? = nil,
        deleteDraft: @escaping (ValidationDraftKind, UUID) throws -> Void = {
            try ValidationDraftStore().deleteAfterConfirmedCommit(
                kind: $0,
                savedTuneID: $1
            )
        }
    ) {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        self.pendingURL = pendingURL ?? base
            .appendingPathComponent("ForzAdvisor", isDirectory: true)
            .appendingPathComponent("pending-validation-draft-cleanups.json")
        self.deleteDraft = deleteDraft
    }

    func scheduleAndRun(_ task: ValidationDraftCleanupTask) throws {
        var pending = try readPendingRecoveringCorruption()
        pending.removeAll {
            $0.kind == task.kind && $0.savedTuneID == task.savedTuneID
        }
        pending.append(task)
        try writePending(pending)
        try execute(task)
        try removePending(task)
    }

    func retryPending() throws {
        for task in try readPendingRecoveringCorruption() {
            try execute(task)
            try removePending(task)
        }
    }

    private func execute(_ task: ValidationDraftCleanupTask) throws {
        try deleteDraft(task.kind, task.savedTuneID)
    }

    private func readPendingRecoveringCorruption() throws
        -> [ValidationDraftCleanupTask] {
        guard FileManager.default.fileExists(atPath: pendingURL.path) else {
            return []
        }
        do {
            return try JSONDecoder().decode(
                [ValidationDraftCleanupTask].self,
                from: Data(contentsOf: pendingURL)
            )
        } catch {
            let quarantineURL = pendingURL
                .deletingPathExtension()
                .appendingPathExtension("corrupt-\(UUID().uuidString).json")
            try FileManager.default.moveItem(
                at: pendingURL,
                to: quarantineURL
            )
            return []
        }
    }

    private func writePending(_ tasks: [ValidationDraftCleanupTask]) throws {
        try FileManager.default.createDirectory(
            at: pendingURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try JSONEncoder().encode(tasks).write(to: pendingURL, options: .atomic)
    }

    private func removePending(_ task: ValidationDraftCleanupTask) throws {
        var pending = try readPendingRecoveringCorruption()
        pending.removeAll { $0 == task }
        if pending.isEmpty {
            if FileManager.default.fileExists(atPath: pendingURL.path) {
                try FileManager.default.removeItem(at: pendingURL)
            }
        } else {
            try writePending(pending)
        }
    }
}
