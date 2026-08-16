//
//  FH6ValidationReviewedSessionsView.swift
//  forzadvisor
//

import SwiftUI

struct FH6ValidationReviewedSessionsView: View {
    let report: FH6ValidationReviewReport

    private var keepCount: Int {
        report.groups.reduce(0) { $0 + $1.keepCount }
    }

    private var adjustCount: Int {
        report.groups.reduce(0) { $0 + $1.adjustCount }
    }

    private var rejectCount: Int {
        report.groups.reduce(0) { $0 + $1.rejectCount }
    }

    var body: some View {
        List {
            Section("Overview") {
                LabeledContent("Accepted sessions", value: "\(report.verifiedUniqueSessionCount)")
                LabeledContent("Keep", value: "\(keepCount)")
                LabeledContent("Adjust", value: "\(adjustCount)")
                LabeledContent("Reject", value: "\(rejectCount)")
                Text("These are observed outcomes. They do not rank tune quality, change settings, or prove accuracy.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .forzAdvisorRowBackground()

            Section("Session groups") {
                if report.groups.isEmpty {
                    ContentUnavailableView(
                        "No Reviewed Sessions",
                        systemImage: "list.bullet.clipboard",
                        description: Text("Import a permission-bound shared session to review its outcome here.")
                    )
                } else {
                    ForEach(report.groups) { group in
                        FH6ValidationSessionGroupView(group: group)
                    }
                }
            }
            .forzAdvisorRowBackground()

            Section {
                DisclosureGroup("Technical details") {
                    LabeledContent("Received files", value: "\(report.receivedCount)")
                    LabeledContent("Quarantined", value: "\(report.quarantinedCount)")
                    LabeledContent("Invalid", value: "\(report.invalidCount)")
                    LabeledContent("Duplicate copies ignored", value: "\(report.duplicateCount)")
                    LabeledContent("Conflicts quarantined", value: "\(report.conflictCount)")
                    LabeledContent("Receipt replays quarantined", value: "\(report.receiptReplayCount)")
                    Text("Quarantined, conflicting, replayed, invalid, stale, or permission-ineligible records are excluded from accepted-session counts.")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .forzAdvisorRowBackground()
        }
        .navigationTitle("Reviewed Sessions")
        .navigationBarTitleDisplayMode(.inline)
        .forzAdvisorScreenChrome()
    }
}

private struct FH6ValidationSessionGroupView: View {
    let group: FH6ValidationReviewOutcomeGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("\(group.associationContext.vehicle.year) \(group.associationContext.vehicle.make) \(group.associationContext.vehicle.model)")
                .font(.subheadline.weight(.semibold))
            Text("\(group.associationContext.game.shortTitle) \(group.associationContext.gameBuildVersion) · \(group.associationContext.discipline.title)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(group.sessionCount) session\(group.sessionCount == 1 ? "" : "s") · Keep \(group.keepCount) · Adjust \(group.adjustCount) · Reject \(group.rejectCount)")
                .font(.caption)

            counts("Handling", group.handlingSymptomCounts, title: feedbackTitle)
            counts("Course", group.courseTypeCounts, title: courseTitle)
            counts("Surface", group.surfaceCounts, title: surfaceTitle)
            counts("Input", group.inputCounts, title: inputTitle)

            DisclosureGroup("Technical details") {
                Text("Setup fingerprint prefix: \(group.testedTuneFingerprint.prefix(12))")
                    .font(.caption.monospaced())
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func counts(
        _ label: String,
        _ values: [FH6ValidationReviewValueCount],
        title: (String) -> String
    ) -> some View {
        if !values.isEmpty {
            Text("\(label): " + values.map { "\(title($0.value)) \($0.count)" }.joined(separator: " · "))
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
