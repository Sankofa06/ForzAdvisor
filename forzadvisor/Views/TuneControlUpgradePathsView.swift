//
//  TuneControlUpgradePathsView.swift
//  forzadvisor
//
//  Result rendering for exact alternative tuning-control buy lists.
//

import SwiftUI

struct TuneControlUpgradePathsView: View {
    let paths: [TuneControlUpgradePath]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Each path unlocks the same tune controls represented here. Pick one path; the alternatives are not cumulative.")
                .font(.subheadline)

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
                }
                .accessibilityIdentifier("tuningControlUpgradePath-\(index + 1)")
            }

            Text("Tuning-control paths do not predict PI, credits, entitlement, performance, or installation order. Confirm every item in your game build before buying.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("tuningControlUpgradePaths")
    }
}
