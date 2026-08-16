import Foundation

enum ValidationDraftStoreError: Error, Equatable {
    case unavailable
    case corrupt
    case stale
    case migrationRequired
}

struct ValidationDraftStore {
    let directory: URL

    init(directory: URL? = nil) {
        if let directory {
            self.directory = directory
        } else {
            let base = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first ?? FileManager.default.temporaryDirectory
            self.directory = base
                .appendingPathComponent("ForzAdvisor", isDirectory: true)
                .appendingPathComponent("ValidationDrafts", isDirectory: true)
        }
    }

    func save(_ document: ValidationDraftDocument) throws {
        try prepareDirectory()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(document)
        try data.write(to: url(for: document.identity), options: .atomic)
    }

    func load(
        expected: ValidationDraftRestoreContext
    ) throws -> ValidationDraftDocument? {
        let identity = ValidationDraftIdentity(
            draftID: UUID(),
            kind: expected.kind,
            savedTuneID: expected.savedTuneID,
            tuneRevisionFingerprint: expected.tuneRevisionFingerprint,
            gameBuildVersion: expected.gameBuildVersion,
            captureRevision: expected.captureRevision
        )
        let target = url(for: identity)
        guard FileManager.default.fileExists(atPath: target.path) else {
            return nil
        }
        let document: ValidationDraftDocument
        do {
            let data = try Data(contentsOf: target)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            document = try decoder.decode(ValidationDraftDocument.self, from: data)
        } catch {
            try? quarantine(target)
            throw ValidationDraftStoreError.corrupt
        }
        switch ValidationDraftRestorePolicy().disposition(
            for: document,
            expected: expected
        ) {
        case .resume:
            return document
        case .requiresMigration:
            throw ValidationDraftStoreError.migrationRequired
        case .discardStale:
            try? FileManager.default.removeItem(at: target)
            throw ValidationDraftStoreError.stale
        }
    }

    func migrateLegacy(
        expected: ValidationDraftRestoreContext
    ) throws -> ValidationDraftDocument {
        let legacy = try loadLegacy(expected: expected)
        let migrated = try ValidationDraftDocument(
            identity: .init(
                draftID: legacy.identity.draftID,
                kind: legacy.identity.kind,
                savedTuneID: legacy.identity.savedTuneID,
                tuneRevisionFingerprint:
                    legacy.identity.tuneRevisionFingerprint,
                gameBuildVersion: legacy.identity.gameBuildVersion,
                captureRevision: expected.captureRevision
            ),
            lifecycle: legacy.lifecycle,
            factualFields: legacy.factualFields
        )
        try save(migrated)
        return migrated
    }

    func delete(kind: ValidationDraftKind, savedTuneID: UUID) throws {
        let identity = ValidationDraftIdentity(
            draftID: UUID(), kind: kind, savedTuneID: savedTuneID,
            tuneRevisionFingerprint: "unused", gameBuildVersion: "unused",
            captureRevision: "unused"
        )
        let target = url(for: identity)
        if FileManager.default.fileExists(atPath: target.path) {
            try FileManager.default.removeItem(at: target)
        }
    }

    @discardableResult
    func purge(savedTuneID: UUID) throws -> Int {
        guard FileManager.default.fileExists(atPath: directory.path) else {
            return 0
        }
        let suffix = "-\(savedTuneID.uuidString.lowercased()).json"
        let files = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ).filter { $0.lastPathComponent.hasSuffix(suffix) }
        for file in files {
            try FileManager.default.removeItem(at: file)
        }
        return files.count
    }

    private func loadLegacy(
        expected: ValidationDraftRestoreContext
    ) throws -> ValidationDraftDocument {
        let identity = ValidationDraftIdentity(
            draftID: UUID(), kind: expected.kind,
            savedTuneID: expected.savedTuneID,
            tuneRevisionFingerprint: expected.tuneRevisionFingerprint,
            gameBuildVersion: expected.gameBuildVersion,
            captureRevision: expected.captureRevision
        )
        let target = url(for: identity)
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let document = try decoder.decode(
                ValidationDraftDocument.self,
                from: Data(contentsOf: target)
            )
            guard document.schemaVersion == 1,
                  document.identity.kind == expected.kind,
                  document.identity.savedTuneID == expected.savedTuneID,
                  document.identity.tuneRevisionFingerprint
                    == expected.tuneRevisionFingerprint,
                  document.identity.gameBuildVersion
                    == expected.gameBuildVersion else {
                throw ValidationDraftStoreError.stale
            }
            return document
        } catch let error as ValidationDraftStoreError {
            throw error
        } catch {
            try? quarantine(target)
            throw ValidationDraftStoreError.corrupt
        }
    }

    private func url(for identity: ValidationDraftIdentity) -> URL {
        directory.appendingPathComponent(
            "\(identity.kind.rawValue)-\(identity.savedTuneID.uuidString.lowercased()).json"
        )
    }

    private func prepareDirectory() throws {
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        } catch {
            throw ValidationDraftStoreError.unavailable
        }
    }

    private func quarantine(_ target: URL) throws {
        try prepareDirectory()
        let quarantineURL = target.appendingPathExtension("corrupt")
        try? FileManager.default.removeItem(at: quarantineURL)
        try FileManager.default.moveItem(at: target, to: quarantineURL)
    }
}
