extension ContentView {
    var isFirstSaveStepGuideHandoffPresented: Bool {
        guard case .result(_, let savedTuneID, _, _, _) = step else {
            return false
        }
        return firstSavedSetupCopilotHandoff.isPresented(
            for: savedTuneID
        )
    }
}
