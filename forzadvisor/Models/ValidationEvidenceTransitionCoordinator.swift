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

    func prepareRevoke(
        savedTuneID: UUID,
        reusableRecord: FirstPartyValidationRecord
    ) throws -> RevokePlan {
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
    }

    func rollbackRevoke(_ plan: RevokePlan) throws {
        _ = try localStore.delete(
            savedTuneID: plan.savedTuneID,
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
