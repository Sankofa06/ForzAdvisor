//
//  TuneCapabilityResolver.swift
//  forzadvisor
//
//  Pure capability resolution. Unknown per-car availability is never guessed.
//

import Foundation

struct TuneCapabilityResolver {
    var knowledge: TuneCapabilityKnowledge

    init(game: ForzaGame) {
        knowledge = .defaults(for: game)
    }

    init(knowledge: TuneCapabilityKnowledge) {
        self.knowledge = knowledge
    }

    func resolve(
        profile: TuneVehicleCapabilityProfile,
        settings requestedSettings: [TuneSetting] = TuneSetting.allCases
    ) -> TuneCapabilityResolution {
        let independentlyResolved = requestedSettings.map { setting in
            resolve(setting: setting, profile: profile)
        }
        let capabilities = harmonizeSameSlotPurchases(independentlyResolved, profile: profile)

        let purchaseIDs = unique(capabilities.flatMap(\.requiredPurchaseIDs))
        let unresolvedIDs = unique(capabilities.flatMap(\.unresolvedPartIDs))

        return TuneCapabilityResolution(
            vehicle: profile.vehicle,
            drivetrain: profile.drivetrain,
            settings: capabilities,
            requiredPurchases: purchaseIDs.map(TunePartCatalog.definition(for:)),
            unresolvedConfirmations: unresolvedIDs
        )
    }

    private func resolve(
        setting: TuneSetting,
        profile: TuneVehicleCapabilityProfile
    ) -> TuneSettingCapability {
        guard profile.vehicle.game == knowledge.game,
              let rule = knowledge.rules.first(where: { $0.setting == setting }) else {
            return capability(setting: setting, status: .unknown)
        }

        guard rule.supportedDrivetrains.contains(profile.drivetrain) else {
            return capability(
                setting: setting,
                status: .unavailable,
                requirement: rule.requirement,
                evidence: [knowledge.evidence]
            )
        }

        if let stockOverride = profile.stockAdjustableSettings.first(where: { $0.setting == setting }) {
            return capability(
                setting: setting,
                status: .stockAvailable,
                evidence: [knowledge.evidence, stockOverride.evidence]
            )
        }

        if rule.stockAvailable {
            return capability(
                setting: setting,
                status: .stockAvailable,
                evidence: [knowledge.evidence]
            )
        }

        guard let requirement = rule.requirement else {
            return capability(
                setting: setting,
                status: .unknown,
                evidence: [knowledge.evidence]
            )
        }

        let candidates = requirement.partIDs.map { partID in
            partState(for: partID, in: profile)
        }

        return switch requirement.kind {
        case .anyOf:
            resolveAnyOf(setting: setting, requirement: requirement, candidates: candidates)
        case .allOf:
            resolveAllOf(setting: setting, requirement: requirement, candidates: candidates)
        }
    }

    private func resolveAnyOf(
        setting: TuneSetting,
        requirement: TuneRequirementGroup,
        candidates: [PartState]
    ) -> TuneSettingCapability {
        if let installed = candidates.first(where: { $0.availability == .installed }) {
            return capability(
                setting: setting,
                status: .installedUpgrade,
                requirement: requirement,
                evidence: [knowledge.evidence, installed.evidence].compacted()
            )
        }

        let unresolved = candidates.filter { $0.availability == .unknown }
        if !unresolved.isEmpty {
            return capability(
                setting: setting,
                status: .unknown,
                requirement: requirement,
                unresolvedPartIDs: unresolved.map(\.partID),
                evidence: uniqueEvidence([knowledge.evidence] + unresolved.compactMap(\.evidence))
            )
        }

        if let available = candidates.first(where: { $0.availability == .available }) {
            return capability(
                setting: setting,
                status: .requiresUpgrade,
                requirement: requirement,
                requiredPurchaseIDs: [available.partID],
                evidence: [knowledge.evidence, available.evidence].compacted()
            )
        }

        return capability(
            setting: setting,
            status: .unavailable,
            requirement: requirement,
            evidence: uniqueEvidence([knowledge.evidence] + candidates.compactMap(\.evidence))
        )
    }

    private func resolveAllOf(
        setting: TuneSetting,
        requirement: TuneRequirementGroup,
        candidates: [PartState]
    ) -> TuneSettingCapability {
        if candidates.contains(where: { $0.availability == .unavailable }) {
            return capability(
                setting: setting,
                status: .unavailable,
                requirement: requirement,
                evidence: uniqueEvidence([knowledge.evidence] + candidates.compactMap(\.evidence))
            )
        }

        let unresolved = candidates.filter { $0.availability == .unknown }
        if !unresolved.isEmpty {
            return capability(
                setting: setting,
                status: .unknown,
                requirement: requirement,
                unresolvedPartIDs: unresolved.map(\.partID),
                evidence: uniqueEvidence([knowledge.evidence] + candidates.compactMap(\.evidence))
            )
        }

        let purchases = candidates
            .filter { $0.availability == .available }
            .map(\.partID)

        return capability(
            setting: setting,
            status: purchases.isEmpty ? .installedUpgrade : .requiresUpgrade,
            requirement: requirement,
            requiredPurchaseIDs: purchases,
            evidence: uniqueEvidence([knowledge.evidence] + candidates.compactMap(\.evidence))
        )
    }

    private func partState(
        for partID: TunePartID,
        in profile: TuneVehicleCapabilityProfile
    ) -> PartState {
        guard let part = profile.parts.first(where: { $0.partID == partID }) else {
            return PartState(partID: partID, availability: .unknown, evidence: nil)
        }

        return PartState(partID: partID, availability: part.availability, evidence: part.evidence)
    }

    private func harmonizeSameSlotPurchases(
        _ capabilities: [TuneSettingCapability],
        profile: TuneVehicleCapabilityProfile
    ) -> [TuneSettingCapability] {
        var result = capabilities

        for slot in TunePartSlot.allCases {
            let indices = result.indices.filter { index in
                guard result[index].status == .requiresUpgrade,
                      let requirement = result[index].requirement,
                      requirement.kind == .anyOf,
                      !requirement.partIDs.isEmpty else {
                    return false
                }

                return requirement.partIDs.allSatisfy {
                    TunePartCatalog.definition(for: $0).slot == slot
                }
            }

            guard indices.count > 1,
                  let firstRequirement = result[indices[0]].requirement else {
                continue
            }

            let commonIDs = indices.dropFirst().reduce(firstRequirement.partIDs) { common, index in
                guard let requirement = result[index].requirement else { return [] }
                return common.filter(requirement.partIDs.contains)
            }

            guard let selectedID = commonIDs.first(where: {
                partState(for: $0, in: profile).availability == .available
            }) else {
                continue
            }

            let selected = partState(for: selectedID, in: profile)
            for index in indices {
                result[index].requiredPurchaseIDs = [selectedID]
                result[index].evidence = uniqueEvidence(
                    [knowledge.evidence, selected.evidence].compacted()
                )
            }
        }

        return result
    }

    private func capability(
        setting: TuneSetting,
        status: TuneCapabilityStatus,
        requirement: TuneRequirementGroup? = nil,
        requiredPurchaseIDs: [TunePartID] = [],
        unresolvedPartIDs: [TunePartID] = [],
        evidence: [TuneEvidence] = []
    ) -> TuneSettingCapability {
        TuneSettingCapability(
            setting: setting,
            status: status,
            requirement: requirement,
            requiredPurchaseIDs: unique(requiredPurchaseIDs),
            unresolvedPartIDs: unique(unresolvedPartIDs),
            evidence: uniqueEvidence(evidence)
        )
    }

    private func unique<T: Hashable>(_ values: [T]) -> [T] {
        var seen: Set<T> = []
        return values.filter { seen.insert($0).inserted }
    }

    private func uniqueEvidence(_ values: [TuneEvidence]) -> [TuneEvidence] {
        var result: [TuneEvidence] = []
        for value in values where !result.contains(value) {
            result.append(value)
        }
        return result
    }
}

private struct PartState {
    var partID: TunePartID
    var availability: TunePartAvailability
    var evidence: TuneEvidence?
}

private extension Array where Element == TuneEvidence? {
    func compacted() -> [TuneEvidence] {
        compactMap { $0 }
    }
}
