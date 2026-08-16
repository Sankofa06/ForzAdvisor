import SwiftData
import XCTest
@testable import forzadvisor

extension FirstPartyValidationRecordTests {
    private enum InjectedFailure: Error { case expected }

    @MainActor
    func testLiveFingerprintResolvesGrantThenRevokeThenDelete() async throws {
        let tune = try await eligibleTune()
        var capture = validCapture()
        capture.deidentifiedReusePermitted = false
        let record = try FirstPartyValidationRecordFactory().make(
            tune: tune,
            savedTune: tune,
            isStreaming: false,
            capture: capture,
            createdAt: date
        )
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let coordinator = ValidationEvidenceTransitionCoordinator(
            localStore: .init(fileURL: directory.appendingPathComponent("local")),
            authorizationStore: .init(fileURL: directory.appendingPathComponent("auth"))
        )
        let resolver = ValidationEvidenceLiveRecordResolver()
        try coordinator.saveLocal(record: record, savedTuneID: tune.id)
        let grant = try coordinator.prepareGrant(
            savedTuneID: tune.id,
            fingerprint: record.contentFingerprint
        )
        var legacy = [grant.legacyReusableRecord]
        try coordinator.activateGrant(grant)
        try coordinator.finalizeGrant(grant)

        guard case .reusable(let liveReusable) = try resolver.resolve(
            fingerprint: record.contentFingerprint,
            savedTuneID: tune.id,
            legacyRecords: legacy,
            localStore: coordinator.localStore
        ) else { return XCTFail("Grant must resolve the live reusable record") }

        let revoke = try coordinator.prepareRevoke(
            savedTuneID: tune.id,
            reusableRecord: liveReusable
        )
        legacy.removeAll { $0.recordID == liveReusable.recordID }
        try coordinator.finalizeRevoke(revoke)
        guard case .localOnly = try resolver.resolve(
            fingerprint: record.contentFingerprint,
            savedTuneID: tune.id,
            legacyRecords: legacy,
            localStore: coordinator.localStore
        ) else { return XCTFail("Revoke must resolve the live local record") }

        XCTAssertTrue(try coordinator.localStore.delete(
            savedTuneID: tune.id,
            fingerprint: record.contentFingerprint
        ))
        XCTAssertNil(try resolver.resolve(
            fingerprint: record.contentFingerprint,
            savedTuneID: tune.id,
            legacyRecords: legacy,
            localStore: coordinator.localStore
        ))
    }

    @MainActor
    func testGrantCompensationCleansAuthorizationWhenLocalRestoreFails() async throws {
        let fixture = try await compensationFixture()
        let failing = ValidationEvidenceTransitionCoordinator(
            localStore: .init(fileURL: fixture.localURL) { operation in
                if operation == .upsert { throw InjectedFailure.expected }
            },
            authorizationStore: .init(fileURL: fixture.authURL)
        )

        XCTAssertThrowsError(try failing.compensateGrant(fixture.plan))
        XCTAssertNil(try failing.authorizationStore.authorizationResult(
            for: fixture.plan.fingerprint
        ))
    }

    @MainActor
    func testGrantCompensationReportsCombinedLocalAndAuthorizationFailures() async throws {
        let fixture = try await compensationFixture()
        let failing = ValidationEvidenceTransitionCoordinator(
            localStore: .init(fileURL: fixture.localURL) { operation in
                if operation == .upsert { throw InjectedFailure.expected }
            },
            authorizationStore: .init(fileURL: fixture.authURL) { operation in
                if operation == .remove { throw InjectedFailure.expected }
            }
        )

        XCTAssertThrowsError(try failing.compensateGrant(fixture.plan)) { error in
            let transaction = error as? ValidationEvidenceTransactionError
            XCTAssertEqual(transaction?.recoveryFailures.count, 1)
        }
        XCTAssertNotNil(try ValidationEvidenceAuthorizationStore(
            fileURL: fixture.authURL
        ).authorizationResult(for: fixture.plan.fingerprint))
    }

    @MainActor
    func testFinalizeGrantFailureCanCompensateEveryPersistedPhase() async throws {
        let fixture = try await compensationFixture()
        let failing = ValidationEvidenceTransitionCoordinator(
            localStore: .init(fileURL: fixture.localURL) { operation in
                if operation == .delete { throw InjectedFailure.expected }
            },
            authorizationStore: .init(fileURL: fixture.authURL)
        )
        XCTAssertThrowsError(try failing.finalizeGrant(fixture.plan))

        let recovery = ValidationEvidenceTransitionCoordinator(
            localStore: .init(fileURL: fixture.localURL),
            authorizationStore: .init(fileURL: fixture.authURL)
        )
        try recovery.compensateGrant(fixture.plan)
        XCTAssertNotNil(try recovery.localStore.observation(
            savedTuneID: fixture.plan.savedTuneID,
            fingerprint: fixture.plan.fingerprint
        ))
        XCTAssertNil(try recovery.authorizationStore.authorizationResult(
            for: fixture.plan.fingerprint
        ))
    }

    @MainActor
    func testFinalizeRevokeFailureRollsBackStagedLocalRecord() async throws {
        let tune = try await eligibleTune()
        let reusable = try FirstPartyValidationRecordFactory().make(
            tune: tune, savedTune: tune, isStreaming: false,
            capture: validCapture(), createdAt: date
        )
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let localURL = directory.appendingPathComponent("local")
        let authURL = directory.appendingPathComponent("auth")
        let base = ValidationEvidenceTransitionCoordinator(
            localStore: .init(fileURL: localURL),
            authorizationStore: .init(fileURL: authURL)
        )
        try base.authorizationStore.persist(.reusable(
            observationFingerprint: reusable.contentFingerprint,
            authorizationID: reusable.permissionReceiptID,
            authorizationVersion: "validation-reuse-v1",
            authorizedAt: date
        ))
        let plan = try base.prepareRevoke(
            savedTuneID: tune.id,
            reusableRecord: reusable
        )
        let failing = ValidationEvidenceTransitionCoordinator(
            localStore: .init(fileURL: localURL),
            authorizationStore: .init(fileURL: authURL) { operation in
                if operation == .revoke { throw InjectedFailure.expected }
            }
        )

        XCTAssertThrowsError(try failing.finalizeRevoke(plan))
        try failing.rollbackRevoke(plan)
        XCTAssertNil(try failing.localStore.observation(
            savedTuneID: tune.id,
            fingerprint: reusable.contentFingerprint
        ))
        XCTAssertTrue(try XCTUnwrap(
            base.authorizationStore.authorizationResult(
                for: reusable.contentFingerprint
            )
        ).allowsReuse(of: reusable.contentFingerprint))
    }

    @MainActor
    func testSummaryCountsEveryScopedRecordForSavedTune() async throws {
        let tune = try await eligibleTune()
        let reusable = try FirstPartyValidationRecordFactory().make(
            tune: tune, savedTune: tune, isStreaming: false,
            capture: validCapture(), createdAt: date
        )
        var firstLocalCapture = validCapture()
        firstLocalCapture.deidentifiedReusePermitted = false
        var secondLocalCapture = firstLocalCapture
        secondLocalCapture.runCount += 1
        let locals = try [firstLocalCapture, secondLocalCapture].map {
            try FirstPartyValidationRecordFactory().make(
                tune: tune, savedTune: tune, isStreaming: false,
                capture: $0, createdAt: date
            )
        }
        let container = try ModelContainer(
            for: SavedTune.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let saved = try SavedTune(tune: tune)
        context.insert(saved)
        try saved.appendValidationRecord(reusable)
        try context.save()
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let localStore = ValidationLocalObservationStore(
            fileURL: directory.appendingPathComponent("local")
        )
        let authStore = ValidationEvidenceAuthorizationStore(
            fileURL: directory.appendingPathComponent("auth")
        )
        for local in locals {
            try localStore.upsert(
                ValidationLocalObservation(record: local),
                savedTuneID: saved.id
            )
        }
        try authStore.persist(.reusable(
            observationFingerprint: reusable.contentFingerprint,
            authorizationID: reusable.permissionReceiptID,
            authorizationVersion: "validation-reuse-v1",
            authorizedAt: date
        ))

        let summary = try TuneEvidenceSummaryFactory(
            localStore: localStore,
            authorizationStore: authStore
        ).make(savedTune: saved)
        XCTAssertEqual(summary.localOnlyRecordCount, 2)
        XCTAssertEqual(summary.reusableRecordCount, 1)
        XCTAssertEqual(summary.totalRecordCount, 3)
    }

    @MainActor
    private func compensationFixture() async throws -> (
        plan: ValidationEvidenceTransitionCoordinator.GrantPlan,
        localURL: URL,
        authURL: URL
    ) {
        let tune = try await eligibleTune()
        var capture = validCapture()
        capture.deidentifiedReusePermitted = false
        let record = try FirstPartyValidationRecordFactory().make(
            tune: tune, savedTune: tune, isStreaming: false,
            capture: capture, createdAt: date
        )
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let localURL = directory.appendingPathComponent("local")
        let authURL = directory.appendingPathComponent("auth")
        let coordinator = ValidationEvidenceTransitionCoordinator(
            localStore: .init(fileURL: localURL),
            authorizationStore: .init(fileURL: authURL)
        )
        try coordinator.saveLocal(record: record, savedTuneID: tune.id)
        let plan = try coordinator.prepareGrant(
            savedTuneID: tune.id,
            fingerprint: record.contentFingerprint
        )
        try coordinator.activateGrant(plan)
        return (plan, localURL, authURL)
    }
}
