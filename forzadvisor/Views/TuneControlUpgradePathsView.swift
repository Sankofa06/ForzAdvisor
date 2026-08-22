//
//  TuneControlUpgradePathsView.swift
//  forzadvisor
//
//  Result rendering for exact alternative tuning-control buy lists.
//

import SwiftUI

struct TuneControlUpgradePathCopyAction: Identifiable {
    enum Outcome: Equatable {
        case copied(pathID: String, message: String)
        case rejected(message: String)
    }

    let path: TuneControlUpgradePath
    let number: Int
    let resolveClipboardText: (String) -> String?
    let writeClipboard: (String) -> Void
    let announce: (String) -> Void

    var id: String { path.id }

    func perform() -> Outcome {
        guard let text = resolveClipboardText(path.id) else {
            let message =
                "Path \(number) could not be freshly verified. Nothing was copied; reopen Upgrade Lab if its evidence changed."
            announce(message)
            return .rejected(message: message)
        }
        writeClipboard(text)
        let message = "Path \(number) copied as a separate checklist."
        announce(message)
        return .copied(pathID: path.id, message: message)
    }
}

struct TuneControlUpgradePathsView: View {
    let paths: [TuneControlUpgradePath]
    let resolveClipboardText: (String) -> String?
    let writeClipboard: (String) -> Void
    let announce: (String) -> Void

    @State private var copiedPathID: String?
    @State private var feedbackMessage: String?

    init(
        paths: [TuneControlUpgradePath],
        resolveClipboardText: @escaping (String) -> String?,
        writeClipboard: @escaping (String) -> Void = {
            UIPasteboard.general.string = $0
        },
        announce: @escaping (String) -> Void = {
            UIAccessibility.post(notification: .announcement, argument: $0)
        }
    ) {
        self.paths = paths
        self.resolveClipboardText = resolveClipboardText
        self.writeClipboard = writeClipboard
        self.announce = announce
    }

    var copyActions: [TuneControlUpgradePathCopyAction] {
        paths.enumerated().map { index, path in
            TuneControlUpgradePathCopyAction(
                path: path,
                number: index + 1,
                resolveClipboardText: resolveClipboardText,
                writeClipboard: writeClipboard,
                announce: announce
            )
        }
    }

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

            ForEach(copyActions) { action in
                let index = action.number - 1
                let path = action.path
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
                        apply(action.perform())
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

    private func apply(_ outcome: TuneControlUpgradePathCopyAction.Outcome) {
        switch outcome {
        case .rejected(let message):
            copiedPathID = nil
            feedbackMessage = message
        case .copied(let pathID, let message):
            copiedPathID = pathID
            feedbackMessage = message
        }
    }
}
