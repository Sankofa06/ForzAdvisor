//
//  TuneClipboardFormatter.swift
//  forzadvisor
//
//  Converts generated tune results into stable plain text for pasteboard
//  export from TuneResultView and focused formatter tests.
//

import Foundation

enum TuneClipboardFormatter {
    static func fullTuneText(for tune: TuneResult, playerNotes: String = "") -> String {
        var lines = [
            tune.request.car.displayName,
            "\(tune.request.discipline.title) | \(tune.request.car.performanceClass.rawValue) \(tune.request.car.performanceIndex) | \(tune.request.car.drivetrain.rawValue)",
            providerText(for: tune.providerInfo),
            ""
        ]

        lines.append(contentsOf: tune.sections.flatMap { section in
            sectionTextLines(for: section) + [""]
        })

        lines.append("Notes")
        lines.append("Bias: \(tune.notes.bias)")
        lines.append("If pushes wide: \(tune.notes.ifPushesWide)")
        lines.append("If snaps on lift: \(tune.notes.ifSnapsOnLift)")
        lines.append("Retune: \(tune.notes.retuneTrigger)")

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

    private static func providerText(for providerInfo: TuneProviderInfo?) -> String {
        guard let providerInfo else {
            return "Provider: Provider not recorded - This saved tune was created before provider tracking."
        }

        return "Provider: \(providerInfo.statusTitle) - \(providerInfo.statusDetail)"
    }
}
