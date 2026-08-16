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

    var allowsCopyOrSave: Bool { completion == .available }

    var statusTitle: String {
        switch completion {
        case .incomplete: "Incomplete result"
        case .available: isSaved ? "Saved locally" : "Ready to use"
        case .legacyUnavailable: "Legacy result needs review"
        }
    }

    var statusDetail: String {
        switch completion {
        case .incomplete:
            "Generation is still in progress. Copy and Save remain unavailable until the complete result arrives."
        case .available:
            "\(availableSettingCount) available setting\(availableSettingCount == 1 ? "" : "s"). Availability does not mean accuracy has been validated."
        case .legacyUnavailable:
            "This saved result predates availability checks. Its values cannot be copied or refined."
        }
    }
}

struct TuneActualProviderPresentation: Equatable {
    let title: String
    let detail: String
    let symbolName: String
    let usedFallback: Bool

    init(tune: TuneResult) {
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
