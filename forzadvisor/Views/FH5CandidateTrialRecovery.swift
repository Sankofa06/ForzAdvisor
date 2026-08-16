import Foundation

extension FH5CandidateTrialCaptureView {
    var recovery: ValidationCaptureRecovery? {
        try? ValidationCaptureRecovery(
            kind: .fh5CandidateTrial,
            tune: tune,
            gameBuildVersion: researchRecord.gameVersion,
            captureRevision: "fh5-candidate-trial-v2"
        )
    }

    var factualFields: [String: String] {
        var fields: [String: String] = [:]
        fields["input"] = input?.rawValue
        fields["surface"] = surface?.rawValue
        fields["outcome"] = outcome?.rawValue
        return fields
    }

    func restoreDraft() {
        guard let recovery else { return }
        do {
            guard let fields = try recovery.restore() else { return }
            input = fields["input"].flatMap(ValidationInput.init(rawValue:))
            surface = fields["surface"].flatMap(ValidationSurface.init(rawValue:))
            outcome = fields["outcome"].flatMap(
                FH5ExperimentOutcome.init(rawValue:)
            )
            recoveryMessage = "Resumed the factual context. Lock a fresh candidate and repeat confirmations."
        } catch ValidationDraftStoreError.stale {
            recoveryMessage = "An older incompatible draft was discarded."
        } catch {
            recoveryMessage = "An unreadable draft was not restored."
        }
    }

    func saveAndExit() {
        guard let recovery else {
            recoveryMessage = "This plan revision cannot safely bind a draft."
            return
        }
        do {
            try recovery.save(factualFields: factualFields)
            onBack()
        } catch {
            recoveryMessage = "Draft could not be saved. Your form remains open."
        }
    }

    func discardDraft() {
        do {
            guard let recovery else { throw ValidationDraftStoreError.unavailable }
            try recovery.discard()
            onBack()
        } catch {
            recoveryMessage = "Draft could not be discarded. Your form remains open."
        }
    }
}
