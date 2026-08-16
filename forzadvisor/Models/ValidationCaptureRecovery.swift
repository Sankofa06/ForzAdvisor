import Foundation

struct ValidationCaptureRecovery {
    let store: ValidationDraftStore
    let context: ValidationDraftRestoreContext

    init(
        kind: ValidationDraftKind,
        tune: TuneResult,
        gameBuildVersion: String? = nil,
        captureRevision: String,
        store: ValidationDraftStore = ValidationDraftStore()
    ) throws {
        guard let fingerprint = FirstPartyValidationRecordFactory()
            .revisionFingerprint(for: tune),
              let build = gameBuildVersion
                ?? tune.request.buildSnapshot?.gameBuild.version else {
            throw ValidationDraftStoreError.unavailable
        }
        self.store = store
        context = ValidationDraftRestoreContext(
            kind: kind,
            savedTuneID: tune.id,
            tuneRevisionFingerprint: fingerprint,
            gameBuildVersion: build,
            captureRevision: captureRevision
        )
    }

    func save(factualFields: [String: String], at date: Date = .now) throws {
        let existing = try? store.load(expected: context)
        let document = try ValidationDraftDocument(
            identity: ValidationDraftIdentity(
                draftID: existing?.identity.draftID ?? UUID(),
                kind: context.kind,
                savedTuneID: context.savedTuneID,
                tuneRevisionFingerprint: context.tuneRevisionFingerprint,
                gameBuildVersion: context.gameBuildVersion,
                captureRevision: context.captureRevision
            ),
            lifecycle: ValidationDraftLifecycle(
                createdAt: existing?.lifecycle.createdAt ?? date,
                updatedAt: date
            ),
            factualFields: factualFields
        )
        try store.save(document)
    }

    func restore() throws -> [String: String]? {
        do {
            return try store.load(expected: context)?.factualFields
        } catch ValidationDraftStoreError.migrationRequired {
            return try store.migrateLegacy(expected: context).factualFields
        }
    }

    func discard() throws {
        try store.delete(kind: context.kind, savedTuneID: context.savedTuneID)
    }
}

enum ValidationDraftFieldCodec {
    static func decodeTuneFieldID(_ value: String?) -> TuneFieldID? {
        guard let value,
              let data = try? JSONEncoder().encode(value) else { return nil }
        return try? JSONDecoder().decode(TuneFieldID.self, from: data)
    }

    static func encode<T: RawRepresentable>(_ value: T?) -> String?
    where T.RawValue == String {
        value?.rawValue
    }

    static func decode<T: RawRepresentable>(_ type: T.Type, _ value: String?) -> T?
    where T.RawValue == String {
        value.flatMap(T.init(rawValue:))
    }

    static func encodeSet<T: RawRepresentable>(_ values: Set<T>) -> String
    where T.RawValue == String {
        values.map(\.rawValue).sorted().joined(separator: ",")
    }

    static func decodeSet<T: RawRepresentable & Hashable>(
        _ type: T.Type,
        _ value: String?
    ) -> Set<T> where T.RawValue == String {
        Set((value ?? "").split(separator: ",").compactMap {
            T(rawValue: String($0))
        })
    }
}
