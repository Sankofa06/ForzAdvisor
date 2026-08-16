import XCTest
@testable import forzadvisor

extension FirstPartyValidationRecordTests {
    private func transitionFixture() -> (
        coordinator: ValidationEvidenceTransitionCoordinator,
        localURL: URL,
        authURL: URL
    ) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let localURL = directory.appendingPathComponent("local.json")
        let authURL = directory.appendingPathComponent("auth.json")
        return (
            ValidationEvidenceTransitionCoordinator(
                localStore: .init(fileURL: localURL),
                authorizationStore: .init(fileURL: authURL)
            ),
            localURL,
            authURL
        )
    }

    func testLocalOnlyRecordNeverEntersLegacyBlob() async throws {
        let tune = try await eligibleTune()
        var capture = validCapture()
        capture.deidentifiedReusePermitted = false
        let local = try FirstPartyValidationRecordFactory().make(
            tune: tune,
            savedTune: tune,
            isStreaming: false,
            capture: capture,
            createdAt: date
        )

        XCTAssertThrowsError(
            try LegacyValidationBlobCompatibility()
                .encodeReusableRecords([local])
        )
        XCTAssertFalse(FirstPartyValidationRecordFactory().isValid(local))
        XCTAssertTrue(
            FirstPartyValidationRecordFactory().isValidLocalObservation(local)
        )
    }

    func testLegacyBlobContainsOnlyReusableCompatibleRecord() async throws {
        let tune = try await eligibleTune()
        let reusable = try FirstPartyValidationRecordFactory().make(
            tune: tune,
            savedTune: tune,
            isStreaming: false,
            capture: validCapture(),
            createdAt: date
        )
        let policy = LegacyValidationBlobCompatibility()
        let data = try XCTUnwrap(try policy.encodeReusableRecords([reusable]))
        let oldRecords = try XCTUnwrap(policy.decodeAsOlderBinary(data))

        XCTAssertEqual(oldRecords, [reusable])
        XCTAssertTrue(oldRecords.allSatisfy(\.deidentifiedReusePermitted))
        XCTAssertThrowsError(
            try FirstPartyValidationExportGate().deterministicJSON(
                for: reusable,
                authorization: nil
            )
        )
    }

    func testRevokedRecordIsAbsentFromOldExportPath() async throws {
        let tune = try await eligibleTune()
        let reusable = try FirstPartyValidationRecordFactory().make(
            tune: tune,
            savedTune: tune,
            isStreaming: false,
            capture: validCapture(),
            createdAt: date
        )
        let remaining = [reusable].filter {
            $0.recordID != reusable.recordID
        }
        let policy = LegacyValidationBlobCompatibility()
        let data = try policy.encodeReusableRecords(remaining)

        XCTAssertNil(data)
        XCTAssertEqual(policy.decodeAsOlderBinary(data), [])
    }

    func testSidecarExcludesAuthorizationAndAttestationFields() async throws {
        let tune = try await eligibleTune()
        var capture = validCapture()
        capture.deidentifiedReusePermitted = false
        let record = try FirstPartyValidationRecordFactory().make(
            tune: tune, savedTune: tune, isStreaming: false,
            capture: capture, createdAt: date
        )
        let fixture = transitionFixture()
        try fixture.coordinator.saveLocal(record: record, savedTuneID: tune.id)

        let json = try String(
            decoding: Data(contentsOf: fixture.localURL),
            as: UTF8.self
        ).lowercased()
        for prohibited in [
            "consent", "author", "attest", "permissionreceipt",
            "deidentifiedreuse", "publicexport"
        ] {
            XCTAssertFalse(json.contains(prohibited), "Persisted \(prohibited)")
        }
    }

    func testGrantProducesLegacyValidBlobThenRemovesSidecar() async throws {
        let tune = try await eligibleTune()
        var capture = validCapture()
        capture.deidentifiedReusePermitted = false
        let local = try FirstPartyValidationRecordFactory().make(
            tune: tune, savedTune: tune, isStreaming: false,
            capture: capture, createdAt: date
        )
        let fixture = transitionFixture()
        try fixture.coordinator.saveLocal(record: local, savedTuneID: tune.id)
        let plan = try fixture.coordinator.prepareGrant(
            savedTuneID: tune.id,
            fingerprint: local.contentFingerprint
        )
        XCTAssertNil(
            fixture.coordinator.authorizationStore.authorization(
                for: local.contentFingerprint
            ),
            "Preparing a transaction must not persist authorization"
        )
        let data = try LegacyValidationBlobCompatibility()
            .encodeReusableRecords([plan.legacyReusableRecord])
        XCTAssertNotNil(
            LegacyValidationBlobCompatibility().decodeAsOlderBinary(data)
        )

        try fixture.coordinator.activateGrant(plan)
        try fixture.coordinator.finalizeGrant(plan)
        XCTAssertNil(try fixture.coordinator.localStore.observation(
            savedTuneID: tune.id,
            fingerprint: local.contentFingerprint
        ))
    }

    func testLocalSidecarAdvancesLocalEvidenceChain() async throws {
        let tune = try await eligibleTune()
        var capture = validCapture()
        capture.deidentifiedReusePermitted = false
        let local = try FirstPartyValidationRecordFactory().make(
            tune: tune, savedTune: tune, isStreaming: false,
            capture: capture, createdAt: date
        )
        let observation = try ValidationLocalObservation(record: local)
        let chain = FH6AccuracyEvidenceChainPolicy().assess(
            tune: tune,
            savedTune: tune,
            isStreaming: false,
            validationRecords: [],
            localValidationObservations: [observation],
            communityComparisonRecords: []
        )

        XCTAssertEqual(chain.matchingValidationCount, 1)
        XCTAssertTrue(chain.permitsCommunityComparison)
        XCTAssertThrowsError(try local.deterministicJSON())
    }

    func testFailedGrantActivationRetainsLocalSidecar() async throws {
        let tune = try await eligibleTune()
        var capture = validCapture()
        capture.deidentifiedReusePermitted = false
        let local = try FirstPartyValidationRecordFactory().make(
            tune: tune, savedTune: tune, isStreaming: false,
            capture: capture, createdAt: date
        )
        let fixture = transitionFixture()
        try fixture.coordinator.saveLocal(record: local, savedTuneID: tune.id)
        let plan = try fixture.coordinator.prepareGrant(
            savedTuneID: tune.id,
            fingerprint: local.contentFingerprint
        )
        try FileManager.default.createDirectory(
            at: fixture.authURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("corrupt".utf8).write(to: fixture.authURL)

        XCTAssertThrowsError(try fixture.coordinator.activateGrant(plan))
        XCTAssertNotNil(try fixture.coordinator.localStore.observation(
            savedTuneID: tune.id,
            fingerprint: local.contentFingerprint
        ))
    }

    func testRevokeStagesLocalThenOldPathMustClearBeforeFinalize() async throws {
        let tune = try await eligibleTune()
        let reusable = try FirstPartyValidationRecordFactory().make(
            tune: tune, savedTune: tune, isStreaming: false,
            capture: validCapture(), createdAt: date
        )
        let fixture = transitionFixture()
        _ = try fixture.coordinator.authorizationStore.grant(
            fingerprint: reusable.contentFingerprint,
            version: "validation-reuse-v1"
        )
        let plan = try fixture.coordinator.prepareRevoke(
            savedTuneID: tune.id,
            reusableRecord: reusable
        )
        XCTAssertNotNil(try fixture.coordinator.localStore.observation(
            savedTuneID: tune.id,
            fingerprint: reusable.contentFingerprint
        ))

        let clearedBlob = try LegacyValidationBlobCompatibility()
            .encodeReusableRecords([])
        XCTAssertNil(clearedBlob)
        try fixture.coordinator.finalizeRevoke(plan)
        XCTAssertFalse(
            fixture.coordinator.authorizationStore
                .authorization(for: reusable.contentFingerprint)?
                .allowsReuse(of: reusable.contentFingerprint) ?? false
        )
    }
}
