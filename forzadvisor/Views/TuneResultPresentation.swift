import Foundation

struct TuneResultPresentation: Equatable {
    enum Completion: Equatable {
        case incomplete
        case available
        case legacyUnavailable
    }

    let completion: Completion
    let isSaved: Bool
    let availableSettingCount: Int

    init(tune: TuneResult, isSaved: Bool, isStreaming: Bool) {
        self.isSaved = isSaved
        if isStreaming {
            completion = .incomplete
        } else if tune.projectionReport != nil {
            completion = .available
        } else {
            completion = .legacyUnavailable
        }
        availableSettingCount = tune.projectionReport?.readyCount ?? 0
    }

    var hasAvailableSettings: Bool { availableSettingCount > 0 }
    var allowsCopy: Bool {
        completion == .available && hasAvailableSettings
    }
    var allowsSave: Bool { completion == .available }
    var allowsCopyOrSave: Bool { allowsCopy || allowsSave }
    var allowsSavedConsequentialActions: Bool {
        isSaved && allowsCopy
    }
    var allowsSavedEdit: Bool {
        isSaved && allowsSave
    }

    var statusTitle: String {
        switch completion {
        case .incomplete: return "Incomplete result"
        case .available:
            if hasAvailableSettings {
                return isSaved ? "Saved locally" : "Settings available"
            }
            return isSaved ? "Saved setup" : "Setup ready to save"
        case .legacyUnavailable: return "Legacy result needs review"
        }
    }

    var statusDetail: String {
        switch completion {
        case .incomplete:
            return "Generation is still in progress. Copy and Save remain unavailable until the complete result arrives."
        case .available:
            if hasAvailableSettings {
                return "\(availableSettingCount) available setting\(availableSettingCount == 1 ? "" : "s"). Availability does not mean accuracy has been validated."
            }
            return isSaved
                ? "No numeric settings are available for this saved setup. You can edit it, but copy and refinement remain unavailable."
                : "No numeric settings are available for this setup. Save Setup to keep it and edit it later."
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
        if tune.purpose == .fh5BuildPlan {
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
