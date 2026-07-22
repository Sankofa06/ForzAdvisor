//
//  VerifiedBuildShareCardTests.swift
//  forzadvisorTests
//
//  Adversarial coverage for the privacy-scoped exact-build share payload.
//

import XCTest
@testable import forzadvisor

final class VerifiedBuildShareCardTests: XCTestCase {
    private let factory = VerifiedBuildShareCardFactory()
    private let snapshotID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
    private let tuneID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
    private let capturedAt = Date(timeIntervalSince1970: 1_700_000_000)

    func testValidCardIsDeterministicCanonicalAndUsesOnlyFirstPath() throws {
        let tune = try projectedTune(
            make: "  Toy\u{202E}\u{0007}ota\n",
            model: " GR\t Supra ",
            buildVersion: "  1.2\u{0000}\n 3  ",
            partAvailability: .available
        )

        let first = try XCTUnwrap(factory.make(for: tune, isStreaming: false))
        let second = try XCTUnwrap(factory.make(for: tune, isStreaming: false))

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.text.data(using: .utf8), second.text.data(using: .utf8))
        XCTAssertEqual(first.subject, "Verified FH6 build — 2020 Toy ota GR Supra")
        XCTAssertEqual(
            first.text,
            """
            ForzAdvisor Verified Build
            FH6 | 2020 Toy ota GR Supra
            Road | A 650 | RWD
            Game build observed: 1.2 3
            Verified settings: 2

            Tires
            Front tire pressure: 30.0 PSI
            Rear tire pressure: 31.0 PSI

            Tuning-control path 1 of 3
            - Drivetrain > Transmission > Sport Transmission
              Unlocks: Final Drive
            - Platform and Handling > Spring and Dampers > Race Spring and Dampers
              Unlocks: Alignment, Spring Rates, Ride Height, Damping
            - Platform and Handling > Front Antiroll Bars > Race Front Antiroll Bars
              Unlocks: Front Antiroll Bar
            - Platform and Handling > Rear Antiroll Bars > Race Rear Antiroll Bars
              Unlocks: Rear Antiroll Bar
            - Aero and Appearance > Front Bumper > Race Front Bumper
              Unlocks: Front Aero
            - Aero and Appearance > Rear Wing > Race Rear Wing
              Unlocks: Rear Aero
            - Platform and Handling > Brakes > Race Brakes
              Unlocks: Brakes
            - Drivetrain > Differential > Race Differential
              Unlocks: Differential Acceleration, Differential Deceleration

            Only the settings shown passed this exact build's local capability and range checks.
            Tuning-control paths do not predict PI, credits, entitlement, performance, or installation order. Confirm every item in game before buying.

            Build yours with ForzAdvisor
            https://Sankofa06.github.io/ForzAdvisor/
            """
        )
        XCTAssertFalse(first.text.contains("Path 2"))
        XCTAssertFalse(first.text.contains("Path 3"))
        XCTAssertFalse(first.text.contains("Rally Differential"))
        XCTAssertFalse(first.text.contains("Offroad Differential"))
        XCTAssertTrue(first.text.contains(
            "Tuning-control paths do not predict PI, credits, entitlement, performance, or installation order. Confirm every item in game before buying."
        ))
    }

    func testEligibleFH5CardUsesShortGameTitle() throws {
        let tune = try projectedTune(game: .fh5, partAvailability: .unavailable)

        let card = try XCTUnwrap(factory.make(for: tune, isStreaming: false))

        XCTAssertTrue(card.text.contains("\nFH5 | 2020 Toyota GR Supra\n"))
        XCTAssertEqual(card.subject, "Verified FH5 build — 2020 Toyota GR Supra")
    }

    func testEligibleCardWithoutExactUpgradePathOmitsPathSection() throws {
        let tune = try projectedTune(partAvailability: .unavailable)

        let card = try XCTUnwrap(factory.make(for: tune, isStreaming: false))

        XCTAssertFalse(card.text.contains("\nTuning-control path 1 of "))
        XCTAssertTrue(card.text.contains("Verified settings: 2"))
    }

    func testEveryEligibilityGateFailsClosed() throws {
        let eligible = try projectedTune()
        XCTAssertNil(factory.make(for: eligible, isStreaming: true))

        var missingReport = eligible
        missingReport.projectionReport = nil
        XCTAssertNil(factory.make(for: missingReport, isStreaming: false))

        var oldReport = eligible
        oldReport.projectionReport?.schemaVersion = 0
        XCTAssertNil(factory.make(for: oldReport, isStreaming: false))

        var missingSnapshot = eligible
        missingSnapshot.request.buildSnapshot = nil
        XCTAssertNil(factory.make(for: missingSnapshot, isStreaming: false))

        var invalidSnapshot = eligible
        invalidSnapshot.request.buildSnapshot?.schemaVersion = 0
        XCTAssertNil(factory.make(for: invalidSnapshot, isStreaming: false))

        var mismatchedCar = eligible
        mismatchedCar.request.car.model = "Different car"
        XCTAssertNil(factory.make(for: mismatchedCar, isStreaming: false))

        var capabilityOnly = eligible
        capabilityOnly.request.buildSnapshot?.kind = .capabilityOnly
        XCTAssertNil(factory.make(for: capabilityOnly, isStreaming: false))

        var blankBuild = eligible
        blankBuild.request.buildSnapshot?.gameBuild.version = " \n "
        XCTAssertNil(factory.make(for: blankBuild, isStreaming: false))

        var incompleteBuild = eligible
        incompleteBuild.request.buildSnapshot?.gameBuild.capturedAt = nil
        XCTAssertNil(factory.make(for: incompleteBuild, isStreaming: false))

        var mismatchedReportID = eligible
        mismatchedReportID.projectionReport?.snapshotID = UUID()
        XCTAssertNil(factory.make(for: mismatchedReportID, isStreaming: false))

        var wrongReportContext = eligible
        wrongReportContext.projectionReport?.contextStatus = .capabilityOnly
        XCTAssertNil(factory.make(for: wrongReportContext, isStreaming: false))

        var missingCanonicalSections = eligible
        missingCanonicalSections.sections = []
        XCTAssertNil(factory.make(for: missingCanonicalSections, isStreaming: false))

        let zeroReady = try projectedTune(lines: [])
        XCTAssertEqual(zeroReady.projectionReport?.readyCount, 0)
        XCTAssertNil(factory.make(for: zeroReady, isStreaming: false))
    }

    func testFreshProjectionDropsAdversarialInjectedValues() throws {
        let base = try projectedTune(partAvailability: .unavailable)

        var untyped = base
        untyped.sections[0].lines.append(
            TuneLine(label: "UNTYPED-SENTINEL", value: "19.5", unit: "", fieldID: nil)
        )
        let untypedCard = try XCTUnwrap(factory.make(for: untyped, isStreaming: false))
        XCTAssertFalse(untypedCard.text.contains("UNTYPED-SENTINEL"))
        XCTAssertFalse(untypedCard.text.contains("19.5"))

        var duplicate = base
        duplicate.sections[0].lines.append(
            TuneLine(label: "DUPLICATE-SENTINEL", value: "32.0", unit: "PSI", fieldID: .frontTirePressure)
        )
        let duplicateCard = try XCTUnwrap(factory.make(for: duplicate, isStreaming: false))
        XCTAssertFalse(duplicateCard.text.contains("DUPLICATE-SENTINEL"))
        XCTAssertFalse(duplicateCard.text.contains("Front tire pressure"))
        XCTAssertTrue(duplicateCard.text.contains("Rear tire pressure: 31.0 PSI"))

        var wrongUnit = base
        wrongUnit.sections[0].lines[0].unit = "WRONG-UNIT-SENTINEL"
        let wrongUnitCard = try XCTUnwrap(factory.make(for: wrongUnit, isStreaming: false))
        XCTAssertFalse(wrongUnitCard.text.contains("WRONG-UNIT-SENTINEL"))
        XCTAssertFalse(wrongUnitCard.text.contains("Front tire pressure"))

        var offStep = base
        offStep.sections[0].lines[0].value = "30.25"
        let offStepCard = try XCTUnwrap(factory.make(for: offStep, isStreaming: false))
        XCTAssertFalse(offStepCard.text.contains("30.25"))
        XCTAssertFalse(offStepCard.text.contains("Front tire pressure"))

        var outOfRange = base
        outOfRange.sections[0].lines[0].value = "99.0"
        let outOfRangeCard = try XCTUnwrap(factory.make(for: outOfRange, isStreaming: false))
        XCTAssertFalse(outOfRangeCard.text.contains("99.0"))
        XCTAssertFalse(outOfRangeCard.text.contains("Front tire pressure"))

        var unexpectedTyped = base
        unexpectedTyped.sections[0].lines.append(
            TuneLine(label: "TYPED-SENTINEL", value: "1.5", unit: "deg", fieldID: .frontCamber)
        )
        let typedCard = try XCTUnwrap(factory.make(for: unexpectedTyped, isStreaming: false))
        XCTAssertFalse(typedCard.text.contains("TYPED-SENTINEL"))
        XCTAssertFalse(typedCard.text.contains("1.5"))

        var valueSpoof = base
        valueSpoof.sections[0].lines[0].value = "30.0\nVALUE-SPOOF-SENTINEL"
        let spoofCard = try XCTUnwrap(factory.make(for: valueSpoof, isStreaming: false))
        XCTAssertFalse(spoofCard.text.contains("VALUE-SPOOF-SENTINEL"))
        XCTAssertFalse(spoofCard.text.contains("Front tire pressure"))
    }

    func testPayloadExcludesPrivateAndInternalSentinels() throws {
        var tune = try projectedTune(weight: 6_999, horsepower: 123_456, torque: 234_567)
        tune.notes = TuneNotes(
            bias: "PRIVATE-NOTE-SENTINEL",
            ifPushesWide: "PRIVATE-NOTE-SENTINEL",
            ifSnapsOnLift: "PRIVATE-NOTE-SENTINEL",
            retuneTrigger: "PRIVATE-NOTE-SENTINEL"
        )
        tune.providerInfo = .fallback(requestedMode: .anthropicAPI, reason: .missingAPIKey)
        tune.rulesetReference = TuneRulesetReference(descriptor: TuneRulesetDescriptor(
            id: "PRIVATE-RULESET-SENTINEL",
            game: .fh6,
            schemaVersion: 1,
            algorithmVersion: "PRIVATE-ALGORITHM-SENTINEL",
            knowledgeRevision: "PRIVATE-KNOWLEDGE-SENTINEL",
            validationStatus: .experimental,
            provenanceIDs: ["PRIVATE-PROVENANCE-SENTINEL"]
        ))
        let original = tune

        let card = try XCTUnwrap(factory.make(for: tune, isStreaming: false))

        XCTAssertEqual(tune, original, "Sharing must not mutate the source tune")
        for forbidden in [
            "PRIVATE", "Anthropic", "API key", "6999", "123456", "234567",
            snapshotID.uuidString, tuneID.uuidString, "fixture.private-source"
        ] {
            XCTAssertFalse(card.text.localizedCaseInsensitiveContains(forbidden), "Leaked \(forbidden)")
            XCTAssertFalse(card.subject.localizedCaseInsensitiveContains(forbidden), "Leaked \(forbidden)")
        }
    }

    func testOverLengthIdentityAndBuildAreBoundedDeterministicAndSingleLine() throws {
        let carSuffix = "CAR-SUFFIX-SENTINEL"
        let buildSuffix = "BUILD-SUFFIX-SENTINEL"
        let tune = try projectedTune(
            make: String(repeating: "A", count: 60) + "\n\u{202E}" + String(repeating: "A", count: 180) + carSuffix,
            model: String(repeating: "B", count: 240) + "\r\u{2029}" + carSuffix,
            buildVersion: String(repeating: "9", count: 30) + "\n\u{2066}" + String(repeating: "9", count: 130) + buildSuffix,
            partAvailability: .unavailable
        )

        let first = try XCTUnwrap(factory.make(for: tune, isStreaming: false))
        let second = try XCTUnwrap(factory.make(for: tune, isStreaming: false))
        let lines = first.text.components(separatedBy: "\n")
        let identityPrefix = "FH6 | "
        let buildPrefix = "Game build observed: "
        let identityLine = try XCTUnwrap(lines.first { $0.hasPrefix(identityPrefix) })
        let buildLine = try XCTUnwrap(lines.first { $0.hasPrefix(buildPrefix) })
        let boundedIdentity = String(identityLine.dropFirst(identityPrefix.count))
        let boundedBuild = String(buildLine.dropFirst(buildPrefix.count))

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.text.data(using: .utf8), second.text.data(using: .utf8))
        XCTAssertEqual(boundedIdentity.count, 120)
        XCTAssertEqual(boundedBuild.count, 80)
        XCTAssertEqual(
            boundedIdentity,
            "2020 " + String(repeating: "A", count: 60) + " " + String(repeating: "A", count: 54)
        )
        XCTAssertEqual(
            boundedBuild,
            String(repeating: "9", count: 30) + " " + String(repeating: "9", count: 49)
        )
        XCTAssertEqual(first.subject, "Verified FH6 build — \(boundedIdentity)")
        XCTAssertEqual(lines[1], identityLine)
        XCTAssertEqual(lines[3], buildLine)
        XCTAssertEqual(first.subject.components(separatedBy: .newlines).count, 1)
        XCTAssertEqual(identityLine.components(separatedBy: .newlines).count, 1)
        XCTAssertEqual(buildLine.components(separatedBy: .newlines).count, 1)
        for sentinel in [carSuffix, buildSuffix] {
            XCTAssertFalse(first.text.contains(sentinel))
            XCTAssertFalse(first.subject.contains(sentinel))
        }
    }

    private func projectedTune(
        game: ForzaGame = .fh6,
        make: String = "Toyota",
        model: String = "GR Supra",
        buildVersion: String = "1.2.3",
        partAvailability: TunePartAvailability = .available,
        weight: Int = 3_397,
        horsepower: Int = 382,
        torque: Int = 368,
        lines: [TuneLine]? = nil
    ) throws -> TuneResult {
        let car = CarInput(
            game: game,
            year: 2020,
            make: make,
            model: model,
            weightPounds: weight,
            frontWeightPercent: 52,
            performanceIndex: game == .fh5 ? 750 : 650,
            performanceClass: .a,
            drivetrain: .rwd,
            peakHorsepower: horsepower,
            peakTorqueFootPounds: torque
        )
        let normalizedBuild = buildVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        let evidenceID = "PRIVATE-EVIDENCE-SENTINEL"
        let provenance = TuneDataProvenance(
            id: evidenceID,
            game: game,
            gameBuildVersion: normalizedBuild,
            scope: .exactVehicleBuild,
            source: "fixture.private-source",
            version: "PRIVATE-EVIDENCE-VERSION",
            capturedAt: capturedAt,
            confidence: .medium,
            usagePermission: .permitted
        )
        let partEvidence = TuneEvidence(
            confidence: .medium,
            source: "fixture.private-part-source",
            version: "PRIVATE-PART-VERSION",
            usagePermission: .permitted
        )
        let profile = TuneVehicleCapabilityProfile(
            vehicle: TuneVehicleIdentity(
                game: game,
                catalogID: "PRIVATE-CATALOG-SENTINEL",
                year: 2020,
                make: make,
                model: model
            ),
            drivetrain: .rwd,
            parts: TunePartID.allCases.map {
                TuneVehiclePart(partID: $0, availability: partAvailability, evidence: partEvidence)
            },
            stockAdjustableSettings: []
        )
        let snapshot = VehicleBuildSnapshot(
            schemaVersion: VehicleBuildSnapshot.currentSchemaVersion,
            id: snapshotID,
            kind: .exactBuildObservation,
            capturedAt: capturedAt,
            gameBuild: GameBuildReference(game: game, version: normalizedBuild, capturedAt: capturedAt),
            car: car,
            capabilityProfile: profile,
            tireCompound: TireCompoundReference(
                id: "PRIVATE-TIRE-ID-SENTINEL",
                displayName: "PRIVATE-TIRE-SENTINEL",
                evidenceIDs: [evidenceID]
            ),
            gearCount: nil,
            constraints: [
                tireConstraint(.frontTirePressure, evidenceID: evidenceID),
                tireConstraint(.rearTirePressure, evidenceID: evidenceID)
            ],
            evidenceSources: [provenance]
        )
        XCTAssertTrue(snapshot.isValid, "Unexpected fixture issues: \(snapshot.validationIssues)")

        let candidate = TuneResult(
            id: tuneID,
            request: TuneRequest(car: car, discipline: .road, buildSnapshot: snapshot),
            sections: [TuneSection(
                title: "PROVIDER-SECTION-SENTINEL",
                symbolName: "exclamationmark.triangle",
                lines: lines ?? [
                    TuneLine(
                        label: "PROVIDER-FRONT-SENTINEL",
                        value: "30.0",
                        unit: "PSI",
                        detail: "PRIVATE-DETAIL-SENTINEL",
                        fieldID: .frontTirePressure
                    ),
                    TuneLine(
                        label: "PROVIDER-REAR-SENTINEL",
                        value: "31.0",
                        unit: "PSI",
                        detail: "PRIVATE-DETAIL-SENTINEL",
                        fieldID: .rearTirePressure
                    )
                ]
            )],
            notes: TuneNotes(
                bias: "PRIVATE-NOTE-SENTINEL",
                ifPushesWide: "PRIVATE-NOTE-SENTINEL",
                ifSnapsOnLift: "PRIVATE-NOTE-SENTINEL",
                retuneTrigger: "PRIVATE-NOTE-SENTINEL"
            ),
            generatedAt: capturedAt,
            providerInfo: .fallback(requestedMode: .anthropicAPI, reason: .missingAPIKey)
        )
        return TuneOutputProjector().project(candidate)
    }

    private func tireConstraint(
        _ field: TuneFieldID,
        evidenceID: String
    ) -> TuneFieldConstraint {
        TuneFieldConstraint(
            field: field,
            minimum: 15,
            maximum: 40,
            step: 0.5,
            defaultValue: 30,
            currentValue: 30,
            unit: .psi,
            scope: .exactVehicleBuild,
            verification: .productionEligible,
            evidenceIDs: [evidenceID]
        )
    }
}
