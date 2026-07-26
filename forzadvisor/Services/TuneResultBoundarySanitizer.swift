//
//  TuneResultBoundarySanitizer.swift
//  forzadvisor
//
//  Canonicalizes tune results before they cross presentation or persistence
//  boundaries while preserving untouched legacy FH6 numeric tunes.
//

struct TuneResultBoundarySanitizer {
    func isSafeFH5BuildPlan(_ tune: TuneResult) -> Bool {
        guard tune.request.car.game == .fh5,
              tune.purpose == .fh5BuildPlan,
              tune.sections.isEmpty,
              tune.providerInfo == nil,
              tune.rulesetReference == nil,
              let report = tune.projectionReport,
              report.schemaVersion
                == TuneProjectionReport.currentSchemaVersion,
              report.snapshotID == tune.request.buildSnapshot?.id,
              report.readyCount == 0,
              !report.fields.contains(where: {
                  $0.status == .ready
              }) else {
            return false
        }
        return sanitize(tune) == tune
    }

    func sanitize(_ tune: TuneResult) -> TuneResult {
        let expectedPurpose: TuneResultPurpose = tune.request.car.game == .fh5
            ? .fh5BuildPlan
            : .numericTune
        let requiresProjection = tune.request.car.game == .fh5
            || tune.purpose != expectedPurpose
            || tune.projectionReport != nil

        guard requiresProjection else { return tune }
        return TuneOutputProjector().project(tune)
    }
}
