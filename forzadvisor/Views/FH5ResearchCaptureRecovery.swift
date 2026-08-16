import Foundation

extension FH5ResearchCaptureView {
    var recovery: ValidationCaptureRecovery? {
        try? ValidationCaptureRecovery(
            kind: .fh5ResearchObservation,
            tune: tune,
            gameBuildVersion: snapshot.gameBuild.version,
            captureRevision: "fh5-research-menu-v2"
        )
    }

    var factualFields: [String: String] {
        var fields = [
            "gameVersion": gameVersion,
            "tireCompound": tireCompound,
            "gearCount": gearCount
        ]
        fields["platform"] = platform?.rawValue
        for (field, draft) in drafts {
            let prefix = "control.\(field.stableID)."
            fields[prefix + "availability"] = draft.availability?.rawValue
            fields[prefix + "minimum"] = draft.minimum
            fields[prefix + "maximum"] = draft.maximum
            fields[prefix + "step"] = draft.step
            fields[prefix + "current"] = draft.current
        }
        return fields
    }

    func restoreDraft() {
        guard let recovery else { return }
        do {
            guard let fields = try recovery.restore() else { return }
            platform = fields["platform"].flatMap(FH5Platform.init(rawValue:))
            gameVersion = fields["gameVersion"] ?? ""
            tireCompound = fields["tireCompound"] ?? ""
            gearCount = fields["gearCount"] ?? ""
            drafts = Dictionary(uniqueKeysWithValues:
                TuneFieldID.expectedFields(
                    drivetrain: tune.request.car.drivetrain,
                    gearCount: 10
                ).compactMap { field in
                    let prefix = "control.\(field.stableID)."
                    guard let raw = fields[prefix + "availability"],
                          let availability = FH5TuneFieldAvailability(
                            rawValue: raw
                          ) else { return nil }
                    return (field, FH5ResearchFieldDraft(
                        availability: availability,
                        minimum: fields[prefix + "minimum"] ?? "",
                        maximum: fields[prefix + "maximum"] ?? "",
                        step: fields[prefix + "step"] ?? "",
                        current: fields[prefix + "current"] ?? ""
                    ))
                }
            )
            recoveryMessage = "Resumed the factual fields from your local draft."
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
        try? recovery?.discard()
        onBack()
    }
}
