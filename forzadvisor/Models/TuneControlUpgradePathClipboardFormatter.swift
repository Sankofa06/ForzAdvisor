//
//  TuneControlUpgradePathClipboardFormatter.swift
//  forzadvisor
//
//  Fail-closed isolated clipboard text for one displayed upgrade path.
//

import Foundation

enum TuneControlUpgradePathClipboardFormatter {
    static func text(
        for tune: TuneResult,
        displayedPathID: String
    ) -> String? {
        let planner = TuneControlUpgradePlanner()
        let displayedPaths = planner.paths(for: tune)
        guard !displayedPaths.isEmpty else {
            return nil
        }

        let freshlyProjected = TuneOutputProjector().project(tune)
        let freshPaths = planner.paths(for: freshlyProjected)
        guard freshPaths == displayedPaths else {
            return nil
        }

        let matches = freshPaths.enumerated().filter {
            $0.element.id == displayedPathID
        }
        guard matches.count == 1,
              let match = matches.first,
              !match.element.items.isEmpty else {
            return nil
        }

        var lines = [
            "Path \(match.offset + 1) of \(freshPaths.count)",
            "Each path unlocks the same tune controls represented here. Pick one path; the alternatives are not cumulative."
        ]
        lines.append(contentsOf: match.element.provenance.stableClipboardLines)
        lines.append("")
        for item in match.element.items {
            lines.append(
                "- \(item.part.category.label) > "
                    + "\(item.part.slot.label) > \(item.part.label)"
            )
            lines.append(
                "  Unlocks: "
                    + item.unlocks.map(\.projectionLabel)
                    .joined(separator: ", ")
            )
        }
        lines.append("")
        lines.append(
            "This tuning-control path does not predict PI, cost, credits, entitlement, performance, or installation order. Confirm every item in your game build before buying."
        )
        return lines.joined(separator: "\n")
    }
}
