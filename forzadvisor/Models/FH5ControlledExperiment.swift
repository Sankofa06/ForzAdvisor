//
//  FH5ControlledExperiment.swift
//  forzadvisor
//
//  A permission-bound, one-variable FH5 Test Track experiment. These records
//  are calibration evidence only. They never authorize numeric tune output.
//

import CryptoKit
import Foundation

enum FH5ExperimentOutcome: String, CaseIterable, Codable, Identifiable, Sendable {
    case variantPreferred
    case noClearDifference
    case baselinePreferred
    case inconclusive

    var id: String { rawValue }

    var title: String {
        switch self {
        case .variantPreferred: "Variant preferred"
        case .noClearDifference: "No clear difference"
        case .baselinePreferred: "Baseline preferred"
        case .inconclusive: "Inconclusive"
        }
    }
}

enum FH5ExperimentDirection: String, CaseIterable, Identifiable, Sendable {
    case decrease
    case increase

    var id: String { rawValue }

    var title: String {
        switch self {
        case .decrease: "One step lower"
        case .increase: "One step higher"
        }
    }

    var multiplier: Double {
        switch self {
        case .decrease: -1
        case .increase: 1
        }
    }
}

struct FH5ControlledExperimentCapture: Equatable, Sendable {
    let field: TuneFieldID
    let candidateValue: Double
    let input: ValidationInput
    let surface: ValidationSurface
    let targetSymptom: TuneFeedback
    let outcome: FH5ExperimentOutcome
    let sameRouteAndConditionsConfirmed: Bool
    let sameAssistsAndInputConfirmed: Bool
    let onlyDeclaredFieldChangedConfirmed: Bool
    let sequenceCompletedConfirmed: Bool
    let stockValuesRestoredConfirmed: Bool
    let firstPartyAuthorshipConfirmed: Bool
    let localStoragePermitted: Bool
    let deidentifiedReusePermitted: Bool
}

enum FH5ControlledExperimentIssue: Error, LocalizedError, Equatable {
    case notSaved
    case streaming
    case notFH5Plan
    case staleSavedRevision
    case missingResearchObservation
    case mismatchedResearchObservation
    case incompleteUpgradeObservation
    case fieldNotAdjustable
    case missingFieldMeasurements
    case nonFiniteCandidate
    case candidateUnchanged
    case candidateOutOfRange
    case candidateOffLattice
    case candidateNotOneStep
    case conditionsNotHeldConstant
    case assistsOrInputChanged
    case moreThanOneSettingChanged
    case sequenceNotCompleted
    case stockValuesNotRestored
    case authorshipNotConfirmed
    case localStorageNotPermitted
    case reuseNotPermitted
    case candidateBoundExportUnsupported
    case unregisteredCandidateAlgorithm
    case candidateArtifactMismatch
    case invalidStoredRecord

    var errorDescription: String? {
        switch self {
        case .notSaved: "Save this FH5 plan before opening Outcome Lab."
        case .streaming: "Wait for the plan to finish before starting an experiment."
        case .notFH5Plan: "Outcome Lab accepts saved FH5 plan-only results."
        case .staleSavedRevision: "Reopen the current saved plan before recording an experiment."
        case .missingResearchObservation:
            "Record the exact stock menu in Research Lab before starting an experiment."
        case .mismatchedResearchObservation:
            "The Research Lab observation no longer matches this saved plan."
        case .incompleteUpgradeObservation:
            "Complete Upgrade Lab for every supported tuning-control part first."
        case .fieldNotAdjustable:
            "Choose a control recorded as Adjustable in the matching Research Lab observation."
        case .missingFieldMeasurements:
            "The selected control is missing its observed minimum, maximum, step, current value, or unit."
        case .nonFiniteCandidate: "The experimental value is not a finite number."
        case .candidateUnchanged: "The experimental value must differ from the stock baseline."
        case .candidateOutOfRange: "The experimental value is outside the observed FH5 slider range."
        case .candidateOffLattice: "The experimental value does not land on the observed slider step."
        case .candidateNotOneStep:
            "This protocol permits exactly one observed slider step from the stock baseline."
        case .conditionsNotHeldConstant:
            "Confirm that every A-B-B-A run used the same Horizon Test Track route and conditions."
        case .assistsOrInputChanged:
            "Confirm that assists and input device stayed unchanged for every run."
        case .moreThanOneSettingChanged:
            "Confirm that only the one declared control changed between A and B."
        case .sequenceNotCompleted:
            "Complete the fixed A-B-B-A sequence before recording the outcome."
        case .stockValuesNotRestored:
            "Restore the tested control to its stock value before saving."
        case .authorshipNotConfirmed:
            "Confirm that you personally completed and observed this experiment."
        case .localStorageNotPermitted:
            "Allow ForzAdvisor to keep this experiment locally with the saved plan."
        case .reuseNotPermitted:
            "Allow deidentified calibration reuse before sharing this experiment."
        case .candidateBoundExportUnsupported:
            "Candidate-bound experiments stay local until a separate export consent and schema are available."
        case .unregisteredCandidateAlgorithm:
            "The experimental algorithm is not registered by this build."
        case .candidateArtifactMismatch:
            "The recorded experiment does not match the trusted generated candidate."
        case .invalidStoredRecord:
            "This stored FH5 experiment failed its integrity checks."
        }
    }
}

struct FH5ControlledExperimentRecord: Codable, Equatable, Identifiable, Sendable {
    static let calibrationSchemaVersion = 1
    static let candidateBoundSchemaVersion = 2
    static let currentSchemaVersion = candidateBoundSchemaVersion
    static let calibrationConsentVersion = "fh5-controlled-experiment-v1"
    static let candidateBoundConsentVersion = "fh5-controlled-experiment-v2"
    static let currentConsentVersion = candidateBoundConsentVersion
    nonisolated static let currentProtocolVersion = "fh5-abba-one-step-v1"
    static let route = "Horizon Test Track"
    static let sequence = ["A", "B", "B", "A"]
    static let privacyExclusions = [
        "local record ID",
        "saved tune ID and plan fingerprint",
        "Research Lab record ID and content fingerprint",
        "generated tune values",
        "provider and ruleset data",
        "lap times and telemetry",
        "free-form notes",
        "screenshots and OCR",
        "device identifiers and location",
        "analytics and share destination",
        "public attribution"
    ]

    struct Change: Codable, Equatable, Sendable {
        let field: TuneFieldID
        let baselineValue: Double
        let candidateValue: Double
        let minimum: Double
        let maximum: Double
        let step: Double
        let unit: TuneUnit
    }

    struct Context: Codable, Equatable, Sendable {
        let platform: FH5Platform
        let gameVersion: String
        let vehicle: FH5ResearchObservationRecord.Vehicle
        let tireCompoundDisplayName: String
        let forwardGearCount: Int
        let input: ValidationInput
        let surface: ValidationSurface
        let route: String
        let sequence: [String]
    }

    struct Attestations: Codable, Equatable, Sendable {
        let sameRouteAndConditions: Bool
        let sameAssistsAndInput: Bool
        let onlyDeclaredFieldChanged: Bool
        let sequenceCompleted: Bool
        let stockValuesRestored: Bool
        let firstPartyAuthorship: Bool
        let localStoragePermitted: Bool
        let deidentifiedReusePermitted: Bool
    }

    var id: UUID { recordID }
    let schemaVersion: Int
    let consentVersion: String
    let protocolVersion: String
    let recordID: UUID
    let submissionID: UUID
    let permissionReceiptID: UUID
    let createdAt: Date
    let game: ForzaGame
    let planRevisionFingerprint: String
    let researchContentFingerprint: String
    let measurementFingerprint: String
    let context: Context
    let change: Change
    let targetSymptom: TuneFeedback
    let outcome: FH5ExperimentOutcome
    let attestations: Attestations
    let candidateBinding: FH5RulesetCandidateBinding?
    let contentFingerprint: String

    var canExport: Bool {
        (try? publicExport()) != nil
    }

    func deterministicJSON() throws -> Data {
        guard FH5ControlledExperimentFactory().isValid(self) else {
            throw FH5ControlledExperimentIssue.invalidStoredRecord
        }
        guard attestations.deidentifiedReusePermitted else {
            throw FH5ControlledExperimentIssue.reuseNotPermitted
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .prettyPrinted,
            .sortedKeys,
            .withoutEscapingSlashes
        ]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(publicExport())
    }

    var deterministicJSONString: String? {
        guard let data = try? deterministicJSON() else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func publicExport() throws -> FH5ControlledExperimentExport {
        let factory = FH5ControlledExperimentFactory()
        guard factory.isValid(self) else {
            throw FH5ControlledExperimentIssue.invalidStoredRecord
        }
        guard attestations.deidentifiedReusePermitted else {
            throw FH5ControlledExperimentIssue.reuseNotPermitted
        }
        guard schemaVersion == Self.calibrationSchemaVersion,
              candidateBinding == nil else {
            throw FH5ControlledExperimentIssue.candidateBoundExportUnsupported
        }
        let export = FH5ControlledExperimentExport(
            schemaVersion: FH5ControlledExperimentExport.currentSchemaVersion,
            consentVersion: Self.calibrationConsentVersion,
            protocolVersion: protocolVersion,
            submissionID: submissionID,
            permissionReceiptID: permissionReceiptID,
            createdAt: createdAt,
            game: game,
            measurementFingerprint: measurementFingerprint,
            context: context,
            change: change,
            targetSymptom: targetSymptom,
            outcome: outcome,
            attestations: attestations,
            privacyExclusions: Self.privacyExclusions,
            contentFingerprint: try factory.publicSemanticFingerprint(
                for: self
            )
        )
        guard factory.isValid(export) else {
            throw FH5ControlledExperimentIssue.invalidStoredRecord
        }
        return export
    }
}

struct FH5ControlledExperimentExport: Codable, Equatable, Sendable {
    static let currentSchemaVersion =
        FH5ControlledExperimentRecord.calibrationSchemaVersion

    let schemaVersion: Int
    let consentVersion: String
    let protocolVersion: String
    let submissionID: UUID
    let permissionReceiptID: UUID
    let createdAt: Date
    let game: ForzaGame
    let measurementFingerprint: String
    let context: FH5ControlledExperimentRecord.Context
    let change: FH5ControlledExperimentRecord.Change
    let targetSymptom: TuneFeedback
    let outcome: FH5ExperimentOutcome
    let attestations: FH5ControlledExperimentRecord.Attestations
    let privacyExclusions: [String]
    let contentFingerprint: String
}

struct FH5GeneratedCandidateArtifact: Equatable, Sendable {
    let candidateBinding: FH5RulesetCandidateBinding
    let protocolVersion: String
    let game: ForzaGame
    let planRevisionFingerprint: String
    let researchContentFingerprint: String
    let measurementFingerprint: String
    let context: FH5ControlledExperimentRecord.Context
    let change: FH5ControlledExperimentRecord.Change
    let targetSymptom: TuneFeedback

    fileprivate init(record: FH5ControlledExperimentRecord) throws {
        guard
            record.schemaVersion
                == FH5ControlledExperimentRecord
                    .candidateBoundSchemaVersion,
            let candidateBinding = record.candidateBinding
        else {
            throw FH5ControlledExperimentIssue.invalidStoredRecord
        }
        self.candidateBinding = candidateBinding
        protocolVersion = record.protocolVersion
        game = record.game
        planRevisionFingerprint = record.planRevisionFingerprint
        researchContentFingerprint = record.researchContentFingerprint
        measurementFingerprint = record.measurementFingerprint
        context = record.context
        change = record.change
        targetSymptom = record.targetSymptom
    }

    fileprivate func exactlyMatches(
        _ record: FH5ControlledExperimentRecord
    ) -> Bool {
        candidateBinding == record.candidateBinding
            && protocolVersion == record.protocolVersion
            && game == record.game
            && planRevisionFingerprint == record.planRevisionFingerprint
            && researchContentFingerprint
                == record.researchContentFingerprint
            && measurementFingerprint == record.measurementFingerprint
            && context == record.context
            && change == record.change
            && targetSymptom == record.targetSymptom
    }
}

struct FH5ControlledExperimentFactory {
    private static let fingerprintLength = 64

    func eligibility(
        tune: TuneResult,
        savedTune: TuneResult?,
        isStreaming: Bool,
        researchRecords: [FH5ResearchObservationRecord]
    ) -> Result<FH5ResearchObservationRecord, FH5ControlledExperimentIssue> {
        guard let savedTune else { return .failure(.notSaved) }
        guard !isStreaming else { return .failure(.streaming) }
        guard tune.request.car.game == .fh5,
              tune.purpose == .fh5BuildPlan,
              savedTune.request.car.game == .fh5,
              savedTune.purpose == .fh5BuildPlan else {
            return .failure(.notFH5Plan)
        }
        guard tune == savedTune,
              tune.id == savedTune.id,
              tune.generatedAt == savedTune.generatedAt else {
            return .failure(.staleSavedRevision)
        }
        let matching = researchRecords
            .filter { FH5ResearchObservationFactory().matches($0, tune: tune) }
            .sorted { $0.capturedAt < $1.capturedAt }
        guard let record = matching.last else {
            return .failure(.missingResearchObservation)
        }
        guard hasCompleteUpgradeObservation(record) else {
            return .failure(.incompleteUpgradeObservation)
        }
        guard record.controls.contains(where: {
            $0.availability == .adjustable
                && $0.minimum != nil
                && $0.maximum != nil
                && $0.step != nil
                && $0.current != nil
                && $0.unit != nil
        }) else {
            return .failure(.fieldNotAdjustable)
        }
        return .success(record)
    }

    func make(
        tune: TuneResult,
        savedTune: TuneResult?,
        isStreaming: Bool,
        researchRecords: [FH5ResearchObservationRecord],
        capture: FH5ControlledExperimentCapture,
        recordID: UUID = UUID(),
        submissionID: UUID = UUID(),
        permissionReceiptID: UUID = UUID(),
        createdAt: Date = .now
    ) throws -> FH5ControlledExperimentRecord {
        try makeRecord(
            tune: tune,
            savedTune: savedTune,
            isStreaming: isStreaming,
            researchRecords: researchRecords,
            capture: capture,
            registration: nil,
            recordID: recordID,
            submissionID: submissionID,
            permissionReceiptID: permissionReceiptID,
            createdAt: createdAt
        )
    }

    /// Candidate-bound records can only consume a separately constructed
    /// artifact. This slice deliberately exposes no release artifact producer.
    func makeCandidateBound(
        tune: TuneResult,
        savedTune: TuneResult?,
        isStreaming: Bool,
        researchRecords: [FH5ResearchObservationRecord],
        capture: FH5ControlledExperimentCapture,
        candidateArtifact: FH5GeneratedCandidateArtifact,
        registry: FH5TrustedNumericRulesetRegistry,
        recordID: UUID = UUID(),
        submissionID: UUID = UUID(),
        permissionReceiptID: UUID = UUID(),
        createdAt: Date = .now
    ) throws -> FH5ControlledExperimentRecord {
        guard let registration = registry.registration(
            for: candidateArtifact.candidateBinding.algorithmID
        ),
              candidateArtifact.candidateBinding.isValid(
                for: registration
              ) else {
            throw FH5ControlledExperimentIssue.unregisteredCandidateAlgorithm
        }
        let record = try makeRecord(
            tune: tune,
            savedTune: savedTune,
            isStreaming: isStreaming,
            researchRecords: researchRecords,
            capture: capture,
            registration: registration,
            recordID: recordID,
            submissionID: submissionID,
            permissionReceiptID: permissionReceiptID,
            createdAt: createdAt
        )
        guard candidateArtifact.exactlyMatches(record) else {
            throw FH5ControlledExperimentIssue.candidateArtifactMismatch
        }
        return record
    }

    #if DEBUG
    /// Debug-only scaffolding for contract tests. A future trusted generator
    /// must replace this before candidate-bound collection is wired into UI.
    func makeCandidateArtifactForTesting(
        tune: TuneResult,
        savedTune: TuneResult?,
        isStreaming: Bool,
        researchRecords: [FH5ResearchObservationRecord],
        capture: FH5ControlledExperimentCapture,
        candidateAlgorithmID: FH5ExperimentalAlgorithmID,
        registry: FH5TrustedNumericRulesetRegistry
    ) throws -> FH5GeneratedCandidateArtifact {
        guard let registration = registry.registration(
            for: candidateAlgorithmID
        ) else {
            throw FH5ControlledExperimentIssue.unregisteredCandidateAlgorithm
        }
        let record = try makeRecord(
            tune: tune,
            savedTune: savedTune,
            isStreaming: isStreaming,
            researchRecords: researchRecords,
            capture: capture,
            registration: registration,
            recordID: UUID(),
            submissionID: UUID(),
            permissionReceiptID: UUID(),
            createdAt: .distantPast
        )
        return try FH5GeneratedCandidateArtifact(record: record)
    }
    #endif

    private func makeRecord(
        tune: TuneResult,
        savedTune: TuneResult?,
        isStreaming: Bool,
        researchRecords: [FH5ResearchObservationRecord],
        capture: FH5ControlledExperimentCapture,
        registration: FH5NumericRulesetRegistration?,
        recordID: UUID,
        submissionID: UUID,
        permissionReceiptID: UUID,
        createdAt: Date
    ) throws -> FH5ControlledExperimentRecord {
        let sourceRecord: FH5ResearchObservationRecord
        switch eligibility(
            tune: tune,
            savedTune: savedTune,
            isStreaming: isStreaming,
            researchRecords: researchRecords
        ) {
        case .success(let record):
            sourceRecord = record
        case .failure(let issue):
            throw issue
        }

        guard let observation = sourceRecord.controls.first(where: {
            $0.field == capture.field && $0.availability == .adjustable
        }) else {
            throw FH5ControlledExperimentIssue.fieldNotAdjustable
        }
        guard let minimum = observation.minimum,
              let maximum = observation.maximum,
              let step = observation.step,
              let current = observation.current,
              let unit = observation.unit else {
            throw FH5ControlledExperimentIssue.missingFieldMeasurements
        }
        if let issue = candidateIssue(
            candidate: capture.candidateValue,
            minimum: minimum,
            maximum: maximum,
            step: step,
            current: current
        ) {
            throw issue
        }
        try validateAttestations(capture)

        let context = FH5ControlledExperimentRecord.Context(
            platform: sourceRecord.platform,
            gameVersion: sourceRecord.gameVersion,
            vehicle: sourceRecord.vehicle,
            tireCompoundDisplayName: sourceRecord.tireCompoundDisplayName,
            forwardGearCount: sourceRecord.forwardGearCount,
            input: capture.input,
            surface: capture.surface,
            route: FH5ControlledExperimentRecord.route,
            sequence: FH5ControlledExperimentRecord.sequence
        )
        let change = FH5ControlledExperimentRecord.Change(
            field: capture.field,
            baselineValue: current,
            candidateValue: capture.candidateValue,
            minimum: minimum,
            maximum: maximum,
            step: step,
            unit: unit
        )
        let attestations = FH5ControlledExperimentRecord.Attestations(
            sameRouteAndConditions: capture.sameRouteAndConditionsConfirmed,
            sameAssistsAndInput: capture.sameAssistsAndInputConfirmed,
            onlyDeclaredFieldChanged: capture.onlyDeclaredFieldChangedConfirmed,
            sequenceCompleted: capture.sequenceCompletedConfirmed,
            stockValuesRestored: capture.stockValuesRestoredConfirmed,
            firstPartyAuthorship: capture.firstPartyAuthorshipConfirmed,
            localStoragePermitted: capture.localStoragePermitted,
            deidentifiedReusePermitted: capture.deidentifiedReusePermitted
        )
        let planFingerprint = try requirePlanFingerprint(tune)
        guard let measurementFingerprint = FH5ResearchReviewIngestor()
            .measurementFingerprint(for: sourceRecord.controls) else {
            throw FH5ControlledExperimentIssue.invalidStoredRecord
        }
        let schemaVersion: Int
        let consentVersion: String
        let candidateBinding: FH5RulesetCandidateBinding?
        if let registration {
            guard registration.isValid,
                  let sourceManifestFingerprint =
                    registration.sourceManifestFingerprint else {
                throw FH5ControlledExperimentIssue.unregisteredCandidateAlgorithm
            }
            schemaVersion =
                FH5ControlledExperimentRecord.candidateBoundSchemaVersion
            consentVersion =
                FH5ControlledExperimentRecord.candidateBoundConsentVersion
            candidateBinding = FH5RulesetCandidateBinding(
                algorithmID: registration.algorithmID,
                rulesetReference: registration.reference,
                sourceManifestFingerprint: sourceManifestFingerprint,
                outcomePolicyVersion:
                    registration.outcomeThreshold.policyVersion,
                generatedCandidateFingerprint:
                    try generatedCandidateFingerprint(
                        algorithmID: registration.algorithmID,
                        rulesetReference: registration.reference,
                        sourceManifestFingerprint:
                            sourceManifestFingerprint,
                        outcomePolicyVersion:
                            registration.outcomeThreshold.policyVersion,
                        protocolVersion:
                            FH5ControlledExperimentRecord
                                .currentProtocolVersion,
                        game: .fh5,
                        planRevisionFingerprint: planFingerprint,
                        researchContentFingerprint:
                            sourceRecord.contentFingerprint,
                        measurementFingerprint: measurementFingerprint,
                        context: context,
                        change: change,
                        targetSymptom: capture.targetSymptom
                    )
            )
        } else {
            schemaVersion =
                FH5ControlledExperimentRecord.calibrationSchemaVersion
            consentVersion =
                FH5ControlledExperimentRecord.calibrationConsentVersion
            candidateBinding = nil
        }
        let fingerprint = try contentFingerprint(
            schemaVersion: schemaVersion,
            consentVersion: consentVersion,
            protocolVersion: FH5ControlledExperimentRecord.currentProtocolVersion,
            submissionID: submissionID,
            permissionReceiptID: permissionReceiptID,
            createdAt: createdAt,
            game: .fh5,
            planRevisionFingerprint: planFingerprint,
            researchContentFingerprint: sourceRecord.contentFingerprint,
            measurementFingerprint: measurementFingerprint,
            context: context,
            change: change,
            targetSymptom: capture.targetSymptom,
            outcome: capture.outcome,
            attestations: attestations,
            candidateBinding: candidateBinding
        )
        let record = FH5ControlledExperimentRecord(
            schemaVersion: schemaVersion,
            consentVersion: consentVersion,
            protocolVersion: FH5ControlledExperimentRecord.currentProtocolVersion,
            recordID: recordID,
            submissionID: submissionID,
            permissionReceiptID: permissionReceiptID,
            createdAt: createdAt,
            game: .fh5,
            planRevisionFingerprint: planFingerprint,
            researchContentFingerprint: sourceRecord.contentFingerprint,
            measurementFingerprint: measurementFingerprint,
            context: context,
            change: change,
            targetSymptom: capture.targetSymptom,
            outcome: capture.outcome,
            attestations: attestations,
            candidateBinding: candidateBinding,
            contentFingerprint: fingerprint
        )
        guard isValid(record) else {
            throw FH5ControlledExperimentIssue.invalidStoredRecord
        }
        return record
    }

    func isValid(_ record: FH5ControlledExperimentRecord) -> Bool {
        guard hasValidVersionAndBinding(record),
              record.protocolVersion == FH5ControlledExperimentRecord.currentProtocolVersion,
              record.game == .fh5,
              record.planRevisionFingerprint.count == Self.fingerprintLength,
              record.researchContentFingerprint.count == Self.fingerprintLength,
              record.measurementFingerprint.count == Self.fingerprintLength,
              record.context.route == FH5ControlledExperimentRecord.route,
              record.context.sequence == FH5ControlledExperimentRecord.sequence,
              record.context.forwardGearCount >= 1,
              record.context.forwardGearCount <= 10,
              record.change.unit == record.change.field.expectedUnit,
              candidateIssue(
                candidate: record.change.candidateValue,
                minimum: record.change.minimum,
                maximum: record.change.maximum,
                step: record.change.step,
                current: record.change.baselineValue
              ) == nil,
              record.attestations.sameRouteAndConditions,
              record.attestations.sameAssistsAndInput,
              record.attestations.onlyDeclaredFieldChanged,
              record.attestations.sequenceCompleted,
              record.attestations.stockValuesRestored,
              record.attestations.firstPartyAuthorship,
              record.attestations.localStoragePermitted,
              let expected = try? contentFingerprint(
                schemaVersion: record.schemaVersion,
                consentVersion: record.consentVersion,
                protocolVersion: record.protocolVersion,
                submissionID: record.submissionID,
                permissionReceiptID: record.permissionReceiptID,
                createdAt: record.createdAt,
                game: record.game,
                planRevisionFingerprint: record.planRevisionFingerprint,
                researchContentFingerprint: record.researchContentFingerprint,
                measurementFingerprint: record.measurementFingerprint,
                context: record.context,
                change: record.change,
                targetSymptom: record.targetSymptom,
                outcome: record.outcome,
                attestations: record.attestations,
                candidateBinding: record.candidateBinding
              ) else {
            return false
        }
        return expected == record.contentFingerprint
    }

    private func hasValidVersionAndBinding(
        _ record: FH5ControlledExperimentRecord
    ) -> Bool {
        switch record.schemaVersion {
        case FH5ControlledExperimentRecord.calibrationSchemaVersion:
            return record.consentVersion
                    == FH5ControlledExperimentRecord
                        .calibrationConsentVersion
                && record.candidateBinding == nil
        case FH5ControlledExperimentRecord.candidateBoundSchemaVersion:
            guard record.consentVersion
                    == FH5ControlledExperimentRecord
                        .candidateBoundConsentVersion,
                  let binding = record.candidateBinding,
                  binding.isStructurallyValid,
                  let expected = try? generatedCandidateFingerprint(
                    algorithmID: binding.algorithmID,
                    rulesetReference: binding.rulesetReference,
                    sourceManifestFingerprint:
                        binding.sourceManifestFingerprint,
                    outcomePolicyVersion: binding.outcomePolicyVersion,
                    protocolVersion: record.protocolVersion,
                    game: record.game,
                    planRevisionFingerprint:
                        record.planRevisionFingerprint,
                    researchContentFingerprint:
                        record.researchContentFingerprint,
                    measurementFingerprint:
                        record.measurementFingerprint,
                    context: record.context,
                    change: record.change,
                    targetSymptom: record.targetSymptom
                  ) else {
                return false
            }
            return binding.generatedCandidateFingerprint == expected
        default:
            return false
        }
    }

    func isValid(_ export: FH5ControlledExperimentExport) -> Bool {
        guard export.schemaVersion
                == FH5ControlledExperimentExport.currentSchemaVersion,
              export.consentVersion
                == FH5ControlledExperimentRecord.calibrationConsentVersion,
              export.protocolVersion
                == FH5ControlledExperimentRecord.currentProtocolVersion,
              export.game == .fh5,
              isSHA256Fingerprint(export.measurementFingerprint),
              export.context.route == FH5ControlledExperimentRecord.route,
              export.context.sequence
                == FH5ControlledExperimentRecord.sequence,
              (1...10).contains(export.context.forwardGearCount),
              export.context.vehicle.stock,
              isCanonical(export.context.gameVersion, maximumLength: 120),
              isCanonical(
                export.context.tireCompoundDisplayName,
                maximumLength: 120
              ),
              isCanonical(
                export.context.vehicle.catalogID,
                maximumLength: 160
              ),
              isCanonical(
                export.context.vehicle.catalogRevision,
                maximumLength: 160
              ),
              isCanonical(export.context.vehicle.make, maximumLength: 120),
              isCanonical(export.context.vehicle.model, maximumLength: 160),
              export.context.vehicle.year > 0,
              export.context.vehicle.weightPounds > 0,
              export.context.vehicle.frontWeightPercent >= 0,
              export.context.vehicle.frontWeightPercent <= 100,
              export.context.vehicle.peakHorsepower > 0,
              export.context.vehicle.peakTorqueFootPounds > 0,
              export.change.unit == export.change.field.expectedUnit,
              candidateIssue(
                candidate: export.change.candidateValue,
                minimum: export.change.minimum,
                maximum: export.change.maximum,
                step: export.change.step,
                current: export.change.baselineValue
              ) == nil,
              export.attestations.sameRouteAndConditions,
              export.attestations.sameAssistsAndInput,
              export.attestations.onlyDeclaredFieldChanged,
              export.attestations.sequenceCompleted,
              export.attestations.stockValuesRestored,
              export.attestations.firstPartyAuthorship,
              export.attestations.localStoragePermitted,
              export.attestations.deidentifiedReusePermitted,
              export.privacyExclusions
                == FH5ControlledExperimentRecord.privacyExclusions,
              isSHA256Fingerprint(export.contentFingerprint),
              let expected = try? publicSemanticFingerprint(for: export)
        else {
            return false
        }
        return expected == export.contentFingerprint
    }

    func matches(
        _ record: FH5ControlledExperimentRecord,
        tune: TuneResult,
        researchRecord: FH5ResearchObservationRecord
    ) -> Bool {
        guard isValid(record),
              FH5ResearchObservationFactory().matches(researchRecord, tune: tune),
              let planFingerprint = FH5ResearchObservationFactory()
                .planRevisionFingerprint(for: tune) else {
            return false
        }
        guard let measurementFingerprint = FH5ResearchReviewIngestor()
            .measurementFingerprint(for: researchRecord.controls) else {
            return false
        }
        return record.planRevisionFingerprint == planFingerprint
            && record.researchContentFingerprint == researchRecord.contentFingerprint
            && record.measurementFingerprint == measurementFingerprint
            && changeMatchesResearch(
                record.change,
                researchRecord: researchRecord
            )
            && record.context.platform == researchRecord.platform
            && record.context.gameVersion == researchRecord.gameVersion
            && record.context.vehicle == researchRecord.vehicle
            && record.context.tireCompoundDisplayName
                == researchRecord.tireCompoundDisplayName
            && record.context.forwardGearCount == researchRecord.forwardGearCount
    }

    func changeMatchesResearch(
        _ change: FH5ControlledExperimentRecord.Change,
        researchRecord: FH5ResearchObservationRecord
    ) -> Bool {
        guard let observation = researchRecord.controls.first(where: {
            $0.field == change.field
        }) else {
            return false
        }
        return observation.availability == .adjustable
            && observation.minimum == change.minimum
            && observation.maximum == change.maximum
            && observation.step == change.step
            && observation.current == change.baselineValue
            && observation.unit == change.unit
    }

    func outcomePolicyReport(
        records: [FH5ControlledExperimentRecord],
        tune: TuneResult,
        researchRecord: FH5ResearchObservationRecord?
    ) -> FH5ControlledOutcomePolicyReport {
        guard let researchRecord else { return .empty }
        let count = records.count {
            matches($0, tune: tune, researchRecord: researchRecord)
        }
        return .unregistered(matchingRecordCount: count)
    }

    func publicSemanticFingerprint(
        for record: FH5ControlledExperimentRecord
    ) throws -> String {
        guard record.schemaVersion
                == FH5ControlledExperimentRecord.calibrationSchemaVersion,
              record.candidateBinding == nil else {
            throw FH5ControlledExperimentIssue
                .candidateBoundExportUnsupported
        }
        return try publicSemanticFingerprint(
            schemaVersion: FH5ControlledExperimentExport.currentSchemaVersion,
            consentVersion:
                FH5ControlledExperimentRecord.calibrationConsentVersion,
            protocolVersion: record.protocolVersion,
            submissionID: record.submissionID,
            permissionReceiptID: record.permissionReceiptID,
            createdAt: record.createdAt,
            game: record.game,
            measurementFingerprint: record.measurementFingerprint,
            context: record.context,
            change: record.change,
            targetSymptom: record.targetSymptom,
            outcome: record.outcome,
            attestations: record.attestations,
            privacyExclusions: FH5ControlledExperimentRecord
                .privacyExclusions
        )
    }

    func publicSemanticFingerprint(
        for export: FH5ControlledExperimentExport
    ) throws -> String {
        try publicSemanticFingerprint(
            schemaVersion: export.schemaVersion,
            consentVersion: export.consentVersion,
            protocolVersion: export.protocolVersion,
            submissionID: export.submissionID,
            permissionReceiptID: export.permissionReceiptID,
            createdAt: export.createdAt,
            game: export.game,
            measurementFingerprint: export.measurementFingerprint,
            context: export.context,
            change: export.change,
            targetSymptom: export.targetSymptom,
            outcome: export.outcome,
            attestations: export.attestations,
            privacyExclusions: export.privacyExclusions
        )
    }

    func experimentSemanticFingerprint(
        for record: FH5ControlledExperimentRecord
    ) throws -> String {
        guard isValid(record),
              record.schemaVersion
                == FH5ControlledExperimentRecord
                    .candidateBoundSchemaVersion,
              record.candidateBinding != nil else {
            throw FH5ControlledExperimentIssue.invalidStoredRecord
        }
        return try candidateBoundAuditSemanticFingerprint(for: record)
    }

    func candidateBoundAuditSemanticFingerprint(
        for record: FH5ControlledExperimentRecord
    ) throws -> String {
        guard let candidateBinding = record.candidateBinding else {
            throw FH5ControlledExperimentIssue.invalidStoredRecord
        }
        let payload = ExperimentSemanticFingerprintPayloadV1(
            schemaVersion: 1,
            protocolVersion: record.protocolVersion,
            createdAt: record.createdAt,
            game: record.game,
            planRevisionFingerprint: record.planRevisionFingerprint,
            researchContentFingerprint: record.researchContentFingerprint,
            measurementFingerprint: record.measurementFingerprint,
            context: record.context,
            change: record.change,
            targetSymptom: record.targetSymptom,
            outcome: record.outcome,
            attestations: record.attestations,
            candidateBinding: candidateBinding
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        let digest = SHA256.hash(data: try encoder.encode(payload))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func validateAttestations(
        _ capture: FH5ControlledExperimentCapture
    ) throws {
        guard capture.sameRouteAndConditionsConfirmed else {
            throw FH5ControlledExperimentIssue.conditionsNotHeldConstant
        }
        guard capture.sameAssistsAndInputConfirmed else {
            throw FH5ControlledExperimentIssue.assistsOrInputChanged
        }
        guard capture.onlyDeclaredFieldChangedConfirmed else {
            throw FH5ControlledExperimentIssue.moreThanOneSettingChanged
        }
        guard capture.sequenceCompletedConfirmed else {
            throw FH5ControlledExperimentIssue.sequenceNotCompleted
        }
        guard capture.stockValuesRestoredConfirmed else {
            throw FH5ControlledExperimentIssue.stockValuesNotRestored
        }
        guard capture.firstPartyAuthorshipConfirmed else {
            throw FH5ControlledExperimentIssue.authorshipNotConfirmed
        }
        guard capture.localStoragePermitted else {
            throw FH5ControlledExperimentIssue.localStorageNotPermitted
        }
    }

    private func hasCompleteUpgradeObservation(
        _ record: FH5ResearchObservationRecord
    ) -> Bool {
        let expected = Set(TunePartID.allCases)
        return record.upgradeParts.count == expected.count
            && Set(record.upgradeParts.map(\.partID)) == expected
            && record.upgradeParts.allSatisfy {
                $0.availability == .available || $0.availability == .unavailable
            }
    }

    private func requirePlanFingerprint(_ tune: TuneResult) throws -> String {
        guard let fingerprint = FH5ResearchObservationFactory()
            .planRevisionFingerprint(for: tune),
              fingerprint.count == Self.fingerprintLength else {
            throw FH5ControlledExperimentIssue.staleSavedRevision
        }
        return fingerprint
    }

    private func candidateIssue(
        candidate: Double,
        minimum: Double,
        maximum: Double,
        step: Double,
        current: Double
    ) -> FH5ControlledExperimentIssue? {
        guard candidate.isFinite,
              minimum.isFinite,
              maximum.isFinite,
              step.isFinite,
              current.isFinite else {
            return .nonFiniteCandidate
        }
        guard step > 0, minimum < maximum else {
            return .missingFieldMeasurements
        }
        let tolerance = max(1e-9, step * 1e-6)
        guard current >= minimum - tolerance,
              current <= maximum + tolerance else {
            return .missingFieldMeasurements
        }
        let currentLattice = (current - minimum) / step
        guard abs(currentLattice - currentLattice.rounded()) <= 1e-6 else {
            return .missingFieldMeasurements
        }
        guard abs(candidate - current) > tolerance else {
            return .candidateUnchanged
        }
        guard candidate >= minimum - tolerance,
              candidate <= maximum + tolerance else {
            return .candidateOutOfRange
        }
        let lattice = (candidate - minimum) / step
        guard abs(lattice - lattice.rounded()) <= 1e-6 else {
            return .candidateOffLattice
        }
        guard abs(abs(candidate - current) - step) <= tolerance else {
            return .candidateNotOneStep
        }
        return nil
    }

    private struct FingerprintPayloadV1: Codable {
        let schemaVersion: Int
        let consentVersion: String
        let protocolVersion: String
        let submissionID: UUID
        let permissionReceiptID: UUID
        let createdAt: Date
        let game: ForzaGame
        let planRevisionFingerprint: String
        let researchContentFingerprint: String
        let measurementFingerprint: String
        let context: FH5ControlledExperimentRecord.Context
        let change: FH5ControlledExperimentRecord.Change
        let targetSymptom: TuneFeedback
        let outcome: FH5ExperimentOutcome
        let attestations: FH5ControlledExperimentRecord.Attestations
    }

    private struct FingerprintPayloadV2: Codable {
        let schemaVersion: Int
        let consentVersion: String
        let protocolVersion: String
        let submissionID: UUID
        let permissionReceiptID: UUID
        let createdAt: Date
        let game: ForzaGame
        let planRevisionFingerprint: String
        let researchContentFingerprint: String
        let measurementFingerprint: String
        let context: FH5ControlledExperimentRecord.Context
        let change: FH5ControlledExperimentRecord.Change
        let targetSymptom: TuneFeedback
        let outcome: FH5ExperimentOutcome
        let attestations: FH5ControlledExperimentRecord.Attestations
        let candidateBinding: FH5RulesetCandidateBinding
    }

    private struct GeneratedCandidateFingerprintPayloadV1: Codable {
        let schemaVersion: Int
        let algorithmID: FH5ExperimentalAlgorithmID
        let rulesetReference: TuneRulesetReference
        let sourceManifestFingerprint: String
        let outcomePolicyVersion: String
        let protocolVersion: String
        let game: ForzaGame
        let planRevisionFingerprint: String
        let researchContentFingerprint: String
        let measurementFingerprint: String
        let context: FH5ControlledExperimentRecord.Context
        let change: FH5ControlledExperimentRecord.Change
        let targetSymptom: TuneFeedback
    }

    private struct ExperimentSemanticFingerprintPayloadV1: Codable {
        let schemaVersion: Int
        let protocolVersion: String
        let createdAt: Date
        let game: ForzaGame
        let planRevisionFingerprint: String
        let researchContentFingerprint: String
        let measurementFingerprint: String
        let context: FH5ControlledExperimentRecord.Context
        let change: FH5ControlledExperimentRecord.Change
        let targetSymptom: TuneFeedback
        let outcome: FH5ExperimentOutcome
        let attestations: FH5ControlledExperimentRecord.Attestations
        let candidateBinding: FH5RulesetCandidateBinding
    }

    private struct PublicSemanticPayload: Codable {
        let schemaVersion: Int
        let consentVersion: String
        let protocolVersion: String
        let submissionID: UUID
        let permissionReceiptID: UUID
        let createdAt: Date
        let game: ForzaGame
        let measurementFingerprint: String
        let context: FH5ControlledExperimentRecord.Context
        let change: FH5ControlledExperimentRecord.Change
        let targetSymptom: TuneFeedback
        let outcome: FH5ExperimentOutcome
        let attestations: FH5ControlledExperimentRecord.Attestations
        let privacyExclusions: [String]
    }

    private func contentFingerprint(
        schemaVersion: Int,
        consentVersion: String,
        protocolVersion: String,
        submissionID: UUID,
        permissionReceiptID: UUID,
        createdAt: Date,
        game: ForzaGame,
        planRevisionFingerprint: String,
        researchContentFingerprint: String,
        measurementFingerprint: String,
        context: FH5ControlledExperimentRecord.Context,
        change: FH5ControlledExperimentRecord.Change,
        targetSymptom: TuneFeedback,
        outcome: FH5ExperimentOutcome,
        attestations: FH5ControlledExperimentRecord.Attestations,
        candidateBinding: FH5RulesetCandidateBinding?
    ) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        let data: Data
        switch schemaVersion {
        case FH5ControlledExperimentRecord.calibrationSchemaVersion:
            guard candidateBinding == nil,
                  consentVersion
                    == FH5ControlledExperimentRecord
                        .calibrationConsentVersion else {
                throw FH5ControlledExperimentIssue.invalidStoredRecord
            }
            data = try encoder.encode(FingerprintPayloadV1(
                schemaVersion: schemaVersion,
                consentVersion: consentVersion,
                protocolVersion: protocolVersion,
                submissionID: submissionID,
                permissionReceiptID: permissionReceiptID,
                createdAt: createdAt,
                game: game,
                planRevisionFingerprint: planRevisionFingerprint,
                researchContentFingerprint: researchContentFingerprint,
                measurementFingerprint: measurementFingerprint,
                context: context,
                change: change,
                targetSymptom: targetSymptom,
                outcome: outcome,
                attestations: attestations
            ))
        case FH5ControlledExperimentRecord.candidateBoundSchemaVersion:
            guard let candidateBinding,
                  consentVersion
                    == FH5ControlledExperimentRecord
                        .candidateBoundConsentVersion else {
                throw FH5ControlledExperimentIssue.invalidStoredRecord
            }
            data = try encoder.encode(FingerprintPayloadV2(
                schemaVersion: schemaVersion,
                consentVersion: consentVersion,
                protocolVersion: protocolVersion,
                submissionID: submissionID,
                permissionReceiptID: permissionReceiptID,
                createdAt: createdAt,
                game: game,
                planRevisionFingerprint: planRevisionFingerprint,
                researchContentFingerprint: researchContentFingerprint,
                measurementFingerprint: measurementFingerprint,
                context: context,
                change: change,
                targetSymptom: targetSymptom,
                outcome: outcome,
                attestations: attestations,
                candidateBinding: candidateBinding
            ))
        default:
            throw FH5ControlledExperimentIssue.invalidStoredRecord
        }
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func generatedCandidateFingerprint(
        algorithmID: FH5ExperimentalAlgorithmID,
        rulesetReference: TuneRulesetReference,
        sourceManifestFingerprint: String,
        outcomePolicyVersion: String,
        protocolVersion: String,
        game: ForzaGame,
        planRevisionFingerprint: String,
        researchContentFingerprint: String,
        measurementFingerprint: String,
        context: FH5ControlledExperimentRecord.Context,
        change: FH5ControlledExperimentRecord.Change,
        targetSymptom: TuneFeedback
    ) throws -> String {
        let payload = GeneratedCandidateFingerprintPayloadV1(
            schemaVersion: 1,
            algorithmID: algorithmID,
            rulesetReference: rulesetReference,
            sourceManifestFingerprint: sourceManifestFingerprint,
            outcomePolicyVersion: outcomePolicyVersion,
            protocolVersion: protocolVersion,
            game: game,
            planRevisionFingerprint: planRevisionFingerprint,
            researchContentFingerprint: researchContentFingerprint,
            measurementFingerprint: measurementFingerprint,
            context: context,
            change: change,
            targetSymptom: targetSymptom
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        let digest = SHA256.hash(data: try encoder.encode(payload))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func publicSemanticFingerprint(
        schemaVersion: Int,
        consentVersion: String,
        protocolVersion: String,
        submissionID: UUID,
        permissionReceiptID: UUID,
        createdAt: Date,
        game: ForzaGame,
        measurementFingerprint: String,
        context: FH5ControlledExperimentRecord.Context,
        change: FH5ControlledExperimentRecord.Change,
        targetSymptom: TuneFeedback,
        outcome: FH5ExperimentOutcome,
        attestations: FH5ControlledExperimentRecord.Attestations,
        privacyExclusions: [String]
    ) throws -> String {
        let payload = PublicSemanticPayload(
            schemaVersion: schemaVersion,
            consentVersion: consentVersion,
            protocolVersion: protocolVersion,
            submissionID: submissionID,
            permissionReceiptID: permissionReceiptID,
            createdAt: createdAt,
            game: game,
            measurementFingerprint: measurementFingerprint,
            context: context,
            change: change,
            targetSymptom: targetSymptom,
            outcome: outcome,
            attestations: attestations,
            privacyExclusions: privacyExclusions
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .sortedKeys,
            .withoutEscapingSlashes
        ]
        encoder.dateEncodingStrategy = .iso8601
        let digest = SHA256.hash(data: try encoder.encode(payload))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func isSHA256Fingerprint(_ value: String) -> Bool {
        value.count == Self.fingerprintLength
            && value.allSatisfy { $0.isHexDigit && !$0.isUppercase }
    }

    private func isCanonical(
        _ value: String,
        maximumLength: Int
    ) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty
            && trimmed == value
            && value.count <= maximumLength
            && !value.unicodeScalars.contains {
                CharacterSet.controlCharacters.contains($0)
            }
    }
}
