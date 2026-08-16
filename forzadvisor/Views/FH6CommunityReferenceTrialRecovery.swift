import Foundation

extension FH6CommunityReferenceTrialCaptureView {
    var recovery: ValidationCaptureRecovery? {
        try? ValidationCaptureRecovery(
            kind: .fh6CommunityReferenceTrial,
            tune: tune,
            captureRevision: "fh6-community-trial-v2"
        )
    }

    var factualFields: [String: String] {
        var fields = [
            "contentURL": draft.contentURL,
            "publisherDisplayName": draft.publisherDisplayName,
            "symptoms": ValidationDraftFieldCodec.encodeSet(
                draft.candidateDeficiencySymptoms
            )
        ]
        fields["kind"] = draft.kind?.rawValue
        fields["courseType"] = draft.courseType?.rawValue
        fields["surface"] = draft.surface?.rawValue
        fields["input"] = draft.input?.rawValue
        fields["outcome"] = draft.outcome?.rawValue
        return fields
    }

    func restoreDraft() {
        guard let recovery else { return }
        do {
            guard let fields = try recovery.restore() else { return }
            draft.kind = fields["kind"].flatMap(
                FH6CommunityReferenceKind.init(rawValue:)
            )
            draft.contentURL = fields["contentURL"] ?? ""
            draft.publisherDisplayName = fields["publisherDisplayName"] ?? ""
            draft.courseType = fields["courseType"].flatMap(
                ValidationCourseType.init(rawValue:)
            )
            draft.surface = fields["surface"].flatMap(
                ValidationSurface.init(rawValue:)
            )
            draft.input = fields["input"].flatMap(ValidationInput.init(rawValue:))
            draft.outcome = fields["outcome"].flatMap(
                FH6CommunityReferenceTrialOutcome.init(rawValue:)
            )
            draft.candidateDeficiencySymptoms =
                ValidationDraftFieldCodec.decodeSet(
                    TuneFeedback.self, fields["symptoms"]
                )
            recoveryMessage = "Resumed factual fields. Run checks and confirmations must be repeated."
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
