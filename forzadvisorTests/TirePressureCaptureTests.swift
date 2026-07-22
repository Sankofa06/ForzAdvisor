//
//  TirePressureCaptureTests.swift
//  forzadvisorTests
//
//  Contract coverage for local tire evidence and formula-step quantization.
//

import XCTest
@testable import forzadvisor

final class TirePressureCaptureTests: XCTestCase {
    private let capturedAt = Date(timeIntervalSinceReferenceDate: 123)
    private let exactSnapshotID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
    private let evidenceID = "local-observation-1"

    func testValidCaptureUpgradesSnapshotWithExactPermittedEvidence() throws {
        let base = try capabilitySnapshot()
        let original = base
        let capture = validCapture(
            gameBuildVersion: "  1.2.3.4  ",
            tireCompound: "  Stock Road  "
        )

        let exact = try capture.exactBuildSnapshot(
            upgrading: base,
            capturedAt: capturedAt,
            snapshotID: exactSnapshotID,
            evidenceID: evidenceID
        )

        XCTAssertEqual(base, original)
        XCTAssertNotEqual(exact.id, base.id)
        XCTAssertEqual(exact.id, exactSnapshotID)
        XCTAssertEqual(exact.kind, .exactBuildObservation)
        XCTAssertEqual(exact.capturedAt, capturedAt)
        XCTAssertEqual(exact.gameBuild, GameBuildReference(game: .fh6, version: "1.2.3.4", capturedAt: capturedAt))
        XCTAssertEqual(exact.car, base.car)
        XCTAssertEqual(exact.capabilityProfile, base.capabilityProfile)
        XCTAssertEqual(exact.tireCompound?.displayName, "Stock Road")
        XCTAssertEqual(exact.tireCompound?.evidenceIDs, [evidenceID])
        XCTAssertEqual(exact.gearCount, 6)
        XCTAssertTrue(exact.isValid, "Unexpected issues: \(exact.validationIssues)")

        let evidence = try XCTUnwrap(exact.evidenceSources.first { $0.id == evidenceID })
        XCTAssertEqual(evidence.game, .fh6)
        XCTAssertEqual(evidence.gameBuildVersion, "1.2.3.4")
        XCTAssertEqual(evidence.scope, .exactVehicleBuild)
        XCTAssertEqual(evidence.source, TirePressureCapture.provenanceSource)
        XCTAssertEqual(TirePressureCapture.provenanceVersion, "2")
        XCTAssertEqual(evidence.version, "2")
        XCTAssertEqual(evidence.capturedAt, capturedAt)
        XCTAssertEqual(evidence.confidence, .medium)
        XCTAssertEqual(evidence.usagePermission, .permitted)

        XCTAssertEqual(exact.constraints.map(\.field), [.frontTirePressure, .rearTirePressure])
        XCTAssertEqual(exact.constraints.map(\.scope), [.exactVehicleBuild, .exactVehicleBuild])
        XCTAssertEqual(exact.constraints.map(\.verification), [.productionEligible, .productionEligible])
        XCTAssertEqual(exact.constraints.map(\.unit), [.psi, .psi])
        XCTAssertEqual(exact.constraints.map(\.evidenceIDs), [[evidenceID], [evidenceID]])
        XCTAssertEqual(exact.constraints[0].minimum, 15)
        XCTAssertEqual(exact.constraints[0].maximum, 40)
        XCTAssertEqual(exact.constraints[0].step, 0.5)
        XCTAssertEqual(exact.constraints[0].currentValue, 30)
        XCTAssertEqual(exact.constraints[1].currentValue, 29.5)
    }

    func testExactSnapshotRoundTripsThroughJSON() throws {
        let capture = validCapture()
        let exact = try capture.exactBuildSnapshot(
            upgrading: capabilitySnapshot(),
            capturedAt: capturedAt,
            snapshotID: exactSnapshotID,
            evidenceID: evidenceID
        )

        XCTAssertEqual(
            try JSONDecoder().decode(VehicleBuildSnapshot.self, from: JSONEncoder().encode(exact)),
            exact
        )
        XCTAssertEqual(
            try JSONDecoder().decode(TirePressureCapture.self, from: JSONEncoder().encode(capture)),
            capture
        )
    }

    func testLegacyCaptureWithoutGearCountDecodesFailClosed() throws {
        let data = try JSONEncoder().encode(validCapture())
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "gearCount")
        let legacyData = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(TirePressureCapture.self, from: legacyData)

        XCTAssertEqual(decoded.gearCount, 0)
        XCTAssertEqual(
            decoded.validationIssues(upgrading: try capabilitySnapshot()),
            [.invalidGearCount(0)]
        )
    }

    func testUpgradePreservesUnrelatedGlobalConstraintsAndEvidence() throws {
        var base = try capabilitySnapshot()
        let global = TuneDataProvenance(
            id: "global-final-drive",
            game: .fh6,
            gameBuildVersion: nil,
            scope: .gameGlobal,
            source: "fixture",
            version: "1",
            capturedAt: capturedAt,
            confidence: .high,
            usagePermission: .permitted
        )
        base.evidenceSources = [global]
        base.constraints = [TuneFieldConstraint(
            field: .finalDrive,
            minimum: 2,
            maximum: 6,
            step: 0.1,
            defaultValue: 3,
            currentValue: 3,
            unit: .ratio,
            scope: .gameGlobal,
            verification: .productionEligible,
            evidenceIDs: [global.id]
        )]
        XCTAssertTrue(base.isValid, "Unexpected issues: \(base.validationIssues)")

        let exact = try validCapture().exactBuildSnapshot(
            upgrading: base,
            capturedAt: capturedAt,
            snapshotID: exactSnapshotID,
            evidenceID: evidenceID
        )

        XCTAssertEqual(exact.constraints.first, base.constraints.first)
        XCTAssertEqual(exact.evidenceSources.first, global)
        XCTAssertEqual(exact.constraints.count, 3)
        XCTAssertEqual(exact.evidenceSources.count, 2)
        XCTAssertTrue(exact.isValid, "Unexpected issues: \(exact.validationIssues)")
    }

    func testValidationRejectsUnsupportedOrNonCatalogBaseSnapshots() throws {
        let fh6 = try capabilitySnapshot()
        var fh5 = try capabilitySnapshot(game: .fh5)
        XCTAssertEqual(validCapture().validationIssues(upgrading: fh5), [.unsupportedGame(.fh5)])

        fh5.kind = .exactBuildObservation
        XCTAssertEqual(
            validCapture().validationIssues(upgrading: fh5),
            [.invalidBaseSnapshot, .requiresCapabilityOnlySnapshot, .unsupportedGame(.fh5)]
        )

        var missingCatalog = fh6
        missingCatalog.car.catalogReference = nil
        XCTAssertTrue(missingCatalog.isValid, "Unexpected issues: \(missingCatalog.validationIssues)")
        XCTAssertEqual(validCapture().validationIssues(upgrading: missingCatalog), [.missingCatalogIdentity])

        var modified = fh6
        modified.car.weightPounds += 1
        XCTAssertTrue(modified.car.catalogValuesModified)
        XCTAssertTrue(modified.isValid, "Unexpected issues: \(modified.validationIssues)")
        XCTAssertEqual(validCapture().validationIssues(upgrading: modified), [.modifiedCatalogIdentity])
    }

    func testValidationRejectsMissingMetadataAndAttestationsInStableOrder() throws {
        var capture = validCapture()
        capture.gameBuildVersion = " \n "
        capture.tireCompound = "  "
        capture.exactStockBuildConfirmed = false
        capture.localUsePermitted = false

        XCTAssertEqual(
            capture.validationIssues(upgrading: try capabilitySnapshot()),
            [
                .missingGameBuildVersion,
                .missingTireCompound,
                .exactStockBuildNotConfirmed,
                .localUseNotPermitted
            ]
        )
    }

    func testValidationRejectsInvalidGearCountsInStableOrder() throws {
        for invalidCount in [0, 11] {
            var capture = validCapture()
            capture.gameBuildVersion = " "
            capture.tireCompound = " "
            capture.gearCount = invalidCount
            capture.exactStockBuildConfirmed = false
            capture.localUsePermitted = false

            XCTAssertEqual(
                capture.validationIssues(upgrading: try capabilitySnapshot()),
                [
                    .missingGameBuildVersion,
                    .missingTireCompound,
                    .invalidGearCount(invalidCount),
                    .exactStockBuildNotConfirmed,
                    .localUseNotPermitted
                ]
            )
        }
    }

    func testTireLabGearCountEntryNormalizesAndFailsClosed() throws {
        XCTAssertEqual(TirePressureCaptureView.parsedGearCount(" 6 "), 6)
        XCTAssertEqual(TirePressureCaptureView.parsedGearCount("٦"), 6)

        for invalidEntry in ["", "not-a-number", "6.5", "0", "11", "nan", "∞"] {
            var capture = validCapture()
            capture.gearCount = TirePressureCaptureView.parsedGearCount(invalidEntry)
            let issues = capture.validationIssues(upgrading: try capabilitySnapshot())

            XCTAssertEqual(issues, [.invalidGearCount(0)])
            XCTAssertEqual(
                issues.first?.localizedDescription,
                "Forward gear count must be between 1 and 10, not 0."
            )
        }
    }

    func testValidationRejectsNonFiniteValuesPerAxle() throws {
        var capture = validCapture()
        capture.front.minimumPSI = .nan
        capture.rear.currentPSI = .infinity

        XCTAssertEqual(
            capture.validationIssues(upgrading: try capabilitySnapshot()),
            [.nonFiniteValue(.front), .nonFiniteValue(.rear)]
        )
    }

    func testValidationRejectsRangeStepCurrentAndOffStepErrors() throws {
        var capture = validCapture()
        capture.front.minimumPSI = 40
        capture.front.maximumPSI = 40
        capture.front.stepPSI = 0
        capture.front.currentPSI = 41
        capture.rear.currentPSI = 29.6

        XCTAssertEqual(
            capture.validationIssues(upgrading: try capabilitySnapshot()),
            [
                .invalidRange(.front),
                .invalidStep(.front),
                .currentOutOfRange(.front),
                .currentOffStep(.rear)
            ]
        )
    }

    func testValidationRejectsMaximumThatIsNotReachableByWholeSteps() throws {
        var capture = validCapture()
        capture.front = TirePressureRangeCapture(
            minimumPSI: 15,
            maximumPSI: 40,
            stepPSI: 6,
            currentPSI: 27
        )

        XCTAssertEqual(
            capture.validationIssues(upgrading: try capabilitySnapshot()),
            [.maximumOffStep(.front)]
        )
        XCTAssertThrowsError(try capture.exactBuildSnapshot(upgrading: capabilitySnapshot()))
    }

    func testFactoryRejectsBlankEvidenceAndReusedSnapshotIdentity() throws {
        let base = try capabilitySnapshot()

        XCTAssertThrowsError(try validCapture().exactBuildSnapshot(
            upgrading: base,
            capturedAt: capturedAt,
            snapshotID: base.id,
            evidenceID: "  "
        )) { error in
            guard case .invalid(let issues) = error as? TirePressureCaptureError else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(issues, [.invalidEvidenceID, .reusedSnapshotIdentity])
        }
    }

    func testQuantizerUsesNearestStepWithTiesAwayFromZero() throws {
        let request = try exactRequest(front: .init(
            minimumPSI: 15,
            maximumPSI: 40,
            stepPSI: 0.5,
            currentPSI: 30
        ))
        let candidate = rawTune(request: request, lines: [
            TuneLine(
                label: "Front pressure",
                value: "26.75",
                unit: "PSI",
                detail: "Formula candidate.",
                fieldID: .frontTirePressure
            )
        ])

        let quantized = FH6LocalTirePressureQuantizer().quantize(candidate)
        let line = try XCTUnwrap(quantized.sections.first?.lines.first)
        let evidence = try XCTUnwrap(request.buildSnapshot?.evidenceSources.first)

        XCTAssertEqual(evidence.version, "2")
        XCTAssertEqual(line.value, LocalizedNumberText.format(27, fractionDigits: 1))
        XCTAssertEqual(
            line.detail,
            "Formula candidate. Rounded to the captured in-game tire-pressure step."
        )
        XCTAssertEqual(quantized.rulesetReference?.id, FH6LocalTirePressureRuleset.id)
        XCTAssertEqual(quantized.rulesetReference?.provenanceIDs, [evidenceID])
        XCTAssertEqual(quantized.rulesetReference?.validationStatus, .experimental)
        XCTAssertTrue(quantized.rulesetReference?.isValid == true)
    }

    func testQuantizerNeverClampsOutsideCandidateAndDoesNotAttachRuleset() throws {
        let request = try exactRequest()
        let candidate = rawTune(request: request, lines: [
            TuneLine(label: "Front pressure", value: "40.1", unit: "PSI", fieldID: .frontTirePressure),
            TuneLine(label: "Final drive", value: "3.20", unit: "", fieldID: .finalDrive)
        ])

        let unchanged = FH6LocalTirePressureQuantizer().quantize(candidate)

        XCTAssertEqual(unchanged, candidate)
        XCTAssertNil(unchanged.rulesetReference)
    }

    func testQuantizerFailsClosedForCapabilityOnlyAndMismatchedSnapshots() throws {
        let selection = try catalogSelection(game: .fh6)
        let capabilityRequest = TuneRequest(
            car: selection.carInput,
            discipline: .road,
            buildSnapshot: selection.capabilityOnlyBuildSnapshot()
        )
        let capabilityCandidate = rawTune(request: capabilityRequest, lines: [
            TuneLine(label: "Front pressure", value: "26.75", unit: "PSI", fieldID: .frontTirePressure)
        ])
        XCTAssertEqual(FH6LocalTirePressureQuantizer().quantize(capabilityCandidate), capabilityCandidate)

        var mismatchRequest = try exactRequest()
        mismatchRequest.car.performanceIndex += 1
        let mismatchCandidate = rawTune(request: mismatchRequest, lines: capabilityCandidate.sections[0].lines)
        XCTAssertEqual(FH6LocalTirePressureQuantizer().quantize(mismatchCandidate), mismatchCandidate)
    }

    func testQuantizerDoesNotRelabelThirdPartyExactEvidenceAsLocalCapture() throws {
        var request = try exactRequest()
        var snapshot = try XCTUnwrap(request.buildSnapshot)
        snapshot.evidenceSources[0].source = "third-party.fixture"
        XCTAssertTrue(snapshot.isValid, "Unexpected issues: \(snapshot.validationIssues)")
        request.buildSnapshot = snapshot
        let candidate = rawTune(request: request, lines: [
            TuneLine(label: "Front pressure", value: "26.75", unit: "PSI", fieldID: .frontTirePressure)
        ])

        let unchanged = FH6LocalTirePressureQuantizer().quantize(candidate)

        XCTAssertEqual(unchanged, candidate)
        XCTAssertNil(unchanged.rulesetReference)
    }

    func testQuantizerDoesNotTrustLegacyV1CaptureEvidenceAsV2() throws {
        var request = try exactRequest()
        var snapshot = try XCTUnwrap(request.buildSnapshot)
        snapshot.evidenceSources[0].version = "1"
        XCTAssertTrue(snapshot.isValid, "Unexpected issues: \(snapshot.validationIssues)")
        request.buildSnapshot = snapshot
        let candidate = rawTune(request: request, lines: [
            TuneLine(label: "Front pressure", value: "26.75", unit: "PSI", fieldID: .frontTirePressure)
        ])

        let unchanged = FH6LocalTirePressureQuantizer().quantize(candidate)

        XCTAssertEqual(unchanged, candidate)
        XCTAssertNil(unchanged.rulesetReference)
    }

    func testLocalProviderQuantizesOnlyEligibleTireFieldsAndAttachesRuleset() async throws {
        let request = try exactRequest(
            front: .init(minimumPSI: 15, maximumPSI: 40, stepPSI: 0.5, currentPSI: 30),
            rear: .init(minimumPSI: 15, maximumPSI: 40, stepPSI: 0.25, currentPSI: 29.5)
        )

        let tune = try await LocalSampleTuneProvider().generateTune(for: request)
        let frontLine = try XCTUnwrap(tune.sections.flatMap(\.lines).first { $0.fieldID == .frontTirePressure })
        let rearLine = try XCTUnwrap(tune.sections.flatMap(\.lines).first { $0.fieldID == .rearTirePressure })
        let frontValue = try XCTUnwrap(LocalizedNumberText.parse(frontLine.value))
        let rearValue = try XCTUnwrap(LocalizedNumberText.parse(rearLine.value))
        let snapshot = try XCTUnwrap(request.buildSnapshot)
        let frontConstraint = try XCTUnwrap(snapshot.constraints.first { $0.field == .frontTirePressure })
        let rearConstraint = try XCTUnwrap(snapshot.constraints.first { $0.field == .rearTirePressure })

        XCTAssertTrue(frontConstraint.accepts(frontValue))
        XCTAssertTrue(rearConstraint.accepts(rearValue))
        XCTAssertEqual(tune.rulesetReference?.id, FH6LocalTirePressureRuleset.id)
        XCTAssertEqual(tune.rulesetReference?.game, .fh6)
        XCTAssertEqual(tune.rulesetReference?.algorithmVersion, FH6LocalTirePressureRuleset.algorithmVersion)
        XCTAssertEqual(tune.rulesetReference?.provenanceIDs, [evidenceID])
        XCTAssertEqual(tune.providerInfo, .direct(.offlineFormula))
    }

    func testCapturedRangesUnlockOnlyProjectedLocalTireSettings() async throws {
        let request = try exactRequest(
            front: .init(minimumPSI: 15, maximumPSI: 40, stepPSI: 0.5, currentPSI: 30),
            rear: .init(minimumPSI: 15, maximumPSI: 40, stepPSI: 0.25, currentPSI: 29.5)
        )
        let provider = CapabilityProjectingTuneProvider(base: LocalSampleTuneProvider())

        let tune = try await provider.generateTune(for: request)

        XCTAssertEqual(
            tune.projectionReport?.readyFieldIDs,
            Set([.frontTirePressure, .rearTirePressure])
        )
        XCTAssertEqual(tune.sections.map(\.title), ["Tires"])
        XCTAssertEqual(
            Set(tune.sections.flatMap(\.lines).compactMap(\.fieldID)),
            Set([.frontTirePressure, .rearTirePressure])
        )
        XCTAssertEqual(tune.rulesetReference?.id, FH6LocalTirePressureRuleset.id)
        XCTAssertEqual(tune.rulesetReference?.provenanceIDs, [evidenceID])
    }

    private func validCapture(
        gameBuildVersion: String = "1.2.3.4",
        tireCompound: String = "Stock"
    ) -> TirePressureCapture {
        TirePressureCapture(
            gameBuildVersion: gameBuildVersion,
            tireCompound: tireCompound,
            gearCount: 6,
            front: TirePressureRangeCapture(
                minimumPSI: 15,
                maximumPSI: 40,
                stepPSI: 0.5,
                currentPSI: 30
            ),
            rear: TirePressureRangeCapture(
                minimumPSI: 15,
                maximumPSI: 40,
                stepPSI: 0.5,
                currentPSI: 29.5
            ),
            exactStockBuildConfirmed: true,
            localUsePermitted: true
        )
    }

    private func capabilitySnapshot(game: ForzaGame = .fh6) throws -> VehicleBuildSnapshot {
        try catalogSelection(game: game).capabilityOnlyBuildSnapshot(capturedAt: capturedAt)
    }

    private func exactRequest(
        front: TirePressureRangeCapture = .init(
            minimumPSI: 15,
            maximumPSI: 40,
            stepPSI: 0.5,
            currentPSI: 30
        ),
        rear: TirePressureRangeCapture = .init(
            minimumPSI: 15,
            maximumPSI: 40,
            stepPSI: 0.5,
            currentPSI: 29.5
        )
    ) throws -> TuneRequest {
        let selection = try catalogSelection(game: .fh6)
        var capture = validCapture()
        capture.front = front
        capture.rear = rear
        let snapshot = try capture.exactBuildSnapshot(
            upgrading: selection.capabilityOnlyBuildSnapshot(capturedAt: capturedAt),
            capturedAt: capturedAt,
            snapshotID: exactSnapshotID,
            evidenceID: evidenceID
        )
        return TuneRequest(car: selection.carInput, discipline: .road, buildSnapshot: snapshot)
    }

    private func catalogSelection(game: ForzaGame) throws -> CatalogCarSelection {
        let catalog = try BundledCarCatalog.load().get()
        let entry = try XCTUnwrap(catalog.entries.first { $0.game == game })
        return catalog.selection(for: entry)
    }

    private func rawTune(request: TuneRequest, lines: [TuneLine]) -> TuneResult {
        TuneResult(
            request: request,
            sections: [TuneSection(title: "Tires", symbolName: "circle.dashed", lines: lines)],
            notes: TuneNotes(
                bias: "Raw",
                ifPushesWide: "Raw",
                ifSnapsOnLift: "Raw",
                retuneTrigger: "Raw"
            )
        )
    }
}
