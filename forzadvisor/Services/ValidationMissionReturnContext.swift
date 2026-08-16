import Foundation

enum ValidationMissionReturnDestination: Equatable, Sendable {
    case betaMissions
}

struct ValidationMissionReturnContext: Equatable, Sendable {
    let missionID: String
    let savedTuneID: UUID?
    let kind: BetaValidationMissionKind
    let returnDestination: ValidationMissionReturnDestination

    init(mission: BetaValidationMission) {
        missionID = mission.id
        savedTuneID = mission.savedTuneID
        kind = mission.kind
        returnDestination = .betaMissions
    }

    func isBound(to savedTuneID: UUID?) -> Bool {
        self.savedTuneID == savedTuneID
    }
}

enum ValidationMissionReturnOutcome: Equatable, Sendable {
    case completedLocalOnly
    case completedOnDevice
    case setupSaved
    case draftPreserved
    case stale

    var message: String {
        switch self {
        case .completedLocalOnly:
            "Test Drive saved locally. Future reuse is still off."
        case .completedOnDevice:
            "Evidence record saved on this device."
        case .setupSaved:
            "Setup saved on this device. Optional missions were refreshed."
        case .draftPreserved:
            "Mission not completed. Beta Missions were refreshed."
        case .stale:
            "That mission is no longer available for the current saved setup."
        }
    }
}

struct ValidationMissionReturnPolicy {
    func resolve(
        active: ValidationMissionReturnContext?,
        expected: ValidationMissionReturnContext?,
        requested: ValidationMissionReturnOutcome,
        savedTuneExists: Bool
    ) -> ValidationMissionReturnOutcome? {
        guard let active,
              expected == nil || expected == active else { return nil }
        if active.savedTuneID != nil && !savedTuneExists {
            return .stale
        }
        return requested
    }
}
