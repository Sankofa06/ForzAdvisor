import Foundation

extension ContentView {
    @discardableResult
    func returnToValidationMission(
        _ outcome: ValidationMissionReturnOutcome,
        expected: ValidationMissionReturnContext? = nil
    ) -> Bool {
        guard let context = validationMissionReturnContext else {
            return false
        }
        let savedTuneExists = context.savedTuneID.map {
            (try? savedTune(for: $0)) != nil
        } ?? true
        guard let resolvedOutcome = ValidationMissionReturnPolicy()
            .resolve(
                active: context,
                expected: expected,
                requested: outcome,
                savedTuneExists: savedTuneExists
            ) else { return false }
        validationMissionOutcomeMessage = resolvedOutcome.message
        validationMissionReturnContext = nil
        step = .home
        rootSheet = .betaMissions
        return true
    }

    func validationMissionBack(_ fallback: () -> Void) {
        if !returnToValidationMission(.draftPreserved) {
            fallback()
        }
    }

}
