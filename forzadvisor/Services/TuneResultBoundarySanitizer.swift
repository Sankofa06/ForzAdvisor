//
//  TuneResultBoundarySanitizer.swift
//  forzadvisor
//
//  Canonicalizes tune results before they cross presentation or persistence
//  boundaries while preserving untouched legacy FH6 numeric tunes.
//

struct TuneResultBoundarySanitizer {
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
