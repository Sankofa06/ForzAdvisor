import Foundation

enum ValidationTunePurgePhase: String, Codable, Equatable {
    case prepared
    case committed
}

struct ValidationTunePurgeTask: Codable, Equatable {
    let savedTuneID: UUID
    let authorizationFingerprints: Set<String>
    var phase: ValidationTunePurgePhase = .prepared

    private enum CodingKeys: String, CodingKey {
        case savedTuneID, authorizationFingerprints, phase
    }

    init(
        savedTuneID: UUID,
        authorizationFingerprints: Set<String>,
        phase: ValidationTunePurgePhase = .prepared
    ) {
        self.savedTuneID = savedTuneID
        self.authorizationFingerprints = authorizationFingerprints
        self.phase = phase
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        savedTuneID = try container.decode(UUID.self, forKey: .savedTuneID)
        authorizationFingerprints = try container.decode(
            Set<String>.self,
            forKey: .authorizationFingerprints
        )
        // Tasks from the prior release were written only after tune deletion.
        phase = try container.decodeIfPresent(
            ValidationTunePurgePhase.self,
            forKey: .phase
        ) ?? .committed
    }
}

struct ValidationTunePurgeFingerprintSource {
    let savedTuneID: UUID
    let legacy: () throws -> Set<String>
    let local: () throws -> Set<String>
    let blocked: () throws -> Set<String>
}

struct ValidationTunePurgePlanner {
    func makeTask(
        deleting savedTuneID: UUID,
        sources: [ValidationTunePurgeFingerprintSource]
    ) throws -> ValidationTunePurgeTask {
        guard let target = sources.first(where: {
            $0.savedTuneID == savedTuneID
        }) else {
            throw ValidationEvidencePurgeError.missingTarget
        }
        var targetFingerprints = try target.legacy()
        targetFingerprints.formUnion(try target.local())
        targetFingerprints.formUnion(try target.blocked())
        var sharedFingerprints = Set<String>()
        for source in sources where source.savedTuneID != savedTuneID {
            sharedFingerprints.formUnion(try source.legacy())
            sharedFingerprints.formUnion(try source.local())
            sharedFingerprints.formUnion(try source.blocked())
        }
        targetFingerprints.subtract(sharedFingerprints)
        return ValidationTunePurgeTask(
            savedTuneID: savedTuneID,
            authorizationFingerprints: targetFingerprints,
            phase: .prepared
        )
    }
}

enum ValidationEvidencePurgeError: Error, Equatable {
    case missingTarget
}

struct ValidationTuneDeletionOutcome {
    let cleanupError: Error?
}

struct ValidationTuneDeletionTransactionCoordinator {
    let purgeCoordinator: ValidationEvidencePurgeCoordinator

    func perform(
        task: ValidationTunePurgeTask,
        commitDeletion: () throws -> Void,
        rollbackDeletion: () -> Void
    ) throws -> ValidationTuneDeletionOutcome {
        try purgeCoordinator.schedule(task)
        do {
            try commitDeletion()
        } catch {
            let primary = error
            rollbackDeletion()
            var recoveryFailures: [Error] = []
            do {
                try purgeCoordinator.cancelPrepared(
                    savedTuneID: task.savedTuneID
                )
            } catch {
                recoveryFailures.append(error)
            }
            throw ValidationEvidenceTransactionError(
                primary: primary,
                recoveryFailures: recoveryFailures
            )
        }
        do {
            try purgeCoordinator.confirmAndRun(
                savedTuneID: task.savedTuneID
            )
            return ValidationTuneDeletionOutcome(cleanupError: nil)
        } catch {
            return ValidationTuneDeletionOutcome(cleanupError: error)
        }
    }
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
            try ValidationEvidenceAuthorizationStore()
                .purgeAllState(fingerprints: $0)
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

    func schedule(_ task: ValidationTunePurgeTask) throws {
        var pending = readPendingQuarantiningCorruption()
        pending.removeAll { $0.savedTuneID == task.savedTuneID }
        var prepared = task
        prepared.phase = .prepared
        pending.append(prepared)
        try writePending(pending)
    }

    func confirmAndRun(savedTuneID: UUID) throws {
        var pending = try readPending()
        guard let index = pending.firstIndex(where: {
            $0.savedTuneID == savedTuneID
        }) else {
            throw ValidationEvidencePurgeError.missingTarget
        }
        pending[index].phase = .committed
        let task = pending[index]
        try writePending(pending)
        try execute(task)
        try removePending(savedTuneID: savedTuneID)
    }

    func cancelPrepared(savedTuneID: UUID) throws {
        var pending = try readPending()
        guard pending.first(where: {
            $0.savedTuneID == savedTuneID
        })?.phase == .prepared else { return }
        pending.removeAll { $0.savedTuneID == savedTuneID }
        try replacePending(pending)
    }

    func retryPending(
        tuneExists: (UUID) throws -> Bool
    ) throws {
        for var task in readPendingQuarantiningCorruption() {
            if task.phase == .prepared {
                if try tuneExists(task.savedTuneID) {
                    try cancelPrepared(savedTuneID: task.savedTuneID)
                    continue
                }
                task.phase = .committed
                var pending = try readPending()
                guard let index = pending.firstIndex(where: {
                    $0.savedTuneID == task.savedTuneID
                }) else { continue }
                pending[index] = task
                try writePending(pending)
            }
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

    private func readPendingQuarantiningCorruption()
        -> [ValidationTunePurgeTask] {
        do {
            return try readPending()
        } catch {
            quarantineCorruptPendingFile()
            return []
        }
    }

    private func quarantineCorruptPendingFile() {
        guard FileManager.default.fileExists(atPath: pendingURL.path) else {
            return
        }
        let quarantineURL = pendingURL.deletingLastPathComponent()
            .appendingPathComponent(
                "\(pendingURL.lastPathComponent).corrupt-\(UUID().uuidString)"
            )
        try? FileManager.default.moveItem(
            at: pendingURL,
            to: quarantineURL
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
        try replacePending(pending)
    }

    private func replacePending(_ pending: [ValidationTunePurgeTask]) throws {
        if pending.isEmpty {
            if FileManager.default.fileExists(atPath: pendingURL.path) {
                try FileManager.default.removeItem(at: pendingURL)
            }
        } else {
            try writePending(pending)
        }
    }
}
