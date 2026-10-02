import Foundation

struct TuneResultPresentation: Equatable {
    enum Completion: Equatable {
        case incomplete
        case available
        case plan
        case needsEvidence
        case legacyUnavailable
    }

    let completion: Completion
    let isSaved: Bool
    let availableSettingCount: Int
    let isFH6EvidenceWithheld: Bool

    init(tune: TuneResult, isSaved: Bool, isStreaming: Bool) {
        self.isSaved = isSaved
        let hasProjectionReport = tune.projectionReport != nil
        let projectedTune = TuneOutputProjector().project(tune)
        let projectedReport = projectedTune.projectionReport
        let readyCount = projectedReport?.readyCount ?? 0
        let projectedLineCount = projectedTune.sections.flatMap(\.lines).count
        let hasUsableNumericOutput = readyCount > 0
            && projectedLineCount == readyCount
        let isFH6 = tune.request.car.game == .fh6
        if isStreaming {
            completion = .incomplete
        } else if tune.purpose == .fh5BuildPlan || tune.request.car.game == .fh5 {
            completion = .plan
        } else if projectedReport?.requiresInGameConfirmation == true {
            completion = .plan
        } else if hasProjectionReport, hasUsableNumericOutput {
            completion = .available
        } else if isFH6 && hasProjectionReport {
            completion = .plan
        } else if TuneClipboardFormatter.buildPlanText(for: projectedTune) != nil {
            completion = .plan
        } else if hasProjectionReport {
            completion = .needsEvidence
        } else {
            completion = .legacyUnavailable
        }
        availableSettingCount = completion == .available ? readyCount : 0
        isFH6EvidenceWithheld = isFH6
            && tune.purpose != .fh5BuildPlan
            && hasProjectionReport
            && completion != .available
            && completion != .incomplete
    }

    var hasAvailableSettings: Bool { availableSettingCount > 0 }
    var allowsCopy: Bool {
        completion == .available && hasAvailableSettings
    }
    var allowsCopyOrSave: Bool { completion == .available }
    var allowsSave: Bool {
        switch completion {
        case .available, .plan, .needsEvidence:
            true
        case .incomplete, .legacyUnavailable:
            false
        }
    }
    var allowsSavedConsequentialActions: Bool {
        isSaved && allowsCopy
    }
    var allowsSavedEdit: Bool {
        isSaved && allowsSave
    }

    var allowsSavedMetadataEdit: Bool {
        guard isSaved else { return false }
        switch completion {
        case .incomplete, .legacyUnavailable:
            return false
        case .available, .plan, .needsEvidence:
            return true
        }
    }

    var statusTitle: String {
        switch completion {
        case .incomplete: "Incomplete result"
        case .available: isSaved ? "Saved locally" : "Ready to use"
        case .plan:
            isFH6EvidenceWithheld
                ? "Settings withheld — more game evidence needed"
                : (isSaved ? "Plan saved locally" : "Setup plan ready")
        case .needsEvidence:
            isFH6EvidenceWithheld
                ? "Settings withheld — more game evidence needed"
                : "Settings withheld"
        case .legacyUnavailable: "Legacy result needs review"
        }
    }

    var statusDetail: String {
        switch completion {
        case .incomplete:
            return "Generation is still in progress. Copy and Save remain unavailable until the complete result arrives."
        case .available:
            "\(availableSettingCount) available setting\(availableSettingCount == 1 ? "" : "s"). Availability does not mean accuracy has been validated."
        case .plan:
            isFH6EvidenceWithheld
                ? "Numeric settings are withheld until more game evidence is confirmed. Use the setup plan when one is available, then generate again."
                : "No numeric settings are ready to enter. Save this setup and follow the in-game confirmations before generating again."
        case .needsEvidence:
            isFH6EvidenceWithheld
                ? "Numeric settings are withheld until more game evidence is confirmed. Capture the missing build evidence before applying values."
                : "No numeric settings passed the current evidence and constraint checks. Capture the missing build evidence before applying values."
        case .legacyUnavailable:
            return "This saved result predates availability checks. Its values cannot be copied or refined."
        }
    }
}

struct TuneActualProviderPresentation: Equatable {
    let title: String
    let detail: String
    let symbolName: String
    let usedFallback: Bool

    init(tune: TuneResult, isComplete: Bool = true) {
        guard isComplete else {
            title = "Generation method still in progress"
            detail = "The actual provider and any fallback are confirmed only when generation completes."
            symbolName = "ellipsis"
            usedFallback = false
            return
        }
        if tune.purpose == .fh5BuildPlan || tune.request.car.game == .fh5 {
            title = "Generated with: Local FH5 build planner"
            detail = "Created locally without numeric tuning output."
            symbolName = "wrench.and.screwdriver"
            usedFallback = false
        } else if let info = tune.providerInfo {
            usedFallback = info.fallbackReason != nil
            title = usedFallback
                ? "Fallback used: \(info.actualMode.resultTitle)"
                : "Generated with: \(info.actualMode.resultTitle)"
            detail = info.statusDetail
            symbolName = info.symbolName
        } else {
            title = "Generated with: Provider not recorded"
            detail = "This saved result predates provider tracking."
            symbolName = "questionmark.circle"
            usedFallback = false
        }
    }
}
