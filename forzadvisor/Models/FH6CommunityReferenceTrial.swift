//
//  FH6CommunityReferenceTrial.swift
//  forzadvisor
//
//  Permission-separated, black-box FH6 community-reference comparisons.
//

import Foundation

enum FH6CommunityReferenceKind: String, CaseIterable, Codable, Sendable {
    case youtube
    case reddit

    var title: String {
        switch self {
        case .youtube: "YouTube"
        case .reddit: "Reddit"
        }
    }
}

enum FH6CommunityReferenceUsageScope: String, Codable, Sendable {
    case metadataOnly
}

enum FH6CommunityReferencePermissionBasis: String, Codable, Sendable {
    case publicAvailability
}

enum FH6CommunityReferenceTrialOutcome: String, CaseIterable, Codable, Sendable {
    case generatedPreferred
    case referencePreferred
    case noClearDifference
    case inconclusive

    var title: String {
        switch self {
        case .generatedPreferred: "ForzAdvisor candidate preferred"
        case .referencePreferred: "Community reference preferred"
        case .noClearDifference: "No clear difference"
        case .inconclusive: "Inconclusive"
        }
    }
}

enum FH6CommunityReferenceTrialRole: String, CaseIterable, Codable, Sendable {
    case a1 = "A1"
    case b1 = "B1"
    case b2 = "B2"
    case a2 = "A2"
}

struct FH6CommunityReferenceTrialRun: Codable, Equatable, Sendable {
    var role: FH6CommunityReferenceTrialRole
    var completed: Bool
    var correctTuneConfirmed: Bool
}

struct FH6CommunityReferenceSourceCapture: Equatable, Sendable {
    var kind: FH6CommunityReferenceKind
    var contentURL: String
    var publisherDisplayName: String
    var sourceID: String
    var retrievedAt: Date
    var derivativeOfSourceID: String?

    init(
        kind: FH6CommunityReferenceKind,
        contentURL: String,
        publisherDisplayName: String,
        sourceID: String,
        retrievedAt: Date,
        derivativeOfSourceID: String? = nil
    ) {
        self.kind = kind
        self.contentURL = contentURL
        self.publisherDisplayName = publisherDisplayName
        self.sourceID = sourceID
        self.retrievedAt = retrievedAt
        self.derivativeOfSourceID = derivativeOfSourceID
    }
}

/// Metadata only. This type intentionally has no tune, setting, part, or prose fields.
struct FH6CommunityReferenceSourceMetadata: Codable, Equatable, Sendable {
    var kind: FH6CommunityReferenceKind
    var canonicalContentURL: String
    var publisherDisplayName: String
    var sourceID: String
    var publisherIdentityFingerprint: String
    var contentIdentityFingerprint: String
    var retrievedAt: Date
    var derivativeOfSourceID: String?
    var usageScope: FH6CommunityReferenceUsageScope
    var permissionBasis: FH6CommunityReferencePermissionBasis
}

// Identity fingerprints above are deterministic normalized-metadata identifiers.
// They neither authenticate a publisher nor grant rights to the referenced content.

struct FH6CommunityReferenceCandidateAssociation: Codable, Equatable, Sendable {
    var catalogID: String
    var performanceClass: PerformanceClass
    var performanceIndex: Int
    var confirmed: Bool
    /// Opaque binding to the exact permission-clear generated candidate.
    var candidateFingerprint: String = ""
}

struct FH6CommunityReferenceTrialContext: Codable, Equatable, Sendable {
    var courseType: ValidationCourseType
    var surface: ValidationSurface
    var input: ValidationInput
}

struct FH6CommunityReferenceTrialAttestations: Codable, Equatable, Sendable {
    var sameRouteAndConditions: Bool
    var sameAssistsAndInput: Bool
    var candidateSettingsApplied: Bool
    var communityIdentityConfirmed: Bool
    var finalCandidateRestored: Bool
    var firstPartyAuthorship: Bool
    var localStoragePermitted: Bool
    var deidentifiedOutcomeReusePermitted: Bool
}

struct FH6CommunityReferenceTrialCapture: Equatable, Sendable {
    var source: FH6CommunityReferenceSourceCapture
    var referenceCandidate: FH6CommunityReferenceCandidateAssociation
    var context: FH6CommunityReferenceTrialContext
    var runs: [FH6CommunityReferenceTrialRun]
    var outcome: FH6CommunityReferenceTrialOutcome
    var candidateDeficiencySymptoms: Set<TuneFeedback>
    var attestations: FH6CommunityReferenceTrialAttestations

    init(
        source: FH6CommunityReferenceSourceCapture,
        referenceCandidate: FH6CommunityReferenceCandidateAssociation,
        context: FH6CommunityReferenceTrialContext,
        runs: [FH6CommunityReferenceTrialRun],
        outcome: FH6CommunityReferenceTrialOutcome,
        candidateDeficiencySymptoms: Set<TuneFeedback> = [],
        sameRouteAndConditionsConfirmed: Bool,
        sameAssistsAndInputConfirmed: Bool,
        candidateSettingsAppliedConfirmed: Bool,
        communityIdentityConfirmed: Bool,
        finalCandidateRestoredConfirmed: Bool,
        firstPartyAuthorshipConfirmed: Bool,
        localStoragePermitted: Bool,
        deidentifiedOutcomeReusePermitted: Bool = false
    ) {
        self.source = source
        self.referenceCandidate = referenceCandidate
        self.context = context
        self.runs = runs
        self.outcome = outcome
        self.candidateDeficiencySymptoms = candidateDeficiencySymptoms
        attestations = FH6CommunityReferenceTrialAttestations(
            sameRouteAndConditions: sameRouteAndConditionsConfirmed,
            sameAssistsAndInput: sameAssistsAndInputConfirmed,
            candidateSettingsApplied: candidateSettingsAppliedConfirmed,
            communityIdentityConfirmed: communityIdentityConfirmed,
            finalCandidateRestored: finalCandidateRestoredConfirmed,
            firstPartyAuthorship: firstPartyAuthorshipConfirmed,
            localStoragePermitted: localStoragePermitted,
            deidentifiedOutcomeReusePermitted: deidentifiedOutcomeReusePermitted
        )
    }
}

struct FH6CommunityReferenceTrialDraft: Equatable, Sendable {
    var kind: FH6CommunityReferenceKind = .youtube
    var contentURL = ""
    var publisherDisplayName = ""
    var courseType: ValidationCourseType = .roadCircuit
    var surface: ValidationSurface = .dry
    var input: ValidationInput = .controller
    var runs = FH6CommunityReferenceTrialRecord.requiredRoles.map {
        FH6CommunityReferenceTrialRun(
            role: $0,
            completed: false,
            correctTuneConfirmed: false
        )
    }
    var outcome: FH6CommunityReferenceTrialOutcome = .inconclusive {
        didSet {
            if outcome != .referencePreferred {
                candidateDeficiencySymptoms.removeAll()
            }
        }
    }
    var candidateDeficiencySymptoms = Set<TuneFeedback>()
    var sameRouteAndConditionsConfirmed = false
    var sameAssistsAndInputConfirmed = false
    var candidateSettingsAppliedConfirmed = false
    var communityIdentityConfirmed = false
    var finalCandidateRestoredConfirmed = false
    var firstPartyAuthorshipConfirmed = false
    var localStoragePermitted = false
    var deidentifiedOutcomeReusePermitted = false

    var isReady: Bool {
        let factory = FH6CommunityReferenceTrialFactory()
        return factory.isValidSourceCapture(
            kind: kind,
            contentURL: contentURL,
            publisherDisplayName: publisherDisplayName
        )
            && runs.map(\.role)
                == FH6CommunityReferenceTrialRecord.requiredRoles
            && runs.allSatisfy { $0.completed && $0.correctTuneConfirmed }
            && sameRouteAndConditionsConfirmed
            && sameAssistsAndInputConfirmed
            && candidateSettingsAppliedConfirmed
            && communityIdentityConfirmed
            && finalCandidateRestoredConfirmed
            && firstPartyAuthorshipConfirmed
            && localStoragePermitted
            && (outcome == .referencePreferred
                ? !candidateDeficiencySymptoms.isEmpty
                : candidateDeficiencySymptoms.isEmpty)
    }

    func capture(
        candidate: FH6CommunityReferenceCandidateAssociation,
        retrievedAt: Date = .now
    ) -> FH6CommunityReferenceTrialCapture? {
        let factory = FH6CommunityReferenceTrialFactory()
        guard isReady,
              let sourceID = factory.sourceID(
                for: contentURL,
                kind: kind
              ) else {
            return nil
        }
        return FH6CommunityReferenceTrialCapture(
            source: .init(
                kind: kind,
                contentURL: contentURL,
                publisherDisplayName: publisherDisplayName,
                sourceID: sourceID,
                retrievedAt: retrievedAt
            ),
            referenceCandidate: candidate,
            context: .init(
                courseType: courseType,
                surface: surface,
                input: input
            ),
            runs: runs,
            outcome: outcome,
            candidateDeficiencySymptoms: candidateDeficiencySymptoms,
            sameRouteAndConditionsConfirmed:
                sameRouteAndConditionsConfirmed,
            sameAssistsAndInputConfirmed:
                sameAssistsAndInputConfirmed,
            candidateSettingsAppliedConfirmed:
                candidateSettingsAppliedConfirmed,
            communityIdentityConfirmed:
                communityIdentityConfirmed,
            finalCandidateRestoredConfirmed:
                finalCandidateRestoredConfirmed,
            firstPartyAuthorshipConfirmed:
                firstPartyAuthorshipConfirmed,
            localStoragePermitted: localStoragePermitted,
            deidentifiedOutcomeReusePermitted:
                deidentifiedOutcomeReusePermitted
        )
    }
}

enum FH6CommunityReferenceTrialIssue: Error, LocalizedError, Equatable {
    case ineligibleCandidate(FirstPartyValidationError)
    case missingFirstPartyValidation
    case invalidSourceURL
    case invalidSourceMetadata
    case selfDerivative
    case referenceContextMismatch
    case invalidSequence
    case incompleteRun
    case conditionsNotHeldConstant
    case assistsOrInputChanged
    case candidateSettingsNotApplied
    case communityIdentityNotConfirmed
    case candidateNotRestored
    case authorshipNotConfirmed
    case localStorageNotPermitted
    case missingCandidateDeficiency
    case unexpectedCandidateDeficiency
    case reuseNotPermitted
    case invalidStoredRecord
    case exportTooLarge

    var errorDescription: String? {
        switch self {
        case .ineligibleCandidate(let issue): issue.errorDescription
        case .missingFirstPartyValidation:
            "Record a valid first-party test drive for this exact saved tune before starting a community comparison."
        case .invalidSourceURL: "Use a direct canonical HTTPS YouTube or Reddit content URL."
        case .invalidSourceMetadata: "Community-source metadata is missing, unsafe, or outside its bounds."
        case .selfDerivative: "A source cannot identify itself as its own derivative."
        case .referenceContextMismatch: "The community reference must match the exact candidate car, class, and PI."
        case .invalidSequence: "Complete the fixed A1-B1-B2-A2 protocol in order."
        case .incompleteRun: "Confirm completion and the correct tune for every protocol run."
        case .conditionsNotHeldConstant: "Confirm the same route and conditions for every run."
        case .assistsOrInputChanged: "Confirm the same assists and input device for every run."
        case .candidateSettingsNotApplied: "Confirm the generated candidate settings were applied exactly."
        case .communityIdentityNotConfirmed: "Confirm the community reference identity before testing."
        case .candidateNotRestored: "Restore the generated candidate after the final run."
        case .authorshipNotConfirmed: "Confirm this comparative outcome is your own observation."
        case .localStorageNotPermitted: "Allow local storage to keep this trial record."
        case .missingCandidateDeficiency: "Describe at least one candidate deficiency when the reference is preferred."
        case .unexpectedCandidateDeficiency: "Candidate deficiencies are only recorded when the reference is preferred."
        case .reuseNotPermitted: "Allow reuse of the tester-authored deidentified comparative outcome before export."
        case .invalidStoredRecord: "This community-reference trial failed its integrity checks."
        case .exportTooLarge: "The community-reference export exceeds 256 KiB."
        }
    }
}

struct FH6CommunityReferenceCandidateProof: Codable, Equatable, Sendable {
    var gameBuildVersion: String
    var vehicle: FirstPartyValidationRecord.Vehicle
    var shopParts: [FirstPartyValidationRecord.ShopPart]
    var discipline: DrivingDiscipline
    var ruleset: FirstPartyValidationRecord.Ruleset
    var appliedFields: [FirstPartyValidationRecord.AppliedField]
    var tuneRevisionFingerprint: String
    var proofFingerprint: String
}

struct FH6CommunityReferenceTrialRecord: Codable, Equatable, Identifiable, Sendable {
    static let currentSchemaVersion = 1
    static let currentConsentVersion = "fh6-community-outcome-v1"
    static let currentProtocolVersion = "fh6-community-abba-v1"
    static let requiredRoles: [FH6CommunityReferenceTrialRole] = [.a1, .b1, .b2, .a2]
    static let unknowns = [
        "lap-times:not-collected",
        "telemetry:not-collected",
        "community-tune-settings:not-collected"
    ]
    static let privacyExclusions = [
        "community tune settings and share codes",
        "community build parts and inventory",
        "source titles, descriptions, quotes, thumbnails, and engagement",
        "source license, endorsement, and publisher-rights claims",
        "local record, tune, and permission identifiers",
        "generated tune settings, provider provenance, and ruleset details",
        "telemetry, free-form notes, attachments, and device identifiers"
    ]
    static let consentScope = [
        "tester-authored deidentified comparative outcome only",
        "no source tune, settings, or publisher rights granted"
    ]

    var id: UUID { recordID }
    var schemaVersion: Int
    var consentVersion: String
    var protocolVersion: String
    var recordID: UUID
    var submissionID: UUID
    var permissionReceiptID: UUID
    var createdAt: Date
    var game: ForzaGame
    var source: FH6CommunityReferenceSourceMetadata
    var candidateAssociation: FH6CommunityReferenceCandidateAssociation
    var candidateTuneID: UUID
    var candidateProof: FH6CommunityReferenceCandidateProof
    var context: FH6CommunityReferenceTrialContext
    var runs: [FH6CommunityReferenceTrialRun]
    var outcome: FH6CommunityReferenceTrialOutcome
    var candidateDeficiencySymptoms: [TuneFeedback]
    var attestations: FH6CommunityReferenceTrialAttestations
    var consentScope: [String]
    var unknowns: [String]
    var privacyExclusions: [String]
    var contentFingerprint: String

    var canExport: Bool {
        attestations.deidentifiedOutcomeReusePermitted
            && FH6CommunityReferenceTrialFactory().isValid(self)
    }

    func publicExport() throws -> FH6CommunityReferenceTrialExport {
        let factory = FH6CommunityReferenceTrialFactory()
        guard factory.isValid(self) else {
            throw FH6CommunityReferenceTrialIssue.invalidStoredRecord
        }
        guard attestations.deidentifiedOutcomeReusePermitted else {
            throw FH6CommunityReferenceTrialIssue.reuseNotPermitted
        }
        return FH6CommunityReferenceTrialExport(
            schemaVersion: schemaVersion,
            consentVersion: consentVersion,
            protocolVersion: protocolVersion,
            submissionID: submissionID,
            permissionReceiptID: permissionReceiptID,
            createdAt: createdAt,
            game: game,
            source: source,
            candidateAssociation: candidateAssociation,
            context: context,
            runs: runs,
            outcome: outcome,
            candidateDeficiencySymptoms: candidateDeficiencySymptoms,
            attestations: attestations,
            consentScope: consentScope,
            unknowns: unknowns,
            privacyExclusions: privacyExclusions,
            contentFingerprint: contentFingerprint
        )
    }

    func deterministicJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(publicExport())
        guard data.count <= FH6CommunityReferenceTrialFactory.maximumExportBytes else {
            throw FH6CommunityReferenceTrialIssue.exportTooLarge
        }
        return data
    }

    var deterministicJSONString: String? {
        guard let data = try? deterministicJSON() else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

/// Explicit public allow-list. It excludes record IDs, local tune linkage, and candidate proof data.
struct FH6CommunityReferenceTrialExport: Codable, Equatable, Sendable {
    var schemaVersion: Int
    var consentVersion: String
    var protocolVersion: String
    var submissionID: UUID
    var permissionReceiptID: UUID
    var createdAt: Date
    var game: ForzaGame
    var source: FH6CommunityReferenceSourceMetadata
    var candidateAssociation: FH6CommunityReferenceCandidateAssociation
    var context: FH6CommunityReferenceTrialContext
    var runs: [FH6CommunityReferenceTrialRun]
    var outcome: FH6CommunityReferenceTrialOutcome
    var candidateDeficiencySymptoms: [TuneFeedback]
    var attestations: FH6CommunityReferenceTrialAttestations
    var consentScope: [String]
    var unknowns: [String]
    var privacyExclusions: [String]
    var contentFingerprint: String
}
