import SwiftUI
import UIKit

struct ValidationEvidenceAuthorizationView: View {
    let observationFingerprint: String
    let allowedFields: [String]
    let currentAuthorization: () -> ValidationEvidenceAuthorizationStatus
    let onGrant: () throws -> ValidationEvidenceReuseActionResult
    let onRevoke: () throws -> ValidationEvidenceReuseActionResult
    let onDelete: () throws -> ValidationEvidenceDeleteActionResult

    @State private var authorizationStatus:
        ValidationEvidenceAuthorizationStatus = .localOnly
    @State private var evidenceDeleted = false
    @State private var message: String?
    @State private var confirmingGrant = false
    @State private var confirmingRevoke = false
    @State private var confirmingDelete = false

    init(
        observationFingerprint: String,
        allowedFields: [String],
        authorization: @escaping () -> ValidationEvidenceAuthorizationStatus,
        onGrant: @escaping () throws
            -> ValidationEvidenceReuseActionResult,
        onRevoke: @escaping () throws
            -> ValidationEvidenceReuseActionResult,
        onDelete: @escaping () throws -> ValidationEvidenceDeleteActionResult
    ) {
        self.observationFingerprint = observationFingerprint
        self.allowedFields = allowedFields
        currentAuthorization = authorization
        self.onGrant = onGrant
        self.onRevoke = onRevoke
        self.onDelete = onDelete
    }

    var body: some View {
        Form {
            Section("Exact Observation") {
                Text(observationFingerprint)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                Text("Authorization is bound to this immutable fingerprint. Editing or replacing the observation requires a new authorization.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Fields Allowed For Future Export") {
                ForEach(allowedFields, id: \.self) { field in
                    Label(field, systemImage: "checkmark.circle")
                }
                Text("No screenshots, notes, tune IDs, provider data, device data, or location are included.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Reuse Status") {
                if evidenceDeleted {
                    Label("Deleted from this device", systemImage: "trash")
                        .accessibilityIdentifier("evidenceReuseStatus")
                } else if allowsReuse {
                    Label("Allowed for future explicit exports", systemImage: "checkmark.shield")
                        .accessibilityIdentifier("evidenceReuseStatus")
                    Button("Revoke Future Reuse", role: .destructive) {
                        confirmingRevoke = true
                    }
                    .accessibilityIdentifier("revokeEvidenceReuseButton")
                } else if recoveryPending {
                    Label("Export blocked · recovery pending", systemImage: "exclamationmark.shield")
                        .accessibilityIdentifier("evidenceReuseStatus")
                    if recoveryReason == .grantRecovery {
                        Button("Retry Allow Future Reuse", action: grant)
                            .accessibilityIdentifier("retryGrantEvidenceButton")
                    } else if recoveryReason == .revokeRecovery {
                        Button("Retry Revoke Future Reuse", action: revoke)
                            .accessibilityIdentifier("retryRevokeEvidenceButton")
                    }
                } else {
                    Label("Local only", systemImage: "lock")
                        .accessibilityIdentifier("evidenceReuseStatus")
                    Button("Allow Future Reuse") { confirmingGrant = true }
                        .accessibilityIdentifier("grantEvidenceReuseButton")
                }
                Text("Already shared files are separate copies and cannot be recalled. Revocation blocks only future exports from this device.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("On This Device") {
                Button("Delete Evidence Record", role: .destructive) {
                    confirmingDelete = true
                }
                .disabled(evidenceDeleted)
                .accessibilityIdentifier("deleteEvidenceButton")
            }
            ValidationRecoveryMessageSection(message: message)
                .accessibilityIdentifier("evidenceActionStatus")
        }
        .navigationTitle("Evidence Reuse")
        .task { authorizationStatus = currentAuthorization() }
        .confirmationDialog(
            "Allow future reuse of these exact fields?",
            isPresented: $confirmingGrant,
            titleVisibility: .visible
        ) {
            Button("Allow Future Reuse", action: grant)
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            "Delete this evidence record from this device?",
            isPresented: $confirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete Evidence Record", role: .destructive) {
                do {
                    let result = try onDelete()
                    let presentation = ValidationEvidenceActionPresentation
                        .delete(result)
                    evidenceDeleted = result == .deleted
                        || result == .deletedAuthorizationCleanupPending
                    authorizationStatus = currentAuthorization()
                    announce(presentation)
                } catch {
                    authorizationStatus = currentAuthorization()
                    announce(.init(
                        message: "Evidence deletion could not start. The current reuse status is shown above.",
                        announcement: "Evidence deletion could not start. The current reuse status is shown above."
                    ))
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            "Revoke future reuse?",
            isPresented: $confirmingRevoke,
            titleVisibility: .visible
        ) {
            Button("Revoke Future Reuse", role: .destructive, action: revoke)
            Button("Cancel", role: .cancel) {}
        }
    }

    private var allowsReuse: Bool {
        guard case .reusable(let authorization) = authorizationStatus else {
            return false
        }
        return authorization.allowsReuse(of: observationFingerprint)
    }

    private var recoveryPending: Bool {
        if case .exportBlockedRecoveryPending = authorizationStatus {
            return true
        }
        return false
    }

    private var recoveryReason: ValidationEvidenceExportBlockReason? {
        guard case .exportBlockedRecoveryPending(let reason) =
                authorizationStatus else { return nil }
        return reason
    }

    private func grant() {
        do {
            let result = try onGrant()
            if case .reusable(let authorization) = result,
               !authorization.allowsReuse(of: observationFingerprint) {
                throw ValidationEvidenceActionError.invalidResult
            }
            authorizationStatus = currentAuthorization()
            announce(.grant(result))
        } catch {
            authorizationStatus = currentAuthorization()
            announce(.init(
                message: "Authorization could not be completed. The current export status is shown above.",
                announcement: "Authorization could not be completed. The current export status is shown above."
            ))
        }
    }

    private func revoke() {
        do {
            let result = try onRevoke()
            authorizationStatus = currentAuthorization()
            announce(.revoke(result))
        } catch {
            authorizationStatus = currentAuthorization()
            announce(.init(
                message: "Revocation could not be completed. The current export status is shown above.",
                announcement: "Revocation could not be completed. The current export status is shown above."
            ))
        }
    }

    private func announce(_ presentation: ValidationEvidenceActionPresentation) {
        message = presentation.message
        UIAccessibility.post(
            notification: .announcement,
            argument: presentation.announcement
        )
    }
}

private enum ValidationEvidenceActionError: Error {
    case invalidResult
}
