//
//  TuneControlUpgradePlanner.swift
//  forzadvisor
//
//  Deterministic alternative buy lists for controls represented by a tune.
//

import Foundation

struct TuneControlUpgradePathItem: Equatable, Identifiable, Sendable {
    var part: TunePartDefinition
    var unlocks: [TuneSetting]

    var id: TunePartID { part.id }
}

struct TuneControlUpgradePathProvenance: Equatable, Sendable {
    let game: ForzaGame
    let gameBuildVersion: String
    let snapshotID: UUID
    let capturedAt: Date
    let source: String

    var attributionText: String {
        "Local Upgrade Lab observation · \(game.shortTitle) build \(gameBuildVersion) · observed \(capturedAt.formatted(date: .abbreviated, time: .shortened))"
    }

    var stableClipboardLines: [String] {
        [
            "Source: Local Upgrade Lab observation",
            "Game build: \(game.shortTitle) \(gameBuildVersion)",
            "Snapshot captured: \(Self.timestampFormatter.string(from: capturedAt))"
        ]
    }

    private static let timestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}

struct TuneControlUpgradePath: Equatable, Identifiable, Sendable {
    var items: [TuneControlUpgradePathItem]
    let provenance: TuneControlUpgradePathProvenance

    var id: String {
        items.map(\.part.id.rawValue).joined(separator: "+")
    }
}

struct TuneControlUpgradePlanner {
    private struct RequiredControl {
        var setting: TuneSetting
        var requirement: TuneRequirementGroup
    }

    func paths(for tune: TuneResult, limit: Int = 3) -> [TuneControlUpgradePath] {
        guard limit > 0,
              let snapshot = tune.request.buildSnapshot,
              snapshot.isValid,
              snapshot.matches(car: tune.request.car),
              let provenance = trustedProvenance(for: snapshot),
              let report = tune.projectionReport,
              report.schemaVersion
                == TuneProjectionReport.currentSchemaVersion,
              report.snapshotID == snapshot.id,
              report.contextStatus == expectedContext(for: snapshot),
              reportMatchesFreshProjection(report, tune: tune),
              report.confirmations.isEmpty,
              !report.fields.contains(where: { $0.status == .needsPartConfirmation }) else {
            return []
        }

        let resolution = TuneCapabilityResolver(game: snapshot.car.game).resolve(
            profile: snapshot.capabilityProfile
        )
        let representedSettings = orderedUnique(report.fields.map { $0.field.setting })
        let capabilities = Dictionary(
            uniqueKeysWithValues: resolution.settings.map { ($0.setting, $0) }
        )
        var required: [RequiredControl] = []
        for setting in representedSettings {
            guard let capability = capabilities[setting] else { return [] }
            switch capability.status {
            case .stockAvailable, .installedUpgrade, .unavailable:
                continue
            case .unknown:
                return []
            case .requiresUpgrade:
                guard let requirement = capability.requirement,
                      !requirement.partIDs.isEmpty,
                      requirement.partIDs.allSatisfy({ partFact(for: $0, in: snapshot) != nil }) else {
                    return []
                }
                required.append(RequiredControl(setting: setting, requirement: requirement))
            }
        }
        guard !required.isEmpty else { return [] }

        var requirementsBySlot: [TunePartSlot: [RequiredControl]] = [:]
        for control in required {
            let slots = Set(control.requirement.partIDs.map {
                TunePartCatalog.definition(for: $0).slot
            })
            guard slots.count == 1, let slot = slots.first else { return [] }
            requirementsBySlot[slot, default: []].append(control)
        }

        let orderedSlots = TunePartSlot.allCases.filter { requirementsBySlot[$0] != nil }
        var choicesBySlot: [[Set<TunePartID>]] = []
        for slot in orderedSlots {
            guard let controls = requirementsBySlot[slot] else { return [] }
            let choices = minimalChoices(for: controls, snapshot: snapshot)
            guard !choices.isEmpty else { return [] }
            choicesBySlot.append(choices)
        }

        let combined = crossProduct(choicesBySlot)
        let minimalTotals = combined.filter { candidate in
            !combined.contains { other in
                other != candidate && other.isSubset(of: candidate)
            }
        }
        let uniqueTotals = orderedUniqueSets(minimalTotals).sorted(by: partSetIsOrderedBefore)

        return uniqueTotals.prefix(limit).map { selectedParts in
            let items = selectedParts.sorted(by: partIsOrderedBefore).map { partID in
                let unlocked = required.compactMap { control -> TuneSetting? in
                    control.requirement.partIDs.contains(partID) ? control.setting : nil
                }
                return TuneControlUpgradePathItem(
                    part: TunePartCatalog.definition(for: partID),
                    unlocks: orderedUnique(unlocked)
                )
            }
            return TuneControlUpgradePath(items: items, provenance: provenance)
        }
    }

    private func trustedProvenance(
        for snapshot: VehicleBuildSnapshot
    ) -> TuneControlUpgradePathProvenance? {
        guard let normalizedBuild = canonicalBuildVersion(
            snapshot.gameBuild.version ?? ""
        ),
              snapshot.gameBuild.capturedAt != nil,
              snapshot.gameBuild.game == snapshot.car.game,
              snapshot.capabilityProfile.vehicle.game == snapshot.car.game,
              snapshot.capabilityProfile.parts.count == TunePartID.allCases.count,
              Set(snapshot.capabilityProfile.parts.map(\.partID)) == Set(TunePartID.allCases),
              snapshot.capabilityProfile.parts.allSatisfy({
                  ($0.availability == .available || $0.availability == .unavailable)
                      && $0.evidence.source == UpgradePartCapture.provenanceSource
                      && normalized($0.evidence.version) == normalizedBuild
                      && ($0.evidence.confidence == .medium
                          || $0.evidence.confidence == .high)
                      && $0.evidence.usagePermission == .permitted
              }) else {
            return nil
        }

        return TuneControlUpgradePathProvenance(
            game: snapshot.car.game,
            gameBuildVersion: normalizedBuild,
            snapshotID: snapshot.id,
            capturedAt: persistedTimestamp(snapshot.capturedAt),
            source: UpgradePartCapture.provenanceSource
        )
    }

    private func persistedTimestamp(_ date: Date) -> Date {
        Date(timeIntervalSince1970: date.timeIntervalSince1970.rounded(.down))
    }

    private func reportMatchesFreshProjection(
        _ report: TuneProjectionReport,
        tune: TuneResult
    ) -> Bool {
        var seed = tune
        seed.projectionReport = nil
        guard let fresh = TuneOutputProjector()
            .project(seed)
            .projectionReport else {
            return false
        }
        return report.capabilityResolution
                == fresh.capabilityResolution
            && report.fields == fresh.fields
            && report.purchasePlan == fresh.purchasePlan
            && report.confirmations == fresh.confirmations
    }

    private func minimalChoices(
        for controls: [RequiredControl],
        snapshot: VehicleBuildSnapshot
    ) -> [Set<TunePartID>] {
        let candidateIDs = orderedUnique(controls.flatMap(\.requirement.partIDs)).filter {
            partFact(for: $0, in: snapshot)?.availability == .available
        }
        guard !candidateIDs.isEmpty, candidateIDs.count < Int.bitWidth else { return [] }

        let satisfying = (1..<(1 << candidateIDs.count)).compactMap { mask -> Set<TunePartID>? in
            let selected = Set(candidateIDs.indices.compactMap { index in
                mask & (1 << index) == 0 ? nil : candidateIDs[index]
            })
            return controls.allSatisfy { satisfies($0.requirement, with: selected) }
                ? selected
                : nil
        }
        return satisfying.filter { candidate in
            !satisfying.contains { other in
                other != candidate && other.isSubset(of: candidate)
            }
        }
        .sorted(by: partSetIsOrderedBefore)
    }

    private func satisfies(
        _ requirement: TuneRequirementGroup,
        with selected: Set<TunePartID>
    ) -> Bool {
        switch requirement.kind {
        case .anyOf:
            return requirement.partIDs.contains(where: selected.contains)
        case .allOf:
            return Set(requirement.partIDs).isSubset(of: selected)
        }
    }

    private func crossProduct(_ choicesBySlot: [[Set<TunePartID>]]) -> [Set<TunePartID>] {
        choicesBySlot.reduce([Set<TunePartID>()]) { partial, choices in
            partial.flatMap { current in choices.map { current.union($0) } }
        }
    }

    private func partFact(
        for partID: TunePartID,
        in snapshot: VehicleBuildSnapshot
    ) -> TuneVehiclePart? {
        let matches = snapshot.capabilityProfile.parts.filter { $0.partID == partID }
        guard matches.count == 1,
              matches[0].availability != .unknown else {
            return nil
        }
        return matches[0]
    }

    private func orderedUnique<T: Hashable>(_ values: [T]) -> [T] {
        var seen: Set<T> = []
        return values.filter { seen.insert($0).inserted }
    }

    private func orderedUniqueSets(_ values: [Set<TunePartID>]) -> [Set<TunePartID>] {
        var seen: Set<Set<TunePartID>> = []
        return values.filter { seen.insert($0).inserted }
    }

    private func partIsOrderedBefore(_ lhs: TunePartID, _ rhs: TunePartID) -> Bool {
        let order = Dictionary(
            uniqueKeysWithValues: TunePartID.allCases.enumerated().map { ($0.element, $0.offset) }
        )
        return order[lhs, default: .max] < order[rhs, default: .max]
    }

    private func partSetIsOrderedBefore(
        _ lhs: Set<TunePartID>,
        _ rhs: Set<TunePartID>
    ) -> Bool {
        let left = lhs.sorted(by: partIsOrderedBefore)
        let right = rhs.sorted(by: partIsOrderedBefore)
        for (leftPart, rightPart) in zip(left, right) where leftPart != rightPart {
            return partIsOrderedBefore(leftPart, rightPart)
        }
        return left.count < right.count
    }

    private func expectedContext(for snapshot: VehicleBuildSnapshot) -> TuneProjectionContextStatus {
        snapshot.kind == .exactBuildObservation ? .exactBuild : .capabilityOnly
    }

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func canonicalBuildVersion(
        _ value: String
    ) -> String? {
        let trimmed = normalized(value)
        guard !trimmed.isEmpty, trimmed.count <= 80 else {
            return nil
        }
        let canonical = trimmed.unicodeScalars.map { scalar in
            let category = scalar.properties.generalCategory
            let isUnsafe =
                CharacterSet.controlCharacters.contains(scalar)
                || category == .format
                || category == .lineSeparator
                || category == .paragraphSeparator
            return isUnsafe ? " " : String(scalar)
        }
        .joined()
        .split(whereSeparator: \.isWhitespace)
        .joined(separator: " ")
        return canonical == trimmed ? canonical : nil
    }
}
