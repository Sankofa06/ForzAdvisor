import Foundation

enum ValidationEvidenceExportError: Error, Equatable {
    case localOnly
    case invalidAuthorization
}

struct ValidationEvidenceAuthorizationStore {
    enum Operation: Equatable {
        case read, persist, remove, revoke, purge
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
            self.fileURL = base
                .appendingPathComponent("ForzAdvisor", isDirectory: true)
                .appendingPathComponent("validation-authorizations.json")
        }
    }

    func authorization(for fingerprint: String)
        -> ValidationEvidenceAuthorizationEnvelope? {
        try? authorizationResult(for: fingerprint)
    }

    func authorizationResult(for fingerprint: String) throws
        -> ValidationEvidenceAuthorizationEnvelope? {
        try fault?(.read)
        return try readAll()[fingerprint]
    }

    func allowsExport(of record: FirstPartyValidationRecord) -> Bool {
        guard let envelope = authorization(for: record.contentFingerprint)
        else { return false }
        return envelope.allowsReuse(of: record.contentFingerprint)
            && envelope.authorizationID == record.permissionReceiptID
    }

    func grant(
        fingerprint: String,
        version: String,
        at date: Date = .now,
        id: UUID = UUID()
    ) throws -> ValidationEvidenceAuthorizationEnvelope {
        try fault?(.persist)
        let envelope = ValidationEvidenceAuthorizationEnvelope.reusable(
            observationFingerprint: fingerprint,
            authorizationID: id,
            authorizationVersion: version,
            authorizedAt: date
        )
        guard envelope.isValid else {
            throw ValidationEvidenceExportError.invalidAuthorization
        }
        var values = try readAll()
        values[fingerprint] = envelope
        try write(values)
        return envelope
    }

    func persist(_ envelope: ValidationEvidenceAuthorizationEnvelope) throws {
        try fault?(.persist)
        guard envelope.isValid else {
            throw ValidationEvidenceExportError.invalidAuthorization
        }
        var values = try readAll()
        values[envelope.observationFingerprint] = envelope
        try write(values)
    }

    @discardableResult
    func remove(fingerprint: String) throws -> Bool {
        try fault?(.remove)
        var values = try readAll()
        guard values.removeValue(forKey: fingerprint) != nil else {
            return false
        }
        try write(values)
        return true
    }

    @discardableResult
    func revoke(fingerprint: String, at date: Date = .now) throws -> Bool {
        try fault?(.revoke)
        var values = try readAll()
        guard let existing = values[fingerprint],
              existing.allowsReuse(of: fingerprint) else { return false }
        values[fingerprint] = existing.revoking(at: date)
        try write(values)
        return true
    }

    @discardableResult
    func purge(fingerprints: Set<String>) throws -> Int {
        try fault?(.purge)
        guard !fingerprints.isEmpty else { return 0 }
        var values = try readAll()
        let count = values.count
        values = values.filter { !fingerprints.contains($0.key) }
        let removed = count - values.count
        guard removed > 0 else { return 0 }
        try write(values)
        return removed
    }

    private func readAll() throws
        -> [String: ValidationEvidenceAuthorizationEnvelope] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return [:]
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let values = try decoder.decode(
            [String: ValidationEvidenceAuthorizationEnvelope].self,
            from: Data(contentsOf: fileURL)
        )
        guard values.allSatisfy({ key, value in
            key == value.observationFingerprint && value.isValid
        }) else {
            throw ValidationEvidenceExportError.invalidAuthorization
        }
        return values
    }

    private func write(
        _ values: [String: ValidationEvidenceAuthorizationEnvelope]
    ) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(values).write(to: fileURL, options: .atomic)
    }
}

struct FirstPartyValidationExportGate {
    func deterministicJSON(
        for record: FirstPartyValidationRecord,
        authorization: ValidationEvidenceAuthorizationEnvelope?
    ) throws -> Data {
        guard FirstPartyValidationRecordFactory()
            .isValidLocalObservation(record) else {
            throw FirstPartyValidationError.invalidStoredRecord
        }
        guard let authorization,
              authorization.allowsReuse(of: record.contentFingerprint),
              let permissionID = authorization.authorizationID else {
            throw ValidationEvidenceExportError.localOnly
        }
        if record.deidentifiedReusePermitted {
            guard record.permissionReceiptID == permissionID else {
                throw ValidationEvidenceExportError.invalidAuthorization
            }
            return try record.deterministicJSON()
        }
        var reusable = record
        reusable.deidentifiedReusePermitted = true
        reusable.permissionReceiptID = permissionID
        return try reusable.deterministicJSON()
    }
}
