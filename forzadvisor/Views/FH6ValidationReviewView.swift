//
//  FH6ValidationReviewView.swift
//  forzadvisor
//
//  Tune-scoped review of shared, permission-bound FH6 validation exports.
//  Reviewed outcomes cannot change the tune, projection, or ruleset.
//

import SwiftUI

struct FH6ValidationReviewView: View {
    let tune: TuneResult
    let entries: [FH6ValidationReviewEntry]
    let storageError: String?
    let onImport: (FH6ValidationReviewEntry) -> String?
    let onDelete: (FH6ValidationReviewEntry) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var pastedJSON = ""
    @State private var validatedJSON: Data?
    @State private var directReceiptAndPermissionConfirmed = false
    @State private var statusMessage: String?

    private var report: FH6ValidationReviewReport {
        FH6ValidationReviewEvaluator().evaluate(entries)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Safety Boundary") {
                    Label(
                        "Test-drive outcomes only",
                        systemImage: "exclamationmark.shield"
                    )
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ForzAdvisorTheme.warning)
                    Text("Review reports only observed test-drive outcomes and conditions. It never ranks tune quality, changes settings, or promotes a ruleset. A local permission check binds the exact bytes but is not identity authentication.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .forzAdvisorRowBackground()

                if let storageError {
                    Section("Local Review Storage") {
                        Label(storageError, systemImage: "externaldrive.badge.exclamationmark")
                            .font(.caption)
                            .foregroundStyle(ForzAdvisorTheme.warning)
                    }
                    .forzAdvisorRowBackground()
                }

                Section("Paste Validation JSON") {
                    TextEditor(text: $pastedJSON)
                        .font(.caption.monospaced())
                        .frame(minHeight: 150)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: pastedJSON) {
                            validatedJSON = nil
                            directReceiptAndPermissionConfirmed = false
                            statusMessage = nil
                        }
                        .accessibilityIdentifier("fh6ValidationReviewJSON")

                    Button("Validate Exact Export") {
                        validatePaste()
                    }
                    .disabled(pastedJSON.isEmpty)
                    .accessibilityIdentifier("validateFH6ValidationReviewButton")

                    if validatedJSON != nil {
                        Label(
                            "Exact export matches this saved FH6 tune",
                            systemImage: "checkmark.seal"
                        )
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(ForzAdvisorTheme.success)

                        Toggle(
                            "I received this directly from the driver and confirmed permission for deidentified structured reuse.",
                            isOn: $directReceiptAndPermissionConfirmed
                        )
                        .font(.caption)
                        .accessibilityIdentifier("confirmFH6ValidationReviewPermission")

                        Button("Import Permission-Bound Session") {
                            importValidatedPaste()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(
                            !directReceiptAndPermissionConfirmed
                                || storageError != nil
                        )
                        .accessibilityIdentifier("importFH6ValidationReviewButton")
                    }

                    if let statusMessage {
                        Text(statusMessage)
                            .font(.caption)
                            .foregroundStyle(
                                validatedJSON == nil
                                    ? ForzAdvisorTheme.warning
                                    : .secondary
                            )
                    }
                }
                .forzAdvisorRowBackground()

                Section("Reviewed Sessions") {
                    LabeledContent(
                        "Permission-bound sessions",
                        value: "\(report.verifiedUniqueSessionCount)"
                    )
                    LabeledContent(
                        "Keep",
                        value: "\(report.groups.reduce(0) { $0 + $1.keepCount })"
                    )
                    LabeledContent(
                        "Adjust",
                        value: "\(report.groups.reduce(0) { $0 + $1.adjustCount })"
                    )
                    LabeledContent(
                        "Reject",
                        value: "\(report.groups.reduce(0) { $0 + $1.rejectCount })"
                    )

                    if report.conflictCount > 0 {
                        LabeledContent(
                            "Administrative conflicts quarantined",
                            value: "\(report.conflictCount)"
                        )
                        .foregroundStyle(ForzAdvisorTheme.warning)
                    }
                    if report.receiptReplayCount > 0 {
                        LabeledContent(
                            "Receipt replays quarantined",
                            value: "\(report.receiptReplayCount)"
                        )
                        .foregroundStyle(ForzAdvisorTheme.warning)
                    }
                    if report.duplicateCount > 0 {
                        LabeledContent(
                            "Administrative copies ignored",
                            value: "\(report.duplicateCount)"
                        )
                    }

                    if report.groups.isEmpty {
                        Text("No permission-bound sessions have been imported for this saved tune.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(report.groups) { group in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(
                                "\(group.associationContext.vehicle.year) \(group.associationContext.vehicle.make) \(group.associationContext.vehicle.model)"
                            )
                            .font(.subheadline.weight(.semibold))
                            Text(
                                "\(group.associationContext.game.shortTitle) \(group.associationContext.gameBuildVersion) · \(group.associationContext.discipline.title)"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            Text(
                                "\(group.sessionCount) session\(group.sessionCount == 1 ? "" : "s") · Keep \(group.keepCount) · Adjust \(group.adjustCount) · Reject \(group.rejectCount)"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)

                            reviewCounts(
                                title: "Handling",
                                counts: group.handlingSymptomCounts,
                                displayValue: feedbackTitle
                            )
                            reviewCounts(
                                title: "Course",
                                counts: group.courseTypeCounts,
                                displayValue: courseTitle
                            )
                            reviewCounts(
                                title: "Surface",
                                counts: group.surfaceCounts,
                                displayValue: surfaceTitle
                            )
                            reviewCounts(
                                title: "Input",
                                counts: group.inputCounts,
                                displayValue: inputTitle
                            )
                        }
                        .padding(.vertical, 3)
                    }
                }
                .forzAdvisorRowBackground()

                if !entries.isEmpty {
                    Section("Local Review Queue") {
                        ForEach(entries) { entry in
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.importedAt, format: .dateTime)
                                        .font(.caption.weight(.semibold))
                                    Text(entry.permission.contentFingerprint.prefix(12))
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Delete", role: .destructive) {
                                    onDelete(entry)
                                }
                                .accessibilityIdentifier(
                                    "deleteFH6ValidationReviewEntryButton"
                                )
                            }
                        }
                    }
                    .forzAdvisorRowBackground()
                }
            }
            .navigationTitle("FH6 Validation Review")
            .forzAdvisorScreenChrome()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func validatePaste() {
        let data = Data(pastedJSON.utf8)
        do {
            let validated = try FH6ValidationReviewIngestor().validate(data)
            guard FH6ValidationReviewIngestor().matchesSavedTune(
                validated,
                tune: tune
            ) else {
                throw FH6ValidationReviewError.tuneMismatch
            }
            validatedJSON = data
            statusMessage = "The exact export matches this saved FH6 build, ruleset, and applied settings. Confirm the separate permission check to import it."
        } catch {
            validatedJSON = nil
            directReceiptAndPermissionConfirmed = false
            statusMessage = error.localizedDescription
        }
    }

    private func importValidatedPaste() {
        guard let validatedJSON else { return }
        do {
            let entry = try FH6ValidationReviewEntry.locallyReviewed(
                canonicalExportJSON: validatedJSON,
                reviewerConfirmedDirectReceiptAndReusePermission:
                    directReceiptAndPermissionConfirmed
            )
            if let errorMessage = onImport(entry) {
                statusMessage = errorMessage
                return
            }
            pastedJSON = ""
            self.validatedJSON = nil
            directReceiptAndPermissionConfirmed = false
            statusMessage = "Permission-bound test-drive session imported locally."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    @ViewBuilder
    private func reviewCounts(
        title: String,
        counts: [FH6ValidationReviewValueCount],
        displayValue: (String) -> String
    ) -> some View {
        if !counts.isEmpty {
            Text(
                "\(title): "
                    + counts.map {
                        "\(displayValue($0.value)) \($0.count)"
                    }.joined(separator: " · ")
            )
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    private func feedbackTitle(_ value: String) -> String {
        TuneFeedback(rawValue: value)?.title ?? value
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
}
