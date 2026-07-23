//
//  CopilotDomain.swift
//  forzadvisor
//
//  Value-only context and deterministic guidance for the contextual Copilot.
//  This feature intentionally has no provider, network, or persistence boundary.
//

import Foundation

enum CopilotPhase: String, CaseIterable, Codable, Sendable {
    case home
    case newTune
    case catalogPicker
    case catalogReview
    case catalogEdit
    case ocrReview
    case manualEntry
    case discipline
    case loading
    case result
    case tirePressureCapture
    case upgradePartCapture
    case fh5ResearchCapture
    case fh5ControlledExperimentCapture
    case recordTestDrive
    case editSavedTune

    var title: String {
        switch self {
        case .home: "Garage"
        case .newTune: "Tune Source"
        case .catalogPicker: "Car Catalog"
        case .catalogReview: "Car Review"
        case .catalogEdit: "Edit Catalog Values"
        case .ocrReview: "OCR Review"
        case .manualEntry: "Manual Entry"
        case .discipline: "Discipline"
        case .loading: "Tune Generation"
        case .result: "Tune Result"
        case .tirePressureCapture: "Tire Lab"
        case .upgradePartCapture: "Upgrade Lab"
        case .fh5ResearchCapture: "FH5 Research Lab"
        case .fh5ControlledExperimentCapture: "FH5 Outcome Lab"
        case .recordTestDrive: "Record Test Drive"
        case .editSavedTune: "Edit Saved Tune"
        }
    }
}

enum CopilotIntent: String, CaseIterable, Codable, Sendable {
    case nextStep
    case trust
    case missing
    case privacy

    var title: String {
        switch self {
        case .nextStep: "Next step"
        case .trust: "What can I trust?"
        case .missing: "What is missing?"
        case .privacy: "Privacy"
        }
    }

    var suggestionIdentifier: String {
        switch self {
        case .nextStep: "copilotSuggestionNextStep"
        case .trust: "copilotSuggestionTrust"
        case .missing: "copilotSuggestionMissing"
        case .privacy: "copilotSuggestionPrivacy"
        }
    }

    static func parse(_ question: String) -> CopilotIntent? {
        switch normalized(question) {
        case "next step", "what should i do next", "what do i do next":
            .nextStep
        case "what can i trust", "what can i trust?", "what is verified", "what's verified":
            .trust
        case "what is missing", "what is missing?", "what's missing", "what still needs verification":
            .missing
        case "privacy", "is this private", "how is my data used":
            .privacy
        default:
            nil
        }
    }

    private static func normalized(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: Locale(identifier: "en_US_POSIX")
            )
    }
}

struct CopilotCountFact: Codable, Equatable, Sendable {
    let label: String
    let count: Int
}

struct CopilotProjectionFacts: Codable, Equatable, Sendable {
    var resultPurpose: TuneResultPurpose = .numericTune
    let readyCount: Int
    let blockedByStatus: [CopilotCountFact]
    let blockedByReason: [CopilotCountFact]
    let tireLabEligible: Bool?
    let upgradeLabEligible: Bool?
    let fh5ResearchLabEligible: Bool?
    let fh5ObservationRecorded: Bool?
    let exactUpgradePathCount: Int?
    let isSaved: Bool?
    let isStreaming: Bool

    init(
        resultPurpose: TuneResultPurpose = .numericTune,
        readyCount: Int,
        blockedByStatus: [CopilotCountFact],
        blockedByReason: [CopilotCountFact],
        tireLabEligible: Bool?,
        upgradeLabEligible: Bool?,
        fh5ResearchLabEligible: Bool? = nil,
        fh5ObservationRecorded: Bool? = nil,
        exactUpgradePathCount: Int?,
        isSaved: Bool?,
        isStreaming: Bool
    ) {
        self.resultPurpose = resultPurpose
        self.readyCount = readyCount
        self.blockedByStatus = blockedByStatus
        self.blockedByReason = blockedByReason
        self.tireLabEligible = tireLabEligible
        self.upgradeLabEligible = upgradeLabEligible
        self.fh5ResearchLabEligible = fh5ResearchLabEligible
        self.fh5ObservationRecorded = fh5ObservationRecorded
        self.exactUpgradePathCount = exactUpgradePathCount
        self.isSaved = isSaved
        self.isStreaming = isStreaming
    }
}

extension CopilotProjectionFacts {
    private enum CodingKeys: String, CodingKey {
        case resultPurpose
        case readyCount
        case blockedByStatus
        case blockedByReason
        case tireLabEligible
        case upgradeLabEligible
        case fh5ResearchLabEligible
        case fh5ObservationRecorded
        case exactUpgradePathCount
        case isSaved
        case isStreaming
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        resultPurpose = try container.decodeIfPresent(
            TuneResultPurpose.self,
            forKey: .resultPurpose
        ) ?? .numericTune
        readyCount = try container.decode(Int.self, forKey: .readyCount)
        blockedByStatus = try container.decode([CopilotCountFact].self, forKey: .blockedByStatus)
        blockedByReason = try container.decode([CopilotCountFact].self, forKey: .blockedByReason)
        tireLabEligible = try container.decodeIfPresent(Bool.self, forKey: .tireLabEligible)
        upgradeLabEligible = try container.decodeIfPresent(Bool.self, forKey: .upgradeLabEligible)
        fh5ResearchLabEligible = try container.decodeIfPresent(Bool.self, forKey: .fh5ResearchLabEligible)
        fh5ObservationRecorded = try container.decodeIfPresent(Bool.self, forKey: .fh5ObservationRecorded)
        exactUpgradePathCount = try container.decodeIfPresent(Int.self, forKey: .exactUpgradePathCount)
        isSaved = try container.decodeIfPresent(Bool.self, forKey: .isSaved)
        isStreaming = try container.decode(Bool.self, forKey: .isStreaming)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(resultPurpose, forKey: .resultPurpose)
        try container.encode(readyCount, forKey: .readyCount)
        try container.encode(blockedByStatus, forKey: .blockedByStatus)
        try container.encode(blockedByReason, forKey: .blockedByReason)
        try container.encodeIfPresent(tireLabEligible, forKey: .tireLabEligible)
        try container.encodeIfPresent(upgradeLabEligible, forKey: .upgradeLabEligible)
        try container.encodeIfPresent(fh5ResearchLabEligible, forKey: .fh5ResearchLabEligible)
        try container.encodeIfPresent(fh5ObservationRecorded, forKey: .fh5ObservationRecorded)
        try container.encodeIfPresent(exactUpgradePathCount, forKey: .exactUpgradePathCount)
        try container.encodeIfPresent(isSaved, forKey: .isSaved)
        try container.encode(isStreaming, forKey: .isStreaming)
    }
}

struct CopilotFact: Identifiable, Codable, Equatable, Sendable {
    let label: String
    let value: String

    var id: String { label }
}

struct CopilotContext: Identifiable, Codable, Equatable, Sendable {
    let phase: CopilotPhase
    let carDisplayName: String?
    let gameTitle: String?
    let disciplineTitle: String?
    let savedTuneCount: Int?
    let catalogCarCount: Int?
    let projection: CopilotProjectionFacts?
    let cannotSeeUnsavedEdits: Bool

    var id: String {
        [phase.rawValue, carDisplayName, gameTitle, disciplineTitle]
            .compactMap { $0 }
            .joined(separator: "|")
    }

    var facts: [CopilotFact] {
        var result: [CopilotFact] = []
        if let carDisplayName {
            result.append(CopilotFact(label: "Car", value: carDisplayName))
        }
        if let gameTitle {
            result.append(CopilotFact(label: "Game", value: gameTitle))
        }
        if let disciplineTitle {
            result.append(CopilotFact(label: "Discipline", value: disciplineTitle))
        }
        if let savedTuneCount {
            result.append(CopilotFact(label: "Saved tunes", value: "\(savedTuneCount)"))
        }
        if let catalogCarCount {
            result.append(CopilotFact(label: "Reviewed cars loaded", value: "\(catalogCarCount)"))
        }
        if let projection {
            result.append(CopilotFact(
                label: "Result type",
                value: projection.resultPurpose == .fh5BuildPlan ? "FH5 build plan" : "Numeric tune"
            ))
            result.append(CopilotFact(label: "Ready settings", value: "\(projection.readyCount)"))
            result.append(contentsOf: projection.blockedByStatus.map {
                CopilotFact(label: $0.label, value: "\($0.count)")
            })
            result.append(contentsOf: projection.blockedByReason.map {
                CopilotFact(label: $0.label, value: "\($0.count)")
            })
            result.append(CopilotFact(
                label: "Tune state",
                value: projection.isStreaming ? "Still generating" : "Generation complete"
            ))
            if !projection.isStreaming {
                if let tireLabEligible = projection.tireLabEligible {
                    result.append(CopilotFact(
                        label: "Tire Lab",
                        value: tireLabEligible ? "Eligible" : "Not eligible"
                    ))
                }
                if let upgradeLabEligible = projection.upgradeLabEligible {
                    result.append(CopilotFact(
                        label: "Upgrade Lab",
                        value: upgradeLabEligible ? "Eligible" : "Not eligible"
                    ))
                }
                if let researchEligible = projection.fh5ResearchLabEligible {
                    result.append(CopilotFact(
                        label: "FH5 Research Lab",
                        value: researchEligible ? "Eligible" : "Not eligible"
                    ))
                }
                if projection.fh5ObservationRecorded == true {
                    result.append(CopilotFact(
                        label: "FH5 stock evidence",
                        value: "Recorded"
                    ))
                }
                if let exactUpgradePathCount = projection.exactUpgradePathCount {
                    result.append(CopilotFact(
                        label: "Exact upgrade paths",
                        value: "\(exactUpgradePathCount)"
                    ))
                }
                if let isSaved = projection.isSaved {
                    result.append(CopilotFact(
                        label: "Garage state",
                        value: isSaved ? "Saved" : "Not saved"
                    ))
                }
            }
        }
        if cannotSeeUnsavedEdits {
            result.append(CopilotFact(
                label: "Unsaved fields",
                value: "Not visible to Copilot"
            ))
        }
        return result
    }
}

struct CopilotResponse: Equatable, Sendable {
    let title: String
    let message: String
    let intent: CopilotIntent?

    static let unsupported = CopilotResponse(
        title: "That is outside this Copilot",
        message: "I can only answer Next step, What can I trust?, What is missing?, or Privacy. I cannot calculate tune numbers, PI, cost, performance, parts, or use web and community sources.",
        intent: nil
    )
}

struct CopilotEngine {
    func response(to question: String, in context: CopilotContext) -> CopilotResponse {
        guard let intent = CopilotIntent.parse(question) else {
            return .unsupported
        }
        return response(to: intent, in: context)
    }

    func response(to intent: CopilotIntent, in context: CopilotContext) -> CopilotResponse {
        let message: String
        switch intent {
        case .nextStep:
            message = nextStep(in: context)
        case .trust:
            message = trust(in: context)
        case .missing:
            message = missing(in: context)
        case .privacy:
            message = privacy(in: context)
        }
        return CopilotResponse(title: intent.title, message: message, intent: intent)
    }

    private func nextStep(in context: CopilotContext) -> String {
        switch context.phase {
        case .home:
            return "Start a new tune, or open one of your \(context.savedTuneCount ?? 0) saved tunes."
        case .newTune:
            return "Choose a reviewed catalog car first. Use screenshot OCR or manual entry when your car is not in the catalog."
        case .catalogPicker:
            return "Select a reviewed car from the loaded catalog. Manual entry remains available when you cannot find your car."
        case .catalogReview:
            return "Confirm the displayed stock facts, then use the car. Edit the values first if they do not match your game."
        case .catalogEdit:
            return unsavedEditsMessage("Validate the edited car facts, then continue from the underlying screen.")
        case .ocrReview:
            return unsavedEditsMessage("Confirm every recognized fact against the screenshot, then continue from the underlying screen.")
        case .manualEntry:
            return unsavedEditsMessage("Complete the required car facts and fix the validation messages before continuing.")
        case .discipline:
            return "Read the discipline summaries in the underlying screen and choose the one that matches how you plan to drive. Copilot does not claim one is objectively best."
        case .loading:
            return "Wait for generation to finish. Closing this sheet does not cancel generation."
        case .result:
            return resultNextStep(context.projection)
        case .tirePressureCapture:
            return unsavedEditsMessage("Complete the exact game-build, tire compound, and front/rear range checklist, then submit through the validated button below.")
        case .upgradePartCapture:
            return unsavedEditsMessage("Confirm the stock-car attestation and every requested tuning-control part, then submit through the validated button below.")
        case .fh5ResearchCapture:
            return unsavedEditsMessage("Record every FH5 control as Adjustable, Shown locked, or Not shown, restore moved sliders, and save the raw observation.")
        case .fh5ControlledExperimentCapture:
            return unsavedEditsMessage("Complete the fixed A-B-B-A sequence, keep every condition constant, restore the stock value, and record only the comparative outcome.")
        case .recordTestDrive:
            return unsavedEditsMessage("Describe this one session, confirm the tested setup, then explicitly opt in if you want to create reusable deidentified evidence.")
        case .editSavedTune:
            return unsavedEditsMessage("Use Save for metadata and notes. Use Save & Re-tune when the underlying screen recommends recalculating after material car changes.")
        }
    }

    private func trust(in context: CopilotContext) -> String {
        switch context.phase {
        case .catalogPicker, .catalogReview:
            return "Treat the reviewed catalog as a starting point and confirm its stock facts in your current game build."
        case .catalogEdit, .ocrReview, .manualEntry, .tirePressureCapture, .upgradePartCapture, .fh5ResearchCapture, .fh5ControlledExperimentCapture, .recordTestDrive, .editSavedTune:
            return unsavedEditsMessage("Trust only facts you personally confirm in the underlying screen and any validation it shows.")
        case .loading:
            guard let projection = context.projection else {
                return "Generation is still in progress. No completed setting is claimed yet."
            }
            return "Generation is still in progress. The partial report currently marks \(projection.readyCount) settings ready; all other statuses remain explicitly withheld."
        case .result:
            guard let projection = context.projection else {
                return "This result has no verified projection report, so Copilot does not claim any tune setting is ready."
            }
            if projection.resultPurpose == .fh5BuildPlan {
                if projection.fh5ObservationRecorded == true {
                    return "Trust the saved record only as raw first-party FH5 stock-menu evidence. It is not a tune and does not make numeric FH5 settings ready."
                }
                return "Trust only the catalog identity, locally recorded upgrade availability, and exact buy paths shown by this plan. It is not a verified numeric tune and contains no tuning values."
            }
            return "Trust only the \(projection.readyCount) settings marked ready by the projection report. Withheld settings remain labeled by status and reason."
        case .home, .newTune, .discipline:
            return "Trust the current workflow label and the facts shown in the underlying screen. Copilot provides process guidance, not new car or tune claims."
        }
    }

    private func missing(in context: CopilotContext) -> String {
        switch context.phase {
        case .home:
            return "No car is selected yet. Start a new tune to provide car facts and a discipline."
        case .newTune:
            return "A car source is still missing. Choose the reviewed catalog, screenshot OCR, or manual entry."
        case .catalogPicker:
            return "A catalog car selection is still missing. \(context.catalogCarCount ?? 0) reviewed cars are currently loaded."
        case .catalogReview:
            return "Your confirmation is still missing. Check the displayed stock facts against the game before continuing."
        case .catalogEdit, .ocrReview, .manualEntry:
            return unsavedEditsMessage("Use the validation and confirmation messages in the underlying form to find missing facts.")
        case .discipline:
            return "A driving discipline is still missing. Choose from the summaries in the underlying screen."
        case .loading:
            return "The final generation result is still missing. Wait for completion; dismissing Copilot will not cancel it."
        case .result:
            return resultMissing(context.projection)
        case .tirePressureCapture:
            return unsavedEditsMessage("The underlying checklist identifies any missing build, compound, range, step, or attestation fact.")
        case .upgradePartCapture:
            return unsavedEditsMessage("The underlying checklist identifies any missing stock-car attestation or tuning-control part fact.")
        case .fh5ResearchCapture:
            return unsavedEditsMessage("The underlying checklist identifies missing tri-state decisions, slider values, context, restoration, or permission.")
        case .fh5ControlledExperimentCapture:
            return unsavedEditsMessage("The underlying protocol identifies missing one-variable, A-B-B-A, conditions, restoration, authorship, or storage confirmations.")
        case .recordTestDrive:
            return unsavedEditsMessage("The underlying form identifies missing session facts, confirmations, symptoms, or reuse permission.")
        case .editSavedTune:
            return unsavedEditsMessage("The underlying form shows validation issues and whether material changes need Save & Re-tune.")
        }
    }

    private func privacy(in context: CopilotContext) -> String {
        let editBoundary = context.cannotSeeUnsavedEdits
            ? " It cannot see unsaved field edits in the underlying form."
            : ""
        return "This Copilot runs deterministic guidance locally. It does not call a model or network service, save a transcript, log questions, or change your workflow. It only receives the current phase and the summary facts shown here.\(editBoundary)"
    }

    private func resultNextStep(_ projection: CopilotProjectionFacts?) -> String {
        guard let projection else {
            return "No verified settings are available. Return to a verified input path before relying on this result."
        }
        if projection.isStreaming {
            return "Wait for generation to finish. Closing this sheet does not cancel generation."
        }
        if projection.resultPurpose == .fh5BuildPlan {
            if projection.fh5ObservationRecorded == true {
                return "The raw FH5 stock-menu evidence is recorded. It is not a tune, and numeric FH5 tuning remains unavailable."
            }
            if projection.fh5ResearchLabEligible == true {
                return "Open FH5 Research Lab to record the untouched stock tuning menu as first-party evidence."
            }
            if projection.upgradeLabEligible == true {
                return "Open Upgrade Lab to verify offered parts and rebuild the FH5 build plan."
            }
            if let exactUpgradePathCount = projection.exactUpgradePathCount,
               exactUpgradePathCount > 0 {
                return projection.isSaved == true
                    ? "Copy the FH5 build plan when you are ready to use one of its exact paths."
                    : "Copy the FH5 build plan and save it so you can reopen the exact paths later."
            }
            return "Save the FH5 build plan. Numeric tuning settings remain unavailable pending a separate validated FH5 ruleset."
        }
        if projection.tireLabEligible == true {
            return "Open Tire Lab from the underlying result to verify the exact stock tire-pressure ranges."
        }
        if projection.upgradeLabEligible == true {
            return "Open Upgrade Lab from the underlying result to verify which tuning-control parts are available."
        }
        if projection.readyCount == 0 {
            return "All tune values are withheld. Follow the blocked status and reason labels before trying to use this tune."
        }
        if projection.isSaved == false {
            return "Save the tune from the underlying result so you can return after testing it in game."
        }
        return "Drive the saved tune, then use the existing guided feedback controls on the result if handling needs adjustment."
    }

    private func resultMissing(_ projection: CopilotProjectionFacts?) -> String {
        guard let projection else {
            return "A verified projection report is missing, so every tune setting remains untrusted."
        }
        if projection.resultPurpose == .fh5BuildPlan {
            if projection.fh5ObservationRecorded == true {
                return "The stock-menu observation is recorded, but it is raw evidence only. A validated numeric FH5 ruleset is still missing."
            }
            if projection.fh5ResearchLabEligible == true {
                return "A first-party stock-menu observation is still missing. Research Lab can record it without creating a tune."
            }
            if projection.upgradeLabEligible == true {
                return "Verified upgrade-shop availability is still missing. Use Upgrade Lab; numeric FH5 settings remain unavailable pending a separate validated ruleset."
            }
            if let exactUpgradePathCount = projection.exactUpgradePathCount,
               exactUpgradePathCount > 0 {
                return "No numeric FH5 settings are included. A separate validated FH5 ruleset is still missing; the \(exactUpgradePathCount) exact build paths are plan-only."
            }
            return "Numeric FH5 settings and a complete verified upgrade path are missing. This result remains plan-only."
        }
        var details = projection.blockedByStatus.map { "\($0.label): \($0.count)" }
        details.append(contentsOf: projection.blockedByReason.map { "\($0.label): \($0.count)" })
        if projection.tireLabEligible == true {
            details.append("Tire Lab verification is available")
        }
        if projection.upgradeLabEligible == true {
            details.append("Upgrade Lab verification is available")
        }
        if let exactUpgradePathCount = projection.exactUpgradePathCount,
           exactUpgradePathCount > 0 {
            details.append("Exact upgrade paths: \(exactUpgradePathCount)")
        }
        return details.isEmpty
            ? "No projection gaps are reported."
            : details.joined(separator: ". ") + "."
    }

    private func unsavedEditsMessage(_ message: String) -> String {
        "\(message) Copilot cannot see unsaved field edits."
    }
}
