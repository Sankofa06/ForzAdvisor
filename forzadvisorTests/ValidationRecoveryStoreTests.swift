import Foundation
import XCTest
@testable import forzadvisor

final class ValidationRecoveryStoreTests: XCTestCase {
    private var directory: URL!
    private let savedTuneID = UUID(
        uuidString: "11111111-1111-1111-1111-111111111111"
    )!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testDraftRoundTripContainsOnlyFactualFields() throws {
        let store = ValidationDraftStore(directory: directory)
        let context = restoreContext()
        let document = try ValidationDraftDocument(
            identity: .init(
                draftID: UUID(), kind: context.kind,
                savedTuneID: context.savedTuneID,
                tuneRevisionFingerprint: context.tuneRevisionFingerprint,
                gameBuildVersion: context.gameBuildVersion,
                captureRevision: context.captureRevision
            ),
            lifecycle: .init(createdAt: .now, updatedAt: .now),
            factualFields: ["courseType": "sprint", "runCount": "3"]
        )

        try store.save(document)
        let restored = try XCTUnwrap(store.load(expected: context))

        XCTAssertEqual(restored.factualFields, document.factualFields)
        let bytes = try Data(contentsOf: try XCTUnwrap(
            FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            ).first
        ))
        let text = String(decoding: bytes, as: UTF8.self).lowercased()
        XCTAssertFalse(text.contains("consent"))
        XCTAssertFalse(text.contains("author"))
        XCTAssertFalse(text.contains("attest"))
        XCTAssertFalse(text.contains("share"))
    }

    func testStaleDraftIsRejectedAndRemoved() throws {
        let store = ValidationDraftStore(directory: directory)
        let context = restoreContext()
        let document = try makeDocument(context: context)
        try store.save(document)

        var stale = context
        stale.tuneRevisionFingerprint = "different"
        XCTAssertThrowsError(try store.load(expected: stale)) {
            XCTAssertEqual($0 as? ValidationDraftStoreError, .stale)
        }
        XCTAssertTrue(
            try FileManager.default.contentsOfDirectory(atPath: directory.path)
                .isEmpty
        )
    }

    func testCorruptDraftIsQuarantined() throws {
        let store = ValidationDraftStore(directory: directory)
        let context = restoreContext()
        try Data("not-json".utf8).write(
            to: directory.appendingPathComponent(
                "firstPartyTestDrive-\(savedTuneID.uuidString.lowercased()).json"
            )
        )

        XCTAssertThrowsError(try store.load(expected: context)) {
            XCTAssertEqual($0 as? ValidationDraftStoreError, .corrupt)
        }
        XCTAssertEqual(
            try FileManager.default.contentsOfDirectory(atPath: directory.path),
            ["firstPartyTestDrive-\(savedTuneID.uuidString.lowercased()).json.corrupt"]
        )
    }

    func testLegacyDraftMigratesOnlyWhenExplicitlyRequested() throws {
        let store = ValidationDraftStore(directory: directory)
        let context = restoreContext()
        let target = directory.appendingPathComponent(
            "firstPartyTestDrive-\(savedTuneID.uuidString.lowercased()).json"
        )
        let legacy = """
        {
          "schemaVersion": 1,
          "draftID": "22222222-2222-2222-2222-222222222222",
          "kind": "firstPartyTestDrive",
          "savedTuneID": "\(savedTuneID.uuidString)",
          "tuneRevisionFingerprint": "revision-v2",
          "gameBuildVersion": "build-42",
          "createdAt": "2023-11-14T22:13:20Z",
          "updatedAt": "2023-11-14T22:13:20Z",
          "factualFields": {"runCount": "3"}
        }
        """
        try Data(legacy.utf8).write(to: target)

        XCTAssertThrowsError(try store.load(expected: context)) {
            XCTAssertEqual($0 as? ValidationDraftStoreError, .migrationRequired)
        }
        let migrated = try store.migrateLegacy(expected: context)
        XCTAssertEqual(migrated.schemaVersion, 2)
        XCTAssertEqual(migrated.identity.captureRevision, "capture-v2")
        XCTAssertEqual(migrated.factualFields, ["runCount": "3"])
        XCTAssertEqual(try store.load(expected: context), migrated)
    }

    func testAuthorizationGrantBindsAndRevokeBlocksExactFingerprint() throws {
        let file = directory.appendingPathComponent("authorizations.json")
        let store = ValidationEvidenceAuthorizationStore(fileURL: file)
        let granted = try store.grant(
            fingerprint: "observation-v1",
            version: "validation-reuse-v1",
            at: Date(timeIntervalSince1970: 100),
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        )

        XCTAssertTrue(granted.allowsReuse(of: "observation-v1"))
        XCTAssertFalse(granted.allowsReuse(of: "different"))
        XCTAssertTrue(try store.revoke(
            fingerprint: "observation-v1",
            at: Date(timeIntervalSince1970: 101)
        ))
        XCTAssertFalse(
            store.authorization(for: "observation-v1")?
                .allowsReuse(of: "observation-v1") ?? true
        )
    }

    func testAuthorizationStoreFailsClosedForCorruptReceipts() throws {
        let file = directory.appendingPathComponent("authorizations.json")
        try Data("{} corrupt".utf8).write(to: file)
        let store = ValidationEvidenceAuthorizationStore(fileURL: file)
        XCTAssertNil(store.authorization(for: "observation-v1"))
        XCTAssertThrowsError(try store.grant(
            fingerprint: "observation-v1",
            version: "validation-reuse-v1"
        ))
    }

    func testPurgeRemovesOnlyMatchingTuneDrafts() throws {
        let store = ValidationDraftStore(directory: directory)
        let matching = restoreContext()
        var other = matching
        other.savedTuneID = UUID()
        try store.save(try makeDocument(context: matching))
        try store.save(try makeDocument(context: other))

        XCTAssertEqual(try store.purge(savedTuneID: savedTuneID), 1)
        XCTAssertNil(try store.load(expected: matching))
        XCTAssertNotNil(try store.load(expected: other))
    }

    private func restoreContext() -> ValidationDraftRestoreContext {
        .init(
            kind: .firstPartyTestDrive,
            savedTuneID: savedTuneID,
            tuneRevisionFingerprint: "revision-v2",
            gameBuildVersion: "build-42",
            captureRevision: "capture-v2"
        )
    }

    private func makeDocument(
        context: ValidationDraftRestoreContext
    ) throws -> ValidationDraftDocument {
        try .init(
            identity: .init(
                draftID: UUID(), kind: context.kind,
                savedTuneID: context.savedTuneID,
                tuneRevisionFingerprint: context.tuneRevisionFingerprint,
                gameBuildVersion: context.gameBuildVersion,
                captureRevision: context.captureRevision
            ),
            lifecycle: .init(createdAt: .now, updatedAt: .now),
            factualFields: ["runCount": "4"]
        )
    }
}
