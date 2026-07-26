//
//  CatalogUpgradeEvidenceReuseResolver.swift
//  forzadvisor
//
//  Explicit, fail-closed reuse of prior Upgrade Lab part availability.
//

import Foundation

struct CatalogUpgradeEvidenceReuseOffer: Equatable, Sendable {
    let buildVersion: String
    let observedAt: Date
    let sourceSnapshotID: UUID
    let parts: [TuneVehiclePart]

    func makeSnapshot(
        for selection: CatalogCarSelection,
        id: UUID = UUID()
    ) -> VehicleBuildSnapshot? {
        var profile = selection.entry.capabilityProfile
        profile.parts = parts
        profile.stockAdjustableSettings = []
        let snapshot = VehicleBuildSnapshot(
            schemaVersion: VehicleBuildSnapshot.currentSchemaVersion,
            id: id,
            kind: .capabilityOnly,
            capturedAt: observedAt,
            gameBuild: GameBuildReference(
                game: selection.entry.game,
                version: buildVersion,
                capturedAt: observedAt
            ),
            car: selection.carInput,
            capabilityProfile: profile,
            tireCompound: nil,
            gearCount: nil,
            constraints: [],
            evidenceSources: []
        )
        return CatalogUpgradeEvidenceReuseResolver()
            .isValidReuseSnapshot(snapshot, for: selection)
            ? snapshot
            : nil
    }
}

struct CatalogUpgradeEvidenceReuseResolver {
    func offer(
        for selection: CatalogCarSelection,
        savedTunes: [TuneResult]
    ) -> CatalogUpgradeEvidenceReuseOffer? {
        let candidates = savedTunes.compactMap {
            candidate(for: selection, tune: $0)
        }
        guard let first = candidates.first,
              candidates.dropFirst().allSatisfy({
                  $0.semantics == first.semantics
              }) else {
            return nil
        }
        let newest = candidates.max {
            if $0.offer.observedAt != $1.offer.observedAt {
                return $0.offer.observedAt < $1.offer.observedAt
            }
            return $0.offer.sourceSnapshotID.uuidString
                < $1.offer.sourceSnapshotID.uuidString
        }
        return newest?.offer
    }

    func isValidReuseSnapshot(
        _ snapshot: VehicleBuildSnapshot,
        for selection: CatalogCarSelection
    ) -> Bool {
        guard snapshot.kind == .capabilityOnly,
              snapshot.isValid,
              snapshot.matches(car: selection.carInput),
              snapshot.car == selection.carInput,
              snapshot.capabilityProfile.vehicle
                == selection.entry.capabilityProfile.vehicle,
              snapshot.capabilityProfile.drivetrain
                == selection.entry.stock.drivetrain,
              snapshot.capabilityProfile.stockAdjustableSettings
                .isEmpty,
              snapshot.tireCompound == nil,
              snapshot.gearCount == nil,
              snapshot.constraints.isEmpty,
              snapshot.evidenceSources.isEmpty,
              let build = canonicalBuild(
                snapshot.gameBuild.version
              ),
              snapshot.gameBuild.capturedAt
                == snapshot.capturedAt,
              completeParts(
                snapshot.capabilityProfile.parts,
                build: build
              ) != nil else {
            return false
        }
        return true
    }

    private struct Semantics: Equatable {
        let build: String
        let availability: [TunePartAvailability]
    }

    private struct Candidate {
        let offer: CatalogUpgradeEvidenceReuseOffer
        let semantics: Semantics
    }

    private func candidate(
        for selection: CatalogCarSelection,
        tune: TuneResult
    ) -> Candidate? {
        let car = tune.request.car
        guard car == selection.carInput,
              car.catalogReference == selection.reference,
              !car.catalogValuesModified,
              let snapshot = tune.request.buildSnapshot,
              snapshot.kind == .exactBuildObservation
                || snapshot.kind == .capabilityOnly,
              snapshot.isValid,
              snapshot.matches(car: car),
              snapshot.car == car,
              sourcePayloadIsValid(
                snapshot,
                for: selection
              ),
              snapshot.capturedAt.timeIntervalSinceReferenceDate
                .isFinite,
              snapshot.gameBuild.capturedAt
                == snapshot.capturedAt,
              let build = canonicalBuild(
                snapshot.gameBuild.version
              ),
              let parts = completeParts(
                snapshot.capabilityProfile.parts,
                build: build
              ) else {
            return nil
        }
        let offer = CatalogUpgradeEvidenceReuseOffer(
            buildVersion: build,
            observedAt: snapshot.capturedAt,
            sourceSnapshotID: snapshot.id,
            parts: parts
        )
        return Candidate(
            offer: offer,
            semantics: Semantics(
                build: build,
                availability: parts.map(\.availability)
            )
        )
    }

    private func sourcePayloadIsValid(
        _ snapshot: VehicleBuildSnapshot,
        for selection: CatalogCarSelection
    ) -> Bool {
        guard snapshot.kind == .capabilityOnly else {
            return snapshot.kind == .exactBuildObservation
        }
        return snapshot.capabilityProfile.vehicle
                == selection.entry.capabilityProfile.vehicle
            && snapshot.capabilityProfile.drivetrain
                == selection.entry.stock.drivetrain
            && snapshot.capabilityProfile.stockAdjustableSettings
                .isEmpty
            && snapshot.tireCompound == nil
            && snapshot.gearCount == nil
            && snapshot.constraints.isEmpty
            && snapshot.evidenceSources.isEmpty
    }

    private func completeParts(
        _ parts: [TuneVehiclePart],
        build: String
    ) -> [TuneVehiclePart]? {
        guard parts.count == TunePartID.allCases.count else {
            return nil
        }
        let grouped = Dictionary(grouping: parts, by: \.partID)
        guard Set(grouped.keys) == Set(TunePartID.allCases),
              grouped.values.allSatisfy({ $0.count == 1 }) else {
            return nil
        }
        let ordered = TunePartID.allCases.compactMap {
            grouped[$0]?.first
        }
        guard ordered.count == TunePartID.allCases.count,
              ordered.allSatisfy({
                  ($0.availability == .available
                    || $0.availability == .unavailable)
                    && $0.evidence.source
                        == UpgradePartCapture.provenanceSource
                    && canonicalBuild($0.evidence.version)
                        == build
                    && ($0.evidence.confidence == .medium
                        || $0.evidence.confidence == .high)
                    && $0.evidence.usagePermission == .permitted
              }) else {
            return nil
        }
        return ordered
    }

    private func canonicalBuild(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmed.isEmpty,
              trimmed.count <= 80,
              value == trimmed,
              value.unicodeScalars.allSatisfy({
                  !CharacterSet.controlCharacters.contains($0)
                    && $0.properties.generalCategory != .format
                    && $0.properties.generalCategory
                        != .lineSeparator
                    && $0.properties.generalCategory
                        != .paragraphSeparator
              }) else {
            return nil
        }
        return value
    }
}
