import Foundation

extension FH5ControlledExperimentCaptureView {
    var canSubmit: Bool { requiredChecks.allSatisfy(\.0) }
    var unmetRequirementCount: Int { requiredChecks.count { !$0.0 } }
    var nextRequirement: String? { requiredChecks.first { !$0.0 }?.1 }

    var requiredChecks: [(Bool, String)] {
        [
            (candidateValue != nil, "Choose a valid one-step variant"),
            (input != nil, "Choose the input used"),
            (surface != nil, "Choose the surface"),
            (targetSymptom != nil, "Choose the target symptom"),
            (outcome != nil, "Choose the comparative outcome"),
            (sameRouteAndConditionsConfirmed, "Confirm the same route and conditions"),
            (sameAssistsAndInputConfirmed, "Confirm the same assists and input"),
            (onlyDeclaredFieldChangedConfirmed, "Confirm only one field changed"),
            (sequenceCompletedConfirmed, "Complete the A-B-B-A sequence"),
            (stockValuesRestoredConfirmed, "Restore the stock value"),
            (firstPartyAuthorshipConfirmed, "Confirm first-party authorship"),
            (localStoragePermitted, "Allow local storage")
        ]
    }

    func formatted(_ value: Double, unit: TuneUnit?) -> String {
        let number = value.formatted(
            .number.precision(.fractionLength(0...3))
        )
        guard let unit else { return number }
        return "\(number) \(unit.rawValue)"
    }

    var recovery: ValidationCaptureRecovery? {
        try? ValidationCaptureRecovery(
            kind: .fh5ControlledExperiment,
            tune: tune,
            gameBuildVersion: researchRecord.gameVersion,
            captureRevision: "fh5-controlled-abba-v2"
        )
    }

    var factualFields: [String: String] {
        var fields = ["field": field.stableID]
        fields["direction"] = direction?.rawValue
        fields["input"] = input?.rawValue
        fields["surface"] = surface?.rawValue
        fields["targetSymptom"] = targetSymptom?.rawValue
        fields["outcome"] = outcome?.rawValue
        return fields
    }

    func restoreDraft() {
        guard let recovery else { return }
        do {
            guard let fields = try recovery.restore() else { return }
            if let restored = ValidationDraftFieldCodec.decodeTuneFieldID(
                fields["field"]
            ) {
                field = restored
            }
            direction = fields["direction"].flatMap(
                FH5ExperimentDirection.init(rawValue:)
            )
            input = fields["input"].flatMap(ValidationInput.init(rawValue:))
            surface = fields["surface"].flatMap(ValidationSurface.init(rawValue:))
            targetSymptom = fields["targetSymptom"].flatMap(
                TuneFeedback.init(rawValue:)
            )
            outcome = fields["outcome"].flatMap(
                FH5ExperimentOutcome.init(rawValue:)
            )
            recoveryMessage = "Resumed the factual fields from your local draft. Confirmations must be made again."
        } catch ValidationDraftStoreError.stale {
            recoveryMessage = "An older incompatible draft was discarded."
        } catch {
            recoveryMessage = "An unreadable draft was not restored."
        }
    }

    func saveAndExit() {
        guard let recovery else {
            recoveryMessage = "This tune revision cannot safely bind a draft."
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
