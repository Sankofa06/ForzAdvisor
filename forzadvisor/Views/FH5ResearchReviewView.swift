//
//  FH5ResearchReviewView.swift
//  forzadvisor
//
//  Plan-scoped review of shared FH5 Research JSON. This surface compares raw
//  observations only and cannot create or unlock tuning output.
//

import SwiftUI

struct FH5ResearchReviewView: View {
    let tune: TuneResult
    let entries: [FH5ResearchReviewEntry]
    let onImport: (FH5ResearchReviewEntry) -> String?
    let onDelete: (FH5ResearchReviewEntry) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var pastedJSON = ""
    @State private var validatedJSON: Data?
    @State private var directReceiptAndPermissionConfirmed = false
    @State private var statusMessage: String?

    private var report: FH5ResearchReviewReport {
        FH5ResearchReviewEvaluator().evaluate(
            entries.map { entry in
                FH5ResearchReviewInput(entry: entry)
            }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Safety Boundary") {
                    Label(
                        "Raw research evidence only",
                        systemImage: "exclamationmark.shield"
                    )
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ForzAdvisorTheme.warning)
                    Text("Review never averages values, creates a ruleset, or unlocks numeric FH5 tuning. A local permission check binds the exact bytes but is not identity authentication.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .forzAdvisorRowBackground()

                Section("Paste Observation JSON") {
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
                        .accessibilityIdentifier("fh5ResearchReviewJSON")

                    Button("Validate Exact Export") {
                        validatePaste()
                    }
                    .disabled(pastedJSON.isEmpty)
                    .accessibilityIdentifier("validateFH5ResearchReviewButton")

                    if validatedJSON != nil {
                        Label(
                            "Exact canonical FH5 Research export",
                            systemImage: "checkmark.seal"
                        )
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(ForzAdvisorTheme.success)

                        Toggle(
                            "I received this directly from the observer and confirmed permission for deidentified structured reuse.",
                            isOn: $directReceiptAndPermissionConfirmed
                        )
                        .font(.caption)
                        .accessibilityIdentifier("confirmFH5ResearchReviewPermission")

                        Button("Import Permission-Bound Observation") {
                            importValidatedPaste()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!directReceiptAndPermissionConfirmed)
                        .accessibilityIdentifier("importFH5ResearchReviewButton")
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

                Section("Current Review") {
                    LabeledContent(
                        "Permission-bound observations",
                        value: "\(report.verifiedUniqueObservationCount)"
                    )
                    LabeledContent("Groups", value: "\(report.groups.count)")
                    if report.administrativeConflictCount > 0 {
                        LabeledContent(
                            "Administrative conflicts quarantined",
                            value: "\(report.administrativeConflictCount)"
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
                        Text("No permission-bound observations have been imported for this saved plan.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(report.groups) { group in
                        VStack(alignment: .leading, spacing: 5) {
                            Label(group.status.title, systemImage: symbol(for: group.status))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(color(for: group.status))
                            Text(
                                "\(group.association.platform.title) · \(group.association.gameVersion) · \(group.association.tireCompoundDisplayName) · \(group.association.forwardGearCount) gears"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            Text(
                                "\(group.observationCount) raw observation\(group.observationCount == 1 ? "" : "s"); \(group.measurementVariantCount) exact value set\(group.measurementVariantCount == 1 ? "" : "s")."
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
                            }
                        }
                    }
                    .forzAdvisorRowBackground()
                }
            }
            .navigationTitle("FH5 Research Review")
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
            let validated = try FH5ResearchReviewIngestor().validate(data)
            guard FH5ResearchReviewIngestor().matchesSavedPlan(validated, tune: tune) else {
                throw FH5ResearchReviewError.planMismatch
            }
            validatedJSON = data
            statusMessage = "The exact export matches this saved FH5 catalog plan. Confirm the separate permission check to import it."
        } catch {
            validatedJSON = nil
            directReceiptAndPermissionConfirmed = false
            statusMessage = error.localizedDescription
        }
    }

    private func importValidatedPaste() {
        guard let validatedJSON else { return }
        do {
            let entry = try FH5ResearchReviewEntry.locallyReviewed(
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
            statusMessage = "Permission-bound raw observation imported locally."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func symbol(for status: FH5ResearchReplicationStatus) -> String {
        switch status {
        case .insufficient: "1.circle"
        case .replicated: "checkmark.seal"
        case .conflicted: "exclamationmark.triangle"
        }
    }

    private func color(for status: FH5ResearchReplicationStatus) -> Color {
        switch status {
        case .insufficient: .secondary
        case .replicated: ForzAdvisorTheme.success
        case .conflicted: ForzAdvisorTheme.warning
        }
    }
}
