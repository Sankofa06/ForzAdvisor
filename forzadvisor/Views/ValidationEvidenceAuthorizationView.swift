import SwiftUI

struct ValidationEvidenceAuthorizationView: View {
    let observationFingerprint: String
    let allowedFields: [String]
    let currentAuthorization: () -> ValidationEvidenceAuthorizationEnvelope?
    let onGrant: () throws -> ValidationEvidenceAuthorizationEnvelope
    let onRevoke: () throws -> ValidationEvidenceAuthorizationEnvelope?
    let onDelete: () throws -> Bool

    @State private var authorization:
        ValidationEvidenceAuthorizationEnvelope?
    @State private var message: String?
    @State private var confirmingGrant = false
    @State private var confirmingRevoke = false
    @State private var confirmingDelete = false

    init(
        observationFingerprint: String,
        allowedFields: [String],
        authorization: @escaping () -> ValidationEvidenceAuthorizationEnvelope?,
        onGrant: @escaping () throws
            -> ValidationEvidenceAuthorizationEnvelope,
        onRevoke: @escaping () throws
            -> ValidationEvidenceAuthorizationEnvelope?,
        onDelete: @escaping () throws -> Bool
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
                if allowsReuse {
                    Label("Allowed for future explicit exports", systemImage: "checkmark.shield")
                    Button("Revoke Future Reuse", role: .destructive) {
                        confirmingRevoke = true
                    }
                } else {
                    Label("Local only", systemImage: "lock")
                    Button("Allow Future Reuse") { confirmingGrant = true }
                }
                Text("Already shared files are separate copies and cannot be recalled. Revocation blocks only future exports from this device.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("On This Device") {
                Button("Delete Evidence Record", role: .destructive) {
                    confirmingDelete = true
                }
            }
            ValidationRecoveryMessageSection(message: message)
        }
        .navigationTitle("Evidence Reuse")
        .task { authorization = currentAuthorization() }
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
                    guard try onDelete() else {
                        throw ValidationEvidenceActionError.noLiveRecord
                    }
                    authorization = nil
                    message = "Evidence record deleted from this device."
                } catch {
                    message = "Evidence could not be deleted. Nothing was changed."
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
        authorization?.allowsReuse(of: observationFingerprint) == true
    }

    private func grant() {
        do {
            let result = try onGrant()
            guard result.allowsReuse(of: observationFingerprint) else {
                throw ValidationEvidenceActionError.invalidResult
            }
            authorization = result
            message = "Future explicit export is now allowed for this exact observation."
        } catch {
            authorization = nil
            message = "Authorization could not be stored. Evidence remains local only."
        }
    }

    private func revoke() {
        do {
            let result = try onRevoke()
            guard result?.allowsReuse(of: observationFingerprint) != true else {
                throw ValidationEvidenceActionError.invalidResult
            }
            authorization = result
            message = "Future export is blocked. Previously shared files cannot be recalled."
        } catch {
            message = "Authorization could not be revoked. Do not export until this is resolved."
        }
    }
}

private enum ValidationEvidenceActionError: Error {
    case noLiveRecord
    case invalidResult
}
