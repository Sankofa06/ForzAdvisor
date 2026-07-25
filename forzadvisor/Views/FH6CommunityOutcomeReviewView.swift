//
//  FH6CommunityOutcomeReviewView.swift
//  forzadvisor
//
//  Local, collection-only review of permission-bound community outcomes.
//

import SwiftUI

struct FH6CommunityOutcomeReviewView: View {
    let tune: TuneResult
    let localRecords: [FH6CommunityReferenceTrialRecord]
    let entries: [FH6CommunityOutcomeReviewEntry]
    let report: FH6CommunityOutcomeCollectionReport
    let storageError: String?
    let onImport:
        (FH6CommunityOutcomeReviewEntry) -> String?
    let onValidateCurrentCandidate: (Data) -> String?
    let onDelete:
        (FH6CommunityOutcomeReviewEntry) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var pastedJSON = ""
    @State private var validatedJSON: Data?
    @State private var directReceiptConfirmed = false
    @State private var reusePermissionConfirmed = false
    @State private var statusMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Collection-Only Boundary") {
                    Label(
                        "Comparative outcomes only",
                        systemImage:
                            "rectangle.stack.badge.checkmark"
                    )
                    .font(.subheadline.weight(.semibold))
                    Text(
                        "This review combines local and permission-bound reviewed A-B-B-A outcomes for the current candidate. It is not validation, an accuracy score, ground truth, a ranking, or promotion, and it cannot change tuning."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .forzAdvisorRowBackground()

                if let storageError {
                    Section("Local Review Storage") {
                        Label(
                            storageError,
                            systemImage:
                                "externaldrive.badge.exclamationmark"
                        )
                        .font(.caption)
                        .foregroundStyle(
                            ForzAdvisorTheme.warning
                        )
                    }
                    .forzAdvisorRowBackground()
                }

                Section("Paste Community Outcome JSON") {
                    TextEditor(text: $pastedJSON)
                        .font(.caption.monospaced())
                        .frame(minHeight: 150)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier(
                            "fh6CommunityOutcomeReviewJSON"
                        )
                        .onChange(of: pastedJSON) {
                            resetValidation()
                        }

                    Button("Validate Exact Candidate Match") {
                        validatePaste()
                    }
                    .disabled(pastedJSON.isEmpty)
                    .accessibilityIdentifier(
                        "validateFH6CommunityOutcomeReviewButton"
                    )

                    if validatedJSON != nil {
                        Label(
                            "Exact current candidate match",
                            systemImage: "checkmark.seal"
                        )
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(
                            ForzAdvisorTheme.success
                        )

                        Toggle(
                            "I received this exact export directly.",
                            isOn: $directReceiptConfirmed
                        )
                        .font(.caption)
                        .accessibilityIdentifier(
                            "confirmFH6CommunityOutcomeDirectReceipt"
                        )

                        Toggle(
                            "The sender permitted deidentified structured outcome reuse.",
                            isOn: $reusePermissionConfirmed
                        )
                        .font(.caption)
                        .accessibilityIdentifier(
                            "confirmFH6CommunityOutcomeReusePermission"
                        )

                        Text(
                            "Hashes and UUIDs bind exact bytes and permissions. They do not authenticate a tester or prove identity."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        Button("Import Reviewed Outcome") {
                            importValidatedPaste()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(
                            !directReceiptConfirmed
                                || !reusePermissionConfirmed
                                || storageError != nil
                        )
                        .accessibilityIdentifier(
                            "importFH6CommunityOutcomeReviewButton"
                        )
                    }

                    if let statusMessage {
                        Text(statusMessage)
                            .font(.caption)
                            .foregroundStyle(
                                validatedJSON == nil
                                    ? ForzAdvisorTheme.warning
                                    : .secondary
                            )
                            .accessibilityIdentifier(
                                "fh6CommunityOutcomeReviewStatus"
                            )
                    }
                }
                .forzAdvisorRowBackground()

                Section("Current Candidate Summary") {
                    Text(report.summary)
                    LabeledContent(
                        "Received",
                        value: "\(report.receivedCount)"
                    )
                    LabeledContent(
                        "Valid local",
                        value: "\(report.validLocalCount)"
                    )
                    LabeledContent(
                        "Valid reviewed",
                        value: "\(report.validReviewedCount)"
                    )
                    LabeledContent(
                        "Unique",
                        value:
                            "\(report.verifiedUniqueSessionCount)"
                    )
                    LabeledContent(
                        "Quarantined",
                        value: "\(report.quarantinedCount)"
                    )
                    .foregroundStyle(
                        report.quarantinedCount > 0
                            ? ForzAdvisorTheme.warning
                            : .secondary
                    )
                    Text(
                        "Invalid: \(report.invalidCount) · Duplicates ignored: \(report.duplicateCount) · Submission conflicts: \(report.conflictCount) · Receipt replays: \(report.receiptReplayCount) · Session replays: \(report.semanticReplayCount)"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    dimensionRows(
                        "Local",
                        report.localDimensions
                    )
                    dimensionRows(
                        "Reviewed",
                        report.reviewedDimensions
                    )
                    dimensionRows(
                        "Combined",
                        report.combinedDimensions
                    )
                }
                .accessibilityIdentifier(
                    "fh6CommunityOutcomeReviewSummary"
                )
                .forzAdvisorRowBackground()

                Section("Local Review Queue") {
                    if entries.isEmpty {
                        Text("No reviewed community outcomes stored.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(entries) { entry in
                            VStack(
                                alignment: .leading,
                                spacing: 7
                            ) {
                                Label(
                                    isCurrent(entry)
                                        ? "Current candidate match"
                                        : "Historical or quarantined entry",
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
                                .font(.caption)
                                Text(
                                    entry.permission
                                        .canonicalExportDigest
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
                                    "deleteFH6CommunityOutcomeReviewEntryButton-\(entry.id.uuidString)"
                                )
                            }
                        }
                    }
                }
                .accessibilityIdentifier(
                    "fh6CommunityOutcomeReviewQueue"
                )
                .forzAdvisorRowBackground()

                Section("Privacy Boundary") {
                    Text(
                        "Imports contain source metadata, controlled context, run confirmations, and a tester-authored comparative outcome only. They contain no community tune settings, parts, share codes, source prose or media, metrics, telemetry, accounts, generated tune settings, notes, or device identifiers. Import is manual and local; there is no source lookup or background upload."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    Text(
                        "\(localRecords.count) local comparison record\(localRecords.count == 1 ? "" : "s") are available to this collection without copying source tune values."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .forzAdvisorRowBackground()
            }
            .navigationTitle("Community Outcome Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func validatePaste() {
        let data = Data(pastedJSON.utf8)
        do {
            let ingestor =
                FH6CommunityOutcomeReviewIngestor()
            let validated = try ingestor.validate(data)
            guard ingestor.matchesSavedTune(
                validated,
                tune: tune
            ) else {
                throw FH6CommunityOutcomeReviewError
                    .tuneMismatch
            }
            if let freshError =
                    onValidateCurrentCandidate(data) {
                throw FH6CommunityOutcomeReviewUIError
                    .freshValidationFailed(freshError)
            }
            validatedJSON = data
            directReceiptConfirmed = false
            reusePermissionConfirmed = false
            statusMessage =
                "The canonical export matches this exact saved candidate. Confirm both separate permission checks to import."
        } catch {
            validatedJSON = nil
            directReceiptConfirmed = false
            reusePermissionConfirmed = false
            statusMessage = error.localizedDescription
        }
    }

    private func importValidatedPaste() {
        do {
            guard let validatedJSON else {
                throw FH6CommunityOutcomeReviewError
                    .emptyPayload
            }
            guard validatedJSON == Data(pastedJSON.utf8) else {
                throw FH6CommunityOutcomeReviewError
                    .nonCanonicalJSON
            }
            let entry =
                try FH6CommunityOutcomeReviewEntry
                    .locallyReviewed(
                        canonicalExportJSON:
                            validatedJSON,
                        expectedTune: tune,
                        reviewerConfirmedDirectReceipt:
                            directReceiptConfirmed,
                        reviewerConfirmedStructuredReusePermission:
                            reusePermissionConfirmed
                    )
            if let error = onImport(entry) {
                statusMessage = error
                return
            }
            pastedJSON = ""
            self.validatedJSON = nil
            directReceiptConfirmed = false
            reusePermissionConfirmed = false
            statusMessage =
                "Reviewed outcome imported into local storage."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func resetValidation() {
        validatedJSON = nil
        directReceiptConfirmed = false
        reusePermissionConfirmed = false
        statusMessage = nil
    }

    private func isCurrent(
        _ entry: FH6CommunityOutcomeReviewEntry
    ) -> Bool {
        let ingestor = FH6CommunityOutcomeReviewIngestor()
        guard ingestor.isValidReviewEntry(entry),
              let validated = try? ingestor.validate(
                  entry.canonicalExportJSON
              ) else {
            return false
        }
        return ingestor.matchesSavedTune(
            validated,
            tune: tune
        )
    }

    @ViewBuilder
    private func dimensionRows(
        _ title: String,
        _ dimensions: FH6CommunityOutcomeDimensions
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(title) collection")
                .font(.caption.weight(.semibold))
            countRows(
                "Platform",
                dimensions.platformCounts,
                title: platformTitle
            )
            countRows(
                "Outcome",
                dimensions.outcomeCounts,
                title: outcomeTitle
            )
            countRows(
                "Course",
                dimensions.courseTypeCounts,
                title: courseTitle
            )
            countRows(
                "Surface",
                dimensions.surfaceCounts,
                title: surfaceTitle
            )
            countRows(
                "Input",
                dimensions.inputCounts,
                title: inputTitle
            )
            countRows(
                "Candidate symptoms",
                dimensions
                    .candidateDeficiencySymptomCounts,
                title: feedbackTitle
            )
        }
        .accessibilityIdentifier(
            "fh6CommunityOutcome\(title)Dimensions"
        )
    }

    @ViewBuilder
    private func countRows(
        _ label: String,
        _ counts: [FH6CommunityOutcomeValueCount],
        title: (String) -> String
    ) -> some View {
        if !counts.isEmpty {
            Text(
                "\(label): "
                    + counts.map {
                        "\(title($0.value)) \($0.count)"
                    }.joined(separator: " · ")
            )
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    private func platformTitle(_ value: String) -> String {
        FH6CommunityReferenceKind(rawValue: value)?
            .title ?? value
    }

    private func outcomeTitle(_ value: String) -> String {
        FH6CommunityReferenceTrialOutcome(rawValue: value)?
            .title ?? value
    }

    private func courseTitle(_ value: String) -> String {
        ValidationCourseType(rawValue: value)?.title ?? value
    }

    private func surfaceTitle(_ value: String) -> String {
        ValidationSurface(rawValue: value)?.title ?? value
    }

    private func inputTitle(_ value: String) -> String {
        ValidationInput(rawValue: value)?.title ?? value
    }

    private func feedbackTitle(_ value: String) -> String {
        TuneFeedback(rawValue: value)?.title ?? value
    }
}

private enum FH6CommunityOutcomeReviewUIError:
    LocalizedError {
    case freshValidationFailed(String)

    var errorDescription: String? {
        switch self {
        case .freshValidationFailed(let message):
            message
        }
    }
}
