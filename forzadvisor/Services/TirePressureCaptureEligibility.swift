//
//  TirePressureCaptureEligibility.swift
//  forzadvisor
//
//  Fail-closed eligibility for the first narrowly scoped Tune Lab capture.
//

import Foundation

struct TirePressureCaptureEligibility {
    func snapshot(for tune: TuneResult) -> VehicleBuildSnapshot? {
        guard tune.request.car.game == .fh6,
              tune.request.car.catalogReference != nil,
              !tune.request.car.catalogValuesModified,
              let snapshot = tune.request.buildSnapshot,
              snapshot.kind == .capabilityOnly,
              snapshot.isValid,
              snapshot.matches(car: tune.request.car),
              let report = tune.projectionReport else {
            return nil
        }

        let front = report.fields.filter { $0.field == .frontTirePressure }
        let rear = report.fields.filter { $0.field == .rearTirePressure }
        guard front.count == 1,
              rear.count == 1,
              front[0].status == .needsConstraint,
              rear[0].status == .needsConstraint else {
            return nil
        }
        return snapshot
    }
}
