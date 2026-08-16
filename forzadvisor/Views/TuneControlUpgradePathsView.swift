//
//  TuneControlUpgradePathsView.swift
//  forzadvisor
//
//  Result rendering for exact alternative tuning-control buy lists.
//

import SwiftUI

struct TuneControlUpgradePathsView: View {
    let paths: [TuneControlUpgradePath]
    let resolveClipboardText: (String) -> String?

    @State private var copiedPathID: String?
    @State private var feedbackMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Each path unlocks the same tune controls represented here. Pick one path; the alternatives are not cumulative.")
                .font(.subheadline)

            if let provenance = sharedProvenance {
                Label(provenance.attributionText, systemImage: "checkmark.seal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("tuningControlUpgradePathsProvenance")
            }

            ForEach(Array(paths.enumerated()), id: \.element.id) { index, path in
                VStack(alignment: .leading, spacing: 8) {
                    Text("Path \(index + 1)")
                        .font(.subheadline.weight(.bold))
                    ForEach(path.items) { item in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(item.part.category.label) > \(item.part.slot.label) > \(item.part.label)")
                                .font(.caption.weight(.semibold))
                            Text("Unlocks: \(item.unlocks.map(\.projectionLabel).joined(separator: ", "))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Button {
                        copy(path: path, number: index + 1)
                    } label: {
                        Label(
                            copiedPathID == path.id
                                ? "Copied Path \(index + 1)"
                                : "Copy This Path",
                            systemImage:
                                copiedPathID == path.id
                                ? "checkmark"
                                : "doc.on.doc"
                        )
                    }
                    .accessibilityIdentifier(
                        "copyTuningControlUpgradePath-\(index + 1)"
                    )
                    .accessibilityHint(
                        "Copies only Path \(index + 1) as an isolated upgrade-shop checklist."
                    )
                }
                .accessibilityIdentifier("tuningControlUpgradePath-\(index + 1)")
            }

            if let feedbackMessage {
                Text(feedbackMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier(
                        "copyTuningControlUpgradePathFeedback"
                    )
            }

            Text("Tuning-control paths do not predict PI, credits, entitlement, performance, or installation order. Confirm every item in your game build before buying.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("tuningControlUpgradePaths")
        .onChange(of: paths.map(\.id)) {
            copiedPathID = nil
            feedbackMessage = nil
        }
    }

    private var sharedProvenance: TuneControlUpgradePathProvenance? {
        guard let first = paths.first?.provenance,
              paths.dropFirst().allSatisfy({ $0.provenance == first }) else {
            return nil
        }
        return first
    }

    private func copy(
        path: TuneControlUpgradePath,
        number: Int
    ) {
        guard let text = resolveClipboardText(path.id) else {
            copiedPathID = nil
            feedbackMessage =
                "Path \(number) could not be freshly verified. Nothing was copied; reopen Upgrade Lab if its evidence changed."
            UIAccessibility.post(
                notification: .announcement,
                argument: feedbackMessage
            )
            return
        }
        UIPasteboard.general.string = text
        copiedPathID = path.id
        feedbackMessage = "Path \(number) copied as a separate checklist."
        UIAccessibility.post(
            notification: .announcement,
            argument: feedbackMessage
        )
    }
}
