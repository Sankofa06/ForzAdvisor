//
//  TuneAccuracyContractTests.swift
//  forzadvisorTests
//
//  Adversarial coverage for typed fields, constraints, snapshots, and ruleset
//  references before capability projection changes user-visible output.
//

import XCTest
@testable import forzadvisor

final class TuneAccuracyContractTests: XCTestCase {
    func testTuneFieldIDsUseStableStringEncoding() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        XCTAssertEqual(String(data: try encoder.encode(TuneFieldID.frontARB), encoding: .utf8), #""frontARB""#)
        XCTAssertEqual(String(data: try encoder.encode(TuneFieldID.gearRatio(6)), encoding: .utf8), #""gearRatio.6""#)
        XCTAssertEqual(try decoder.decode(TuneFieldID.self, from: Data(#""gearRatio.1""#.utf8)), .gearRatio(1))
        XCTAssertThrowsError(try decoder.decode(TuneFieldID.self, from: Data(#""gearRatio.0""#.utf8)))
        XCTAssertThrowsError(try decoder.decode(TuneFieldID.self, from: Data(#""futureField""#.utf8)))
        XCTAssertThrowsError(try encoder.encode(TuneFieldID.gearRatio(0)))
    }

    func testEveryFieldMapsToItsCapabilityExpectedUnitAndStableCodableValue() throws {
        let expected: [(TuneFieldID, TuneSetting, TuneUnit)] = [
            (.frontTirePressure, .tirePressure, .psi),
            (.rearTirePressure, .tirePressure, .psi),
            (.finalDrive, .finalDrive, .ratio),
            (.gearRatio(1), .gearRatios, .ratio),
            (.frontCamber, .alignment, .degrees),
            (.rearCamber, .alignment, .degrees),
            (.frontToe, .alignment, .degrees),
            (.rearToe, .alignment, .degrees),
            (.caster, .alignment, .degrees),
            (.frontARB, .frontARB, .scalar),
            (.rearARB, .rearARB, .scalar),
            (.frontSpringRate, .springRates, .poundsPerInch),
            (.rearSpringRate, .springRates, .poundsPerInch),
            (.frontRideHeight, .rideHeight, .inches),
            (.rearRideHeight, .rideHeight, .inches),
            (.frontRebound, .damping, .scalar),
            (.rearRebound, .damping, .scalar),
            (.frontBump, .damping, .scalar),
            (.rearBump, .damping, .scalar),
            (.frontAero, .frontAero, .pounds),
            (.rearAero, .rearAero, .pounds),
            (.brakeBalance, .brakes, .percent),
            (.brakePressure, .brakes, .percent),
            (.differentialAcceleration, .differentialAcceleration, .percent),
            (.differentialDeceleration, .differentialDeceleration, .percent),
            (.frontDifferentialAcceleration, .differentialAcceleration, .percent),
            (.frontDifferentialDeceleration, .differentialDeceleration, .percent),
            (.rearDifferentialAcceleration, .differentialAcceleration, .percent),
            (.rearDifferentialDeceleration, .differentialDeceleration, .percent),
            (.differentialCenterBalance, .differentialCenter, .percentRear)
        ]

        for (field, setting, unit) in expected {
            XCTAssertEqual(field.setting, setting, "Incorrect setting for \(field)")
            XCTAssertEqual(field.expectedUnit, unit, "Incorrect unit for \(field)")
            let decoded = try JSONDecoder().decode(
                TuneFieldID.self,
                from: JSONEncoder().encode(field)
            )
            XCTAssertEqual(decoded, field, "Unstable Codable value for \(field)")
        }
    }

    func testConstraintAcceptsOnlyFiniteInRangeOnStepValues() {
        let constraint = tireConstraint()

        XCTAssertTrue(constraint.validationIssues.isEmpty)
        XCTAssertTrue(constraint.accepts(15))
        XCTAssertTrue(constraint.accepts(40))
        XCTAssertTrue(constraint.accepts(30.0000000001))
        XCTAssertFalse(constraint.accepts(14.9))
        XCTAssertFalse(constraint.accepts(40.1))
        XCTAssertFalse(constraint.accepts(29.95))
        XCTAssertFalse(constraint.accepts(.nan))
        XCTAssertFalse(constraint.accepts(.infinity))
    }

    func testConstraintValidationRejectsInvalidRangesUnitsValuesAndEvidence() {
        var constraint = tireConstraint()
        constraint.minimum = 40
        constraint.maximum = 15
        constraint.step = 0
        constraint.defaultValue = .infinity
        constraint.currentValue = 29.95
        constraint.unit = .degrees
        constraint.evidenceIDs = ["", "same", "same"]

        let issues = constraint.validationIssues
        XCTAssertTrue(issues.contains(.nonFiniteValue))
        XCTAssertTrue(issues.contains(.invertedRange))
        XCTAssertTrue(issues.contains(.invalidStep))
        XCTAssertTrue(issues.contains(.wrongUnit(expected: .psi, actual: .degrees)))
        XCTAssertTrue(issues.contains(.missingEvidence))
        XCTAssertTrue(issues.contains(.duplicateEvidenceID("same")))
    }

    func testValidSnapshotRoundTripsLosslessly() throws {
        let snapshot = validSnapshot()
        XCTAssertTrue(snapshot.isValid, "Unexpected issues: \(snapshot.validationIssues)")

        let decoded = try JSONDecoder().decode(
            VehicleBuildSnapshot.self,
            from: JSONEncoder().encode(snapshot)
        )
        XCTAssertEqual(decoded, snapshot)
    }

    func testCapabilityOnlySnapshotCanRepresentAnUnknownGameBuild() throws {
        var snapshot = validSnapshot()
        snapshot.kind = .capabilityOnly
        snapshot.gameBuild.version = nil
        snapshot.gameBuild.capturedAt = nil
        snapshot.tireCompound = nil
        snapshot.gearCount = nil
        snapshot.constraints = []
        snapshot.evidenceSources = []

        XCTAssertTrue(snapshot.isValid, "Unexpected issues: \(snapshot.validationIssues)")
        XCTAssertFalse(snapshot.gameBuild.hasKnownVersion)
        XCTAssertEqual(
            try JSONDecoder().decode(VehicleBuildSnapshot.self, from: JSONEncoder().encode(snapshot)),
            snapshot
        )
    }

    func testExactObservationRequiresCompleteKnownGameBuild() {
        var snapshot = validSnapshot()
        snapshot.gameBuild.version = nil
        snapshot.gameBuild.capturedAt = nil

        XCTAssertTrue(snapshot.validationIssues.contains(.exactBuildObservationRequiresVersion))

        snapshot.kind = .capabilityOnly
        snapshot.constraints = []
        snapshot.evidenceSources = []
        snapshot.tireCompound = nil
        snapshot.gearCount = nil
        snapshot.gameBuild.version = "2026.07"

        XCTAssertTrue(snapshot.validationIssues.contains(.incompleteGameBuildReference))
    }

    func testCapabilityOnlySnapshotRejectsExactDataButAcceptsVersionlessGlobalEvidence() {
        var snapshot = validSnapshot()
        snapshot.kind = .capabilityOnly
        snapshot.gameBuild.version = nil
        snapshot.gameBuild.capturedAt = nil
        snapshot.tireCompound = nil
        snapshot.gearCount = nil

        XCTAssertTrue(snapshot.validationIssues.contains(.capabilityOnlyContainsExactBuildData))
        XCTAssertTrue(snapshot.validationIssues.contains(.exactConstraintRequiresKnownBuild(.frontTirePressure)))
        XCTAssertTrue(snapshot.validationIssues.contains(.exactEvidenceRequiresKnownBuild("capture.fh6.supra")))

        var globalConstraint = tireConstraint()
        globalConstraint.scope = .gameGlobal
        globalConstraint.evidenceIDs = ["rules.fh6.global"]
        snapshot.constraints = [globalConstraint]
        snapshot.evidenceSources = [TuneDataProvenance(
            id: "rules.fh6.global",
            game: .fh6,
            gameBuildVersion: nil,
            scope: .gameGlobal,
            source: "forzadvisor.rules",
            version: "1",
            capturedAt: Date(timeIntervalSinceReferenceDate: 20),
            confidence: .high
        )]

        XCTAssertTrue(snapshot.isValid, "Unexpected issues: \(snapshot.validationIssues)")
    }

    func testCapabilityOnlySnapshotRejectsInstalledPartsAndTireCompound() {
        var snapshot = validSnapshot()
        snapshot.kind = .capabilityOnly
        snapshot.gameBuild.version = nil
        snapshot.gameBuild.capturedAt = nil
        snapshot.gearCount = nil
        snapshot.constraints = []
        snapshot.evidenceSources = []
        snapshot.tireCompound = nil
        snapshot.capabilityProfile.parts = [TuneVehiclePart(
            partID: .raceTransmission,
            availability: .installed,
            evidence: TuneEvidence(
                confidence: .high,
                source: "adversarial.payload",
                version: "1"
            )
        )]

        XCTAssertTrue(snapshot.validationIssues.contains(.capabilityOnlyContainsExactBuildData))

        snapshot.capabilityProfile.parts = []
        snapshot.tireCompound = TireCompoundReference(
            id: "stock",
            displayName: "Stock",
            evidenceIDs: []
        )

        XCTAssertTrue(snapshot.validationIssues.contains(.capabilityOnlyContainsExactBuildData))
    }

    func testLegacySnapshotWithoutKindDecodesFailClosed() throws {
        let encoded = try JSONEncoder().encode(validSnapshot())
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "kind")
        let legacyData = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(VehicleBuildSnapshot.self, from: legacyData)

        XCTAssertEqual(decoded.kind, .capabilityOnly)
        XCTAssertFalse(decoded.isValid)
        XCTAssertTrue(decoded.validationIssues.contains(.capabilityOnlyContainsExactBuildData))
    }

    func testSnapshotRejectsIdentityDrivetrainCatalogAndSchemaMismatches() {
        var snapshot = validSnapshot()
        snapshot.schemaVersion = 99
        snapshot.gameBuild.game = .fh5
        snapshot.capabilityProfile.drivetrain = .awd
        snapshot.capabilityProfile.vehicle.model = "Wrong car"
        snapshot.capabilityProfile.vehicle.catalogID = "fh6:wrong"

        let issues = snapshot.validationIssues
        XCTAssertTrue(issues.contains(.unsupportedSchema(99)))
        XCTAssertTrue(issues.contains(.gameMismatch))
        XCTAssertTrue(issues.contains(.drivetrainMismatch))
        XCTAssertTrue(issues.contains(.vehicleIdentityMismatch))
        XCTAssertTrue(issues.contains(.catalogIdentityMismatch))
    }

    func testSnapshotRejectsIncompleteIdentityAndNonpositiveVehicleStatistics() {
        var snapshot = validSnapshot()
        snapshot.car.year = 0
        snapshot.car.make = ""
        snapshot.car.peakHorsepower = 0
        snapshot.car.peakTorqueFootPounds = -1
        snapshot.capabilityProfile.vehicle.year = 0
        snapshot.capabilityProfile.vehicle.make = ""

        let issues = snapshot.validationIssues
        XCTAssertTrue(issues.contains(.incompleteVehicleIdentity))
        XCTAssertTrue(issues.contains(.invalidVehicleStatistics))
    }

    func testSnapshotRejectsDuplicateFieldsBadGearsAndUnresolvedEvidence() {
        var snapshot = validSnapshot()
        var gear = tireConstraint()
        gear.field = .gearRatio(7)
        gear.unit = .ratio
        gear.minimum = 0.5
        gear.maximum = 6
        gear.step = 0.01
        gear.defaultValue = 1
        gear.currentValue = 1
        gear.evidenceIDs = ["missing"]
        snapshot.gearCount = 6
        snapshot.constraints = [tireConstraint(), tireConstraint(), gear]

        let issues = snapshot.validationIssues
        XCTAssertTrue(issues.contains(.duplicateField(.frontTirePressure)))
        XCTAssertTrue(issues.contains(.gearIndexExceedsCount(index: 7, count: 6)))
        XCTAssertTrue(issues.contains(.danglingEvidenceID("missing")))
    }

    func testGearConstraintRequiresKnownValidGearCount() {
        var snapshot = validSnapshot()
        var gear = tireConstraint()
        gear.field = .gearRatio(1)
        gear.unit = .ratio
        snapshot.constraints = [gear]
        snapshot.gearCount = nil
        XCTAssertTrue(snapshot.validationIssues.contains(.gearIndexWithoutCount(1)))

        snapshot.gearCount = 0
        XCTAssertTrue(snapshot.validationIssues.contains(.invalidGearCount(0)))
    }

    func testSnapshotBuildFingerprintDetectsBuildChangesButIgnoresOriginFlag() {
        let snapshot = validSnapshot()
        var sameBuild = snapshot.car
        sameBuild.catalogValuesModified.toggle()
        XCTAssertTrue(snapshot.matches(car: sameBuild))

        sameBuild.weightPounds += 1
        XCTAssertFalse(snapshot.matches(car: sameBuild))
    }

    func testRulesetDescriptorValidationAndImmutableReference() throws {
        let descriptor = TuneRulesetDescriptor(
            id: "forzadvisor.fh6.local",
            game: .fh6,
            schemaVersion: 1,
            algorithmVersion: "1.0.0",
            knowledgeRevision: "2026.07.1",
            validationStatus: .experimental,
            provenanceIDs: ["internal.fh6.v1"]
        )
        XCTAssertTrue(descriptor.validationIssues.isEmpty)
        let reference = try XCTUnwrap(TuneRulesetReference(descriptor: descriptor))
        XCTAssertEqual(reference.id, descriptor.id)
        XCTAssertEqual(reference.game, .fh6)
        XCTAssertEqual(reference.validationStatus, .experimental)
        XCTAssertEqual(reference.provenanceIDs, descriptor.provenanceIDs)

        var invalid = descriptor
        invalid.id = " "
        invalid.schemaVersion = 0
        invalid.algorithmVersion = ""
        invalid.knowledgeRevision = ""
        invalid.provenanceIDs = ["same", "same"]
        XCTAssertTrue(invalid.validationIssues.contains(.invalidID))
        XCTAssertTrue(invalid.validationIssues.contains(.invalidSchemaVersion))
        XCTAssertTrue(invalid.validationIssues.contains(.invalidAlgorithmVersion))
        XCTAssertTrue(invalid.validationIssues.contains(.invalidKnowledgeRevision))
        XCTAssertTrue(invalid.validationIssues.contains(.duplicateProvenanceID("same")))
        XCTAssertNil(TuneRulesetReference(descriptor: invalid))
    }

    func testMalformedPersistedRulesetReferenceDecodesButCannotClaimTrust() throws {
        let malformed = #"""
        {
          "id":" ","game":"fh6","schemaVersion":0,
          "algorithmVersion":"","knowledgeRevision":"",
          "validationStatus":"validated","provenanceIDs":["same","same"]
        }
        """#

        let reference = try JSONDecoder().decode(
            TuneRulesetReference.self,
            from: Data(malformed.utf8)
        )
        XCTAssertFalse(reference.isValid)
        XCTAssertNil(reference.trustedValidationStatus)
        XCTAssertTrue(reference.validationIssues.contains(.invalidID))
        XCTAssertTrue(reference.validationIssues.contains(.invalidSchemaVersion))
        XCTAssertTrue(reference.validationIssues.contains(.duplicateProvenanceID("same")))
    }

    func testLegacyTunePayloadDecodesWithoutTypedAccuracyKeys() throws {
        let legacy = #"""
        {
          "id":"00000000-0000-0000-0000-000000000001",
          "request":{
            "car":{
              "game":"fh6","year":2020,"make":"Toyota","model":"GR Supra",
              "weightPounds":3397,"frontWeightPercent":51,"performanceIndex":616,
              "performanceClass":"A","drivetrain":"RWD",
              "peakHorsepower":335,"peakTorqueFootPounds":365
            },
            "discipline":"road"
          },
          "sections":[{"title":"Tires","symbolName":"circle.dashed","lines":[
            {"label":"Front pressure","value":"27.0","unit":"PSI"}
          ]}],
          "notes":{"bias":"Legacy","ifPushesWide":"A","ifSnapsOnLift":"B","retuneTrigger":"C"},
          "generatedAt":0
        }
        """#

        let tune = try JSONDecoder().decode(TuneResult.self, from: Data(legacy.utf8))
        XCTAssertNil(tune.request.buildSnapshot)
        XCTAssertNil(tune.rulesetReference)
        XCTAssertNil(tune.sections.first?.lines.first?.fieldID)
        XCTAssertEqual(tune.sections.first?.lines.first?.value, "27.0")
    }

    func testTypedTuneMetadataRoundTripsAndSurvivesProviderAnnotation() throws {
        let descriptor = TuneRulesetDescriptor(
            id: "forzadvisor.fh6.local",
            game: .fh6,
            schemaVersion: 1,
            algorithmVersion: "1.0.0",
            knowledgeRevision: "2026.07.1",
            validationStatus: .experimental,
            provenanceIDs: ["internal.fh6.v1"]
        )
        let snapshot = validSnapshot()
        let request = TuneRequest(car: snapshot.car, discipline: .road, buildSnapshot: snapshot)
        let tune = TuneResult(
            request: request,
            sections: [TuneSection(title: "Tires", symbolName: "circle.dashed", lines: [
                TuneLine(
                    label: "Front pressure",
                    value: "27.0",
                    unit: "PSI",
                    detail: nil,
                    fieldID: .frontTirePressure
                )
            ])],
            notes: TuneNotes(bias: "Experimental", ifPushesWide: "A", ifSnapsOnLift: "B", retuneTrigger: "C"),
            rulesetReference: try XCTUnwrap(TuneRulesetReference(descriptor: descriptor))
        ).withProviderInfo(.direct(.offlineFormula))

        let decoded = try JSONDecoder().decode(TuneResult.self, from: JSONEncoder().encode(tune))
        XCTAssertEqual(decoded, tune)
        XCTAssertEqual(decoded.request.buildSnapshot, snapshot)
        XCTAssertEqual(decoded.sections.first?.lines.first?.fieldID, .frontTirePressure)
        XCTAssertEqual(decoded.rulesetReference?.algorithmVersion, "1.0.0")
    }

    private func tireConstraint() -> TuneFieldConstraint {
        TuneFieldConstraint(
            field: .frontTirePressure,
            minimum: 15,
            maximum: 40,
            step: 0.1,
            defaultValue: 30,
            currentValue: 30,
            unit: .psi,
            scope: .exactVehicleBuild,
            verification: .productionEligible,
            evidenceIDs: ["capture.fh6.supra"]
        )
    }

    private func validSnapshot() -> VehicleBuildSnapshot {
        let car = CarInput(
            game: .fh6,
            year: 2020,
            make: "Toyota",
            model: "GR Supra",
            weightPounds: 3_397,
            frontWeightPercent: 51,
            performanceIndex: 616,
            performanceClass: .a,
            drivetrain: .rwd,
            peakHorsepower: 335,
            peakTorqueFootPounds: 365,
            catalogReference: CatalogCarReference(
                entryID: "fh6:2020-toyota-gr-supra",
                revision: "2026.07.21.1",
                reviewedAt: Date(timeIntervalSinceReferenceDate: 10),
                verificationStatus: .communityCrossChecked,
                sources: []
            )
        )
        let profile = TuneVehicleCapabilityProfile(
            vehicle: TuneVehicleIdentity(
                game: .fh6,
                catalogID: "fh6:2020-toyota-gr-supra",
                year: 2020,
                make: "Toyota",
                model: "GR Supra"
            ),
            drivetrain: .rwd,
            parts: [],
            stockAdjustableSettings: []
        )
        let evidence = TuneDataProvenance(
            id: "capture.fh6.supra",
            game: .fh6,
            gameBuildVersion: "2026.07",
            scope: .exactVehicleBuild,
            source: "forzadvisor.user-capture",
            version: "1",
            capturedAt: Date(timeIntervalSinceReferenceDate: 20),
            confidence: .high
        )
        return VehicleBuildSnapshot(
            schemaVersion: VehicleBuildSnapshot.currentSchemaVersion,
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            kind: .exactBuildObservation,
            capturedAt: Date(timeIntervalSinceReferenceDate: 20),
            gameBuild: GameBuildReference(
                game: .fh6,
                version: "2026.07",
                capturedAt: Date(timeIntervalSinceReferenceDate: 20)
            ),
            car: car,
            capabilityProfile: profile,
            tireCompound: TireCompoundReference(
                id: "stock",
                displayName: "Stock",
                evidenceIDs: [evidence.id]
            ),
            gearCount: 6,
            constraints: [tireConstraint()],
            evidenceSources: [evidence]
        )
    }
}
