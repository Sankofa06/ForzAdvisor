import Foundation

enum ValidationLocalObservationStoreError: Error, Equatable {
    case corrupt
    case invalidObservation
}

struct ValidationLocalObservationStore {
    enum Operation: Equatable {
        case read, upsert, delete, purge
    }

    struct Entry: Codable, Equatable, Sendable {
        let savedTuneID: UUID
        let observation: ValidationLocalObservation
    }

    let fileURL: URL
    let fault: ((Operation) throws -> Void)?

    init(
        fileURL: URL? = nil,
        fault: ((Operation) throws -> Void)? = nil
    ) {
        self.fault = fault
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let base = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first ?? FileManager.default.temporaryDirectory
            self.fileURL = base.appendingPathComponent("ForzAdvisor")
                .appendingPathComponent("validation-local-observations.json")
        }
    }

    func observations(savedTuneID: UUID) throws
        -> [ValidationLocalObservation] {
        try fault?(.read)
        return try readAll().filter { $0.savedTuneID == savedTuneID }
            .map(\.observation)
            .sorted { $0.capturedAt < $1.capturedAt }
    }

    func observation(
        savedTuneID: UUID,
        fingerprint: String
    ) throws -> ValidationLocalObservation? {
        try fault?(.read)
        return try readAll().first {
            $0.savedTuneID == savedTuneID
                && $0.observation.observationFingerprint == fingerprint
        }?.observation
    }

    func upsert(
        _ observation: ValidationLocalObservation,
        savedTuneID: UUID
    ) throws {
        try fault?(.upsert)
        guard !observation.observationFingerprint.isEmpty else {
            throw ValidationLocalObservationStoreError.invalidObservation
        }
        var entries = try readAll()
        entries.removeAll {
            $0.savedTuneID == savedTuneID
                && $0.observation.observationFingerprint
                    == observation.observationFingerprint
        }
        entries.append(Entry(savedTuneID: savedTuneID, observation: observation))
        try write(entries)
    }

    @discardableResult
    func delete(savedTuneID: UUID, fingerprint: String) throws -> Bool {
        try fault?(.delete)
        var entries = try readAll()
        let count = entries.count
        entries.removeAll {
            $0.savedTuneID == savedTuneID
                && $0.observation.observationFingerprint == fingerprint
        }
        guard entries.count != count else { return false }
        try write(entries)
        return true
    }

    @discardableResult
    func purge(savedTuneID: UUID) throws -> Int {
        try fault?(.purge)
        var entries = try readAll()
        let count = entries.count
        entries.removeAll { $0.savedTuneID == savedTuneID }
        let removed = count - entries.count
        guard removed > 0 else { return 0 }
        try write(entries)
        return removed
    }

    func mergedRecords(
        savedTuneID: UUID,
        legacyReusable: [FirstPartyValidationRecord]
    ) throws -> [ValidationEvidenceRecord] {
        var seen = Set<String>()
        let reusable = legacyReusable.compactMap { record -> ValidationEvidenceRecord? in
            guard record.deidentifiedReusePermitted,
                  seen.insert(record.contentFingerprint).inserted else { return nil }
            return .reusable(record)
        }
        let local: [ValidationEvidenceRecord] = try observations(
            savedTuneID: savedTuneID
        ).compactMap {
            seen.insert($0.observationFingerprint).inserted
                ? .localOnly($0) : nil
        }
        return reusable + local
    }

    private func readAll() throws -> [Entry] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let entries = try decoder.decode([Entry].self, from: Data(contentsOf: fileURL))
            guard Set(entries.map {
                "\($0.savedTuneID.uuidString):\($0.observation.observationFingerprint)"
            }).count == entries.count else {
                throw ValidationLocalObservationStoreError.corrupt
            }
            return entries
        } catch {
            throw ValidationLocalObservationStoreError.corrupt
        }
    }

    private func write(_ entries: [Entry]) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(entries).write(to: fileURL, options: .atomic)
    }
}

enum ValidationEvidenceRecord: Equatable, Sendable {
    case localOnly(ValidationLocalObservation)
    case reusable(FirstPartyValidationRecord)

    var fingerprint: String {
        switch self {
        case .localOnly(let value): value.observationFingerprint
        case .reusable(let value): value.contentFingerprint
        }
    }
}
