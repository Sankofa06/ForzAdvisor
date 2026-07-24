//
//  FH6TuneMenuCapture.swift
//  forzadvisor
//
//  First-party, exact-build numeric tuning-menu evidence for FH6.
//

import Foundation

enum FH6TuneMenuFieldAvailability: String, CaseIterable, Codable, Sendable {
    case adjustable
    case shownLocked
    case notShown
}

struct FH6TuneMenuFieldObservation: Codable, Equatable, Sendable {
    var field: TuneFieldID
    var availability: FH6TuneMenuFieldAvailability
    var minimum: Double?
    var maximum: Double?
    var step: Double?
    var current: Double?
    var unit: TuneUnit?
}

enum FH6TuneMenuCaptureIssue: Error, LocalizedError, Equatable {
    case invalidBaseSnapshot
    case unsupportedGame(ForzaGame)
    case missingCatalogIdentity
    case modifiedCatalogIdentity
    case installedPartsPresent
    case missingGameBuildVersion
    case invalidGameBuildVersion
    case mismatchedGameBuild(expected: String, entered: String)
    case mismatchedUpgradeGameBuild(expected: String, entered: String)
    case missingTireCompound
    case invalidTireCompound
    case invalidGearCount(Int)
    case missingField(TuneFieldID)
    case duplicateField(TuneFieldID)
    case unexpectedField(TuneFieldID)
    case invalidAdjustableField(TuneFieldID)
    case lockedFieldContainsValues(TuneFieldID)
    case exactStockBuildNotConfirmed
    case slidersNotRestored
    case firstPartyReadingNotConfirmed
    case localUseNotPermitted
    case invalidEvidenceID
    case reusedSnapshotIdentity

    var errorDescription: String? {
        switch self {
        case .invalidBaseSnapshot:
            "The selected build snapshot is not valid."
        case .unsupportedGame(let game):
            "Tune Menu Lab is not available for \(game.title)."
        case .missingCatalogIdentity:
            "Choose an untouched catalog car before recording its tuning menu."
        case .modifiedCatalogIdentity:
            "Restore the selected car's stock catalog values before recording its tuning menu."
        case .installedPartsPresent:
            "Tune Menu Lab v1 requires the exact untouched stock car with no installed parts."
        case .missingGameBuildVersion:
            "Enter the exact FH6 game build version."
        case .invalidGameBuildVersion:
            "The FH6 game build version is not valid."
        case .mismatchedGameBuild(let expected, let entered):
            "This build already contains evidence for FH6 build \(expected), not \(entered)."
        case .mismatchedUpgradeGameBuild(let expected, let entered):
            "Upgrade Lab evidence is for FH6 build \(expected), not \(entered)."
        case .missingTireCompound:
            "Enter the tire compound shown for this stock build."
        case .invalidTireCompound:
            "The tire compound name is not valid."
        case .invalidGearCount(let count):
            "Forward gear count must be between 1 and 10, not \(count)."
        case .missingField(let field):
            "Record \(field.projectionLabel)."
        case .duplicateField(let field):
            "\(field.projectionLabel) was recorded more than once."
        case .unexpectedField(let field):
            "\(field.projectionLabel) does not belong to this exact build."
        case .invalidAdjustableField(let field):
            "\(field.projectionLabel) needs a valid range, step, current value, and unit."
        case .lockedFieldContainsValues(let field):
            "\(field.projectionLabel) cannot contain numeric values when it is locked or not shown."
        case .exactStockBuildNotConfirmed:
            "Confirm that this is the exact untouched stock catalog car."
        case .slidersNotRestored:
            "Restore every slider to its original value before saving."
        case .firstPartyReadingNotConfirmed:
            "Confirm that you personally read every value from FH6."
        case .localUseNotPermitted:
            "Allow ForzAdvisor to store and use this observation locally."
        case .invalidEvidenceID:
            "The local observation identifier is invalid."
        case .reusedSnapshotIdentity:
            "The menu observation must have a new snapshot identifier."
        }
    }
}

enum FH6TuneMenuCaptureError: Error, LocalizedError {
    case invalid([FH6TuneMenuCaptureIssue])
    case invalidGeneratedSnapshot([VehicleBuildSnapshotIssue])

    var errorDescription: String? {
        switch self {
        case .invalid(let issues):
            issues.first?.errorDescription ?? "The FH6 tuning-menu observation is invalid."
        case .invalidGeneratedSnapshot:
            "The tuning-menu observation could not create a valid exact build snapshot."
        }
    }
}

struct FH6TuneMenuCapture: Codable, Equatable, Sendable {
    static let provenanceSource = "forzadvisor.local.first-party-fh6-menu-observation"
    static let provenanceVersion = "fh6-tune-menu-v1"

    var gameBuildVersion: String
    var tireCompoundDisplayName: String
    var forwardGearCount: Int
    var controls: [FH6TuneMenuFieldObservation]
    var exactUntouchedStockConfirmed: Bool
    var allSlidersRestoredConfirmed: Bool
    var personallyReadFromGameConfirmed: Bool
    var localStoragePermitted: Bool

    func validationIssues(upgrading snapshot: VehicleBuildSnapshot) -> [FH6TuneMenuCaptureIssue] {
        validationIssues(upgrading: snapshot, snapshotID: nil, evidenceID: nil)
    }

    func exactBuildSnapshot(
        upgrading snapshot: VehicleBuildSnapshot,
        capturedAt: Date = .now,
        snapshotID: UUID = UUID(),
        evidenceID: String? = nil
    ) throws -> VehicleBuildSnapshot {
        let resolvedEvidenceID = evidenceID
            ?? "fh6-menu.\(snapshotID.uuidString.lowercased())"
        let issues = validationIssues(
            upgrading: snapshot,
            snapshotID: snapshotID,
            evidenceID: resolvedEvidenceID
        )
        guard issues.isEmpty else {
            throw FH6TuneMenuCaptureError.invalid(issues)
        }

        let build = normalized(gameBuildVersion)
        let compound = normalized(tireCompoundDisplayName)
        let capturedEvidence = TuneDataProvenance(
            id: normalized(resolvedEvidenceID),
            game: .fh6,
            gameBuildVersion: build,
            scope: .exactVehicleBuild,
            source: Self.provenanceSource,
            version: Self.provenanceVersion,
            capturedAt: capturedAt,
            confidence: .medium,
            usagePermission: .permitted
        )
        let expected = TuneFieldID.expectedFields(
            drivetrain: snapshot.car.drivetrain,
            gearCount: forwardGearCount
        )
        let byField = Dictionary(uniqueKeysWithValues: controls.map { ($0.field, $0) })
        let constraints = expected.compactMap { field -> TuneFieldConstraint? in
            guard let observation = byField[field],
                  observation.availability == .adjustable,
                  let minimum = observation.minimum,
                  let maximum = observation.maximum,
                  let step = observation.step,
                  let current = observation.current,
                  let unit = observation.unit else {
                return nil
            }
            return TuneFieldConstraint(
                field: field,
                minimum: minimum,
                maximum: maximum,
                step: step,
                defaultValue: nil,
                currentValue: current,
                unit: unit,
                scope: .exactVehicleBuild,
                verification: .productionEligible,
                evidenceIDs: [capturedEvidence.id]
            )
        }
        let menuEvidence = TuneEvidence(
            confidence: .medium,
            source: Self.provenanceSource,
            version: build,
            usagePermission: .permitted
        )
        let grouped = Dictionary(grouping: expected, by: \.setting)
        let stockAdjustableSettings = grouped.keys
            .filter { setting in
                let fields = grouped[setting] ?? []
                return !fields.isEmpty && fields.allSatisfy {
                    byField[$0]?.availability == .adjustable
                }
            }
            .sorted { $0.rawValue < $1.rawValue }
            .map {
                StockAdjustableSetting(setting: $0, evidence: menuEvidence)
            }

        var profile = snapshot.capabilityProfile
        profile.stockAdjustableSettings = stockAdjustableSettings

        let globalConstraints = snapshot.constraints.filter { $0.scope == .gameGlobal }
        let globalEvidenceIDs = Set(globalConstraints.flatMap(\.evidenceIDs))
        let globalEvidence = snapshot.evidenceSources.filter {
            $0.scope == .gameGlobal && globalEvidenceIDs.contains($0.id)
        }
        let exact = VehicleBuildSnapshot(
            schemaVersion: VehicleBuildSnapshot.currentSchemaVersion,
            id: snapshotID,
            kind: .exactBuildObservation,
            capturedAt: capturedAt,
            gameBuild: GameBuildReference(
                game: .fh6,
                version: build,
                capturedAt: capturedAt
            ),
            car: snapshot.car,
            capabilityProfile: profile,
            tireCompound: TireCompoundReference(
                id: "fh6-stock-tire:\(compound.lowercased())",
                displayName: compound,
                evidenceIDs: [capturedEvidence.id]
            ),
            gearCount: forwardGearCount,
            constraints: globalConstraints + constraints,
            evidenceSources: globalEvidence + [capturedEvidence]
        )
        guard exact.isValid else {
            throw FH6TuneMenuCaptureError.invalidGeneratedSnapshot(exact.validationIssues)
        }
        return exact
    }

    private func validationIssues(
        upgrading snapshot: VehicleBuildSnapshot,
        snapshotID: UUID?,
        evidenceID: String?
    ) -> [FH6TuneMenuCaptureIssue] {
        var issues: [FH6TuneMenuCaptureIssue] = []
        if !snapshot.isValid {
            issues.append(.invalidBaseSnapshot)
        }
        if snapshot.car.game != .fh6 {
            issues.append(.unsupportedGame(snapshot.car.game))
        }
        if snapshot.car.catalogReference == nil {
            issues.append(.missingCatalogIdentity)
        } else if snapshot.car.catalogValuesModified {
            issues.append(.modifiedCatalogIdentity)
        }
        if snapshot.capabilityProfile.parts.contains(where: { $0.availability == .installed }) {
            issues.append(.installedPartsPresent)
        }

        let build = normalized(gameBuildVersion)
        if build.isEmpty {
            issues.append(.missingGameBuildVersion)
        } else if canonicalText(gameBuildVersion) == nil {
            issues.append(.invalidGameBuildVersion)
        } else if let existing = snapshot.gameBuild.version.map(normalized),
                  !existing.isEmpty,
                  existing != build {
            issues.append(.mismatchedGameBuild(expected: existing, entered: build))
        }
        if let upgradeBuild = verifiedUpgradeBuild(in: snapshot),
           !build.isEmpty,
           upgradeBuild != build {
            issues.append(.mismatchedUpgradeGameBuild(expected: upgradeBuild, entered: build))
        }

        let compound = normalized(tireCompoundDisplayName)
        if compound.isEmpty {
            issues.append(.missingTireCompound)
        } else if canonicalText(tireCompoundDisplayName) == nil {
            issues.append(.invalidTireCompound)
        }
        if !(1...10).contains(forwardGearCount) {
            issues.append(.invalidGearCount(forwardGearCount))
        } else {
            let expected = TuneFieldID.expectedFields(
                drivetrain: snapshot.car.drivetrain,
                gearCount: forwardGearCount
            )
            let expectedSet = Set(expected)
            let groups = Dictionary(grouping: controls, by: \.field)
            for field in expected {
                switch groups[field]?.count ?? 0 {
                case 0:
                    issues.append(.missingField(field))
                case 1:
                    if let observation = groups[field]?.first {
                        issues.append(contentsOf: fieldIssues(observation))
                    }
                default:
                    issues.append(.duplicateField(field))
                }
            }
            for field in groups.keys
                .filter({ !expectedSet.contains($0) })
                .sorted(by: { $0.stableID < $1.stableID }) {
                issues.append(.unexpectedField(field))
            }
        }

        if !exactUntouchedStockConfirmed {
            issues.append(.exactStockBuildNotConfirmed)
        }
        if !allSlidersRestoredConfirmed {
            issues.append(.slidersNotRestored)
        }
        if !personallyReadFromGameConfirmed {
            issues.append(.firstPartyReadingNotConfirmed)
        }
        if !localStoragePermitted {
            issues.append(.localUseNotPermitted)
        }
        if let evidenceID, normalized(evidenceID).isEmpty {
            issues.append(.invalidEvidenceID)
        }
        if snapshotID == snapshot.id {
            issues.append(.reusedSnapshotIdentity)
        }
        return issues
    }

    private func fieldIssues(
        _ observation: FH6TuneMenuFieldObservation
    ) -> [FH6TuneMenuCaptureIssue] {
        switch observation.availability {
        case .shownLocked, .notShown:
            let payload: [Any?] = [
                observation.minimum,
                observation.maximum,
                observation.step,
                observation.current,
                observation.unit
            ]
            return payload.contains(where: { $0 != nil })
                ? [.lockedFieldContainsValues(observation.field)]
                : []
        case .adjustable:
            guard let minimum = observation.minimum,
                  let maximum = observation.maximum,
                  let step = observation.step,
                  let current = observation.current,
                  let unit = observation.unit,
                  minimum < maximum else {
                return [.invalidAdjustableField(observation.field)]
            }
            let constraint = TuneFieldConstraint(
                field: observation.field,
                minimum: minimum,
                maximum: maximum,
                step: step,
                defaultValue: nil,
                currentValue: current,
                unit: unit,
                scope: .exactVehicleBuild,
                verification: .productionEligible,
                evidenceIDs: ["validation"]
            )
            let maximumStep = (maximum - minimum) / step
            guard constraint.validationIssues.isEmpty,
                  maximumStep.isFinite,
                  abs(maximumStep - maximumStep.rounded()) <= 1e-8 else {
                return [.invalidAdjustableField(observation.field)]
            }
            return []
        }
    }

    private func verifiedUpgradeBuild(in snapshot: VehicleBuildSnapshot) -> String? {
        let parts = snapshot.capabilityProfile.parts
        guard !parts.isEmpty,
              parts.allSatisfy({
                  $0.availability == .available || $0.availability == .unavailable
              }) else {
            return nil
        }
        let builds = Set(parts.map { normalized($0.evidence.version) })
        return builds.count == 1 ? builds.first : nil
    }

    private func canonicalText(_ value: String) -> String? {
        let text = normalized(value)
        guard !text.isEmpty,
              text.count <= 120,
              !text.unicodeScalars.contains(where: {
                  CharacterSet.controlCharacters.contains($0)
              }) else {
            return nil
        }
        return text
    }

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
