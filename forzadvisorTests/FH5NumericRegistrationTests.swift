import SwiftData
import XCTest
@testable import forzadvisor

final class FH5NumericRegistrationTests: FH5ResearchTestCase {
    func testNumericRulesetRegistrationBindsRightsThresholdAndCandidate() throws {
        let registration = try makeExperimentalRegistration()
        let registry = try FH5TrustedNumericRulesetRegistry(
            validating: [registration]
        )
        let threshold = registration.outcomeThreshold

        XCTAssertTrue(registration.isValid)
        XCTAssertFalse(registry.isEmpty)
        XCTAssertEqual(
            registry.registration(for: registration.algorithmID),
            registration
        )
        XCTAssertEqual(threshold.minimumUniqueRecords, 10)
        XCTAssertEqual(threshold.minimumVariantPreferred, 8)
        XCTAssertEqual(threshold.maximumBaselinePreferred, 0)
        XCTAssertEqual(threshold.maximumNonDecisive, 2)
        XCTAssertEqual(threshold.minimumDistinctUTCDays, 2)
        XCTAssertTrue(threshold.requiresDeidentifiedReusePermission)
        XCTAssertEqual(
            threshold.protocolVersion,
            FH5ControlledExperimentRecord.currentProtocolVersion
        )
        let sourceFingerprint = try XCTUnwrap(
            registration.sourceManifestFingerprint
        )
        XCTAssertEqual(
            sourceFingerprint,
            FH5NumericRulesetSourceManifest.fingerprint(
                for: Array(registration.sourceManifests.reversed())
            )
        )
        let changedSource = FH5NumericRulesetSourceManifest(
            sourceID: registration.sourceManifests[0].sourceID,
            sourceVersion: registration.sourceManifests[0].sourceVersion,
            owner: "Different rights owner",
            rightsBasis: registration.sourceManifests[0].rightsBasis,
            rightsEvidenceID:
                registration.sourceManifests[0].rightsEvidenceID,
            usagePermission:
                registration.sourceManifests[0].usagePermission
        )
        XCTAssertNotEqual(
            sourceFingerprint,
            FH5NumericRulesetSourceManifest.fingerprint(for: [changedSource])
        )

        let binding = FH5RulesetCandidateBinding(
            algorithmID: registration.algorithmID,
            rulesetReference: registration.reference,
            sourceManifestFingerprint: sourceFingerprint,
            outcomePolicyVersion: threshold.policyVersion,
            generatedCandidateFingerprint: String(repeating: "a", count: 64)
        )
        XCTAssertTrue(binding.isValid(for: registration))
        XCTAssertFalse(FH5RulesetCandidateBinding(
            algorithmID: binding.algorithmID,
            rulesetReference: binding.rulesetReference,
            sourceManifestFingerprint: binding.sourceManifestFingerprint,
            outcomePolicyVersion: binding.outcomePolicyVersion,
            generatedCandidateFingerprint: String(repeating: "A", count: 64)
        ).isValid(for: registration))
        XCTAssertFalse(FH5RulesetCandidateBinding(
            algorithmID: binding.algorithmID,
            rulesetReference: try XCTUnwrap(TuneRulesetReference(
                descriptor: TuneRulesetDescriptor(
                    id: binding.algorithmID.rawValue,
                    game: .fh5,
                    schemaVersion: 1,
                    algorithmVersion: "2",
                    knowledgeRevision: binding.sourceManifestFingerprint,
                    validationStatus: .experimental,
                    provenanceIDs: registration.reference.provenanceIDs
                )
            )),
            sourceManifestFingerprint: binding.sourceManifestFingerprint,
            outcomePolicyVersion: binding.outcomePolicyVersion,
            generatedCandidateFingerprint:
                binding.generatedCandidateFingerprint
        ).isValid(for: registration))
        XCTAssertFalse(FH5RulesetCandidateBinding(
            algorithmID: binding.algorithmID,
            rulesetReference: binding.rulesetReference,
            sourceManifestFingerprint: String(repeating: "b", count: 64),
            outcomePolicyVersion: binding.outcomePolicyVersion,
            generatedCandidateFingerprint:
                binding.generatedCandidateFingerprint
        ).isValid(for: registration))
        XCTAssertFalse(FH5RulesetCandidateBinding(
            algorithmID: binding.algorithmID,
            rulesetReference: binding.rulesetReference,
            sourceManifestFingerprint: binding.sourceManifestFingerprint,
            outcomePolicyVersion: "fh5-controlled-outcome-experimental-v2",
            generatedCandidateFingerprint:
                binding.generatedCandidateFingerprint
        ).isValid(for: registration))
        XCTAssertThrowsError(
            try JSONDecoder().decode(
                FH5ExperimentalAlgorithmID.self,
                from: Data("\"fh5.other-algorithm\"".utf8)
            )
        )
    }
    func testNumericRulesetRegistrationRejectsSelfAssertedOrWeakenedContracts() throws {
        let valid = try makeExperimentalRegistration()
        let unknownPermission = FH5NumericRulesetSourceManifest(
            sourceID: "first-party.clean-room",
            sourceVersion: "1",
            owner: "ForzAdvisor",
            rightsBasis: .firstPartyCleanRoom,
            rightsEvidenceID: "internal.clean-room-record",
            usagePermission: .unknown
        )
        let unknownRights = try makeExperimentalRegistration(
            sourceManifests: [unknownPermission]
        )
        XCTAssertTrue(unknownRights.validationIssues.contains(
            .invalidSourceManifest(unknownPermission.sourceID)
        ))

        let validatedClaim = FH5NumericRulesetRegistration(
            algorithmID: valid.algorithmID,
            reference: try XCTUnwrap(TuneRulesetReference(
                descriptor: TuneRulesetDescriptor(
                    id: valid.reference.id,
                    game: .fh5,
                    schemaVersion: valid.reference.schemaVersion,
                    algorithmVersion: valid.reference.algorithmVersion,
                    knowledgeRevision: valid.reference.knowledgeRevision,
                    validationStatus: .validated,
                    provenanceIDs: valid.reference.provenanceIDs
                )
            )),
            sourceManifests: valid.sourceManifests,
            outcomeThreshold: valid.outcomeThreshold
        )
        XCTAssertTrue(validatedClaim.validationIssues.contains(
            .nonExperimentalStatus
        ))

        let wrongGame = FH5NumericRulesetRegistration(
            algorithmID: valid.algorithmID,
            reference: try XCTUnwrap(TuneRulesetReference(
                descriptor: TuneRulesetDescriptor(
                    id: valid.reference.id,
                    game: .fh6,
                    schemaVersion: valid.reference.schemaVersion,
                    algorithmVersion: valid.reference.algorithmVersion,
                    knowledgeRevision: valid.reference.knowledgeRevision,
                    validationStatus: .experimental,
                    provenanceIDs: valid.reference.provenanceIDs
                )
            )),
            sourceManifests: valid.sourceManifests,
            outcomeThreshold: valid.outcomeThreshold
        )
        XCTAssertTrue(wrongGame.validationIssues.contains(.wrongGame))

        let provenanceMismatch = FH5NumericRulesetRegistration(
            algorithmID: valid.algorithmID,
            reference: try XCTUnwrap(TuneRulesetReference(
                descriptor: TuneRulesetDescriptor(
                    id: valid.reference.id,
                    game: .fh5,
                    schemaVersion: valid.reference.schemaVersion,
                    algorithmVersion: valid.reference.algorithmVersion,
                    knowledgeRevision: valid.reference.knowledgeRevision,
                    validationStatus: .experimental,
                    provenanceIDs: ["different.source"]
                )
            )),
            sourceManifests: valid.sourceManifests,
            outcomeThreshold: valid.outcomeThreshold
        )
        XCTAssertTrue(provenanceMismatch.validationIssues.contains(
            .provenanceMismatch
        ))

        let weakenedThreshold = FH5ControlledOutcomeThreshold(
            policyVersion: "fh5-controlled-outcome-experimental-v1",
            protocolVersion:
                FH5ControlledExperimentRecord.currentProtocolVersion,
            minimumUniqueRecords: 2,
            minimumVariantPreferred: 1,
            maximumBaselinePreferred: 1,
            maximumNonDecisive: 1,
            minimumDistinctUTCDays: 1,
            requiresDeidentifiedReusePermission: true
        )
        let weakened = FH5NumericRulesetRegistration(
            algorithmID: valid.algorithmID,
            reference: valid.reference,
            sourceManifests: valid.sourceManifests,
            outcomeThreshold: weakenedThreshold
        )
        XCTAssertTrue(weakened.validationIssues.contains(
            .unsupportedOutcomeThreshold
        ))
        XCTAssertThrowsError(
            try FH5TrustedNumericRulesetRegistry(
                validating: [weakened]
            )
        ) {
            XCTAssertEqual(
                $0 as? FH5NumericRulesetRegistryIssue,
                .invalidRegistration(weakened.algorithmID)
            )
        }
        XCTAssertThrowsError(
            try FH5TrustedNumericRulesetRegistry(
                validating: [valid, valid]
            )
        ) {
            XCTAssertEqual(
                $0 as? FH5NumericRulesetRegistryIssue,
                .duplicateAlgorithmID(valid.algorithmID)
            )
        }
    }
}
