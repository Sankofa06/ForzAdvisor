import Foundation
import SwiftData

extension ContentView {
    private var evidenceCoordinator: ValidationEvidenceTransitionCoordinator {
        .init(localStore: .init(), authorizationStore: .init())
    }

    func grantEvidenceReuse(
        savedTuneID: UUID,
        fingerprint: String
    ) throws -> ValidationEvidenceAuthorizationEnvelope {
        guard let savedTune = try savedTune(for: savedTuneID) else {
            throw ContentWorkflowError.missingSavedTune
        }
        let plan = try evidenceCoordinator.prepareGrant(
            savedTuneID: savedTuneID,
            fingerprint: fingerprint
        )
        do {
            try savedTune.appendValidationRecord(plan.legacyReusableRecord)
            try modelContext.save()
            try evidenceCoordinator.activateGrant(plan)
            try evidenceCoordinator.finalizeGrant(plan)
            return plan.authorization
        } catch {
            let primary = error
            modelContext.rollback()
            var recoveryFailures: [Error] = []
            do {
                if try savedTune.deleteValidationRecord(
                    id: plan.legacyReusableRecord.recordID
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
            throw ValidationEvidenceTransactionError(
                primary: primary,
                recoveryFailures: recoveryFailures
            )
        }
    }

    func revokeEvidenceReuse(
        savedTuneID: UUID,
        fingerprint: String
    ) throws -> ValidationEvidenceAuthorizationEnvelope? {
        guard let savedTune = try savedTune(for: savedTuneID) else {
            throw ContentWorkflowError.missingSavedTune
        }
        guard case .reusable(let reusableRecord) = try
            ValidationEvidenceLiveRecordResolver().resolve(
                fingerprint: fingerprint,
                savedTuneID: savedTuneID,
                legacyRecords: savedTune.allFirstPartyValidationRecords(),
                localStore: evidenceCoordinator.localStore
            ) else {
            throw ValidationEvidenceRootError.missingLiveRecord
        }
        let plan = try evidenceCoordinator.prepareRevoke(
            savedTuneID: savedTuneID,
            reusableRecord: reusableRecord
        )
        do {
            guard try savedTune.deleteValidationRecord(
                id: reusableRecord.recordID
            ) else {
                throw ContentWorkflowError.missingSavedTune
            }
            try modelContext.save()
            try evidenceCoordinator.finalizeRevoke(plan)
            return evidenceCoordinator.authorizationStore.authorization(
                for: plan.fingerprint
            )
        } catch {
            let primary = error
            modelContext.rollback()
            var recoveryFailures: [Error] = []
            var restored = false
            do {
                restored = try savedTune.allFirstPartyValidationRecords()
                    .contains(where: {
                    $0.recordID == reusableRecord.recordID
                })
            } catch {
                recoveryFailures.append(error)
            }
            if !restored {
                do {
                    try savedTune.appendValidationRecord(reusableRecord)
                    try modelContext.save()
                    restored = true
                } catch {
                    modelContext.rollback()
                    recoveryFailures.append(error)
                }
            }
            if restored {
                do {
                    try evidenceCoordinator.rollbackRevoke(plan)
                } catch {
                    recoveryFailures.append(error)
                }
            }
            throw ValidationEvidenceTransactionError(
                primary: primary,
                recoveryFailures: recoveryFailures
            )
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
    ) throws -> Bool {
        guard let savedTune = try savedTune(for: savedTuneID) else {
            throw ContentWorkflowError.missingSavedTune
        }
        let liveRecord = try ValidationEvidenceLiveRecordResolver().resolve(
            fingerprint: fingerprint,
            savedTuneID: savedTuneID,
            legacyRecords: savedTune.allFirstPartyValidationRecords(),
            localStore: evidenceCoordinator.localStore
        )
        if case .reusable = liveRecord {
            _ = try revokeEvidenceReuse(
                savedTuneID: savedTuneID,
                fingerprint: fingerprint
            )
            let deleted = try evidenceCoordinator.localStore.delete(
                savedTuneID: savedTuneID,
                fingerprint: fingerprint
            )
            return deleted
        }
        guard case .localOnly = liveRecord else {
            throw ValidationEvidenceRootError.missingLiveRecord
        }
        let deleted = try evidenceCoordinator.localStore.delete(
            savedTuneID: savedTuneID,
            fingerprint: fingerprint
        )
        guard deleted else { throw ValidationEvidenceRootError.missingLiveRecord }
        _ = try evidenceCoordinator.authorizationStore.remove(
            fingerprint: fingerprint
        )
        return true
    }
}

enum ValidationEvidenceRootError: Error {
    case missingLiveRecord
}
