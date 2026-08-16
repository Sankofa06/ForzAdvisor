import Foundation

struct FH6CommunityReferenceTrialDraft: Equatable, Sendable {
    var kind: FH6CommunityReferenceKind?
    var contentURL = ""
    var publisherDisplayName = ""
    var courseType: ValidationCourseType?
    var surface: ValidationSurface?
    var input: ValidationInput?
    var runs = FH6CommunityReferenceTrialRecord.requiredRoles.map {
        FH6CommunityReferenceTrialRun(
            role: $0,
            completed: false,
            correctTuneConfirmed: false
        )
    }
    var outcome: FH6CommunityReferenceTrialOutcome? {
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
        guard let kind, courseType != nil, surface != nil, input != nil,
              let outcome else { return false }
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
        guard isReady, let kind, let courseType, let surface, let input,
              let outcome,
              let sourceID = factory.sourceID(for: contentURL, kind: kind)
        else { return nil }
        return FH6CommunityReferenceTrialCapture(
            source: .init(
                kind: kind, contentURL: contentURL,
                publisherDisplayName: publisherDisplayName,
                sourceID: sourceID, retrievedAt: retrievedAt
            ),
            referenceCandidate: candidate,
            context: .init(
                courseType: courseType, surface: surface, input: input
            ),
            runs: runs,
            outcome: outcome,
            candidateDeficiencySymptoms: candidateDeficiencySymptoms,
            sameRouteAndConditionsConfirmed: sameRouteAndConditionsConfirmed,
            sameAssistsAndInputConfirmed: sameAssistsAndInputConfirmed,
            candidateSettingsAppliedConfirmed: candidateSettingsAppliedConfirmed,
            communityIdentityConfirmed: communityIdentityConfirmed,
            finalCandidateRestoredConfirmed: finalCandidateRestoredConfirmed,
            firstPartyAuthorshipConfirmed: firstPartyAuthorshipConfirmed,
            localStoragePermitted: localStoragePermitted,
            deidentifiedOutcomeReusePermitted: deidentifiedOutcomeReusePermitted
        )
    }
}
