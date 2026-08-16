import Foundation

enum ValidationEvidenceExportError: Error, Equatable {
    case localOnly
    case invalidAuthorization
}

enum ValidationEvidenceAuthorizationStatus: Equatable, Sendable {
    case localOnly
    case reusable(ValidationEvidenceAuthorizationEnvelope)
    case exportBlockedRecoveryPending(ValidationEvidenceExportBlockReason?)
}

enum ValidationEvidenceExportBlockReason: String, Codable, Sendable {
    case grantRecovery
    case revokeRecovery
}

struct ValidationEvidenceExportBlock: Codable, Equatable, Sendable {
    let savedTuneID: UUID
    let fingerprint: String
    let reason: ValidationEvidenceExportBlockReason
    let authorization: ValidationEvidenceAuthorizationEnvelope?
    let sourceObservation: ValidationLocalObservation?
}

struct ValidationEvidenceAuthorizationCleanupTask:
    Codable, Equatable, Sendable {
    let savedTuneID: UUID
    let fingerprint: String
}

struct ValidationEvidenceAuthorizationCleanupStore {
    let fileURL: URL

    func contains(fingerprint: String) throws -> Bool {
        try readAll().contains { $0.fingerprint == fingerprint }
    }

    func tasks() throws -> [ValidationEvidenceAuthorizationCleanupTask] {
        try readAll()
    }

    func schedule(_ task: ValidationEvidenceAuthorizationCleanupTask) throws {
        guard !task.fingerprint.isEmpty else {
            throw ValidationEvidenceExportError.invalidAuthorization
        }
        var tasks = try readAll()
        tasks.removeAll { $0 == task }
        tasks.append(task)
        try write(tasks)
    }

    func remove(_ task: ValidationEvidenceAuthorizationCleanupTask) throws {
        var tasks = try readAll()
        tasks.removeAll { $0 == task }
        if tasks.isEmpty {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
        } else {
            try write(tasks)
        }
    }

    private func readAll() throws
        -> [ValidationEvidenceAuthorizationCleanupTask] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        let tasks = try JSONDecoder().decode(
            [ValidationEvidenceAuthorizationCleanupTask].self,
            from: Data(contentsOf: fileURL)
        )
        guard tasks.allSatisfy({ !$0.fingerprint.isEmpty }) else {
            throw ValidationEvidenceExportError.invalidAuthorization
        }
        return tasks
    }

    private func write(
        _ tasks: [ValidationEvidenceAuthorizationCleanupTask]
    ) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try JSONEncoder().encode(tasks).write(to: fileURL, options: .atomic)
    }
}

struct ValidationEvidenceExportBlockStore {
    enum Operation: Equatable {
        case read, persist, remove, purge
    }

    let fileURL: URL
    let fault: ((Operation) throws -> Void)?

    init(
        fileURL: URL,
        fault: ((Operation) throws -> Void)? = nil
    ) {
        self.fileURL = fileURL
        self.fault = fault
    }

    func block(for fingerprint: String) throws
        -> ValidationEvidenceExportBlock? {
        try fault?(.read)
        return try readAll()[fingerprint]
    }

    func fingerprints(savedTuneID: UUID) throws -> Set<String> {
        try fault?(.read)
        return Set(try readAll().values.compactMap {
            $0.savedTuneID == savedTuneID ? $0.fingerprint : nil
        })
    }

    func persist(_ block: ValidationEvidenceExportBlock) throws {
        try fault?(.persist)
        guard !block.fingerprint.isEmpty else {
            throw ValidationEvidenceExportError.invalidAuthorization
        }
        var values = try readAll()
        values[block.fingerprint] = block
        try write(values)
    }

    @discardableResult
    func remove(fingerprint: String) throws -> Bool {
        try fault?(.remove)
        var values = try readAll()
        guard values.removeValue(forKey: fingerprint) != nil else {
            return false
        }
        try write(values)
        return true
    }

    @discardableResult
    func purge(fingerprints: Set<String>) throws -> Int {
        try fault?(.purge)
        guard !fingerprints.isEmpty else { return 0 }
        var values = try readAll()
        let priorCount = values.count
        values = values.filter { !fingerprints.contains($0.key) }
        let removed = priorCount - values.count
        guard removed > 0 else { return 0 }
        try write(values)
        return removed
    }

    private func readAll() throws -> [String: ValidationEvidenceExportBlock] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return [:]
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let values = try decoder.decode(
            [String: ValidationEvidenceExportBlock].self,
            from: Data(contentsOf: fileURL)
        )
        guard values.allSatisfy({ key, value in
            key == value.fingerprint && !key.isEmpty
        }) else {
            throw ValidationEvidenceExportError.invalidAuthorization
        }
        return values
    }

    private func write(
        _ values: [String: ValidationEvidenceExportBlock]
    ) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(values).write(to: fileURL, options: .atomic)
    }
}

struct ValidationEvidenceAuthorizationStore {
    enum Operation: Equatable {
        case read, persist, remove, revoke, purge
    }

    let fileURL: URL
    let fault: ((Operation) throws -> Void)?
    let exportBlockStore: ValidationEvidenceExportBlockStore
    let authorizationCleanupStore: ValidationEvidenceAuthorizationCleanupStore

    init(
        fileURL: URL? = nil,
        fault: ((Operation) throws -> Void)? = nil,
        exportBlockURL: URL? = nil,
        authorizationCleanupURL: URL? = nil,
        exportBlockFault:
            ((ValidationEvidenceExportBlockStore.Operation) throws -> Void)? = nil
    ) {
        self.fault = fault
        let resolvedFileURL: URL
        if let fileURL {
            resolvedFileURL = fileURL
        } else {
            let base = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first ?? FileManager.default.temporaryDirectory
            resolvedFileURL = base
                .appendingPathComponent("ForzAdvisor", isDirectory: true)
                .appendingPathComponent("validation-authorizations.json")
        }
        self.fileURL = resolvedFileURL
        self.exportBlockStore = ValidationEvidenceExportBlockStore(
            fileURL: exportBlockURL ?? resolvedFileURL
                .deletingLastPathComponent()
                .appendingPathComponent("validation-export-blocks.json"),
            fault: exportBlockFault
        )
        self.authorizationCleanupStore =
            ValidationEvidenceAuthorizationCleanupStore(
                fileURL: authorizationCleanupURL ?? resolvedFileURL
                    .deletingLastPathComponent()
                    .appendingPathComponent(
                        "pending-validation-authorization-cleanups.json"
                    )
            )
    }

    func authorization(for fingerprint: String)
        -> ValidationEvidenceAuthorizationEnvelope? {
        try? authorizationResult(for: fingerprint)
    }

    func authorizationResult(for fingerprint: String) throws
        -> ValidationEvidenceAuthorizationEnvelope? {
        if try authorizationCleanupStore.contains(fingerprint: fingerprint) {
            return nil
        }
        if try exportBlockStore.block(for: fingerprint) != nil {
            return nil
        }
        try fault?(.read)
        return try readAll()[fingerprint]
    }

    func storedAuthorizationResult(for fingerprint: String) throws
        -> ValidationEvidenceAuthorizationEnvelope? {
        try fault?(.read)
        return try readAll()[fingerprint]
    }

    func status(for fingerprint: String)
        -> ValidationEvidenceAuthorizationStatus {
        do {
            if try authorizationCleanupStore.contains(
                fingerprint: fingerprint
            ) {
                return .exportBlockedRecoveryPending(nil)
            }
            return try transitionStatus(for: fingerprint)
        } catch {
            return .exportBlockedRecoveryPending(nil)
        }
    }

    /// Transaction compensation uses this view while a delete has staged its
    /// own cleanup task. Public export lookup must continue to use `status`.
    func transitionStatus(for fingerprint: String) throws
        -> ValidationEvidenceAuthorizationStatus {
        do {
            if let block = try exportBlockStore.block(for: fingerprint) {
                return .exportBlockedRecoveryPending(block.reason)
            }
            guard let authorization = try storedAuthorizationResult(
                for: fingerprint
            ) else {
                return .localOnly
            }
            return authorization.allowsReuse(of: fingerprint)
                ? .reusable(authorization) : .localOnly
        } catch {
            return .exportBlockedRecoveryPending(nil)
        }
    }

    func allowsExport(of record: FirstPartyValidationRecord) -> Bool {
        guard let envelope = authorization(for: record.contentFingerprint)
        else { return false }
        return envelope.allowsReuse(of: record.contentFingerprint)
            && envelope.authorizationID == record.permissionReceiptID
    }

    func grant(
        fingerprint: String,
        version: String,
        at date: Date = .now,
        id: UUID = UUID()
    ) throws -> ValidationEvidenceAuthorizationEnvelope {
        try fault?(.persist)
        let envelope = ValidationEvidenceAuthorizationEnvelope.reusable(
            observationFingerprint: fingerprint,
            authorizationID: id,
            authorizationVersion: version,
            authorizedAt: date
        )
        guard envelope.isValid else {
            throw ValidationEvidenceExportError.invalidAuthorization
        }
        var values = try readAll()
        values[fingerprint] = envelope
        try write(values)
        return envelope
    }

    func persist(_ envelope: ValidationEvidenceAuthorizationEnvelope) throws {
        try fault?(.persist)
        guard envelope.isValid else {
            throw ValidationEvidenceExportError.invalidAuthorization
        }
        var values = try readAll()
        values[envelope.observationFingerprint] = envelope
        try write(values)
    }

    @discardableResult
    func remove(fingerprint: String) throws -> Bool {
        try fault?(.remove)
        var values = try readAll()
        guard values.removeValue(forKey: fingerprint) != nil else {
            return false
        }
        try write(values)
        return true
    }

    @discardableResult
    func revoke(fingerprint: String, at date: Date = .now) throws -> Bool {
        try fault?(.revoke)
        var values = try readAll()
        guard let existing = values[fingerprint],
              existing.allowsReuse(of: fingerprint) else { return false }
        values[fingerprint] = existing.revoking(at: date)
        try write(values)
        return true
    }

    @discardableResult
    func purge(fingerprints: Set<String>) throws -> Int {
        try fault?(.purge)
        guard !fingerprints.isEmpty else { return 0 }
        var values = try readAll()
        let count = values.count
        values = values.filter { !fingerprints.contains($0.key) }
        let removed = count - values.count
        guard removed > 0 else { return 0 }
        try write(values)
        return removed
    }

    func purgeAllState(fingerprints: Set<String>) throws {
        var failures: [Error] = []
        do { _ = try purge(fingerprints: fingerprints) }
        catch { failures.append(error) }
        do { _ = try exportBlockStore.purge(fingerprints: fingerprints) }
        catch { failures.append(error) }
        if let first = failures.first {
            throw ValidationEvidenceTransactionError(
                primary: first,
                recoveryFailures: Array(failures.dropFirst())
            )
        }
    }

    private func readAll() throws
        -> [String: ValidationEvidenceAuthorizationEnvelope] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return [:]
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let values = try decoder.decode(
            [String: ValidationEvidenceAuthorizationEnvelope].self,
            from: Data(contentsOf: fileURL)
        )
        guard values.allSatisfy({ key, value in
            key == value.observationFingerprint && value.isValid
        }) else {
            throw ValidationEvidenceExportError.invalidAuthorization
        }
        return values
    }

    private func write(
        _ values: [String: ValidationEvidenceAuthorizationEnvelope]
    ) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(values).write(to: fileURL, options: .atomic)
    }
}

struct FirstPartyValidationExportGate {
    func deterministicJSON(
        for record: FirstPartyValidationRecord,
        authorization: ValidationEvidenceAuthorizationEnvelope?
    ) throws -> Data {
        guard FirstPartyValidationRecordFactory()
            .isValidLocalObservation(record) else {
            throw FirstPartyValidationError.invalidStoredRecord
        }
        guard let authorization,
              authorization.allowsReuse(of: record.contentFingerprint),
              let permissionID = authorization.authorizationID else {
            throw ValidationEvidenceExportError.localOnly
        }
        if record.deidentifiedReusePermitted {
            guard record.permissionReceiptID == permissionID else {
                throw ValidationEvidenceExportError.invalidAuthorization
            }
            return try record.deterministicJSON()
        }
        var reusable = record
        reusable.deidentifiedReusePermitted = true
        reusable.permissionReceiptID = permissionID
        return try reusable.deterministicJSON()
    }
}
