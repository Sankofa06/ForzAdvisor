//
//  SavedTuneEditDraft.swift
//  forzadvisor
//
//  Editable garage detail state. It detects PRD retune conditions before the
//  saved tune metadata is persisted or regenerated.
//

import Foundation

struct SavedTuneEditDraft: Equatable {
    var car: CarInput
    var playerNotes: String
    var originalWeightPounds: Int
    var originalFrontWeightPercent: Double

    init(tune: TuneResult, playerNotes: String) {
        self.car = tune.request.car
        self.playerNotes = playerNotes
        self.originalWeightPounds = tune.request.car.weightPounds
        self.originalFrontWeightPercent = tune.request.car.frontWeightPercent
    }

    var validationIssues: [ValidationIssue] {
        car.validationIssues
    }

    var isValid: Bool {
        car.isValid
    }

    var needsRetune: Bool {
        weightShiftExceedsThreshold || frontWeightShiftExceedsThreshold
    }

    var weightShiftExceedsThreshold: Bool {
        guard originalWeightPounds > 0 else { return false }
        let delta = abs(Double(car.weightPounds - originalWeightPounds))
        return delta / Double(originalWeightPounds) > 0.02
    }

    var frontWeightShiftExceedsThreshold: Bool {
        abs(car.frontWeightPercent - originalFrontWeightPercent) > 2
    }

    func metadataUpdatedTune(from tune: TuneResult) -> TuneResult {
        var updatedTune = tune
        updatedTune.request.car = car
        return updatedTune
    }
}
