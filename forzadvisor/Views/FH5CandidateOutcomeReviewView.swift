//
//  FH5CandidateOutcomeReviewView.swift
//  forzadvisor
//

import SwiftUI

struct FH5CandidateOutcomeReviewView: View {
    let artifact: FH5GeneratedCandidateArtifact
    let entries: [FH5CandidateOutcomeReviewEntry]
    let report: FH5CandidateOutcomeCollectionReport
    let storageError: String?
    let onImport: (FH5CandidateOutcomeReviewEntry) -> String?
    let onDelete: (FH5CandidateOutcomeReviewEntry) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var pastedJSON = ""
    @State private var validatedData: Data?
    @State private var matchStatus: String?
    @State private var permissionConfirmed = false
    @State private var importError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Candidate Outcome Review") {
                    Text(
                        "Paste a permission-bound FH5 Candidate Outcome export. ForzAdvisor accepts it only when this device independently regenerates the exact same candidate association."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    TextEditor(text: $pastedJSON)
                        .frame(minHeight: 150)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier(
                            "fh5CandidateOutcomeReviewJSON"
                        )
                    Button("Validate Exact Candidate Match") {
                        validate()
                    }
                    .accessibilityIdentifier(
                        "validateFH5CandidateOutcomeReviewButton"
                    )
                    if let matchStatus {
                        Text(matchStatus)
                            .font(.caption)
                            .accessibilityIdentifier(
                                "fh5CandidateOutcomeReviewMatchStatus"
                            )
                    }
                }

                if validatedData != nil {
                    Section("Direct Receipt And Permission") {
                        Toggle(
                            "I received this export directly and the sender permitted deidentified structured reuse",
                            isOn: $permissionConfirmed
                        )
                        .accessibilityIdentifier(
                            "confirmFH5CandidateOutcomeReviewPermission"
                        )
                        Text(
                            "Hashes and UUIDs bind exact bytes; they do not authenticate a tester or prove identity."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        Button("Import Reviewed Outcome") {
                            importValidated()
                        }
                        .disabled(!permissionConfirmed)
                        .accessibilityIdentifier(
                            "importFH5CandidateOutcomeReviewButton"
                        )
                    }
                }

                Section("Collection-Only Summary") {
                    Text(report.summary)
                    Text(
                        "Duplicates: \(report.duplicateCount) · Conflicts: \(report.conflictCount) · Receipt replays: \(report.receiptReplayCount) · Semantic replays: \(report.semanticReplayCount) · Quarantined: \(report.quarantinedCount)"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    Text(
                        "Reviewed outcomes cannot register or promote a ruleset, unlock numeric FH5 output, enter TuneResult, or reach the clipboard."
                    )
                    .font(.caption)
                    .foregroundStyle(ForzAdvisorTheme.warning)
                }
                .accessibilityIdentifier(
                    "fh5CandidateOutcomeReviewSummary"
                )

                Section("Local Review Queue") {
                    if let storageError {
                        Label(
                            storageError,
                            systemImage: "exclamationmark.triangle"
                        )
                        .foregroundStyle(ForzAdvisorTheme.warning)
                    } else if entries.isEmpty {
                        Text("No reviewed candidate outcomes stored.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(entries) { entry in
                            VStack(alignment: .leading, spacing: 8) {
                                Label(
                                    isCurrent(entry)
                                        ? "Current candidate match"
                                        : "Historical candidate",
                                    systemImage: isCurrent(entry)
                                        ? "checkmark.circle"
                                        : "clock.arrow.circlepath"
                                )
                                .font(.caption.weight(.semibold))
                                Text(
                                    entry.importedAt.formatted(
                                        date: .abbreviated,
                                        time: .shortened
                                    )
                                )
                                .font(.caption.weight(.semibold))
                                Text(
                                    entry.permission
                                        .associationFingerprint
                                )
                                .font(.caption2.monospaced())
                                .lineLimit(1)
                                Button(
                                    "Delete reviewed outcome",
                                    role: .destructive
                                ) {
                                    onDelete(entry)
                                }
                                .accessibilityIdentifier(
                                    "deleteFH5CandidateOutcomeReviewEntryButton-\(entry.id.uuidString)"
                                )
                            }
                        }
                    }
                }
                .accessibilityIdentifier(
                    "fh5CandidateOutcomeReviewQueue"
                )

                Section("Privacy Boundary") {
                    Text(
                        "The export contains the exact experiment context, one-step change, outcome, and protocol attestations. It is not a tune. Sharing is manual, copies cannot be recalled, and ForzAdvisor performs no background upload."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                if let importError {
                    Section {
                        Label(
                            importError,
                            systemImage: "exclamationmark.triangle"
                        )
                        .font(.caption)
                        .foregroundStyle(ForzAdvisorTheme.warning)
                    }
                }
            }
            .navigationTitle("Candidate Outcome Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onChange(of: pastedJSON) {
                validatedData = nil
                permissionConfirmed = false
                matchStatus = nil
                importError = nil
            }
        }
    }

    private func validate() {
        do {
            let data = Data(pastedJSON.utf8)
            let exchange = FH5CandidateOutcomeExchange()
            let validated = try exchange.validate(data)
            guard try exchange.matches(
                validated,
                locallyRegeneratedArtifact: artifact
            ) else {
                throw FH5CandidateOutcomeExchangeError
                    .candidateMismatch
            }
            validatedData = data
            permissionConfirmed = false
            importError = nil
            matchStatus =
                "Exact locally regenerated candidate match. Permission confirmation is still required."
        } catch {
            validatedData = nil
            permissionConfirmed = false
            matchStatus = error.localizedDescription
        }
    }

    private func importValidated() {
        do {
            guard let validatedData else {
                throw FH5CandidateOutcomeExchangeError.emptyPayload
            }
            guard Data(pastedJSON.utf8) == validatedData else {
                throw FH5CandidateOutcomeExchangeError
                    .nonCanonicalJSON
            }
            let entry = try FH5CandidateOutcomeReviewEntry
                .locallyReviewed(
                    canonicalExportJSON: validatedData,
                    expectedArtifact: artifact,
                    reviewerConfirmedDirectReceiptAndReusePermission:
                        permissionConfirmed
                )
            if let error = onImport(entry) {
                importError = error
                return
            }
            pastedJSON = ""
            self.validatedData = nil
            matchStatus = "Imported into the local review queue."
            permissionConfirmed = false
            importError = nil
        } catch {
            importError = error.localizedDescription
        }
    }

    private func isCurrent(
        _ entry: FH5CandidateOutcomeReviewEntry
    ) -> Bool {
        guard let fingerprint = try?
                FH5CandidateOutcomeExchange()
                    .associationFingerprint(for: artifact) else {
            return false
        }
        return entry.permission.associationFingerprint
            == fingerprint
    }
}
