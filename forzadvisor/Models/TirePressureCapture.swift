//
//  TirePressureCapture.swift
//  forzadvisor
//
//  User-attested, local-only evidence for the tire controls exposed by one
//  exact FH6 stock vehicle build.
//

import Foundation

enum TirePressureCaptureAxle: String, Codable, Equatable, Sendable {
    case front
    case rear

    var title: String {
        rawValue.capitalized
    }
}

struct TirePressureRangeCapture: Codable, Equatable, Sendable {
    var minimumPSI: Double
    var maximumPSI: Double
    var stepPSI: Double
    var currentPSI: Double
}

enum TirePressureCaptureIssue: Error, LocalizedError, Equatable {
    case invalidBaseSnapshot
    case requiresCapabilityOnlySnapshot
    case unsupportedGame(ForzaGame)
    case missingCatalogIdentity
    case modifiedCatalogIdentity
    case missingGameBuildVersion
    case mismatchedGameBuild(expected: String, entered: String)
    case missingTireCompound
    case invalidGearCount(Int)
    case exactStockBuildNotConfirmed
    case localUseNotPermitted
    case nonFiniteValue(TirePressureCaptureAxle)
    case invalidRange(TirePressureCaptureAxle)
    case invalidStep(TirePressureCaptureAxle)
    case maximumOffStep(TirePressureCaptureAxle)
    case currentOutOfRange(TirePressureCaptureAxle)
    case currentOffStep(TirePressureCaptureAxle)
    case invalidEvidenceID
    case reusedSnapshotIdentity

    var errorDescription: String? {
        switch self {
        case .invalidBaseSnapshot:
            "The selected catalog snapshot is not valid."
        case .requiresCapabilityOnlySnapshot:
            "Tire verification must start from an unverified catalog snapshot."
        case .unsupportedGame(let game):
            "Tire verification is not available for \(game.title) yet."
        case .missingCatalogIdentity:
            "Choose an unedited car from the catalog before verifying tire pressures."
        case .modifiedCatalogIdentity:
            "The selected catalog car was edited. Restore its stock catalog values before verifying it."
        case .missingGameBuildVersion:
            "Enter the exact game build version shown in FH6."
        case .mismatchedGameBuild(let expected, let entered):
            "The upgrade observation uses FH6 build \(expected), not \(entered). Use the same exact build."
        case .missingTireCompound:
            "Enter the tire compound shown for this stock build."
        case .invalidGearCount(let count):
            "Forward gear count must be between 1 and 10, not \(count)."
        case .exactStockBuildNotConfirmed:
            "Confirm that the in-game stock build exactly matches the selected catalog car."
        case .localUseNotPermitted:
            "Allow ForzAdvisor to store and use this observation locally for this tune."
        case .nonFiniteValue(let axle):
            "\(axle.title) tire values must be finite numbers."
        case .invalidRange(let axle):
            "\(axle.title) minimum PSI must be lower than maximum PSI."
        case .invalidStep(let axle):
            "\(axle.title) tire step must be greater than zero."
        case .maximumOffStep(let axle):
            "\(axle.title) maximum PSI must land on a captured slider step."
        case .currentOutOfRange(let axle):
            "\(axle.title) current PSI must be inside the captured range."
        case .currentOffStep(let axle):
            "\(axle.title) current PSI must land on a captured slider step."
        case .invalidEvidenceID:
            "The local observation identifier is invalid."
        case .reusedSnapshotIdentity:
            "The exact build observation must have a new snapshot identifier."
        }
    }
}

enum TirePressureCaptureError: Error, LocalizedError {
    case invalid([TirePressureCaptureIssue])
    case invalidGeneratedSnapshot([VehicleBuildSnapshotIssue])

    var errorDescription: String? {
        switch self {
        case .invalid(let issues):
            issues.first?.errorDescription ?? "The tire-pressure observation is invalid."
        case .invalidGeneratedSnapshot:
            "The tire-pressure observation could not create a valid exact build snapshot."
        }
    }
}

struct TirePressureCapture: Codable, Equatable, Sendable {
    static let provenanceSource = "forzadvisor.local.user-observation"
    static let provenanceVersion = "2"

    var gameBuildVersion: String
    var tireCompound: String
    var gearCount: Int
    var front: TirePressureRangeCapture
    var rear: TirePressureRangeCapture
    var exactStockBuildConfirmed: Bool
    var localUsePermitted: Bool

    func validationIssues(upgrading snapshot: VehicleBuildSnapshot) -> [TirePressureCaptureIssue] {
        validationIssues(
            upgrading: snapshot,
            snapshotID: nil,
            evidenceID: nil
        )
    }

    func exactBuildSnapshot(
        upgrading snapshot: VehicleBuildSnapshot,
        capturedAt: Date = .now,
        snapshotID: UUID = UUID(),
        evidenceID: String = "forzadvisor.local.user-observation.\(UUID().uuidString.lowercased())"
    ) throws -> VehicleBuildSnapshot {
        let issues = validationIssues(
            upgrading: snapshot,
            snapshotID: snapshotID,
            evidenceID: evidenceID
        )
        guard issues.isEmpty else {
            throw TirePressureCaptureError.invalid(issues)
        }

        let normalizedBuildVersion = normalized(gameBuildVersion)
        let normalizedCompound = normalized(tireCompound)
        let normalizedEvidenceID = normalized(evidenceID)
        let evidence = TuneDataProvenance(
            id: normalizedEvidenceID,
            game: .fh6,
            gameBuildVersion: normalizedBuildVersion,
            scope: .exactVehicleBuild,
            source: Self.provenanceSource,
            version: Self.provenanceVersion,
            capturedAt: capturedAt,
            confidence: .medium,
            usagePermission: .permitted
        )

        let capturedFields: Set<TuneFieldID> = [.frontTirePressure, .rearTirePressure]
        let preservedConstraints = snapshot.constraints.filter { !capturedFields.contains($0.field) }
        let exactSnapshot = VehicleBuildSnapshot(
            schemaVersion: VehicleBuildSnapshot.currentSchemaVersion,
            id: snapshotID,
            kind: .exactBuildObservation,
            capturedAt: capturedAt,
            gameBuild: GameBuildReference(
                game: .fh6,
                version: normalizedBuildVersion,
                capturedAt: capturedAt
            ),
            car: snapshot.car,
            capabilityProfile: snapshot.capabilityProfile,
            tireCompound: TireCompoundReference(
                id: "forzadvisor.local.observed-tire-compound",
                displayName: normalizedCompound,
                evidenceIDs: [normalizedEvidenceID]
            ),
            gearCount: gearCount,
            constraints: preservedConstraints + [
                constraint(for: .frontTirePressure, range: front, evidenceID: normalizedEvidenceID),
                constraint(for: .rearTirePressure, range: rear, evidenceID: normalizedEvidenceID)
            ],
            evidenceSources: snapshot.evidenceSources + [evidence]
        )

        guard exactSnapshot.isValid else {
            throw TirePressureCaptureError.invalidGeneratedSnapshot(exactSnapshot.validationIssues)
        }
        return exactSnapshot
    }

    private func validationIssues(
        upgrading snapshot: VehicleBuildSnapshot,
        snapshotID: UUID?,
        evidenceID: String?
    ) -> [TirePressureCaptureIssue] {
        var issues: [TirePressureCaptureIssue] = []

        if !snapshot.isValid {
            issues.append(.invalidBaseSnapshot)
        }
        if snapshot.kind != .capabilityOnly {
            issues.append(.requiresCapabilityOnlySnapshot)
        }
        if snapshot.car.game != .fh6 {
            issues.append(.unsupportedGame(snapshot.car.game))
        }
        if snapshot.car.catalogReference == nil {
            issues.append(.missingCatalogIdentity)
        } else if snapshot.car.catalogValuesModified {
            issues.append(.modifiedCatalogIdentity)
        }
        let enteredBuild = normalized(gameBuildVersion)
        if enteredBuild.isEmpty {
            issues.append(.missingGameBuildVersion)
        } else if let knownBuild = snapshot.gameBuild.version.map(normalized),
                  !knownBuild.isEmpty,
                  knownBuild != enteredBuild {
            issues.append(.mismatchedGameBuild(expected: knownBuild, entered: enteredBuild))
        }
        if normalized(tireCompound).isEmpty {
            issues.append(.missingTireCompound)
        }
        if !(1...10).contains(gearCount) {
            issues.append(.invalidGearCount(gearCount))
        }
        if !exactStockBuildConfirmed {
            issues.append(.exactStockBuildNotConfirmed)
        }
        if !localUsePermitted {
            issues.append(.localUseNotPermitted)
        }

        issues.append(contentsOf: rangeIssues(front, axle: .front))
        issues.append(contentsOf: rangeIssues(rear, axle: .rear))

        if let evidenceID, normalized(evidenceID).isEmpty {
            issues.append(.invalidEvidenceID)
        }
        if snapshotID == snapshot.id {
            issues.append(.reusedSnapshotIdentity)
        }
        return issues
    }

    private func rangeIssues(
        _ range: TirePressureRangeCapture,
        axle: TirePressureCaptureAxle
    ) -> [TirePressureCaptureIssue] {
        let values = [range.minimumPSI, range.maximumPSI, range.stepPSI, range.currentPSI]
        guard values.allSatisfy(\.isFinite) else {
            return [.nonFiniteValue(axle)]
        }

        var issues: [TirePressureCaptureIssue] = []
        if range.minimumPSI >= range.maximumPSI {
            issues.append(.invalidRange(axle))
        }
        if range.stepPSI <= 0 {
            issues.append(.invalidStep(axle))
        }
        if range.minimumPSI < range.maximumPSI,
           range.stepPSI > 0,
           !isOnStep(range.maximumPSI, in: range) {
            issues.append(.maximumOffStep(axle))
        }
        if range.currentPSI < range.minimumPSI || range.currentPSI > range.maximumPSI {
            issues.append(.currentOutOfRange(axle))
        } else if range.stepPSI > 0 && !isOnStep(range.currentPSI, in: range) {
            issues.append(.currentOffStep(axle))
        }
        return issues
    }

    private func isOnStep(_ value: Double, in range: TirePressureRangeCapture) -> Bool {
        let quotient = (value - range.minimumPSI) / range.stepPSI
        return abs(quotient - quotient.rounded()) <= 1e-8
    }

    private func constraint(
        for field: TuneFieldID,
        range: TirePressureRangeCapture,
        evidenceID: String
    ) -> TuneFieldConstraint {
        TuneFieldConstraint(
            field: field,
            minimum: range.minimumPSI,
            maximum: range.maximumPSI,
            step: range.stepPSI,
            defaultValue: nil,
            currentValue: range.currentPSI,
            unit: .psi,
            scope: .exactVehicleBuild,
            verification: .productionEligible,
            evidenceIDs: [evidenceID]
        )
    }

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension TirePressureCapture {
    private enum CodingKeys: String, CodingKey {
        case gameBuildVersion
        case tireCompound
        case gearCount
        case front
        case rear
        case exactStockBuildConfirmed
        case localUsePermitted
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        gameBuildVersion = try container.decode(String.self, forKey: .gameBuildVersion)
        tireCompound = try container.decode(String.self, forKey: .tireCompound)
        gearCount = try container.decodeIfPresent(Int.self, forKey: .gearCount) ?? 0
        front = try container.decode(TirePressureRangeCapture.self, forKey: .front)
        rear = try container.decode(TirePressureRangeCapture.self, forKey: .rear)
        exactStockBuildConfirmed = try container.decode(Bool.self, forKey: .exactStockBuildConfirmed)
        localUsePermitted = try container.decode(Bool.self, forKey: .localUsePermitted)
    }
}
