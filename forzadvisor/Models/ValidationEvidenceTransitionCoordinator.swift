import Foundation

struct ValidationEvidenceTransactionError: Error, LocalizedError {
    let primary: Error
    let recoveryFailures: [Error]

    var errorDescription: String? {
        let recovery = recoveryFailures.map(\.localizedDescription)
            .joined(separator: "; ")
        guard !recovery.isEmpty else { return primary.localizedDescription }
        return "\(primary.localizedDescription) Recovery also failed: \(recovery)"
    }
}

struct ValidationEvidenceAuthorizationCleanupCoordinator {
    let pendingStore: ValidationEvidenceAuthorizationCleanupStore
    let purgeAuthorization: (Set<String>) throws -> Void

    init(
        pendingURL: URL? = nil,
        purgeAuthorization: @escaping (Set<String>) throws -> Void = {
            try ValidationEvidenceAuthorizationStore()
                .purgeAllState(fingerprints: $0)
        }
    ) {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        self.pendingStore = ValidationEvidenceAuthorizationCleanupStore(
            fileURL: pendingURL ?? base
                .appendingPathComponent("ForzAdvisor", isDirectory: true)
                .appendingPathComponent(
                    "pending-validation-authorization-cleanups.json"
                )
        )
        self.purgeAuthorization = purgeAuthorization
    }

    func schedule(
        _ task: ValidationEvidenceAuthorizationCleanupTask
    ) throws {
        try pendingStore.schedule(task)
    }

    func cancel(
        _ task: ValidationEvidenceAuthorizationCleanupTask
    ) throws {
        try pendingStore.remove(task)
    }

    func confirmAndRun(
        _ task: ValidationEvidenceAuthorizationCleanupTask,
        hasLiveReference: (ValidationEvidenceAuthorizationCleanupTask) throws
            -> Bool
    ) throws {
        try execute(task, hasLiveReference: hasLiveReference)
    }

    func retryPending(
        hasLiveReference: (ValidationEvidenceAuthorizationCleanupTask) throws
            -> Bool
    ) throws {
        for task in try pendingStore.tasks() {
            try execute(task, hasLiveReference: hasLiveReference)
        }
    }

    private func execute(
        _ task: ValidationEvidenceAuthorizationCleanupTask,
        hasLiveReference: (ValidationEvidenceAuthorizationCleanupTask) throws
            -> Bool
    ) throws {
        if try hasLiveReference(task) {
            try pendingStore.remove(task)
            return
        }
        try purgeAuthorization([task.fingerprint])
        try pendingStore.remove(task)
    }
}

/// Produces rollback-safe persistence steps. The caller must confirm its
/// SwiftData mutation before invoking the matching finalize method.
struct ValidationEvidenceTransitionCoordinator {
    let localStore: ValidationLocalObservationStore
    let authorizationStore: ValidationEvidenceAuthorizationStore

    struct GrantPlan: Equatable, Sendable {
        let savedTuneID: UUID
        let fingerprint: String
        let authorization: ValidationEvidenceAuthorizationEnvelope
        let legacyReusableRecord: FirstPartyValidationRecord
    }

    struct RevokePlan: Equatable, Sendable {
        let savedTuneID: UUID
        let fingerprint: String
        let recordIDToRemoveFromLegacyBlob: UUID
    }

    func saveLocal(
        record: FirstPartyValidationRecord,
        savedTuneID: UUID
    ) throws {
        var local = record
        local.deidentifiedReusePermitted = false
        try localStore.upsert(
            ValidationLocalObservation(record: local),
            savedTuneID: savedTuneID
        )
    }

    func prepareGrant(
        savedTuneID: UUID,
        fingerprint: String,
        authorizationVersion: String = "validation-reuse-v1"
    ) throws -> GrantPlan {
        if let pending = try authorizationStore.exportBlockStore.block(
            for: fingerprint
        ), pending.savedTuneID == savedTuneID,
           pending.reason == .grantRecovery,
           let authorization = pending.authorization,
           let sourceObservation = pending.sourceObservation {
            return GrantPlan(
                savedTuneID: savedTuneID,
                fingerprint: fingerprint,
                authorization: authorization,
                legacyReusableRecord: try sourceObservation.reusableRecord(
                    authorization: authorization
                )
            )
        }
        guard let local = try localStore.observation(
            savedTuneID: savedTuneID,
            fingerprint: fingerprint
        ) else {
            throw ValidationEvidenceExportError.localOnly
        }
        let authorization = ValidationEvidenceAuthorizationEnvelope.reusable(
            observationFingerprint: fingerprint,
            authorizationID: UUID(),
            authorizationVersion: authorizationVersion,
            authorizedAt: .now
        )
        guard authorization.isValid else {
            throw ValidationEvidenceExportError.invalidAuthorization
        }
        return GrantPlan(
            savedTuneID: savedTuneID,
            fingerprint: fingerprint,
            authorization: authorization,
            legacyReusableRecord: try local.reusableRecord(
                authorization: authorization
            )
        )
    }

    /// Must be durably persisted before any reusable blob or receipt is saved.
    func stageGrant(_ plan: GrantPlan) throws {
        try authorizationStore.exportBlockStore.persist(
            ValidationEvidenceExportBlock(
                savedTuneID: plan.savedTuneID,
                fingerprint: plan.fingerprint,
                reason: .grantRecovery,
                authorization: plan.authorization,
                sourceObservation: try ValidationLocalObservation(
                    record: plan.legacyReusableRecord
                )
            )
        )
    }

    /// Call only after the reusable legacy blob has been persisted and saved.
    func finalizeGrant(_ plan: GrantPlan) throws {
        _ = try localStore.delete(
            savedTuneID: plan.savedTuneID,
            fingerprint: plan.fingerprint
        )
    }

    func activateGrant(_ plan: GrantPlan) throws {
        try authorizationStore.persist(plan.authorization)
    }

    func completeGrant(_ plan: GrantPlan) throws {
        _ = try authorizationStore.exportBlockStore.remove(
            fingerprint: plan.fingerprint
        )
    }

    func compensateGrant(_ plan: GrantPlan) throws {
        var failures: [Error] = []
        do {
            try saveLocal(
                record: plan.legacyReusableRecord,
                savedTuneID: plan.savedTuneID
            )
        } catch {
            failures.append(error)
        }
        do {
            _ = try authorizationStore.remove(fingerprint: plan.fingerprint)
        } catch {
            failures.append(error)
        }
        if let first = failures.first {
            throw ValidationEvidenceTransactionError(
                primary: first,
                recoveryFailures: Array(failures.dropFirst())
            )
        }
    }

    func resolveGrantRecovery(_ plan: GrantPlan) throws {
        _ = try authorizationStore.exportBlockStore.remove(
            fingerprint: plan.fingerprint
        )
    }

    func prepareRevoke(
        savedTuneID: UUID,
        reusableRecord: FirstPartyValidationRecord
    ) throws -> RevokePlan {
        try authorizationStore.exportBlockStore.persist(
            ValidationEvidenceExportBlock(
                savedTuneID: savedTuneID,
                fingerprint: reusableRecord.contentFingerprint,
                reason: .revokeRecovery,
                authorization: nil,
                sourceObservation: nil
            )
        )
        try localStore.upsert(
            ValidationLocalObservation(record: reusableRecord),
            savedTuneID: savedTuneID
        )
        return RevokePlan(
            savedTuneID: savedTuneID,
            fingerprint: reusableRecord.contentFingerprint,
            recordIDToRemoveFromLegacyBlob: reusableRecord.recordID
        )
    }

    /// Call only after the reusable record is absent from the saved legacy blob.
    func finalizeRevoke(_ plan: RevokePlan) throws {
        _ = try authorizationStore.revoke(fingerprint: plan.fingerprint)
        _ = try authorizationStore.exportBlockStore.remove(
            fingerprint: plan.fingerprint
        )
    }

    func completePendingRevoke(
        savedTuneID: UUID,
        fingerprint: String
    ) throws {
        guard let block = try authorizationStore.exportBlockStore.block(
            for: fingerprint
        ), block.savedTuneID == savedTuneID,
           block.reason == .revokeRecovery else {
            throw ValidationEvidenceExportError.invalidAuthorization
        }
        _ = try authorizationStore.revoke(fingerprint: fingerprint)
        _ = try authorizationStore.exportBlockStore.remove(
            fingerprint: fingerprint
        )
    }

    func rollbackRevoke(_ plan: RevokePlan) throws {
        _ = try localStore.delete(
            savedTuneID: plan.savedTuneID,
            fingerprint: plan.fingerprint
        )
        _ = try authorizationStore.exportBlockStore.remove(
            fingerprint: plan.fingerprint
        )
    }
}

struct ValidationEvidenceLiveRecordResolver {
    func resolve(
        fingerprint: String,
        savedTuneID: UUID,
        legacyRecords: [FirstPartyValidationRecord],
        localStore: ValidationLocalObservationStore
    ) throws -> ValidationEvidenceRecord? {
        if let reusable = legacyRecords.first(where: {
            $0.contentFingerprint == fingerprint
        }) {
            return .reusable(reusable)
        }
        return try localStore.observation(
            savedTuneID: savedTuneID,
            fingerprint: fingerprint
        ).map(ValidationEvidenceRecord.localOnly)
    }
}

struct ValidationEvidenceDeleteCoordinator {
    func delete(
        liveRecord: ValidationEvidenceRecord,
        revoke: () throws -> ValidationEvidenceReuseActionResult,
        deleteLocal: () throws -> Bool,
        removeAuthorization: () throws -> Void
    ) throws -> ValidationEvidenceDeleteActionResult {
        if case .reusable = liveRecord {
            switch try revoke() {
            case .reusable:
                return .retainedReusable
            case .exportBlockedRecoveryPending:
                return .exportBlockedRecoveryPending
            case .localOnly:
                do {
                    guard try deleteLocal() else {
                        return .retainedLocalOnly
                    }
                } catch {
                    return .retainedLocalOnly
                }
                do {
                    try removeAuthorization()
                    return .deleted
                } catch {
                    return .deletedAuthorizationCleanupPending
                }
            }
        }
        do {
            guard try deleteLocal() else {
                throw ValidationEvidenceRootError.missingLiveRecord
            }
        } catch ValidationEvidenceRootError.missingLiveRecord {
            throw ValidationEvidenceRootError.missingLiveRecord
        } catch {
            return .retainedLocalOnly
        }
        do {
            try removeAuthorization()
            return .deleted
        } catch {
            return .deletedAuthorizationCleanupPending
        }
    }
}
