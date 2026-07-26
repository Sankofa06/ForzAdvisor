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
    let onPrepareIndependentReviewPacket: (() throws -> String)?
    let preparedInputStateFingerprint: String?
    let onValidateIndependentReviewPacket:
        ((Data) throws -> FH6IndependentValidationReviewPacket)?
    let receiverCandidateRevisionFingerprint: String?
    let communityReferenceRecords: [FH6CommunityReferenceTrialRecord]
    let accuracyEvidenceChain:
        FH6AccuracyEvidenceChainAssessment
    let onRunCommunityReferenceTrial: (() -> Void)?
    let onOpenCommunityOutcomeReview: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var pastedJSON = ""
    @State private var validatedJSON: Data?
    @State private var directReceiptAndPermissionConfirmed = false
    @State private var statusMessage: String?
    @State private var preparedIndependentReviewPacket: String?
    @State private var packetStatusMessage: String?

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

                Section("Community Reference Comparisons") {
                    Label(
                        chainTitle,
                        systemImage: "point.3.connected.trianglepath.dotted"
                    )
                    .font(.subheadline.weight(.semibold))
                    .accessibilityIdentifier(
                        "validationReviewAccuracyEvidenceChainState"
                    )
                    Text(
                        "\(accuracyEvidenceChain.matchingValidationCount) matching test drive(s) · \(accuracyEvidenceChain.matchingCommunityComparisonCount) matching community comparison(s). This sequence does not establish accuracy."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    Text(
                        "Separate local comparative observations. These counts are not imported validation sessions and do not affect promotion or tune settings."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    LabeledContent(
                        "YouTube",
                        value: "\(communityReferenceRecords.filter { $0.source.kind == .youtube }.count)"
                    )
                    LabeledContent(
                        "Reddit",
                        value: "\(communityReferenceRecords.filter { $0.source.kind == .reddit }.count)"
                    )
                    ForEach(
                        FH6CommunityReferenceTrialOutcome.allCases,
                        id: \.self
                    ) { outcome in
                        let count = communityReferenceRecords.filter {
                            $0.outcome == outcome
                        }.count
                        if count > 0 {
                            LabeledContent(
                                outcome.title,
                                value: "\(count)"
                            )
                        }
                    }
                    if let onRunCommunityReferenceTrial {
                        Button("Run Community Reference Comparison") {
                            dismiss()
                            onRunCommunityReferenceTrial()
                        }
                        .accessibilityIdentifier(
                            "validationReviewRunCommunityComparisonButton"
                        )
                    }
                    if let onOpenCommunityOutcomeReview {
                        Button("Open Community Outcome Review") {
                            dismiss()
                            onOpenCommunityOutcomeReview()
                        }
                        .accessibilityIdentifier(
                            "validationReviewOpenCommunityOutcomeReviewButton"
                        )
                    }
                }
                .forzAdvisorRowBackground()

                if let onValidateIndependentReviewPacket,
                   let receiverCandidateRevisionFingerprint {
                    FH6SharedIndependentReviewPacketInspector(
                        carDisplayName:
                            tune.request.car.displayName,
                        candidateRevisionFingerprint:
                            receiverCandidateRevisionFingerprint,
                        onValidate:
                            onValidateIndependentReviewPacket
                    )
                }

                if let onPrepareIndependentReviewPacket {
                    Section("Independent Review Packet") {
                        Text(
                            FH6IndependentValidationReviewPacketPolicy
                                .reviewBoundary
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        Button("Prepare Review Packet") {
                            do {
                                preparedIndependentReviewPacket =
                                    try onPrepareIndependentReviewPacket()
                                packetStatusMessage =
                                    "Canonical review-only packet prepared from the current saved evidence."
                            } catch {
                                preparedIndependentReviewPacket = nil
                                packetStatusMessage =
                                    error.localizedDescription
                            }
                        }
                        .accessibilityIdentifier(
                            "prepareFH6IndependentValidationReviewPacketButton"
                        )

                        if let preparedIndependentReviewPacket {
                            ShareLink(
                                item: preparedIndependentReviewPacket
                            ) {
                                Label(
                                    "Share Review Packet",
                                    systemImage: "square.and.arrow.up"
                                )
                            }
                            .accessibilityIdentifier(
                                "shareFH6IndependentValidationReviewPacketButton"
                            )
                        }

                        if let packetStatusMessage {
                            Text(packetStatusMessage)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .forzAdvisorRowBackground()
                }

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
                                    preparedIndependentReviewPacket = nil
                                    packetStatusMessage = nil
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
            .onChange(of: preparedInputStateFingerprint) {
                preparedIndependentReviewPacket = nil
                packetStatusMessage = nil
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    ModalCopilotToolbarLink(
                        destination: .fh6ValidationReview(
                            carDisplayName:
                                tune.request.car.displayName,
                            gameTitle:
                                tune.request.car.game.shortTitle,
                            disciplineTitle:
                                tune.request.discipline.title
                        )
                    )
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var chainTitle: String {
        switch accuracyEvidenceChain.stage {
        case .needsFirstPartyValidation:
            "First-party test drive required"
        case .readyForCommunityComparison:
            "Ready for a community comparison"
        case .communityComparisonCollected:
            "Community comparison collected"
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
            preparedIndependentReviewPacket = nil
            packetStatusMessage = nil
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

private struct FH6SharedIndependentReviewPacketInspector:
    View {
    let carDisplayName: String
    let candidateRevisionFingerprint: String
    let onValidate:
        (Data) throws -> FH6IndependentValidationReviewPacket

    @State private var pastedPacketJSON = ""
    @State private var validatedPacket:
        FH6IndependentValidationReviewPacket?
    @State private var statusMessage: String?

    var body: some View {
        Section("Inspect Shared Review Packet") {
            Text(
                "Paste an exact canonical FH6 Independent Validation Review Packet to inspect it against the freshly loaded current saved candidate."
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            TextEditor(text: $pastedPacketJSON)
                .font(.caption.monospaced())
                .frame(minHeight: 150)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onChange(of: pastedPacketJSON) {
                    validatedPacket = nil
                    statusMessage = nil
                }
                .accessibilityLabel(
                    "Shared FH6 independent validation review packet JSON"
                )
                .accessibilityHint(
                    "Paste the exact canonical JSON shared for this saved candidate."
                )
                .accessibilityIdentifier(
                    "fh6IndependentValidationReviewPacketJSON"
                )

            Button("Validate Shared Review Packet") {
                validatePaste()
            }
            .disabled(pastedPacketJSON.isEmpty)
            .accessibilityIdentifier(
                "validateFH6IndependentValidationReviewPacketButton"
            )

            if let validatedPacket {
                Label(
                    "Shared review packet accepted",
                    systemImage: "checkmark.seal"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(ForzAdvisorTheme.success)
                .accessibilityIdentifier(
                    "fh6IndependentValidationReviewPacketAccepted"
                )

                FH6SharedIndependentReviewPacketSummary(
                    carDisplayName: carDisplayName,
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
                    "fh6IndependentValidationReviewPacketStatus"
                )
            }

            Text(
                FH6IndependentValidationReviewPacketPolicy
                    .reviewBoundary
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            Text(
                "Inspection is transient. Pasted JSON and the validated result are not imported or saved. This summary does not display evidence payloads, permission identifiers, or full fingerprints."
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            Button("Clear") {
                clear()
            }
            .disabled(
                pastedPacketJSON.isEmpty
                    && validatedPacket == nil
                    && statusMessage == nil
            )
            .accessibilityIdentifier(
                "clearFH6IndependentValidationReviewPacketButton"
            )
        }
        .forzAdvisorRowBackground()
        .onChange(of: candidateRevisionFingerprint) {
            clear()
        }
    }

    private func validatePaste() {
        do {
            validatedPacket = try onValidate(
                Data(pastedPacketJSON.utf8)
            )
            statusMessage =
                "Validated against the freshly loaded exact current saved FH6 candidate. No data was imported or saved."
        } catch {
            validatedPacket = nil
            statusMessage = error.localizedDescription
        }
    }

    private func clear() {
        pastedPacketJSON = ""
        validatedPacket = nil
        statusMessage = nil
    }
}

private struct FH6SharedIndependentReviewPacketSummary: View {
    let carDisplayName: String
    let packet: FH6IndependentValidationReviewPacket

    var body: some View {
        LabeledContent("Car", value: carDisplayName)
        LabeledContent(
            "Catalog ID",
            value: packet.candidate.catalogID
        )
        LabeledContent(
            "Test Drives",
            value:
                "\(packet.counts.includedFirstPartyTestDriveCount)"
        )
        LabeledContent(
            "Sender-local Community Outcomes",
            value:
                "\(packet.counts.includedLocalCommunityOutcomeCount)"
        )
        LabeledContent(
            "Permission-bound Reviewed Community Outcomes",
            value:
                "\(packet.counts.includedReviewedCommunityOutcomeCount)"
        )
        LabeledContent(
            "Total Accepted Evidence",
            value: "\(packet.counts.includedEvidenceCount)"
        )
        accessibleFingerprint(
            title: "Candidate Binding",
            fingerprint: packet.candidate.bindingFingerprint
        )
        accessibleFingerprint(
            title: "Packet Fingerprint",
            fingerprint: packet.artifactFingerprint
        )
        Label(
            "Accuracy not established",
            systemImage: "xmark.shield"
        )
        Label(
            "Automatic promotion not permitted",
            systemImage: "hand.raised"
        )
        Label(
            "Independent human review required",
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
