//
//  TuneCapabilityResolverTests.swift
//  forzadvisorTests
//
//  Focused coverage for honest tune unlock and exact-purchase resolution.
//

import XCTest
@testable import forzadvisor

final class TuneCapabilityResolverTests: XCTestCase {
    func testCatalogDefinesEveryStablePartWithCanonicalTerms() {
        XCTAssertEqual(Set(TunePartCatalog.parts.map(\.id)), Set(TunePartID.allCases))
        XCTAssertEqual(TunePartCatalog.parts.count, TunePartID.allCases.count)
        for id in TunePartID.allCases {
            XCTAssertEqual(TunePartCatalog.definition(for: id).id, id)
        }
        XCTAssertEqual(TunePartCatalog.definition(for: .sportTransmission).label, "Sport Transmission")
        XCTAssertTrue(TunePartCatalog.definition(for: .raceTransmission).aliases.contains("Race Gearbox"))
        XCTAssertEqual(TunePartCatalog.definition(for: .raceFrontAntirollBar).slot, .frontAntirollBar)
        XCTAssertEqual(TunePartCatalog.definition(for: .raceRearAntirollBar).slot, .rearAntirollBar)
        XCTAssertEqual(TunePartCatalog.definition(for: .raceFrontBumper).slot, .frontAero)
        XCTAssertEqual(TunePartCatalog.definition(for: .raceRearWing).slot, .rearAero)
        XCTAssertEqual(TunePartCatalog.definition(for: .raceTransmission).category, .drivetrain)
        XCTAssertEqual(TunePartCatalog.definition(for: .raceSuspension).category, .platformAndHandling)
        XCTAssertEqual(TunePartCatalog.definition(for: .raceFrontBumper).category, .aeroAndAppearance)
        XCTAssertEqual(TunePartCategory.drivetrain.label, "Drivetrain")
        XCTAssertEqual(TunePartCategory.platformAndHandling.label, "Platform and Handling")
        XCTAssertEqual(TunePartCategory.aeroAndAppearance.label, "Aero and Appearance")
        XCTAssertEqual(TunePartCatalog.definition(for: .raceSuspension).label, "Race Spring and Dampers")
        XCTAssertTrue(
            TunePartCatalog.definition(for: .raceSuspension).aliases.contains("Race Springs and Dampers")
        )
    }

    func testEveryPartSlotHasItsCanonicalHumanReadableLabel() {
        let expectedLabels: [TunePartSlot: String] = [
            .transmission: "Transmission",
            .suspension: "Spring and Dampers",
            .frontAntirollBar: "Front Antiroll Bars",
            .rearAntirollBar: "Rear Antiroll Bars",
            .frontAero: "Front Bumper",
            .rearAero: "Rear Wing",
            .brakes: "Brakes",
            .differential: "Differential"
        ]

        XCTAssertEqual(Set(expectedLabels.keys), Set(TunePartSlot.allCases))
        for slot in TunePartSlot.allCases {
            XCTAssertEqual(slot.label, expectedLabels[slot])
        }
    }

    func testFrontAndRearAdjustmentGatesRemainIndependent() {
        let profile = makeProfile(parts: [
            vehiclePart(.raceFrontAntirollBar, .available),
            vehiclePart(.raceRearAntirollBar, .unavailable),
            vehiclePart(.raceFrontBumper, .installed),
            vehiclePart(.raceRearWing, .unavailable)
        ])

        let resolution = TuneCapabilityResolver(game: .fh5).resolve(
            profile: profile,
            settings: [.frontARB, .rearARB, .frontAero, .rearAero]
        )

        XCTAssertEqual(capability(.frontARB, in: resolution).status, .requiresUpgrade)
        XCTAssertEqual(capability(.frontARB, in: resolution).requiredPurchaseIDs, [.raceFrontAntirollBar])
        XCTAssertEqual(capability(.rearARB, in: resolution).status, .unavailable)
        XCTAssertEqual(capability(.frontAero, in: resolution).status, .installedUpgrade)
        XCTAssertEqual(capability(.rearAero, in: resolution).status, .unavailable)
    }

    func testStockInstalledOverrideWinsOverGlobalUpgradeRequirement() {
        let overrideEvidence = TuneEvidence(
            confidence: .high,
            source: "catalog.fh6.car-42",
            version: "42.3"
        )
        let profile = makeProfile(
            game: .fh6,
            parts: [
                vehiclePart(.raceTransmission, .unavailable),
                vehiclePart(.driftTransmission, .unavailable)
            ],
            stockAdjustableSettings: [
                StockAdjustableSetting(setting: .gearRatios, evidence: overrideEvidence)
            ]
        )

        let result = TuneCapabilityResolver(game: .fh6).resolve(
            profile: profile,
            settings: [.gearRatios]
        )
        let gears = capability(.gearRatios, in: result)

        XCTAssertEqual(gears.status, .stockAvailable)
        XCTAssertTrue(gears.requiredPurchaseIDs.isEmpty)
        XCTAssertTrue(gears.evidence.contains(overrideEvidence))
    }

    func testSharedUpgradeProducesOneExactPurchase() {
        let profile = makeProfile(parts: [
            vehiclePart(.raceSuspension, .available),
            vehiclePart(.rallySuspension, .unavailable),
            vehiclePart(.offroadSuspension, .unavailable),
            vehiclePart(.driftSuspension, .unavailable)
        ])

        let result = TuneCapabilityResolver(game: .fh5).resolve(
            profile: profile,
            settings: [.alignment, .springRates, .rideHeight, .damping]
        )

        XCTAssertTrue(result.settings.allSatisfy { $0.status == .requiresUpgrade })
        XCTAssertEqual(result.requiredPurchases.map(\.id), [.raceSuspension])
    }

    func testUnknownAvailabilityRequiresConfirmationAndNeverGuessesPurchase() {
        let profile = makeProfile(parts: [
            vehiclePart(.sportTransmission, .available),
            vehiclePart(.raceTransmission, .unavailable)
        ])

        let result = TuneCapabilityResolver(game: .fh5).resolve(
            profile: profile,
            settings: [.finalDrive]
        )
        let finalDrive = capability(.finalDrive, in: result)

        XCTAssertEqual(finalDrive.status, .unknown)
        XCTAssertEqual(finalDrive.unresolvedPartIDs, [.driftTransmission])
        XCTAssertTrue(finalDrive.requiredPurchaseIDs.isEmpty)
        XCTAssertTrue(result.requiredPurchases.isEmpty)
        XCTAssertEqual(result.unresolvedConfirmations, [.driftTransmission])
    }

    func testProvenUnavailablePartsDoNotProducePurchasesOrConfirmations() {
        let profile = makeProfile(parts: [
            vehiclePart(.raceFrontBumper, .unavailable)
        ])

        let result = TuneCapabilityResolver(game: .fh5).resolve(
            profile: profile,
            settings: [.frontAero]
        )
        let frontAero = capability(.frontAero, in: result)

        XCTAssertEqual(frontAero.status, .unavailable)
        XCTAssertTrue(frontAero.requiredPurchaseIDs.isEmpty)
        XCTAssertTrue(frontAero.unresolvedPartIDs.isEmpty)
        XCTAssertTrue(result.requiredPurchases.isEmpty)
        XCTAssertTrue(result.unresolvedConfirmations.isEmpty)
    }

    func testSportTransmissionUnlocksFinalDriveButNotGearRatios() {
        let profile = makeProfile(parts: [
            vehiclePart(.sportTransmission, .available),
            vehiclePart(.raceTransmission, .unavailable),
            vehiclePart(.driftTransmission, .unavailable)
        ])

        let result = TuneCapabilityResolver(game: .fh5).resolve(
            profile: profile,
            settings: [.finalDrive, .gearRatios]
        )

        XCTAssertEqual(capability(.finalDrive, in: result).status, .requiresUpgrade)
        XCTAssertEqual(capability(.finalDrive, in: result).requiredPurchaseIDs, [.sportTransmission])
        XCTAssertEqual(capability(.gearRatios, in: result).status, .unavailable)
    }

    func testRaceTransmissionSupersedesSportForCombinedGearingPlan() {
        let profile = makeProfile(parts: [
            vehiclePart(.sportTransmission, .available),
            vehiclePart(.raceTransmission, .available),
            vehiclePart(.driftTransmission, .unavailable)
        ])

        let result = TuneCapabilityResolver(game: .fh5).resolve(
            profile: profile,
            settings: [.finalDrive, .gearRatios]
        )

        XCTAssertEqual(result.requiredPurchases.map(\.id), [.raceTransmission])
        XCTAssertEqual(capability(.finalDrive, in: result).requiredPurchaseIDs, [.raceTransmission])
        XCTAssertEqual(capability(.gearRatios, in: result).requiredPurchaseIDs, [.raceTransmission])
    }

    func testSportDifferentialUnlocksAccelerationButNotFullControls() {
        let differentialParts = [
            vehiclePart(.sportDifferential, .available),
            vehiclePart(.raceDifferential, .unavailable),
            vehiclePart(.rallyDifferential, .unavailable),
            vehiclePart(.offroadDifferential, .unavailable),
            vehiclePart(.driftDifferential, .unavailable)
        ]
        let rwd = makeProfile(drivetrain: .rwd, parts: differentialParts)

        let result = TuneCapabilityResolver(game: .fh5).resolve(
            profile: rwd,
            settings: [.differentialAcceleration, .differentialDeceleration, .differentialCenter]
        )

        XCTAssertEqual(capability(.differentialAcceleration, in: result).status, .requiresUpgrade)
        XCTAssertEqual(
            capability(.differentialAcceleration, in: result).requiredPurchaseIDs,
            [.sportDifferential]
        )
        XCTAssertEqual(capability(.differentialDeceleration, in: result).status, .unavailable)
        XCTAssertEqual(capability(.differentialCenter, in: result).status, .unavailable)
    }

    func testFullDifferentialUnlocksAWDCenterControl() {
        let profile = makeProfile(drivetrain: .awd, parts: [
            vehiclePart(.raceDifferential, .installed),
            vehiclePart(.rallyDifferential, .unavailable),
            vehiclePart(.offroadDifferential, .unavailable),
            vehiclePart(.driftDifferential, .unavailable)
        ])

        let result = TuneCapabilityResolver(game: .fh5).resolve(
            profile: profile,
            settings: [.differentialAcceleration, .differentialDeceleration, .differentialCenter]
        )

        XCTAssertTrue(result.settings.allSatisfy { $0.status == .installedUpgrade })
    }

    func testFullDifferentialSupersedesSportForCombinedControlPlan() {
        let profile = makeProfile(parts: [
            vehiclePart(.sportDifferential, .available),
            vehiclePart(.raceDifferential, .available),
            vehiclePart(.rallyDifferential, .unavailable),
            vehiclePart(.offroadDifferential, .unavailable),
            vehiclePart(.driftDifferential, .unavailable)
        ])

        let result = TuneCapabilityResolver(game: .fh5).resolve(
            profile: profile,
            settings: [.differentialAcceleration, .differentialDeceleration]
        )

        XCTAssertEqual(result.requiredPurchases.map(\.id), [.raceDifferential])
        XCTAssertEqual(
            capability(.differentialAcceleration, in: result).requiredPurchaseIDs,
            [.raceDifferential]
        )
        XCTAssertEqual(
            capability(.differentialDeceleration, in: result).requiredPurchaseIDs,
            [.raceDifferential]
        )
    }

    func testDrivetrainConstraintWinsOverImpossibleStockOverride() {
        let profile = makeProfile(
            drivetrain: .rwd,
            stockAdjustableSettings: [
                StockAdjustableSetting(
                    setting: .differentialCenter,
                    evidence: TuneEvidence(
                        confidence: .high,
                        source: "bad-import",
                        version: "1"
                    )
                )
            ]
        )

        let result = TuneCapabilityResolver(game: .fh5).resolve(
            profile: profile,
            settings: [.differentialCenter]
        )

        XCTAssertEqual(capability(.differentialCenter, in: result).status, .unavailable)
    }

    func testRequirementGroupsSupportAllOfWithoutPartialPurchaseGuessing() {
        let knowledge = TuneCapabilityKnowledge(
            game: .fh5,
            evidence: knowledgeEvidence(game: .fh5),
            rules: [
                TuneUnlockRule(
                    setting: .brakes,
                    stockAvailable: false,
                    requirement: TuneRequirementGroup(
                        kind: .allOf,
                        partIDs: [.raceBrakes, .raceFrontBumper]
                    ),
                    supportedDrivetrains: Drivetrain.allCases
                )
            ]
        )
        let profile = makeProfile(parts: [
            vehiclePart(.raceBrakes, .available)
        ])

        let result = TuneCapabilityResolver(knowledge: knowledge).resolve(
            profile: profile,
            settings: [.brakes]
        )

        XCTAssertEqual(capability(.brakes, in: result).status, .unknown)
        XCTAssertTrue(result.requiredPurchases.isEmpty)
        XCTAssertEqual(result.unresolvedConfirmations, [.raceFrontBumper])
    }

    func testGameKnowledgeUsesExplicitConfidenceAndVersion() {
        let fh5 = TuneCapabilityKnowledge.defaults(for: .fh5)
        let fh6 = TuneCapabilityKnowledge.defaults(for: .fh6)

        XCTAssertEqual(fh5.evidence.confidence, .high)
        XCTAssertEqual(fh6.evidence.confidence, .medium)
        XCTAssertFalse(fh5.evidence.source.isEmpty)
        XCTAssertFalse(fh6.evidence.source.isEmpty)
        XCTAssertEqual(fh5.evidence.version, "2026.07.1")
        XCTAssertEqual(fh6.evidence.version, "2026.07.1")
    }

    func testCapabilityValuesRoundTripWithSourceAndVersionPreserved() throws {
        let sourceEvidence = TuneEvidence(
            confidence: .high,
            source: "catalog.fh5.car-123",
            version: "7.4"
        )
        let profile = makeProfile(
            game: .fh5,
            drivetrain: .awd,
            parts: [
                TuneVehiclePart(
                    partID: .raceBrakes,
                    availability: .available,
                    evidence: sourceEvidence
                )
            ]
        )
        let knowledge = TuneCapabilityKnowledge.defaults(for: .fh5)
        let resolution = TuneCapabilityResolver(knowledge: knowledge).resolve(
            profile: profile,
            settings: [.brakes]
        )

        try assertRoundTrip(profile)
        try assertRoundTrip(knowledge)
        let decodedResolution = try assertRoundTrip(resolution)

        XCTAssertEqual(resolution.vehicle, profile.vehicle)
        XCTAssertEqual(resolution.vehicle.game, .fh5)
        XCTAssertEqual(resolution.drivetrain, .awd)
        XCTAssertEqual(decodedResolution.vehicle, profile.vehicle)
        XCTAssertEqual(decodedResolution.vehicle.game, .fh5)
        XCTAssertEqual(decodedResolution.drivetrain, .awd)
        XCTAssertTrue(capability(.brakes, in: decodedResolution).evidence.contains(sourceEvidence))
        XCTAssertEqual(decodedResolution.requiredPurchases.first?.label, "Race Brakes")
    }

    private func makeProfile(
        game: ForzaGame = .fh5,
        drivetrain: Drivetrain = .rwd,
        parts: [TuneVehiclePart] = [],
        stockAdjustableSettings: [StockAdjustableSetting] = []
    ) -> TuneVehicleCapabilityProfile {
        TuneVehicleCapabilityProfile(
            vehicle: TuneVehicleIdentity(
                game: game,
                catalogID: "\(game.rawValue):test-car",
                year: 2020,
                make: "Test",
                model: "Car"
            ),
            drivetrain: drivetrain,
            parts: parts,
            stockAdjustableSettings: stockAdjustableSettings
        )
    }

    private func vehiclePart(
        _ partID: TunePartID,
        _ availability: TunePartAvailability
    ) -> TuneVehiclePart {
        TuneVehiclePart(
            partID: partID,
            availability: availability,
            evidence: TuneEvidence(
                confidence: .high,
                source: "catalog.test-car",
                version: "1.0"
            )
        )
    }

    private func knowledgeEvidence(game: ForzaGame) -> TuneEvidence {
        TuneCapabilityKnowledge.defaults(for: game).evidence
    }

    private func capability(
        _ setting: TuneSetting,
        in resolution: TuneCapabilityResolution,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> TuneSettingCapability {
        guard let capability = resolution.settings.first(where: { $0.setting == setting }) else {
            XCTFail("Missing capability for \(setting.rawValue)", file: file, line: line)
            return TuneSettingCapability(
                setting: setting,
                status: .unknown,
                requirement: nil,
                requiredPurchaseIDs: [],
                unresolvedPartIDs: [],
                evidence: []
            )
        }
        return capability
    }

    @discardableResult
    private func assertRoundTrip<Value: Codable & Equatable>(
        _ value: Value,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> Value {
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(Value.self, from: data)
        XCTAssertEqual(decoded, value, file: file, line: line)
        return decoded
    }
}
