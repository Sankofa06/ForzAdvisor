//
//  TuneClipboardFormatter.swift
//  forzadvisor
//
//  Converts generated tune results into stable plain text for pasteboard
//  export from TuneResultView and focused formatter tests.
//

import Foundation

enum TuneClipboardFormatter {
    static func verifiedSettingsText(for tune: TuneResult) -> String? {
        let sanitized = TuneOutputProjector().project(tune)
        guard sanitized.projectionReport?.readyCount ?? 0 > 0,
              !sanitized.sections.isEmpty else {
            return nil
        }

        var lines = headerLines(for: sanitized)
        lines.append("Verified settings")
        lines.append(contentsOf: sanitized.sections.flatMap { section in
            sectionTextLines(for: section) + [""]
        })
        return lines.dropLast().joined(separator: "\n")
    }

    static func buildPlanText(for tune: TuneResult) -> String? {
        let sanitized = TuneOutputProjector().project(tune)
        let paths = TuneControlUpgradePlanner().paths(for: sanitized)
        if !paths.isEmpty {
            var lines = headerLines(for: sanitized)
            if sanitized.purpose == .fh5BuildPlan {
                lines.append("FH5 local build plan — no numeric tuning settings")
                lines.append("This plan was rebuilt from the upgrade availability you verified for this stock catalog car.")
                lines.append("")
            }
            lines.append("Tuning-control upgrade paths")
            lines.append(
                sanitized.purpose == .fh5BuildPlan
                    ? "Each path unlocks the same represented tuning controls. Pick one path; the alternatives are not cumulative."
                    : "Each path unlocks the same tune controls represented here. Pick one path; the alternatives are not cumulative."
            )
            for (index, path) in paths.enumerated() {
                lines.append("")
                lines.append("Path \(index + 1)")
                for item in path.items {
                    lines.append("- \(item.part.category.label) > \(item.part.slot.label) > \(item.part.label)")
                    lines.append("  Unlocks: \(item.unlocks.map(\.projectionLabel).joined(separator: ", "))")
                }
            }
            lines.append("")
            lines.append("These tuning-control paths do not predict PI, credits, entitlement, performance, or installation order. Confirm every item in your game build before buying.")
            return lines.joined(separator: "\n")
        }

        guard let report = sanitized.projectionReport,
              !report.purchasePlan.isEmpty || !report.confirmations.isEmpty else {
            return nil
        }

        var lines = headerLines(for: sanitized)
        if sanitized.purpose == .fh5BuildPlan {
            lines.append("FH5 local build plan — no numeric tuning settings")
            lines.append("Verify every requested upgrade in Upgrade Lab, then rebuild this plan for exact paths.")
            lines.append("")
        }
        if !report.purchasePlan.isEmpty {
            lines.append("Buy these upgrades")
            for item in report.purchasePlan {
                let unlocks = item.unlocks.map(\.projectionLabel).joined(separator: ", ")
                lines.append("- \(item.part.category.label) > \(item.part.slot.label) > \(item.part.label)")
                lines.append("  Unlocks: \(unlocks)")
            }
        }
        if !report.confirmations.isEmpty {
            if !report.purchasePlan.isEmpty { lines.append("") }
            lines.append("Confirm in game")
            for confirmation in report.confirmations {
                let candidates = confirmation.candidateParts.map(\.label).joined(separator: " or ")
                lines.append("- \(confirmation.setting.projectionLabel): \(candidates)")
            }
        }
        return lines.joined(separator: "\n")
    }

    static func fullTuneText(for tune: TuneResult, playerNotes: String = "") -> String {
        let exportTune = tune.request.car.game == .fh5 || tune.purpose == .fh5BuildPlan
            ? TuneOutputProjector().project(tune)
            : tune

        if exportTune.purpose == .fh5BuildPlan {
            return buildPlanText(for: exportTune)
                ?? (headerLines(for: exportTune) + [
                    "FH5 local build plan — no numeric tuning settings",
                    "Numeric FH5 settings remain unavailable pending a separate validated ruleset."
                ]).joined(separator: "\n")
        }

        var lines = [
            exportTune.request.car.displayName,
            "\(exportTune.request.discipline.title) | \(exportTune.request.car.performanceClass.rawValue) \(exportTune.request.car.performanceIndex) | \(exportTune.request.car.drivetrain.rawValue)",
            providerText(for: exportTune),
            ""
        ]

        lines.append(contentsOf: exportTune.sections.flatMap { section in
            sectionTextLines(for: section) + [""]
        })

        lines.append("Notes")
        lines.append("Bias: \(exportTune.notes.bias)")
        lines.append("If pushes wide: \(exportTune.notes.ifPushesWide)")
        lines.append("If snaps on lift: \(exportTune.notes.ifSnapsOnLift)")
        lines.append("Retune: \(exportTune.notes.retuneTrigger)")

        let trimmedNotes = playerNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedNotes.isEmpty {
            lines.append("")
            lines.append("Garage notes")
            lines.append(trimmedNotes)
        }

        return lines.joined(separator: "\n")
    }

    static func sectionText(for section: TuneSection) -> String {
        sectionTextLines(for: section).joined(separator: "\n")
    }

    private static func sectionTextLines(for section: TuneSection) -> [String] {
        [section.title] + section.lines.map { line in
            line.unit.isEmpty
                ? "\(line.label): \(line.value)"
                : "\(line.label): \(line.value) \(line.unit)"
        }
    }

    private static func headerLines(for tune: TuneResult) -> [String] {
        [
            tune.request.car.displayName,
            "\(tune.request.discipline.title) | \(tune.request.car.performanceClass.rawValue) \(tune.request.car.performanceIndex) | \(tune.request.car.drivetrain.rawValue)",
            ""
        ]
    }

    private static func providerText(for tune: TuneResult) -> String {
        if tune.purpose == .fh5BuildPlan {
            return "Provider: Local FH5 build planner - No formulas, model, API, or numeric tuning values were used."
        }
        let providerInfo = tune.providerInfo
        guard let providerInfo else {
            return "Provider: Provider not recorded - This saved tune was created before provider tracking."
        }

        return "Provider: \(providerInfo.statusTitle) - \(providerInfo.statusDetail)"
    }
}
