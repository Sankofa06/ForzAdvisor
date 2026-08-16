import SwiftUI

struct TuneEvidenceHubAdapter {
    let summary: TuneEvidenceSummary
    let evidenceRecords: [ValidationEvidenceRecord]
    let onRecordTestDrive: (() -> Void)?
    let onOpenFH5Research: (() -> Void)?
    let onOpenFH5Experiment: (() -> Void)?
    let onRunFH6CommunityTrial: (() -> Void)?
    let fh5ResearchReview: AnyView?
    let fh5CandidateReview: AnyView?
    let fh6ValidationReview: AnyView?
    let fh6CommunityReview: AnyView?
    let authorization: (String) -> ValidationEvidenceAuthorizationEnvelope?
    let onGrant: (String) throws -> ValidationEvidenceAuthorizationEnvelope
    let onRevoke: (FirstPartyValidationRecord) throws
        -> ValidationEvidenceAuthorizationEnvelope?
    let onDelete: (ValidationEvidenceRecord) throws -> Void
}

struct TuneEvidenceHubView: View {
    let adapter: TuneEvidenceHubAdapter

    var body: some View {
        List {
            Section("Evidence records on this device") {
                LabeledContent(
                    "Local only",
                    value: "\(adapter.summary.localOnlyRecordCount)"
                )
                LabeledContent(
                    "Reusable",
                    value: "\(adapter.summary.reusableRecordCount)"
                )
                LabeledContent(
                    "Reviewed copies",
                    value: "\(adapter.summary.reviewedRecordCount)"
                )
                Text("Local-only observations can guide the next optional step on this device, but never enter exports or review packets.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .forzAdvisorRowBackground()

            captureSection
            reuseSection
            reviewSection
        }
        .navigationTitle("Evidence Hub")
        .forzAdvisorScreenChrome()
        .accessibilityIdentifier("tuneEvidenceHub")
    }

    @ViewBuilder
    private var captureSection: some View {
        Section("Optional capture") {
            action("Record Test Drive", id: "hubRecordTestDrive", adapter.onRecordTestDrive)
            action("Record FH5 Research", id: "hubRecordFH5Research", adapter.onOpenFH5Research)
            action("Run FH5 Experiment", id: "hubRunFH5Experiment", adapter.onOpenFH5Experiment)
            action("Run FH6 Community Comparison", id: "hubRunFH6CommunityTrial", adapter.onRunFH6CommunityTrial)
        }
        .forzAdvisorRowBackground()
    }

    @ViewBuilder
    private var reuseSection: some View {
        Section("Future reuse") {
            if adapter.evidenceRecords.isEmpty {
                Text("Record an exact test drive before choosing whether it may be reused.")
                    .foregroundStyle(.secondary)
            }
            ForEach(Array(adapter.evidenceRecords.enumerated()), id: \.element.fingerprint) {
                index, evidence in
                NavigationLink {
                    authorizationView(for: evidence)
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(evidenceTitle(evidence, index: index))
                        Text(String(evidence.fingerprint.prefix(12)))
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityIdentifier("evidenceReuseRecord-\(index)")
            }
        }
        .forzAdvisorRowBackground()
    }

    @ViewBuilder
    private var reviewSection: some View {
        Section("Import, review, and packets") {
            destination("FH5 Research Review", id: "hubFH5ResearchReview", adapter.fh5ResearchReview)
            destination("FH5 Candidate Outcome Review", id: "hubFH5CandidateReview", adapter.fh5CandidateReview)
            destination("FH6 Validation Review", id: "hubFH6ValidationReview", adapter.fh6ValidationReview)
            destination("FH6 Community Outcome Review", id: "hubFH6CommunityReview", adapter.fh6CommunityReview)
        }
        .forzAdvisorRowBackground()
    }

    @ViewBuilder
    private func authorizationView(
        for evidence: ValidationEvidenceRecord
    ) -> some View {
        switch evidence {
        case .localOnly:
            ValidationEvidenceAuthorizationView(
                observationFingerprint: evidence.fingerprint,
                allowedFields: ValidationLocalObservation.reusableFieldLabels,
                authorization: adapter.authorization(evidence.fingerprint),
                onGrant: { try adapter.onGrant(evidence.fingerprint) },
                onRevoke: { adapter.authorization(evidence.fingerprint) },
                onDelete: { try adapter.onDelete(evidence) }
            )
        case .reusable(let record):
            ValidationEvidenceAuthorizationView(
                observationFingerprint: evidence.fingerprint,
                allowedFields: ValidationLocalObservation.reusableFieldLabels,
                authorization: adapter.authorization(evidence.fingerprint),
                onGrant: { try adapter.onGrant(evidence.fingerprint) },
                onRevoke: { try adapter.onRevoke(record) },
                onDelete: { try adapter.onDelete(evidence) }
            )
        }
    }

    private func evidenceTitle(
        _ evidence: ValidationEvidenceRecord,
        index: Int
    ) -> String {
        switch evidence {
        case .localOnly: "Test Drive \(index + 1) · Local only"
        case .reusable: "Test Drive \(index + 1) · Reusable"
        }
    }

    @ViewBuilder
    private func action(
        _ title: String,
        id: String,
        _ callback: (() -> Void)?
    ) -> some View {
        if let callback {
            Button(title, action: callback)
                .accessibilityIdentifier(id)
        }
    }

    @ViewBuilder
    private func destination(
        _ title: String,
        id: String,
        _ view: AnyView?
    ) -> some View {
        if let view {
            NavigationLink(title, destination: view)
                .accessibilityIdentifier(id)
        }
    }
}
