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
    let onPrepareNumericPromotionReviewPacket:
        (() throws -> String)?
    let preparedInputStateFingerprint: String?
    let onValidateNumericPromotionReviewPacket:
        ((Data) throws -> FH5NumericPromotionReviewPacket)?
    let receiverCandidateFingerprint: String?

    @Environment(\.dismiss) private var dismiss
    @State private var pastedJSON = ""
    @State private var validatedData: Data?
    @State private var matchStatus: String?
    @State private var permissionConfirmed = false
    @State private var importError: String?
    @State private var packetEvidenceMutationToken = UUID()

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

                if let onPrepareNumericPromotionReviewPacket {
                    FH5NumericPromotionReviewPacketPreparationView(
                        onPrepare:
                            onPrepareNumericPromotionReviewPacket,
                        preparedInputStateFingerprint:
                            preparedInputStateFingerprint,
                        evidenceMutationToken:
                            packetEvidenceMutationToken
                    )
                }

                if let onValidateNumericPromotionReviewPacket,
                   let receiverCandidateFingerprint {
                    FH5SharedNumericPromotionReviewPacketInspector(
                        onValidate:
                            onValidateNumericPromotionReviewPacket,
                        receiverCandidateFingerprint:
                            receiverCandidateFingerprint
                    )
                }

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
                                    packetEvidenceMutationToken = UUID()
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
                ToolbarItemGroup(placement: .topBarTrailing) {
                    ModalCopilotToolbarLink(
                        destination: .fh5CandidateOutcomeReview
                    )
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
            packetEvidenceMutationToken = UUID()
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

private struct FH5NumericPromotionReviewPacketPreparationView:
    View {
    let onPrepare: () throws -> String
    let preparedInputStateFingerprint: String?
    let evidenceMutationToken: UUID

    @State private var preparedPacket: String?
    @State private var statusMessage: String?

    var body: some View {
        Section("Numeric Promotion Review Packet") {
            Text(
                "Prepare a canonical packet from the freshly loaded exact candidate and permission-bound outcomes. It is eligible only for independent maintainer review; it cannot establish accuracy, register a production ruleset, unlock numeric readiness, or activate output."
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            Button("Prepare Promotion Review Packet") {
                do {
                    preparedPacket = try onPrepare()
                    statusMessage =
                        "Canonical review-only packet prepared from the current committed evidence."
                } catch {
                    preparedPacket = nil
                    statusMessage = error.localizedDescription
                }
            }
            .accessibilityIdentifier(
                "prepareFH5NumericPromotionReviewPacketButton"
            )

            if let preparedPacket {
                ShareLink(item: preparedPacket) {
                    Label(
                        "Share Promotion Review Packet",
                        systemImage: "square.and.arrow.up"
                    )
                }
                .accessibilityIdentifier(
                    "shareFH5NumericPromotionReviewPacketButton"
                )
            }

            if let statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onChange(of: preparedInputStateFingerprint) {
            clear()
        }
        .onChange(of: evidenceMutationToken) {
            clear()
        }
    }

    private func clear() {
        preparedPacket = nil
        statusMessage = nil
    }
}

private struct FH5SharedNumericPromotionReviewPacketInspector:
    View {
    let onValidate:
        (Data) throws -> FH5NumericPromotionReviewPacket
    let receiverCandidateFingerprint: String

    @State private var pastedJSON = ""
    @State private var validatedPacket:
        FH5NumericPromotionReviewPacket?
    @State private var statusMessage: String?

    var body: some View {
        Section("Inspect Shared Promotion Packet") {
            Text(
                "Paste an exact canonical FH5 Numeric Promotion Review packet to inspect it transiently against the freshly regenerated current saved candidate."
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            TextEditor(text: $pastedJSON)
                .font(.caption.monospaced())
                .frame(minHeight: 150)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onChange(of: pastedJSON) {
                    validatedPacket = nil
                    statusMessage = nil
                }
                .accessibilityIdentifier(
                    "fh5NumericPromotionReviewPacketJSON"
                )

            Button("Validate Shared Promotion Packet") {
                validate()
            }
            .disabled(pastedJSON.isEmpty)
            .accessibilityIdentifier(
                "validateFH5NumericPromotionReviewPacketButton"
            )

            if let validatedPacket {
                Label(
                    "Shared promotion packet accepted for maintainer review",
                    systemImage: "checkmark.seal"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(ForzAdvisorTheme.success)
                .accessibilityIdentifier(
                    "fh5NumericPromotionReviewPacketAccepted"
                )
                FH5NumericPromotionReviewPacketSummary(
                    packet: validatedPacket
                )
            }

            if let statusMessage {
                Label(
                    statusMessage,
                    systemImage:
                        validatedPacket == nil
                        ? "exclamationmark.triangle"
                        : "checkmark.circle"
                )
                .font(.caption)
                .foregroundStyle(
                    validatedPacket == nil
                    ? ForzAdvisorTheme.warning
                    : .secondary
                )
                .accessibilityIdentifier(
                    "fh5NumericPromotionReviewPacketStatus"
                )
            }

            Text(
                "Inspection is review-only and transient. Pasted JSON and the validated result are not imported, saved, applied, scored, ranked, promoted, or used to activate numeric FH5 output. The sender's prepared-input fingerprint is not receiver-verifiable history."
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            Button("Clear") {
                clear()
            }
            .disabled(
                pastedJSON.isEmpty
                    && validatedPacket == nil
                    && statusMessage == nil
            )
            .accessibilityIdentifier(
                "clearFH5NumericPromotionReviewPacketButton"
            )
        }
        .onChange(of: receiverCandidateFingerprint) {
            clear()
        }
    }

    private func validate() {
        do {
            validatedPacket = try onValidate(
                Data(pastedJSON.utf8)
            )
            statusMessage =
                "Validated against the freshly regenerated exact current saved FH5 candidate. No data was imported or saved."
        } catch {
            validatedPacket = nil
            statusMessage = error.localizedDescription
        }
    }

    private func clear() {
        pastedJSON = ""
        validatedPacket = nil
        statusMessage = nil
    }
}

private struct FH5NumericPromotionReviewPacketSummary: View {
    let packet: FH5NumericPromotionReviewPacket

    var body: some View {
        LabeledContent(
            "Unique Sessions",
            value: "\(packet.counts.uniqueSessionCount)"
        )
        LabeledContent(
            "Variant Preferred",
            value: "\(packet.counts.variantPreferredCount)"
        )
        LabeledContent(
            "Nondecisive",
            value: "\(packet.counts.nonDecisiveCount)"
        )
        LabeledContent(
            "Baseline Preferred",
            value: "\(packet.counts.baselinePreferredCount)"
        )
        LabeledContent(
            "Distinct UTC Days",
            value: "\(packet.counts.distinctUTCDayCount)"
        )
        accessibleFingerprint(
            title: "Candidate",
            fingerprint:
                packet.candidateBinding
                    .generatedCandidateFingerprint
        )
        accessibleFingerprint(
            title: "Packet",
            fingerprint: packet.artifactFingerprint
        )
        Label(
            "Accuracy not established",
            systemImage: "xmark.shield"
        )
        Label(
            "Production registration and numeric output not permitted",
            systemImage: "hand.raised"
        )
        Label(
            "Independent maintainer review required",
            systemImage: "person.badge.shield.checkmark"
        )
    }

    private func accessibleFingerprint(
        title: String,
        fingerprint: String
    ) -> some View {
        let prefix = String(fingerprint.prefix(12))
        return LabeledContent(title) {
            Text(prefix)
                .font(.caption.monospaced())
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title) fingerprint")
        .accessibilityValue("Prefix \(prefix)")
    }
}
