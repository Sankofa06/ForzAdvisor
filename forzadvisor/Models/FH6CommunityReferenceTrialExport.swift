import Foundation

/// Public allow-list excluding record IDs, local tune linkage, and proof data.
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
