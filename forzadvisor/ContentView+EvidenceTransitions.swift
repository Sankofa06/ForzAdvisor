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
            modelContext.rollback()
            if (try? savedTune.deleteValidationRecord(
                id: plan.legacyReusableRecord.recordID
            )) == true {
                try? modelContext.save()
            }
            try? evidenceCoordinator.compensateGrant(plan)
            throw error
        }
    }

    func revokeEvidenceReuse(
        savedTuneID: UUID,
        reusableRecord: FirstPartyValidationRecord
    ) throws -> ValidationEvidenceAuthorizationEnvelope? {
        guard let savedTune = try savedTune(for: savedTuneID) else {
            throw ContentWorkflowError.missingSavedTune
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
            modelContext.rollback()
            var restored = (try? savedTune.allFirstPartyValidationRecords())?
                .contains(where: {
                    $0.recordID == reusableRecord.recordID
                }) == true
            if !restored {
                do {
                    try savedTune.appendValidationRecord(reusableRecord)
                    try modelContext.save()
                    restored = true
                } catch {
                    modelContext.rollback()
                }
            }
            if restored {
                try? evidenceCoordinator.rollbackRevoke(plan)
            }
            throw error
        }
    }

    /// Repairs compatibility blobs written without a matching active receipt.
    /// The evidence remains on-device, but it cannot enter an export packet.
    func reusableAuthorizedValidationRecords(
        savedTune: SavedTune,
        savedTuneID: UUID
    ) throws -> [FirstPartyValidationRecord] {
        let records = try savedTune.allFirstPartyValidationRecords()
        var authorized: [FirstPartyValidationRecord] = []
        var orphaned: [FirstPartyValidationRecord] = []
        for record in records {
            let authorization = evidenceCoordinator.authorizationStore
                .authorization(for: record.contentFingerprint)
            if authorization?.allowsReuse(of: record.contentFingerprint)
                == true,
               authorization?.authorizationID == record.permissionReceiptID {
                authorized.append(record)
            } else {
                orphaned.append(record)
            }
        }
        guard !orphaned.isEmpty else { return authorized }
        for record in orphaned {
            try evidenceCoordinator.saveLocal(
                record: record,
                savedTuneID: savedTuneID
            )
            _ = try savedTune.deleteValidationRecord(id: record.recordID)
        }
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
        return authorized
    }

    func deleteValidationEvidence(
        _ evidence: ValidationEvidenceRecord,
        savedTuneID: UUID
    ) throws {
        switch evidence {
        case .localOnly:
            _ = try evidenceCoordinator.localStore.delete(
                savedTuneID: savedTuneID,
                fingerprint: evidence.fingerprint
            )
        case .reusable(let record):
            _ = try revokeEvidenceReuse(
                savedTuneID: savedTuneID,
                reusableRecord: record
            )
            _ = try evidenceCoordinator.localStore.delete(
                savedTuneID: savedTuneID,
                fingerprint: evidence.fingerprint
            )
        }
    }
}
