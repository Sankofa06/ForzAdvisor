import Foundation

struct ValidationTunePurgeTask: Codable, Equatable {
    let savedTuneID: UUID
    let authorizationFingerprints: Set<String>
}

struct ValidationEvidencePurgeCoordinator {
    let pendingURL: URL
    let purgeDrafts: (UUID) throws -> Void
    let purgeLocal: (UUID) throws -> Void
    let purgeAuthorizations: (Set<String>) throws -> Void

    init(
        pendingURL: URL? = nil,
        purgeDrafts: @escaping (UUID) throws -> Void = {
            _ = try ValidationDraftStore().purge(savedTuneID: $0)
        },
        purgeLocal: @escaping (UUID) throws -> Void = {
            _ = try ValidationLocalObservationStore().purge(savedTuneID: $0)
        },
        purgeAuthorizations: @escaping (Set<String>) throws -> Void = {
            _ = try ValidationEvidenceAuthorizationStore().purge(
                fingerprints: $0
            )
        }
    ) {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        self.pendingURL = pendingURL ?? base
            .appendingPathComponent("ForzAdvisor", isDirectory: true)
            .appendingPathComponent("pending-validation-purges.json")
        self.purgeDrafts = purgeDrafts
        self.purgeLocal = purgeLocal
        self.purgeAuthorizations = purgeAuthorizations
    }

    func scheduleAndRun(_ task: ValidationTunePurgeTask) throws {
        var pending = try readPending()
        pending.removeAll { $0.savedTuneID == task.savedTuneID }
        pending.append(task)
        try writePending(pending)
        do {
            try execute(task)
            try removePending(savedTuneID: task.savedTuneID)
        } catch {
            throw error
        }
    }

    func retryPending() throws {
        for task in try readPending() {
            try execute(task)
            try removePending(savedTuneID: task.savedTuneID)
        }
    }

    private func execute(_ task: ValidationTunePurgeTask) throws {
        var failures: [Error] = []
        do { try purgeDrafts(task.savedTuneID) } catch { failures.append(error) }
        do { try purgeLocal(task.savedTuneID) } catch { failures.append(error) }
        do {
            try purgeAuthorizations(task.authorizationFingerprints)
        } catch { failures.append(error) }
        if let first = failures.first {
            throw ValidationEvidenceTransactionError(
                primary: first,
                recoveryFailures: Array(failures.dropFirst())
            )
        }
    }

    private func readPending() throws -> [ValidationTunePurgeTask] {
        guard FileManager.default.fileExists(atPath: pendingURL.path) else {
            return []
        }
        return try JSONDecoder().decode(
            [ValidationTunePurgeTask].self,
            from: Data(contentsOf: pendingURL)
        )
    }

    private func writePending(_ tasks: [ValidationTunePurgeTask]) throws {
        try FileManager.default.createDirectory(
            at: pendingURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try JSONEncoder().encode(tasks).write(to: pendingURL, options: .atomic)
    }

    private func removePending(savedTuneID: UUID) throws {
        var pending = try readPending()
        pending.removeAll { $0.savedTuneID == savedTuneID }
        if pending.isEmpty {
            if FileManager.default.fileExists(atPath: pendingURL.path) {
                try FileManager.default.removeItem(at: pendingURL)
            }
        } else {
            try writePending(pending)
        }
    }
}
