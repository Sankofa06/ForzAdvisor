import XCTest
@testable import forzadvisor

extension FirstPartyValidationRecordTests {
    private enum OrphanInjectedFailure: Error { case expected }

    @MainActor
    func testOrphanStagingFailureStillCleansThenRestoresAuthorization() async throws {
        let fixture = try await orphanFixture(localFailsOnUpsert: true)
        var legacyRemovalCalled = false

        XCTAssertThrowsError(try fixture.reconciler.reconcile(
            records: [fixture.record],
            savedTuneID: fixture.savedTuneID,
            removeLegacyRecord: { _ in legacyRemovalCalled = true },
            saveLegacyChanges: {},
            rollbackLegacyChanges: {}
        ))

        XCTAssertFalse(legacyRemovalCalled)
        XCTAssertEqual(
            try fixture.authorizationStore.authorizationResult(
                for: fixture.record.contentFingerprint
            ),
            fixture.priorAuthorization
        )
    }

    @MainActor
    func testOrphanLegacySaveFailureRollsBackAllThreeStores() async throws {
        let fixture = try await orphanFixture(localFailsOnUpsert: false)
        var legacyRemoved = false
        var legacyRolledBack = false

        XCTAssertThrowsError(try fixture.reconciler.reconcile(
            records: [fixture.record],
            savedTuneID: fixture.savedTuneID,
            removeLegacyRecord: { _ in legacyRemoved = true },
            saveLegacyChanges: { throw OrphanInjectedFailure.expected },
            rollbackLegacyChanges: {
                legacyRemoved = false
                legacyRolledBack = true
            }
        ))

        XCTAssertTrue(legacyRolledBack)
        XCTAssertFalse(legacyRemoved)
        XCTAssertNil(try fixture.localStore.observation(
            savedTuneID: fixture.savedTuneID,
            fingerprint: fixture.record.contentFingerprint
        ))
        XCTAssertEqual(
            try fixture.authorizationStore.authorizationResult(
                for: fixture.record.contentFingerprint
            ),
            fixture.priorAuthorization
        )
    }

    @MainActor
    private func orphanFixture(localFailsOnUpsert: Bool) async throws -> (
        reconciler: ValidationEvidenceOrphanReconciler,
        record: FirstPartyValidationRecord,
        savedTuneID: UUID,
        localStore: ValidationLocalObservationStore,
        authorizationStore: ValidationEvidenceAuthorizationStore,
        priorAuthorization: ValidationEvidenceAuthorizationEnvelope
    ) {
        let tune = try await eligibleTune()
        let record = try FirstPartyValidationRecordFactory().make(
            tune: tune, savedTune: tune, isStreaming: false,
            capture: validCapture(), createdAt: date
        )
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let localURL = directory.appendingPathComponent("local")
        let authURL = directory.appendingPathComponent("auth")
        let authorizationStore = ValidationEvidenceAuthorizationStore(
            fileURL: authURL
        )
        let prior = ValidationEvidenceAuthorizationEnvelope.reusable(
            observationFingerprint: record.contentFingerprint,
            authorizationID: UUID(),
            authorizationVersion: "validation-reuse-v1",
            authorizedAt: date
        )
        try authorizationStore.persist(prior)
        let localStore = ValidationLocalObservationStore(
            fileURL: localURL,
            fault: { operation in
                if localFailsOnUpsert && operation == .upsert {
                    throw OrphanInjectedFailure.expected
                }
            }
        )
        let coordinator = ValidationEvidenceTransitionCoordinator(
            localStore: localStore,
            authorizationStore: authorizationStore
        )
        return (
            ValidationEvidenceOrphanReconciler(coordinator: coordinator),
            record,
            tune.id,
            localStore,
            authorizationStore,
            prior
        )
    }
}
