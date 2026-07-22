//
//  VerifiedBuildShareCard.swift
//  forzadvisor
//
//  Fail-closed, privacy-scoped text shared from an exact verified build.
//

import Foundation

struct VerifiedBuildShareCard: Equatable, Sendable {
    let subject: String
    let text: String
}

struct VerifiedBuildShareCardFactory {
    private static let marketingURL = "https://Sankofa06.github.io/ForzAdvisor/"

    func make(for tune: TuneResult, isStreaming: Bool) -> VerifiedBuildShareCard? {
        guard !isStreaming,
              let sourceReport = tune.projectionReport,
              sourceReport.schemaVersion == TuneProjectionReport.currentSchemaVersion,
              let sourceSnapshot = tune.request.buildSnapshot,
              sourceSnapshot.isValid,
              sourceSnapshot.matches(car: tune.request.car),
              sourceSnapshot.kind == .exactBuildObservation,
              sourceSnapshot.gameBuild.hasKnownVersion,
              sourceReport.snapshotID == sourceSnapshot.id,
              sourceReport.contextStatus == .exactBuild else {
            return nil
        }

        let projected = TuneOutputProjector().project(tune)
        guard let report = projected.projectionReport,
              report.schemaVersion == TuneProjectionReport.currentSchemaVersion,
              let snapshot = projected.request.buildSnapshot,
              snapshot.isValid,
              snapshot.matches(car: projected.request.car),
              snapshot.kind == .exactBuildObservation,
              snapshot.gameBuild.hasKnownVersion,
              report.snapshotID == snapshot.id,
              report.contextStatus == .exactBuild,
              report.readyCount > 0,
              !projected.sections.isEmpty,
              let buildVersion = oneLine(snapshot.gameBuild.version ?? "", maximumLength: 80),
              let carName = oneLine(projected.request.car.displayName, maximumLength: 120) else {
            return nil
        }

        let readyFields = report.readyFieldIDs
        let readyLines = projected.sections.flatMap(\.lines)
        guard readyLines.count == report.readyCount,
              readyLines.allSatisfy({ line in
                  guard let fieldID = line.fieldID else { return false }
                  return readyFields.contains(fieldID)
              }) else {
            return nil
        }

        guard let sectionLines = sectionLines(for: projected.sections) else {
            return nil
        }

        var lines = [
            "ForzAdvisor Verified Build",
            "\(projected.request.car.game.shortTitle) | \(carName)",
            "\(projected.request.discipline.title) | \(projected.request.car.performanceClass.rawValue) \(projected.request.car.performanceIndex) | \(projected.request.car.drivetrain.rawValue)",
            "Game build observed: \(buildVersion)",
            "Verified settings: \(report.readyCount)",
            ""
        ]
        lines.append(contentsOf: sectionLines)

        let paths = TuneControlUpgradePlanner().paths(for: projected)
        if let firstPath = paths.first,
           let pathLines = pathLines(for: firstPath, totalCount: paths.count) {
            lines.append("")
            lines.append(contentsOf: pathLines)
        }

        lines.append("")
        lines.append("Only the settings shown passed this exact build's local capability and range checks.")
        lines.append("Tuning-control paths do not predict PI, credits, entitlement, performance, or installation order. Confirm every item in game before buying.")
        lines.append("")
        lines.append("Build yours with ForzAdvisor")
        lines.append(Self.marketingURL)

        return VerifiedBuildShareCard(
            subject: "Verified \(projected.request.car.game.shortTitle) build — \(carName)",
            text: lines.joined(separator: "\n")
        )
    }

    private func sectionLines(for sections: [TuneSection]) -> [String]? {
        var result: [String] = []
        for (sectionIndex, section) in sections.enumerated() {
            guard let title = oneLine(section.title, maximumLength: 80),
                  !section.lines.isEmpty else {
                return nil
            }
            if sectionIndex > 0 {
                result.append("")
            }
            result.append(title)
            for line in section.lines {
                guard let label = oneLine(line.label, maximumLength: 120),
                      let value = oneLine(line.value, maximumLength: 80) else {
                    return nil
                }
                let unit = oneLine(line.unit, maximumLength: 40)
                result.append(unit.map { "\(label): \(value) \($0)" } ?? "\(label): \(value)")
            }
        }
        return result
    }

    private func pathLines(
        for path: TuneControlUpgradePath,
        totalCount: Int
    ) -> [String]? {
        guard totalCount > 0, !path.items.isEmpty else { return nil }
        var lines = ["Tuning-control path 1 of \(totalCount)"]
        for item in path.items {
            guard let category = oneLine(item.part.category.label, maximumLength: 80),
                  let slot = oneLine(item.part.slot.label, maximumLength: 80),
                  let part = oneLine(item.part.label, maximumLength: 80),
                  let unlocks = oneLine(
                    item.unlocks.map(\.projectionLabel).joined(separator: ", "),
                    maximumLength: 240
                  ) else {
                return nil
            }
            lines.append("- \(category) > \(slot) > \(part)")
            lines.append("  Unlocks: \(unlocks)")
        }
        return lines
    }

    private func oneLine(_ value: String, maximumLength: Int) -> String? {
        let withoutControls = value.unicodeScalars.map { scalar in
            let category = scalar.properties.generalCategory
            let isUnsafe = CharacterSet.controlCharacters.contains(scalar)
                || category == .format
                || category == .lineSeparator
                || category == .paragraphSeparator
            return isUnsafe ? " " : String(scalar)
        }
        .joined()
        let collapsed = withoutControls
            .split(whereSeparator: \Character.isWhitespace)
            .joined(separator: " ")
        let bounded = String(collapsed.prefix(maximumLength))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return bounded.isEmpty ? nil : bounded
    }
}
