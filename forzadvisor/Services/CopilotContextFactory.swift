//
//  CopilotContextFactory.swift
//  forzadvisor
//
//  Adapts root-owned workflow state into value-free Copilot summary facts.
//

import Foundation

struct CopilotContextFactory {
    func make(
        step: WorkflowStep,
        savedTuneCount: Int,
        catalogCarCount: Int
    ) -> CopilotContext {
        switch step {
        case .home:
            return context(.home, savedTuneCount: savedTuneCount)
        case .newTune:
            return context(.newTune, catalogCarCount: catalogCarCount)
        case .catalogPicker:
            return context(.catalogPicker, catalogCarCount: catalogCarCount)
        case .catalogReview(let selection):
            return context(.catalogReview, car: selection.carInput)
        case .catalogEdit:
            return context(.catalogEdit, cannotSeeUnsavedEdits: true)
        case .ocrReview:
            return context(.ocrReview, cannotSeeUnsavedEdits: true)
        case .manualEntry:
            return context(.manualEntry, cannotSeeUnsavedEdits: true)
        case .discipline(let car, _, _):
            return context(.discipline, car: car)
        case .loading(let request, _, let savedTuneID, _, let partialTune):
            return context(
                .loading,
                car: request.car,
                discipline: request.discipline,
                projection: partialTune.flatMap {
                    projectionFacts(for: $0, isSaved: savedTuneID != nil, isStreaming: true)
                }
            )
        case .result(let tune, let savedTuneID, _, _, _):
            return resultContext(tune, phase: .result, isSaved: savedTuneID != nil)
        case .tirePressureCapture:
            return context(.tirePressureCapture, cannotSeeUnsavedEdits: true)
        case .upgradePartCapture:
            return context(.upgradePartCapture, cannotSeeUnsavedEdits: true)
        case .editSavedTune:
            return context(.editSavedTune, cannotSeeUnsavedEdits: true)
        }
    }

    private func resultContext(
        _ tune: TuneResult,
        phase: CopilotPhase,
        isSaved: Bool,
        cannotSeeUnsavedEdits: Bool = false
    ) -> CopilotContext {
        context(
            phase,
            car: tune.request.car,
            discipline: tune.request.discipline,
            projection: projectionFacts(for: tune, isSaved: isSaved, isStreaming: false),
            cannotSeeUnsavedEdits: cannotSeeUnsavedEdits
        )
    }

    private func context(
        _ phase: CopilotPhase,
        car: CarInput? = nil,
        discipline: DrivingDiscipline? = nil,
        savedTuneCount: Int? = nil,
        catalogCarCount: Int? = nil,
        projection: CopilotProjectionFacts? = nil,
        cannotSeeUnsavedEdits: Bool = false
    ) -> CopilotContext {
        CopilotContext(
            phase: phase,
            carDisplayName: car?.displayName,
            gameTitle: car?.game.shortTitle,
            disciplineTitle: discipline?.title,
            savedTuneCount: savedTuneCount,
            catalogCarCount: catalogCarCount,
            projection: projection,
            cannotSeeUnsavedEdits: cannotSeeUnsavedEdits
        )
    }

    private func projectionFacts(
        for tune: TuneResult,
        isSaved: Bool,
        isStreaming: Bool
    ) -> CopilotProjectionFacts? {
        guard let report = tune.projectionReport else {
            return nil
        }

        return CopilotProjectionFacts(
            readyCount: report.readyCount,
            blockedByStatus: statusCounts(in: report),
            blockedByReason: reasonCounts(in: report),
            tireLabEligible: isStreaming ? nil : TirePressureCaptureEligibility().snapshot(for: tune) != nil,
            upgradeLabEligible: isStreaming ? nil : UpgradePartCaptureEligibility().snapshot(for: tune) != nil,
            exactUpgradePathCount: isStreaming ? nil : TuneControlUpgradePlanner().paths(for: tune).count,
            isSaved: isStreaming ? nil : isSaved,
            isStreaming: isStreaming
        )
    }

    private func statusCounts(in report: TuneProjectionReport) -> [CopilotCountFact] {
        let statuses: [(TuneProjectionStatus, String)] = [
            (.requiresUpgrade, "Requires upgrade"),
            (.needsPartConfirmation, "Needs part confirmation"),
            (.needsConstraint, "Needs in-game constraint"),
            (.unavailable, "Unavailable"),
            (.awaitingProvider, "Awaiting generation"),
            (.providerOmitted, "Provider omitted"),
            (.rejectedValue, "Rejected value")
        ]
        return statuses.compactMap { status, label in
            let count = report.fields.filter { $0.status == status }.count
            return count == 0 ? nil : CopilotCountFact(label: label, count: count)
        }
    }

    private func reasonCounts(in report: TuneProjectionReport) -> [CopilotCountFact] {
        let reasons: [(TuneProjectionReason, String)] = [
            (.missingSnapshot, "Reason: missing build snapshot"),
            (.invalidSnapshot, "Reason: invalid build snapshot"),
            (.capabilityUnavailable, "Reason: capability unavailable"),
            (.partAvailabilityUnknown, "Reason: part availability unknown"),
            (.upgradeRequired, "Reason: upgrade required"),
            (.missingProductionConstraint, "Reason: missing production constraint"),
            (.providerPending, "Reason: generation pending"),
            (.providerOmitted, "Reason: provider omitted"),
            (.duplicateField, "Reason: duplicate field"),
            (.unexpectedField, "Reason: unexpected field"),
            (.invalidGearIndex, "Reason: invalid gear index"),
            (.malformedValue, "Reason: malformed value"),
            (.wrongDisplayUnit, "Reason: wrong display unit"),
            (.valueOutsideConstraint, "Reason: value outside constraint")
        ]
        return reasons.compactMap { reason, label in
            let count = report.fields.filter { $0.reason == reason }.count
            return count == 0 ? nil : CopilotCountFact(label: label, count: count)
        }
    }
}
