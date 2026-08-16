import Foundation
import SwiftData

extension ContentView {
    private var evidenceCoordinator: ValidationEvidenceTransitionCoordinator {
        .init(localStore: .init(), authorizationStore: .init())
    }

    func grantEvidenceReuse(
        savedTuneID: UUID,
        fingerprint: String
    ) throws -> ValidationEvidenceReuseActionResult {
        guard let savedTune = try savedTune(for: savedTuneID) else {
            throw ContentWorkflowError.missingSavedTune
        }
        let plan = try evidenceCoordinator.prepareGrant(
            savedTuneID: savedTuneID,
            fingerprint: fingerprint
        )
        try evidenceCoordinator.stageGrant(plan)
        do {
            try savedTune.replaceValidationRecord(
                fingerprint: fingerprint,
                with: plan.legacyReusableRecord
            )
            try modelContext.save()
            try evidenceCoordinator.activateGrant(plan)
            try evidenceCoordinator.finalizeGrant(plan)
            try evidenceCoordinator.completeGrant(plan)
            return .reusable(plan.authorization)
        } catch {
            modelContext.rollback()
            var recoveryFailures: [Error] = []
            do {
                if try savedTune.deleteValidationRecords(
                    fingerprint: fingerprint
                ) {
                    try modelContext.save()
                }
            } catch {
                modelContext.rollback()
                recoveryFailures.append(error)
            }
            do {
                try evidenceCoordinator.compensateGrant(plan)
            } catch {
                recoveryFailures.append(error)
            }
            if recoveryFailures.isEmpty {
                do {
                    try evidenceCoordinator.resolveGrantRecovery(plan)
                    return .localOnly
                } catch {
                    recoveryFailures.append(error)
                }
            }
            return .exportBlockedRecoveryPending
        }
    }

    func revokeEvidenceReuse(
        savedTuneID: UUID,
        fingerprint: String
    ) throws -> ValidationEvidenceReuseActionResult {
        guard let savedTune = try savedTune(for: savedTuneID) else {
            throw ContentWorkflowError.missingSavedTune
        }
        let liveRecord = try ValidationEvidenceLiveRecordResolver().resolve(
                fingerprint: fingerprint,
                savedTuneID: savedTuneID,
                legacyRecords: savedTune.allFirstPartyValidationRecords(),
                localStore: evidenceCoordinator.localStore
            )
        if case .localOnly = liveRecord,
           case .exportBlockedRecoveryPending(.revokeRecovery) =
            evidenceCoordinator.authorizationStore.status(for: fingerprint) {
            do {
                try evidenceCoordinator.completePendingRevoke(
                    savedTuneID: savedTuneID,
                    fingerprint: fingerprint
                )
                return .localOnly
            } catch {
                return .exportBlockedRecoveryPending
            }
        }
        guard case .reusable(let reusableRecord) = liveRecord else {
            throw ValidationEvidenceRootError.missingLiveRecord
        }
        let plan: ValidationEvidenceTransitionCoordinator.RevokePlan
        do {
            plan = try evidenceCoordinator.prepareRevoke(
                savedTuneID: savedTuneID,
                reusableRecord: reusableRecord
            )
        } catch {
            return reuseResult(for: fingerprint)
        }
        do {
            guard try savedTune.deleteValidationRecord(
                id: reusableRecord.recordID
            ) else {
                throw ContentWorkflowError.missingSavedTune
            }
            try modelContext.save()
        } catch {
            modelContext.rollback()
            do {
                try evidenceCoordinator.rollbackRevoke(plan)
                return reuseResult(for: fingerprint)
            } catch {
                return .exportBlockedRecoveryPending
            }
        }
        do {
            try evidenceCoordinator.finalizeRevoke(plan)
            return .localOnly
        } catch {
            return .exportBlockedRecoveryPending
        }
    }

    private func reuseResult(
        for fingerprint: String
    ) -> ValidationEvidenceReuseActionResult {
        switch evidenceCoordinator.authorizationStore.status(for: fingerprint) {
        case .localOnly:
            return .localOnly
        case .reusable(let authorization):
            return .reusable(authorization)
        case .exportBlockedRecoveryPending:
            return .exportBlockedRecoveryPending
        }
    }

    /// Repairs compatibility blobs written without a matching active receipt.
    /// The evidence remains on-device, but it cannot enter an export packet.
    func reusableAuthorizedValidationRecords(
        savedTune: SavedTune,
        savedTuneID: UUID
    ) throws -> [FirstPartyValidationRecord] {
        let records = try savedTune.allFirstPartyValidationRecords()
        return try ValidationEvidenceOrphanReconciler(
            coordinator: evidenceCoordinator
        ).reconcile(
            records: records,
            savedTuneID: savedTuneID,
            removeLegacyRecord: { recordID in
                guard try savedTune.deleteValidationRecord(id: recordID) else {
                    throw ValidationEvidenceRootError.missingLiveRecord
                }
            },
            saveLegacyChanges: { try modelContext.save() },
            rollbackLegacyChanges: { modelContext.rollback() }
        )
    }

    @discardableResult
    func deleteValidationEvidence(
        fingerprint: String,
        savedTuneID: UUID
    ) throws -> ValidationEvidenceDeleteActionResult {
        guard let savedTune = try savedTune(for: savedTuneID) else {
            throw ContentWorkflowError.missingSavedTune
        }
        let liveRecord = try ValidationEvidenceLiveRecordResolver().resolve(
            fingerprint: fingerprint,
            savedTuneID: savedTuneID,
            legacyRecords: savedTune.allFirstPartyValidationRecords(),
            localStore: evidenceCoordinator.localStore
        )
        guard let liveRecord else {
            throw ValidationEvidenceRootError.missingLiveRecord
        }
        return try ValidationEvidenceDeleteCoordinator().delete(
            liveRecord: liveRecord,
            revoke: {
                try revokeEvidenceReuse(
                    savedTuneID: savedTuneID,
                    fingerprint: fingerprint
                )
            },
            deleteLocal: {
                try evidenceCoordinator.localStore.delete(
                    savedTuneID: savedTuneID,
                    fingerprint: fingerprint
                )
            },
            removeAuthorization: {
                try evidenceCoordinator.authorizationStore.purgeAllState(
                    fingerprints: [fingerprint]
                )
            }
        )
    }
}

enum ValidationEvidenceRootError: Error {
    case missingLiveRecord
}
