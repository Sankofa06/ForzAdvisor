import Foundation

@MainActor
struct ValidationEvidenceOrphanReconciler {
    let coordinator: ValidationEvidenceTransitionCoordinator

    func reconcile(
        records: [FirstPartyValidationRecord],
        savedTuneID: UUID,
        removeLegacyRecord: (UUID) throws -> Void,
        saveLegacyChanges: () throws -> Void,
        rollbackLegacyChanges: () -> Void
    ) throws -> [FirstPartyValidationRecord] {
        var authorized: [FirstPartyValidationRecord] = []
        var orphaned: [FirstPartyValidationRecord] = []
        for record in records {
            let authorization = try coordinator.authorizationStore
                .authorizationResult(for: record.contentFingerprint)
            if authorization?.allowsReuse(of: record.contentFingerprint) == true,
               authorization?.authorizationID == record.permissionReceiptID {
                authorized.append(record)
            } else {
                orphaned.append(record)
            }
        }
        guard !orphaned.isEmpty else { return authorized }
        let snapshots = try orphaned.map { record in
            OrphanSnapshot(
                record: record,
                priorLocal: try coordinator.localStore.observation(
                    savedTuneID: savedTuneID,
                    fingerprint: record.contentFingerprint
                ),
                priorAuthorization: try coordinator.authorizationStore
                    .authorizationResult(for: record.contentFingerprint)
            )
        }
        var stagingFailures: [Error] = []
        for snapshot in snapshots {
            do {
                try coordinator.saveLocal(
                    record: snapshot.record,
                    savedTuneID: savedTuneID
                )
            } catch { stagingFailures.append(error) }
            do {
                _ = try coordinator.authorizationStore.remove(
                    fingerprint: snapshot.record.contentFingerprint
                )
            } catch { stagingFailures.append(error) }
        }
        if let first = stagingFailures.first {
            throw ValidationEvidenceTransactionError(
                primary: first,
                recoveryFailures: Array(stagingFailures.dropFirst())
                    + restore(snapshots, savedTuneID: savedTuneID)
            )
        }
        do {
            for record in orphaned {
                try removeLegacyRecord(record.recordID)
            }
            try saveLegacyChanges()
        } catch {
            let primary = error
            rollbackLegacyChanges()
            throw ValidationEvidenceTransactionError(
                primary: primary,
                recoveryFailures: restore(
                    snapshots,
                    savedTuneID: savedTuneID
                )
            )
        }
        return authorized
    }

    private func restore(
        _ snapshots: [OrphanSnapshot],
        savedTuneID: UUID
    ) -> [Error] {
        var failures: [Error] = []
        for snapshot in snapshots {
            do {
                if let prior = snapshot.priorLocal {
                    try coordinator.localStore.upsert(
                        prior,
                        savedTuneID: savedTuneID
                    )
                } else {
                    _ = try coordinator.localStore.delete(
                        savedTuneID: savedTuneID,
                        fingerprint: snapshot.record.contentFingerprint
                    )
                }
            } catch { failures.append(error) }
            do {
                if let prior = snapshot.priorAuthorization {
                    try coordinator.authorizationStore.persist(prior)
                } else {
                    _ = try coordinator.authorizationStore.remove(
                        fingerprint: snapshot.record.contentFingerprint
                    )
                }
            } catch { failures.append(error) }
        }
        return failures
    }
}

private struct OrphanSnapshot {
    let record: FirstPartyValidationRecord
    let priorLocal: ValidationLocalObservation?
    let priorAuthorization: ValidationEvidenceAuthorizationEnvelope?
}
