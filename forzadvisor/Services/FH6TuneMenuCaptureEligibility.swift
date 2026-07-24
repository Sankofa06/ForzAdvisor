//
//  FH6TuneMenuCaptureEligibility.swift
//  forzadvisor
//
//  Fail-closed eligibility for exact FH6 stock tuning-menu capture.
//

import Foundation

struct FH6TuneMenuCaptureEligibility {
    func snapshot(
        for tune: TuneResult,
        isStreaming: Bool = false
    ) -> VehicleBuildSnapshot? {
        guard !isStreaming,
              tune.purpose == .numericTune,
              tune.request.car.game == .fh6,
              tune.request.car.catalogReference != nil,
              !tune.request.car.catalogValuesModified,
              let snapshot = tune.request.buildSnapshot,
              snapshot.isValid,
              snapshot.matches(car: tune.request.car),
              !containsCompletedMenuCapture(snapshot),
              !snapshot.capabilityProfile.parts.contains(where: {
                  $0.availability == .installed
              }),
              let report = tune.projectionReport,
              report.schemaVersion == TuneProjectionReport.currentSchemaVersion,
              report.snapshotID == snapshot.id,
              report.contextStatus == expectedContext(for: snapshot),
              hasCanonicalFields(report.fields),
              report.fields.contains(where: {
                  $0.status == .needsConstraint
                      || $0.status == .needsPartConfirmation
              }) else {
            return nil
        }
        return snapshot
    }

    private func containsCompletedMenuCapture(
        _ snapshot: VehicleBuildSnapshot
    ) -> Bool {
        snapshot.evidenceSources.contains {
            $0.game == .fh6
                && $0.scope == .exactVehicleBuild
                && $0.source == FH6TuneMenuCapture.provenanceSource
                && $0.version == FH6TuneMenuCapture.provenanceVersion
                && $0.usagePermission == .permitted
        }
    }

    private func hasCanonicalFields(_ fields: [TuneFieldProjection]) -> Bool {
        guard !fields.isEmpty else { return false }
        let grouped = Dictionary(grouping: fields, by: \.field)
        return grouped.values.allSatisfy { $0.count == 1 }
    }

    private func expectedContext(
        for snapshot: VehicleBuildSnapshot
    ) -> TuneProjectionContextStatus {
        snapshot.kind == .exactBuildObservation ? .exactBuild : .capabilityOnly
    }
}
