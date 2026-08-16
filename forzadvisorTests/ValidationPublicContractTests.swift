import Foundation
import XCTest
@testable import forzadvisor

final class ValidationPublicContractTests: XCTestCase {
    private let setupID = UUID(
        uuidString: "11111111-1111-1111-1111-111111111111"
    )!
    private let draftID = UUID(
        uuidString: "22222222-2222-2222-2222-222222222222"
    )!
    private let authorizationID = UUID(
        uuidString: "33333333-3333-3333-3333-333333333333"
    )!
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    func testEvidenceSummarySeparatesLocalAndReusableCounts() {
        let summary = TuneEvidenceSummary(
            savedTuneID: setupID,
            localOnlyRecordCount: 3,
            reusableRecordCount: 2,
            reviewedRecordCount: 1
        )

        XCTAssertEqual(summary.totalRecordCount, 6)
        XCTAssertEqual(summary.localRecordCount, 6)
        XCTAssertEqual(summary.exportableRecordCount, 2)
        XCTAssertTrue(summary.isValid)
        XCTAssertFalse(
            TuneEvidenceSummary(
                savedTuneID: setupID,
                localOnlyRecordCount: -1,
                reusableRecordCount: 0,
                reviewedRecordCount: 0
            ).isValid
        )
    }

    func testLocalOnlyAuthorizationEnvelopeFailsClosedForExport() {
        let envelope = ValidationEvidenceAuthorizationEnvelope.localOnly(
            observationFingerprint: "observation-v1"
        )

        XCTAssertTrue(envelope.isValid)
        XCTAssertFalse(envelope.allowsReuse(of: "observation-v1"))
        XCTAssertFalse(envelope.allowsReuse(of: "different"))
    }

    func testReusableAuthorizationMustBindExactFingerprint() {
        let envelope = ValidationEvidenceAuthorizationEnvelope.reusable(
            observationFingerprint: "observation-v1",
            authorizationID: authorizationID,
            authorizationVersion: "validation-reuse-v1",
            authorizedAt: now
        )

        XCTAssertTrue(envelope.isValid)
        XCTAssertTrue(envelope.allowsReuse(of: "observation-v1"))
        XCTAssertFalse(envelope.allowsReuse(of: "different"))
    }

    func testReusableAuthorizationWithoutReceiptFailsClosed() {
        let envelope = ValidationEvidenceAuthorizationEnvelope(
            schemaVersion: 1,
            observationFingerprint: "observation-v1",
            scope: .reusable,
            authorizationID: nil,
            authorizationVersion: nil,
            authorizedAt: nil
        )

        XCTAssertFalse(envelope.isValid)
        XCTAssertFalse(envelope.allowsReuse(of: "observation-v1"))
    }

    func testRevokedAuthorizationNoLongerAllowsReuse() {
        let envelope = ValidationEvidenceAuthorizationEnvelope.reusable(
            observationFingerprint: "observation-v1",
            authorizationID: authorizationID,
            authorizationVersion: "validation-reuse-v1",
            authorizedAt: now
        ).revoking(at: now.addingTimeInterval(1))

        XCTAssertTrue(envelope.isValid)
        XCTAssertFalse(envelope.allowsReuse(of: "observation-v1"))
    }

    func testMissionSummariesGroupBySetupWithOneRecommendation() {
        let missions = [
            mission(.verifyTireRanges),
            mission(.recordTestDrive),
            mission(.verifyUpgradeParts)
        ]

        let groups = GroupedValidationMissionSummary.make(
            missions: missions,
            evidenceBySavedTuneID: [
                setupID: TuneEvidenceSummary(
                    savedTuneID: setupID,
                    localOnlyRecordCount: 1,
                    reusableRecordCount: 0,
                    reviewedRecordCount: 0
                )
            ]
        )

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].savedTuneID, setupID)
        XCTAssertEqual(groups[0].missions.count, 3)
        XCTAssertEqual(groups[0].recommendedMission?.kind, .verifyTireRanges)
        XCTAssertEqual(
            groups[0].missions.filter(\.isRecommended).count,
            1
        )
    }

    func testV2DraftRestoresOnlyForExactBindings() throws {
        let document = try decode(fixtureV2)
        let expected = ValidationDraftRestoreContext(
            kind: .firstPartyTestDrive,
            savedTuneID: setupID,
            tuneRevisionFingerprint: "revision-v2",
            gameBuildVersion: "build-42",
            captureRevision: "capture-v2"
        )

        XCTAssertEqual(
            ValidationDraftRestorePolicy().disposition(
                for: document,
                expected: expected
            ),
            .resume
        )

        var stale = expected
        stale.tuneRevisionFingerprint = "new-revision"
        XCTAssertEqual(
            ValidationDraftRestorePolicy().disposition(
                for: document,
                expected: stale
            ),
            .discardStale
        )
    }

    func testV1DraftDecodesButRequiresMigrationInsteadOfResume() throws {
        let document = try decode(fixtureV1)
        let expected = ValidationDraftRestoreContext(
            kind: .firstPartyTestDrive,
            savedTuneID: setupID,
            tuneRevisionFingerprint: "revision-v1",
            gameBuildVersion: "build-41",
            captureRevision: "capture-v2"
        )

        XCTAssertEqual(document.schemaVersion, 1)
        XCTAssertEqual(
            ValidationDraftRestorePolicy().disposition(
                for: document,
                expected: expected
            ),
            .requiresMigration
        )
    }

    func testUnknownDraftSchemaFailsToDecode() {
        XCTAssertThrowsError(try decode(fixtureV3))
    }

    func testDraftRejectsPermissionOrAttestationFields() {
        let permissionDraft = fixtureV2.replacingOccurrences(
            of: "\"runCount\": \"4\"",
            with: "\"reusePermitted\": \"true\""
        )
        let attestationDraft = fixtureV2.replacingOccurrences(
            of: "\"runCount\": \"4\"",
            with: "\"authorshipAttestation\": \"true\""
        )

        XCTAssertThrowsError(try decode(permissionDraft))
        XCTAssertThrowsError(try decode(attestationDraft))
    }

    func testNewDraftContractRequiresCurrentCaptureBinding() {
        let lifecycle = ValidationDraftLifecycle(
            createdAt: now,
            updatedAt: now
        )
        let validIdentity = ValidationDraftIdentity(
            draftID: draftID,
            kind: .firstPartyTestDrive,
            savedTuneID: setupID,
            tuneRevisionFingerprint: "revision-v2",
            gameBuildVersion: "build-42",
            captureRevision: "capture-v2"
        )

        XCTAssertNoThrow(
            try ValidationDraftDocument(
                identity: validIdentity,
                lifecycle: lifecycle,
                factualFields: ["runCount": "4"]
            )
        )
        XCTAssertThrowsError(
            try ValidationDraftDocument(
                identity: ValidationDraftIdentity(
                    draftID: draftID,
                    kind: .firstPartyTestDrive,
                    savedTuneID: setupID,
                    tuneRevisionFingerprint: "revision-v2",
                    gameBuildVersion: "build-42",
                    captureRevision: nil
                ),
                lifecycle: lifecycle,
                factualFields: ["runCount": "4"]
            )
        )
    }

    private func mission(
        _ kind: BetaValidationMissionKind
    ) -> BetaValidationMission {
        BetaValidationMission(
            kind: kind,
            game: .fh6,
            savedTuneID: setupID,
            carDisplayName: "1997 Mazda Miata",
            disciplineTitle: "Road"
        )
    }

    private func decode(_ json: String) throws -> ValidationDraftDocument {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(
            ValidationDraftDocument.self,
            from: Data(json.utf8)
        )
    }

    private var fixtureV1: String {
        """
        {
          "schemaVersion": 1,
          "draftID": "\(draftID.uuidString)",
          "kind": "firstPartyTestDrive",
          "savedTuneID": "\(setupID.uuidString)",
          "tuneRevisionFingerprint": "revision-v1",
          "gameBuildVersion": "build-41",
          "createdAt": "2023-11-14T22:13:20Z",
          "updatedAt": "2023-11-14T22:13:20Z",
          "factualFields": {"runCount": "3"}
        }
        """
    }

    private var fixtureV2: String {
        """
        {
          "schemaVersion": 2,
          "draftID": "\(draftID.uuidString)",
          "kind": "firstPartyTestDrive",
          "savedTuneID": "\(setupID.uuidString)",
          "tuneRevisionFingerprint": "revision-v2",
          "gameBuildVersion": "build-42",
          "captureRevision": "capture-v2",
          "createdAt": "2023-11-14T22:13:20Z",
          "updatedAt": "2023-11-14T22:13:20Z",
          "factualFields": {"runCount": "4"}
        }
        """
    }

    private var fixtureV3: String {
        fixtureV2.replacingOccurrences(
            of: "\"schemaVersion\": 2",
            with: "\"schemaVersion\": 3"
        )
    }
}
