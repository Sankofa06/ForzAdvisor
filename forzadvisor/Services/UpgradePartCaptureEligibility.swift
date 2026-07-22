//
//  UpgradePartCaptureEligibility.swift
//  forzadvisor
//
//  Fail-closed eligibility for stock-car tuning-control part capture.
//

import Foundation

struct UpgradePartCaptureEligibility {
    func snapshot(for tune: TuneResult) -> VehicleBuildSnapshot? {
        guard tune.request.car.catalogReference != nil,
              !tune.request.car.catalogValuesModified,
              let snapshot = tune.request.buildSnapshot,
              snapshot.isValid,
              snapshot.matches(car: tune.request.car),
              !snapshot.capabilityProfile.parts.contains(where: { $0.availability == .installed }),
              let report = tune.projectionReport,
              report.snapshotID == snapshot.id,
              report.contextStatus == expectedContext(for: snapshot),
              !report.confirmations.isEmpty,
              report.fields.contains(where: { $0.status == .needsPartConfirmation }) else {
            return nil
        }
        return snapshot
    }

    private func expectedContext(for snapshot: VehicleBuildSnapshot) -> TuneProjectionContextStatus {
        snapshot.kind == .exactBuildObservation ? .exactBuild : .capabilityOnly
    }
}
