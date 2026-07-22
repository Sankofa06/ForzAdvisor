//
//  UpgradePartCapture.swift
//  forzadvisor
//
//  Local, user-attested availability facts for stock-car tuning controls.
//

import Foundation

enum UpgradePartCaptureStatus: String, Codable, Equatable, Sendable {
    case offered
    case notOffered

    var title: String {
        switch self {
        case .offered: "Offered"
        case .notOffered: "Not offered"
        }
    }

    var availability: TunePartAvailability {
        switch self {
        case .offered: .available
        case .notOffered: .unavailable
        }
    }
}

struct UpgradePartCaptureValue: Codable, Equatable, Sendable {
    var partID: TunePartID
    var status: UpgradePartCaptureStatus
}

enum UpgradePartCaptureIssue: Error, LocalizedError, Equatable {
    case invalidBaseSnapshot
    case missingCatalogIdentity
    case modifiedCatalogIdentity
    case installedPartsPresent
    case missingGameBuildVersion
    case mismatchedGameBuild(expected: String, entered: String)
    case missingPartDecision(TunePartID)
    case duplicatePartDecision(TunePartID)
    case exactStockBuildNotConfirmed
    case localUseNotPermitted
    case reusedSnapshotIdentity

    var errorDescription: String? {
        switch self {
        case .invalidBaseSnapshot:
            "The selected catalog snapshot is not valid."
        case .missingCatalogIdentity:
            "Choose an unedited car from the catalog before verifying upgrade-shop parts."
        case .modifiedCatalogIdentity:
            "The selected catalog car was edited. Restore its stock catalog values before verifying it."
        case .installedPartsPresent:
            "Upgrade verification requires the exact untouched stock car with no parts installed."
        case .missingGameBuildVersion:
            "Enter the exact game build version shown in settings."
        case .mismatchedGameBuild(let expected, let entered):
            "This tune was verified on game build \(expected), not \(entered). Use the same exact build."
        case .missingPartDecision(let partID):
            "Mark \(TunePartCatalog.definition(for: partID).label) as Offered or Not offered."
        case .duplicatePartDecision(let partID):
            "\(TunePartCatalog.definition(for: partID).label) was recorded more than once."
        case .exactStockBuildNotConfirmed:
            "Confirm that this is the exact untouched stock catalog car."
        case .localUseNotPermitted:
            "Allow ForzAdvisor to store and use this observation locally for this tune."
        case .reusedSnapshotIdentity:
            "The upgrade observation must have a new snapshot identifier."
        }
    }
}

enum UpgradePartCaptureError: Error, LocalizedError {
    case invalid([UpgradePartCaptureIssue])
    case invalidGeneratedSnapshot([VehicleBuildSnapshotIssue])

    var errorDescription: String? {
        switch self {
        case .invalid(let issues):
            issues.first?.errorDescription ?? "The upgrade-shop observation is invalid."
        case .invalidGeneratedSnapshot:
            "The upgrade-shop observation could not create a valid build snapshot."
        }
    }
}

struct UpgradePartCapture: Codable, Equatable, Sendable {
    static let provenanceSource = "forzadvisor.local.user-observation"

    var gameBuildVersion: String
    var parts: [UpgradePartCaptureValue]
    var exactStockBuildConfirmed: Bool
    var localUsePermitted: Bool

    func validationIssues(upgrading snapshot: VehicleBuildSnapshot) -> [UpgradePartCaptureIssue] {
        validationIssues(upgrading: snapshot, snapshotID: nil)
    }

    func verifiedSnapshot(
        upgrading snapshot: VehicleBuildSnapshot,
        capturedAt: Date = .now,
        snapshotID: UUID = UUID()
    ) throws -> VehicleBuildSnapshot {
        let issues = validationIssues(upgrading: snapshot, snapshotID: snapshotID)
        guard issues.isEmpty else {
            throw UpgradePartCaptureError.invalid(issues)
        }

        let buildVersion = normalized(gameBuildVersion)
        let statusByPart = Dictionary(uniqueKeysWithValues: parts.map { ($0.partID, $0.status) })
        let evidence = TuneEvidence(
            confidence: .medium,
            source: Self.provenanceSource,
            version: buildVersion,
            usagePermission: .permitted
        )
        var profile = snapshot.capabilityProfile
        profile.parts = TunePartID.allCases.map { partID in
            TuneVehiclePart(
                partID: partID,
                availability: statusByPart[partID]!.availability,
                evidence: evidence
            )
        }

        let verified = VehicleBuildSnapshot(
            schemaVersion: VehicleBuildSnapshot.currentSchemaVersion,
            id: snapshotID,
            kind: snapshot.kind,
            capturedAt: capturedAt,
            gameBuild: GameBuildReference(
                game: snapshot.car.game,
                version: buildVersion,
                capturedAt: capturedAt
            ),
            car: snapshot.car,
            capabilityProfile: profile,
            tireCompound: snapshot.tireCompound,
            gearCount: snapshot.gearCount,
            constraints: snapshot.constraints,
            evidenceSources: snapshot.evidenceSources
        )

        guard verified.isValid else {
            throw UpgradePartCaptureError.invalidGeneratedSnapshot(verified.validationIssues)
        }
        return verified
    }

    private func validationIssues(
        upgrading snapshot: VehicleBuildSnapshot,
        snapshotID: UUID?
    ) -> [UpgradePartCaptureIssue] {
        var issues: [UpgradePartCaptureIssue] = []
        if !snapshot.isValid {
            issues.append(.invalidBaseSnapshot)
        }
        if snapshot.car.catalogReference == nil {
            issues.append(.missingCatalogIdentity)
        } else if snapshot.car.catalogValuesModified {
            issues.append(.modifiedCatalogIdentity)
        }
        if snapshot.capabilityProfile.parts.contains(where: { $0.availability == .installed }) {
            issues.append(.installedPartsPresent)
        }

        let enteredBuild = normalized(gameBuildVersion)
        if enteredBuild.isEmpty {
            issues.append(.missingGameBuildVersion)
        } else if snapshot.kind == .exactBuildObservation,
                  let knownBuild = snapshot.gameBuild.version.map(normalized),
                  !knownBuild.isEmpty,
                  knownBuild != enteredBuild {
            issues.append(.mismatchedGameBuild(expected: knownBuild, entered: enteredBuild))
        }

        let grouped = Dictionary(grouping: parts, by: \.partID)
        for partID in TunePartID.allCases {
            switch grouped[partID]?.count ?? 0 {
            case 0:
                issues.append(.missingPartDecision(partID))
            case 1:
                break
            default:
                issues.append(.duplicatePartDecision(partID))
            }
        }
        if !exactStockBuildConfirmed {
            issues.append(.exactStockBuildNotConfirmed)
        }
        if !localUsePermitted {
            issues.append(.localUseNotPermitted)
        }
        if snapshotID == snapshot.id {
            issues.append(.reusedSnapshotIdentity)
        }
        return issues
    }

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
