import Foundation

struct DisciplineSelectionState: Equatable, Sendable {
    private(set) var selection: DrivingDiscipline?

    init(selection: DrivingDiscipline? = nil) {
        self.selection = selection
    }

    mutating func select(_ discipline: DrivingDiscipline) {
        selection = discipline
    }

    var startIntent: DrivingDiscipline? { selection }
}

enum DisciplineGenerationCopy {
    static let retryTitle = "Retry"
    static let changeDisciplineTitle = "Change Discipline"
    static let backTitle = "Back"

    static func startButtonTitle(for game: ForzaGame) -> String {
        switch game {
        case .fh5: "Create FH5 Build Plan"
        case .fh6: "Generate FH6 Tune"
        }
    }

    static func dataBoundary(
        for game: ForzaGame,
        disclosure: TuneProviderDisclosure
    ) -> String {
        if game == .fh5 {
            return "This FH5 build plan stays on this device. Screenshots and API keys are never included."
        }
        return disclosure.dataBoundary.summary
    }

    static func routeSummary(_ disclosure: TuneProviderDisclosure) -> String {
        let route = disclosure.route
        if !route.preferredModeWillBeAttempted {
            return "Uses \(route.expectedFirstMode.resultTitle). The preferred method is not ready."
        }
        if let fallback = route.fallbackMode {
            return "Tries \(route.expectedFirstMode.resultTitle) first, then \(fallback.resultTitle) if needed."
        }
        return "Uses \(route.expectedFirstMode.resultTitle) with no provider fallback."
    }
}

enum TuneGenerationPresentationPhase: Equatable, Sendable {
    case working
    case partial
    case failed
    case canceled
    case completed

    var title: String {
        switch self {
        case .working: "Starting generation"
        case .partial: "Receiving available settings"
        case .failed: "Generation stopped"
        case .canceled: "Generation canceled"
        case .completed: "Generation completed"
        }
    }

    var detail: String {
        switch self {
        case .working:
            "Preparing the selected method. No completion time is estimated."
        case .partial:
            "Some settings have arrived. Wait for completion before copying or saving."
        case .failed:
            "Your car facts and discipline are still here. Retry or change them before starting again."
        case .canceled:
            "Your selections were kept so you can continue when ready."
        case .completed:
            "Finalizing the completed result."
        }
    }

    var showsProgress: Bool {
        self == .working || self == .partial || self == .completed
    }

    var showsCancel: Bool {
        self == .working || self == .partial || self == .completed
    }

    var showsRecovery: Bool { self == .failed }
}
