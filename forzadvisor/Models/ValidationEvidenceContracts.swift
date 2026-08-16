//
//  ValidationEvidenceContracts.swift
//  forzadvisor
//
//  Additive value contracts for validation summaries and reuse authorization.
//

import Foundation

struct TuneEvidenceSummary: Codable, Equatable, Sendable {
    let savedTuneID: UUID
    let localOnlyRecordCount: Int
    let reusableRecordCount: Int
    let reviewedRecordCount: Int

    var localRecordCount: Int {
        isValid ? safeTotal ?? 0 : 0
    }

    var totalRecordCount: Int {
        localRecordCount
    }

    var exportableRecordCount: Int {
        isValid ? reusableRecordCount : 0
    }

    var isValid: Bool {
        localOnlyRecordCount >= 0
            && reusableRecordCount >= 0
            && reviewedRecordCount >= 0
            && safeTotal != nil
    }

    static func empty(savedTuneID: UUID) -> Self {
        Self(
            savedTuneID: savedTuneID,
            localOnlyRecordCount: 0,
            reusableRecordCount: 0,
            reviewedRecordCount: 0
        )
    }

    private var safeTotal: Int? {
        let first = localOnlyRecordCount.addingReportingOverflow(
            reusableRecordCount
        )
        guard !first.overflow else { return nil }
        let second = first.partialValue.addingReportingOverflow(
            reviewedRecordCount
        )
        return second.overflow ? nil : second.partialValue
    }
}

enum ValidationEvidenceScope: String, Codable, Equatable, Sendable {
    case localOnly
    case reusable
}

struct ValidationEvidenceAuthorizationEnvelope:
    Codable,
    Equatable,
    Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let observationFingerprint: String
    let scope: ValidationEvidenceScope
    let authorizationID: UUID?
    let authorizationVersion: String?
    let authorizedAt: Date?
    let revokedAt: Date?

    init(
        schemaVersion: Int = currentSchemaVersion,
        observationFingerprint: String,
        scope: ValidationEvidenceScope,
        authorizationID: UUID?,
        authorizationVersion: String?,
        authorizedAt: Date?,
        revokedAt: Date? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.observationFingerprint = observationFingerprint
        self.scope = scope
        self.authorizationID = authorizationID
        self.authorizationVersion = authorizationVersion
        self.authorizedAt = authorizedAt
        self.revokedAt = revokedAt
    }

    static func localOnly(
        observationFingerprint: String
    ) -> Self {
        Self(
            observationFingerprint: observationFingerprint,
            scope: .localOnly,
            authorizationID: nil,
            authorizationVersion: nil,
            authorizedAt: nil
        )
    }

    static func reusable(
        observationFingerprint: String,
        authorizationID: UUID,
        authorizationVersion: String,
        authorizedAt: Date
    ) -> Self {
        Self(
            observationFingerprint: observationFingerprint,
            scope: .reusable,
            authorizationID: authorizationID,
            authorizationVersion: authorizationVersion,
            authorizedAt: authorizedAt
        )
    }

    var isValid: Bool {
        guard schemaVersion == Self.currentSchemaVersion,
              Self.isCanonical(observationFingerprint, maximumLength: 256)
        else { return false }

        switch scope {
        case .localOnly:
            return authorizationID == nil
                && authorizationVersion == nil
                && authorizedAt == nil
                && revokedAt == nil
        case .reusable:
            guard authorizationID != nil,
                  let authorizationVersion,
                  Self.isCanonical(
                    authorizationVersion,
                    maximumLength: 120
                  ),
                  let authorizedAt
            else { return false }
            return revokedAt.map { $0 >= authorizedAt } ?? true
        }
    }

    func allowsReuse(of fingerprint: String) -> Bool {
        isValid
            && scope == .reusable
            && revokedAt == nil
            && fingerprint == observationFingerprint
    }

    func revoking(at date: Date) -> Self {
        Self(
            schemaVersion: schemaVersion,
            observationFingerprint: observationFingerprint,
            scope: scope,
            authorizationID: authorizationID,
            authorizationVersion: authorizationVersion,
            authorizedAt: authorizedAt,
            revokedAt: date
        )
    }

    private static func isCanonical(
        _ value: String,
        maximumLength: Int
    ) -> Bool {
        !value.isEmpty
            && value.count <= maximumLength
            && value == value.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            && !value.unicodeScalars.contains {
                CharacterSet.controlCharacters.contains($0)
            }
    }
}
