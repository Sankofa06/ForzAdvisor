//
//  ValidationDraftContracts.swift
//  forzadvisor
//
//  Versioned, factual-only recovery contracts for validation capture drafts.
//

import Foundation

enum ValidationDraftKind: String, Codable, Equatable, Sendable {
    case firstPartyTestDrive
    case fh5ResearchObservation
    case fh5ControlledExperiment
    case fh6CommunityReferenceTrial
    case fh6TuneMenuCapture
    case tirePressureCapture
    case upgradePartCapture
}

enum ValidationDraftContractError: Error, Equatable {
    case invalidDocument
}

struct ValidationDraftIdentity: Codable, Equatable, Sendable {
    let draftID: UUID
    let kind: ValidationDraftKind
    let savedTuneID: UUID
    let tuneRevisionFingerprint: String
    let gameBuildVersion: String
    let captureRevision: String?

    var hasValidCoreBindings: Bool {
        guard Self.isBinding(tuneRevisionFingerprint),
              Self.isBinding(gameBuildVersion) else {
            return false
        }
        guard let captureRevision else { return true }
        return Self.isBinding(captureRevision)
    }

    private static func isBinding(_ value: String) -> Bool {
        !value.isEmpty
            && value.count <= 256
            && value == value.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            && !value.unicodeScalars.contains {
                CharacterSet.controlCharacters.contains($0)
            }
    }
}

struct ValidationDraftLifecycle: Codable, Equatable, Sendable {
    let createdAt: Date
    let updatedAt: Date

    var isValid: Bool {
        updatedAt >= createdAt
    }
}

struct ValidationDraftDocument: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 2
    static let supportedSchemaVersions = 1...currentSchemaVersion

    let schemaVersion: Int
    let identity: ValidationDraftIdentity
    let lifecycle: ValidationDraftLifecycle
    let factualFields: [String: String]

    var draftID: UUID { identity.draftID }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case draftID
        case kind
        case savedTuneID
        case tuneRevisionFingerprint
        case gameBuildVersion
        case captureRevision
        case createdAt
        case updatedAt
        case factualFields
    }

    init(
        identity: ValidationDraftIdentity,
        lifecycle: ValidationDraftLifecycle,
        factualFields: [String: String]
    ) throws {
        guard identity.captureRevision != nil,
              identity.hasValidCoreBindings,
              lifecycle.isValid,
              Self.areFactualFieldsSafe(factualFields) else {
            throw ValidationDraftContractError.invalidDocument
        }
        schemaVersion = Self.currentSchemaVersion
        self.identity = identity
        self.lifecycle = lifecycle
        self.factualFields = factualFields
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let schemaVersion = try values.decode(
            Int.self,
            forKey: .schemaVersion
        )
        guard Self.supportedSchemaVersions.contains(schemaVersion) else {
            throw DecodingError.dataCorruptedError(
                forKey: .schemaVersion,
                in: values,
                debugDescription: "Unsupported validation draft schema."
            )
        }

        let captureRevision = try values.decodeIfPresent(
            String.self,
            forKey: .captureRevision
        )
        if schemaVersion == Self.currentSchemaVersion,
           captureRevision == nil {
            throw DecodingError.keyNotFound(
                CodingKeys.captureRevision,
                .init(
                    codingPath: decoder.codingPath,
                    debugDescription: "V2 drafts require a capture revision."
                )
            )
        }

        let identity = try ValidationDraftIdentity(
            draftID: values.decode(UUID.self, forKey: .draftID),
            kind: values.decode(ValidationDraftKind.self, forKey: .kind),
            savedTuneID: values.decode(UUID.self, forKey: .savedTuneID),
            tuneRevisionFingerprint: values.decode(
                String.self,
                forKey: .tuneRevisionFingerprint
            ),
            gameBuildVersion: values.decode(
                String.self,
                forKey: .gameBuildVersion
            ),
            captureRevision: captureRevision
        )
        let lifecycle = try ValidationDraftLifecycle(
            createdAt: values.decode(Date.self, forKey: .createdAt),
            updatedAt: values.decode(Date.self, forKey: .updatedAt)
        )
        let factualFields = try values.decode(
            [String: String].self,
            forKey: .factualFields
        )
        guard identity.hasValidCoreBindings,
              lifecycle.isValid,
              Self.areFactualFieldsSafe(factualFields) else {
            throw DecodingError.dataCorruptedError(
                forKey: .factualFields,
                in: values,
                debugDescription: "Draft bindings or factual fields are invalid."
            )
        }

        self.schemaVersion = schemaVersion
        self.identity = identity
        self.lifecycle = lifecycle
        self.factualFields = factualFields
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(schemaVersion, forKey: .schemaVersion)
        try values.encode(identity.draftID, forKey: .draftID)
        try values.encode(identity.kind, forKey: .kind)
        try values.encode(identity.savedTuneID, forKey: .savedTuneID)
        try values.encode(
            identity.tuneRevisionFingerprint,
            forKey: .tuneRevisionFingerprint
        )
        try values.encode(
            identity.gameBuildVersion,
            forKey: .gameBuildVersion
        )
        try values.encodeIfPresent(
            identity.captureRevision,
            forKey: .captureRevision
        )
        try values.encode(lifecycle.createdAt, forKey: .createdAt)
        try values.encode(lifecycle.updatedAt, forKey: .updatedAt)
        try values.encode(factualFields, forKey: .factualFields)
    }

    private static func areFactualFieldsSafe(
        _ fields: [String: String]
    ) -> Bool {
        guard fields.count <= 100 else { return false }
        let prohibitedFragments = [
            "attest", "author", "consent", "export", "permission",
            "public", "reuse", "share"
        ]
        return fields.allSatisfy { key, value in
            let normalizedKey = key.lowercased()
            return !key.isEmpty
                && key.count <= 120
                && value.count <= 2_000
                && key == key.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                && !key.unicodeScalars.contains {
                    CharacterSet.controlCharacters.contains($0)
                }
                && !prohibitedFragments.contains {
                    normalizedKey.contains($0)
                }
        }
    }
}

struct ValidationDraftRestoreContext: Equatable, Sendable {
    var kind: ValidationDraftKind
    var savedTuneID: UUID
    var tuneRevisionFingerprint: String
    var gameBuildVersion: String
    var captureRevision: String
}

enum ValidationDraftRestoreDisposition: Equatable, Sendable {
    case resume
    case requiresMigration
    case discardStale
}

struct ValidationDraftRestorePolicy {
    func disposition(
        for document: ValidationDraftDocument,
        expected: ValidationDraftRestoreContext
    ) -> ValidationDraftRestoreDisposition {
        guard document.schemaVersion
                == ValidationDraftDocument.currentSchemaVersion else {
            return .requiresMigration
        }
        let identity = document.identity
        guard identity.kind == expected.kind,
              identity.savedTuneID == expected.savedTuneID,
              identity.tuneRevisionFingerprint
                == expected.tuneRevisionFingerprint,
              identity.gameBuildVersion == expected.gameBuildVersion,
              identity.captureRevision == expected.captureRevision else {
            return .discardStale
        }
        return .resume
    }
}
