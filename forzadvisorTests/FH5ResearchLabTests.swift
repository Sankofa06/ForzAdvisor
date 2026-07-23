//
//  FH5ResearchLabTests.swift
//  forzadvisorTests
//
//  Fail-closed contracts for first-party FH5 stock tuning-menu observations.
//

import SwiftData
import XCTest
@testable import forzadvisor

final class FH5ResearchLabTests: XCTestCase {
    private let capturedAt = Date(timeIntervalSinceReferenceDate: 1_000)
    private let recordID = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
    private let submissionID = UUID(uuidString: "20000000-0000-0000-0000-000000000002")!
    private let permissionID = UUID(uuidString: "30000000-0000-0000-0000-000000000003")!
    private let snapshotID = UUID(uuidString: "40000000-0000-0000-0000-000000000004")!

    func testEligibilityRequiresSavedUntouchedCatalogPlanAndFailsClosed() async throws {
        let plan = try await makePlan()
        let eligibility = FH5ResearchEligibility()

        XCTAssertSuccess(eligibility.snapshot(for: plan, savedTune: plan, isStreaming: false))
        XCTAssertFailure(
            eligibility.snapshot(for: plan, savedTune: nil, isStreaming: false),
            .notSaved
        )
        XCTAssertFailure(
            eligibility.snapshot(for: plan, savedTune: plan, isStreaming: true),
            .streaming
        )

        var edited = plan
        edited.request.car.weightPounds += 1
        XCTAssertFailure(
            eligibility.snapshot(for: edited, savedTune: edited, isStreaming: false),
            .invalidCapabilitySnapshot
        )

        var manual = plan
        manual.request.car.catalogReference = nil
        manual.request.buildSnapshot?.car.catalogReference = nil
        XCTAssertFailure(
            eligibility.snapshot(for: manual, savedTune: manual, isStreaming: false),
            .missingCatalogIdentity
        )

        var exact = plan
        exact.request.buildSnapshot?.kind = .exactBuildObservation
        XCTAssertFailure(
            eligibility.snapshot(for: exact, savedTune: exact, isStreaming: false),
            .invalidCapabilitySnapshot
        )

        var numeric = plan
        numeric.sections = [TuneSection(
            title: "Forged",
            symbolName: "xmark",
            lines: [TuneLine(label: "Forbidden", value: "31.73", unit: "PSI")]
        )]
        XCTAssertFailure(
            eligibility.snapshot(for: numeric, savedTune: numeric, isStreaming: false),
            .numericOrProviderPayload
        )

        var stale = plan
        stale.generatedAt = capturedAt
        XCTAssertFailure(
            eligibility.snapshot(for: plan, savedTune: stale, isStreaming: false),
            .staleSavedRevision
        )
    }

    func testExpectedControlMatricesAreExactForEveryDrivetrainAndGearCount() {
        for drivetrain in Drivetrain.allCases {
            for gearCount in [1, 6, 10] {
                let expected = TuneFieldID.expectedFields(
                    drivetrain: drivetrain,
                    gearCount: gearCount
                )
                let capture = validCapture(
                    drivetrain: drivetrain,
                    gearCount: gearCount,
                    availability: .notShown
                )
                XCTAssertTrue(
                    FH5ResearchObservationFactory()
                        .validationIssues(capture: capture, drivetrain: drivetrain)
                        .isEmpty
                )
                XCTAssertEqual(capture.controls.map(\.field), expected)
                XCTAssertEqual(Set(capture.controls.map(\.field)).count, expected.count)
                XCTAssertEqual(
                    expected.filter { $0.gearIndex != nil },
                    (1...gearCount).map(TuneFieldID.gearRatio)
                )

                let differential = expected.filter {
                    $0.projectionSectionTitle == "Differential"
                }
                switch drivetrain {
                case .fwd:
                    XCTAssertEqual(differential, [
                        .frontDifferentialAcceleration,
                        .frontDifferentialDeceleration
                    ])
                case .rwd:
                    XCTAssertEqual(differential, [
                        .differentialAcceleration,
                        .differentialDeceleration
                    ])
                case .awd:
                    XCTAssertEqual(differential, [
                        .frontDifferentialAcceleration,
                        .frontDifferentialDeceleration,
                        .rearDifferentialAcceleration,
                        .rearDifferentialDeceleration,
                        .differentialCenterBalance
                    ])
                }
            }
        }
    }

    func testControlValidationRejectsMissingDuplicateUnexpectedAndForbiddenPayloads() {
        let factory = FH5ResearchObservationFactory()
        let valid = validCapture(drivetrain: .rwd, gearCount: 6, availability: .notShown)
        let first = valid.controls[0]

        var controls = valid.controls
        controls.removeFirst()
        XCTAssertTrue(factory.validationIssues(
            capture: replacing(valid, controls: controls),
            drivetrain: .rwd
        ).contains(.missingField(first.field)))

        controls = valid.controls + [first]
        XCTAssertTrue(factory.validationIssues(
            capture: replacing(valid, controls: controls),
            drivetrain: .rwd
        ).contains(.duplicateField(first.field)))

        controls = valid.controls + [
            FH5TuneFieldObservation(
                field: .frontDifferentialAcceleration,
                availability: .notShown
            ),
            FH5TuneFieldObservation(field: .gearRatio(7), availability: .notShown)
        ]
        let unexpected = factory.validationIssues(
            capture: replacing(valid, controls: controls),
            drivetrain: .rwd
        )
        XCTAssertTrue(unexpected.contains(.unexpectedField(.frontDifferentialAcceleration)))
        XCTAssertTrue(unexpected.contains(.unexpectedField(.gearRatio(7))))

        controls = valid.controls
        controls[0] = FH5TuneFieldObservation(
            field: first.field,
            availability: .notShown,
            current: 30,
            unit: first.field.expectedUnit
        )
        XCTAssertTrue(factory.validationIssues(
            capture: replacing(valid, controls: controls),
            drivetrain: .rwd
        ).contains(.forbiddenNumericPayload(first.field)))

        controls[0] = FH5TuneFieldObservation(
            field: first.field,
            availability: .shownLocked,
            minimum: 15,
            current: 30,
            unit: first.field.expectedUnit
        )
        XCTAssertTrue(factory.validationIssues(
            capture: replacing(valid, controls: controls),
            drivetrain: .rwd
        ).contains(.forbiddenNumericPayload(first.field)))
    }

    func testAdjustableNumericValidationRejectsEveryAdversarialShape() {
        let factory = FH5ResearchObservationFactory()
        let base = validCapture(drivetrain: .rwd, gearCount: 6, availability: .adjustable)
        let field = base.controls[0].field

        func issues(_ observation: FH5TuneFieldObservation) -> [FH5ResearchIssue] {
            var controls = base.controls
            controls[0] = observation
            return factory.validationIssues(
                capture: replacing(base, controls: controls),
                drivetrain: .rwd
            )
        }

        XCTAssertTrue(issues(FH5TuneFieldObservation(
            field: field,
            availability: .adjustable
        )).contains(.missingAdjustablePayload(field)))
        XCTAssertTrue(issues(adjustable(field, minimum: .nan)).contains(.nonFiniteValue(field)))
        XCTAssertTrue(issues(adjustable(field, minimum: 100, maximum: 100)).contains(.invalidRange(field)))
        XCTAssertTrue(issues(adjustable(field, step: 0)).contains(.invalidStep(field)))
        XCTAssertTrue(issues(adjustable(field, current: 101)).contains(.currentOutOfRange(field)))
        XCTAssertTrue(issues(adjustable(field, maximum: 99.5)).contains(.valueOffLattice(field)))
        XCTAssertTrue(issues(adjustable(
            field,
            unit: field.expectedUnit == .psi ? .ratio : .psi
        )).contains(.wrongUnit(field)))

        var invalidGearCount = base
        invalidGearCount = FH5ResearchCapture(
            platform: invalidGearCount.platform,
            gameVersion: invalidGearCount.gameVersion,
            tireCompoundDisplayName: invalidGearCount.tireCompoundDisplayName,
            forwardGearCount: 11,
            controls: invalidGearCount.controls,
            exactUntouchedStockConfirmed: true,
            allSlidersRestoredConfirmed: true,
            personallyReadFromGameConfirmed: true,
            firstPartyAuthorshipConfirmed: true,
            localStoragePermitted: true
        )
        XCTAssertEqual(
            factory.validationIssues(capture: invalidGearCount, drivetrain: .rwd).first,
            .invalidGearCount
        )
    }

    func testFactoryCreatesDetachedProvisionalSnapshotAndCanonicalExport() async throws {
        let plan = try await makePlan(upgradeBuild: "3.688.109.0")
        var capture = validCapture(
            drivetrain: plan.request.car.drivetrain,
            gearCount: 6,
            availability: .adjustable,
            build: "  3.688.109.0  ",
            reuse: true
        )
        capture = replacing(capture, controls: Array(capture.controls.reversed()))

        let record = try FH5ResearchObservationFactory().make(
            tune: plan,
            savedTune: plan,
            isStreaming: false,
            capture: capture,
            recordID: recordID,
            submissionID: submissionID,
            permissionReceiptID: permissionID,
            capturedAt: capturedAt,
            snapshotID: snapshotID
        )
        let expected = TuneFieldID.expectedFields(
            drivetrain: plan.request.car.drivetrain,
            gearCount: 6
        )

        XCTAssertTrue(FH5ResearchObservationFactory().isValid(record))
        XCTAssertEqual(record.game, .fh5)
        XCTAssertEqual(record.gameVersion, "3.688.109.0")
        XCTAssertEqual(record.controls.map(\.field), expected)
        XCTAssertEqual(record.contentFingerprint.count, 64)
        XCTAssertTrue(record.canExport)
        XCTAssertEqual(record.internalValidationSnapshot.kind, .exactBuildObservation)
        XCTAssertEqual(record.internalValidationSnapshot.constraints.count, expected.count)
        XCTAssertTrue(record.internalValidationSnapshot.constraints.allSatisfy {
            $0.scope == .exactVehicleBuild && $0.verification == .provisional
        })
        XCTAssertFalse(record.internalValidationSnapshot.constraints.contains {
            $0.verification == .productionEligible
        })
        XCTAssertEqual(
            Set(record.internalValidationSnapshot.capabilityProfile.parts.map(\.partID)),
            Set(TunePartID.allCases)
        )
        XCTAssertEqual(
            Set(record.internalValidationSnapshot.capabilityProfile.stockAdjustableSettings.map(\.setting)),
            Set(expected.map(\.setting))
        )

        let first = try record.deterministicJSON()
        let second = try record.deterministicJSON()
        XCTAssertEqual(first, second)
        let json = try XCTUnwrap(String(data: first, encoding: .utf8))
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: first) as? [String: Any]
        )
        XCTAssertFalse(json.contains(recordID.uuidString))
        XCTAssertFalse(json.contains(plan.id.uuidString))
        XCTAssertNil(object["discipline"])
        XCTAssertFalse(json.contains("\"providerInfo\""))
        XCTAssertFalse(json.contains("\"rulesetReference\""))
        XCTAssertFalse(json.contains("\"planRevisionFingerprint\""))
        XCTAssertFalse(json.contains("\"internalValidationSnapshot\""))
        XCTAssertFalse(json.contains("\"screenshots\""))
        XCTAssertFalse(json.contains("\"sourceURLs\""))
        XCTAssertTrue(json.contains("\"contentFingerprint\""))
        XCTAssertNil(object["upgradeParts"])
        XCTAssertEqual(Set(object.keys), Set([
            "schemaVersion",
            "consentVersion",
            "submissionID",
            "permissionReceiptID",
            "capturedAt",
            "game",
            "platform",
            "gameVersion",
            "unitScope",
            "vehicle",
            "tireCompoundDisplayName",
            "forwardGearCount",
            "controls",
            "attestations",
            "unknowns",
            "privacyExclusions",
            "contentFingerprint"
        ]))
        XCTAssertNoThrow(try record.publicExport())
    }

    func testReusePermissionDefaultsOffAndExportFailsClosed() async throws {
        let plan = try await makePlan()
        let capture = validCapture(
            drivetrain: plan.request.car.drivetrain,
            gearCount: 6,
            availability: .notShown
        )
        XCTAssertFalse(capture.deidentifiedStructuredReusePermitted)

        let record = try FH5ResearchObservationFactory().make(
            tune: plan,
            savedTune: plan,
            isStreaming: false,
            capture: capture,
            capturedAt: capturedAt
        )
        XCTAssertTrue(FH5ResearchObservationFactory().isValid(record))
        XCTAssertFalse(record.canExport)
        XCTAssertNil(record.deterministicJSONString)
        XCTAssertThrowsError(try record.deterministicJSON()) {
            XCTAssertEqual($0 as? FH5ResearchIssue, .reuseNotPermitted)
        }
        XCTAssertThrowsError(try record.publicExport()) {
            XCTAssertEqual($0 as? FH5ResearchIssue, .reuseNotPermitted)
        }
    }

    func testPublicSemanticFingerprintExcludesLocalUpgradeAvailability() async throws {
        let offeredPlan = try await makePlan(upgradeBuild: "matching-build")
        var unavailablePlan = offeredPlan
        for index in try XCTUnwrap(
            unavailablePlan.request.buildSnapshot
        ).capabilityProfile.parts.indices {
            unavailablePlan.request.buildSnapshot?
                .capabilityProfile.parts[index].availability = .unavailable
        }
        XCTAssertTrue(try XCTUnwrap(unavailablePlan.request.buildSnapshot).isValid)

        let capture = validCapture(
            drivetrain: offeredPlan.request.car.drivetrain,
            gearCount: 6,
            availability: .adjustable,
            build: "matching-build",
            reuse: true
        )
        let factory = FH5ResearchObservationFactory()
        let offered = try factory.make(
            tune: offeredPlan,
            savedTune: offeredPlan,
            isStreaming: false,
            capture: capture,
            recordID: recordID,
            submissionID: submissionID,
            permissionReceiptID: permissionID,
            capturedAt: capturedAt,
            snapshotID: snapshotID
        )
        let unavailable = try factory.make(
            tune: unavailablePlan,
            savedTune: unavailablePlan,
            isStreaming: false,
            capture: capture,
            recordID: UUID(),
            submissionID: submissionID,
            permissionReceiptID: permissionID,
            capturedAt: capturedAt,
            snapshotID: UUID()
        )

        XCTAssertNotEqual(offered.upgradeParts, unavailable.upgradeParts)
        XCTAssertNotEqual(offered.contentFingerprint, unavailable.contentFingerprint)
        let offeredExport = try offered.publicExport()
        let unavailableExport = try unavailable.publicExport()
        XCTAssertEqual(offeredExport, unavailableExport)
        XCTAssertEqual(
            offeredExport.contentFingerprint,
            unavailableExport.contentFingerprint
        )
        XCTAssertNotEqual(offeredExport.contentFingerprint, offered.contentFingerprint)
        XCTAssertNotEqual(unavailableExport.contentFingerprint, unavailable.contentFingerprint)
        XCTAssertEqual(try offered.deterministicJSON(), try unavailable.deterministicJSON())

        var tamperedSnapshot = offered.internalValidationSnapshot
        tamperedSnapshot.capabilityProfile.parts[0].availability = .unavailable
        XCTAssertTrue(tamperedSnapshot.isValid)
        XCTAssertFalse(factory.isValid(replacing(offered, snapshot: tamperedSnapshot)))
    }

    func testStockAdjustableOverridesRequireEveryApplicableField() async throws {
        let plan = try await makePlan()
        var capture = validCapture(
            drivetrain: plan.request.car.drivetrain,
            gearCount: 6,
            availability: .adjustable
        )
        let rearCamberIndex = try XCTUnwrap(
            capture.controls.firstIndex { $0.field == .rearCamber }
        )
        var controls = capture.controls
        controls[rearCamberIndex] = FH5TuneFieldObservation(
            field: .rearCamber,
            availability: .shownLocked,
            current: 0,
            unit: .degrees
        )
        capture = replacing(capture, controls: controls)

        let record = try FH5ResearchObservationFactory().make(
            tune: plan,
            savedTune: plan,
            isStreaming: false,
            capture: capture,
            capturedAt: capturedAt
        )
        let settings = Set(
            record.internalValidationSnapshot.capabilityProfile
                .stockAdjustableSettings.map(\.setting)
        )
        XCTAssertFalse(settings.contains(.alignment))
        XCTAssertTrue(settings.contains(.frontARB))
        XCTAssertFalse(
            record.internalValidationSnapshot.constraints.contains {
                $0.field == .rearCamber
            }
        )
    }

    func testCompleteUpgradeObservationRequiresMatchingBuildAndIncompleteEvidenceDoesNotGate() async throws {
        let plan = try await makePlan(upgradeBuild: "matching-build")
        XCTAssertEqual(
            FH5ResearchObservationFactory().verifiedUpgradeGameVersion(
                in: try XCTUnwrap(plan.request.buildSnapshot)
            ),
            "matching-build"
        )
        let matching = try FH5ResearchObservationFactory().make(
            tune: plan,
            savedTune: plan,
            isStreaming: false,
            capture: validCapture(
                drivetrain: plan.request.car.drivetrain,
                gearCount: 6,
                availability: .notShown,
                build: "matching-build"
            ),
            capturedAt: capturedAt
        )
        XCTAssertEqual(
            matching.internalValidationSnapshot.capabilityProfile.parts.count,
            TunePartID.allCases.count
        )

        XCTAssertThrowsError(try FH5ResearchObservationFactory().make(
            tune: plan,
            savedTune: plan,
            isStreaming: false,
            capture: validCapture(
                drivetrain: plan.request.car.drivetrain,
                gearCount: 6,
                availability: .notShown,
                build: "different-build"
            ),
            capturedAt: capturedAt
        )) {
            XCTAssertEqual(
                $0 as? FH5ResearchIssue,
                .mismatchedGameVersion(
                    expected: "matching-build",
                    entered: "different-build"
                )
            )
        }

        var incomplete = try await makePlan()
        let incompleteBuild = "partial-build"
        let evidence = TuneEvidence(
            confidence: .medium,
            source: UpgradePartCapture.provenanceSource,
            version: incompleteBuild,
            usagePermission: .permitted
        )
        incomplete.request.buildSnapshot?.gameBuild = GameBuildReference(
            game: .fh5,
            version: incompleteBuild,
            capturedAt: capturedAt
        )
        incomplete.request.buildSnapshot?.capabilityProfile.parts = [
            TuneVehiclePart(
                partID: TunePartID.allCases[0],
                availability: .available,
                evidence: evidence
            )
        ]
        XCTAssertTrue(try XCTUnwrap(incomplete.request.buildSnapshot).isValid)
        XCTAssertNil(FH5ResearchObservationFactory().verifiedUpgradeGameVersion(
            in: try XCTUnwrap(incomplete.request.buildSnapshot)
        ))
        let independent = try FH5ResearchObservationFactory().make(
            tune: incomplete,
            savedTune: incomplete,
            isStreaming: false,
            capture: validCapture(
                drivetrain: incomplete.request.car.drivetrain,
                gearCount: 6,
                availability: .notShown,
                build: "independently-observed-build"
            ),
            capturedAt: capturedAt
        )
        XCTAssertTrue(independent.upgradeParts.isEmpty)
        XCTAssertTrue(independent.internalValidationSnapshot.capabilityProfile.parts.isEmpty)
    }

    @MainActor
    func testSeparateSwiftDataBlobAppendDedupeReopenDeleteAndCorruptIsolation() async throws {
        let plan = try await makePlan()
        let capture = validCapture(
            drivetrain: plan.request.car.drivetrain,
            gearCount: 6,
            availability: .notShown,
            reuse: true
        )
        let record = try FH5ResearchObservationFactory().make(
            tune: plan,
            savedTune: plan,
            isStreaming: false,
            capture: capture,
            recordID: recordID,
            submissionID: submissionID,
            permissionReceiptID: permissionID,
            capturedAt: capturedAt,
            snapshotID: snapshotID
        )
        let duplicateContent = try FH5ResearchObservationFactory().make(
            tune: plan,
            savedTune: plan,
            isStreaming: false,
            capture: capture,
            recordID: UUID(),
            submissionID: UUID(),
            permissionReceiptID: UUID(),
            capturedAt: capturedAt,
            snapshotID: UUID()
        )
        XCTAssertEqual(record.contentFingerprint, duplicateContent.contentFingerprint)

        let container = try ModelContainer(
            for: SavedTune.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let saved = try SavedTune(tune: plan)
        context.insert(saved)
        try context.save()
        XCTAssertTrue(saved.fh5ResearchObservationRecords.isEmpty)
        let originalTune = try XCTUnwrap(saved.tuneResult)
        let validationBlob = try JSONEncoder().encode([FirstPartyValidationRecord]())
        saved.replaceValidationRecordsDataForTesting(validationBlob)

        try saved.appendFH5ResearchObservationRecord(record)
        try saved.appendFH5ResearchObservationRecord(record)
        try saved.appendFH5ResearchObservationRecord(duplicateContent)
        try context.save()
        XCTAssertEqual(saved.fh5ResearchObservationRecords, [record])
        XCTAssertEqual(saved.tuneResult, originalTune)
        XCTAssertTrue(saved.firstPartyValidationRecords.isEmpty)

        let reopened = try XCTUnwrap(
            context.fetch(FetchDescriptor<SavedTune>()).first
        )
        XCTAssertEqual(reopened.fh5ResearchObservationRecords, [record])
        XCTAssertEqual(reopened.tuneResult, originalTune)

        XCTAssertTrue(try reopened.deleteFH5ResearchObservationRecord(id: recordID))
        XCTAssertTrue(reopened.fh5ResearchObservationRecords.isEmpty)
        XCTAssertEqual(reopened.tuneResult, originalTune)

        reopened.replaceFH5ResearchObservationRecordsDataForTesting(Data("corrupt".utf8))
        XCTAssertTrue(reopened.fh5ResearchObservationRecords.isEmpty)
        XCTAssertEqual(reopened.tuneResult, originalTune)
        XCTAssertTrue(reopened.firstPartyValidationRecords.isEmpty)
        XCTAssertThrowsError(try reopened.appendFH5ResearchObservationRecord(record)) {
            XCTAssertEqual($0 as? SavedTuneFH5ResearchRecordError, .corruptStorage)
        }
        XCTAssertEqual(reopened.tuneResult, originalTune)
    }

    @MainActor
    func testStoredHistoryOnlySurfacesRecordsMatchingCurrentSavedPlan() async throws {
        let plan = try await makePlan()
        let record = try FH5ResearchObservationFactory().make(
            tune: plan,
            savedTune: plan,
            isStreaming: false,
            capture: validCapture(
                drivetrain: plan.request.car.drivetrain,
                gearCount: 6,
                availability: .notShown,
                reuse: true
            ),
            capturedAt: capturedAt
        )
        let saved = try SavedTune(tune: plan)
        try saved.appendFH5ResearchObservationRecord(record)
        XCTAssertEqual(saved.fh5ResearchObservationRecords(matching: plan), [record])

        var revisedCatalog = plan
        let reference = try XCTUnwrap(revisedCatalog.request.car.catalogReference)
        let revisedReference = CatalogCarReference(
            entryID: reference.entryID,
            revision: "\(reference.revision)-new",
            reviewedAt: reference.reviewedAt.addingTimeInterval(1),
            verificationStatus: reference.verificationStatus,
            sources: reference.sources
        )
        revisedCatalog.request.car.catalogReference = revisedReference
        revisedCatalog.request.buildSnapshot?.car.catalogReference = revisedReference
        revisedCatalog.generatedAt = revisedCatalog.generatedAt.addingTimeInterval(1)
        try saved.update(with: revisedCatalog)
        XCTAssertEqual(saved.fh5ResearchObservationRecords, [record])
        XCTAssertTrue(saved.fh5ResearchObservationRecords(matching: revisedCatalog).isEmpty)

        let otherFH5Car = try await makePlan(fh5EntryOffset: 1)
        try saved.update(with: otherFH5Car)
        XCTAssertEqual(saved.fh5ResearchObservationRecords, [record])
        XCTAssertTrue(saved.fh5ResearchObservationRecords(matching: otherFH5Car).isEmpty)

        let fh6Tune = try await makeTune(game: .fh6)
        try saved.update(with: fh6Tune)
        XCTAssertEqual(saved.fh5ResearchObservationRecords, [record])
        XCTAssertTrue(saved.fh5ResearchObservationRecords(matching: fh6Tune).isEmpty)

        let recorded = !saved.fh5ResearchObservationRecords(matching: fh6Tune).isEmpty
        let context = CopilotContextFactory().make(
            step: .result(
                fh6Tune,
                savedTuneID: saved.id,
                adjustmentChanges: [],
                thumbnailData: nil,
                playerNotes: ""
            ),
            savedTuneCount: 1,
            catalogCarCount: 1,
            fh5ObservationRecorded: recorded
        )
        XCTAssertFalse(recorded)
        XCTAssertNotEqual(context.projection?.fh5ObservationRecorded, true)
        XCTAssertFalse(context.facts.contains { $0.label == "FH5 stock evidence" })
    }

    func testDetachedSnapshotRejectsIndividuallyValidSemanticTampering() async throws {
        let plan = try await makePlan(upgradeBuild: "matching-build")
        let record = try FH5ResearchObservationFactory().make(
            tune: plan,
            savedTune: plan,
            isStreaming: false,
            capture: validCapture(
                drivetrain: plan.request.car.drivetrain,
                gearCount: 6,
                availability: .adjustable,
                build: "matching-build",
                reuse: true
            ),
            capturedAt: capturedAt,
            snapshotID: snapshotID
        )
        let factory = FH5ResearchObservationFactory()

        var carTamper = record.internalValidationSnapshot
        carTamper.car.weightPounds += 1
        XCTAssertTrue(carTamper.isValid)
        XCTAssertFalse(factory.isValid(replacing(record, snapshot: carTamper)))

        var constraintTamper = record.internalValidationSnapshot
        constraintTamper.constraints[0].minimum -= constraintTamper.constraints[0].step
        XCTAssertTrue(constraintTamper.isValid)
        XCTAssertFalse(factory.isValid(replacing(record, snapshot: constraintTamper)))

        var evidenceTamper = record.internalValidationSnapshot
        let forgedEvidenceID = "fh5-research.forged-but-valid"
        evidenceTamper.evidenceSources[0].id = forgedEvidenceID
        for index in evidenceTamper.constraints.indices {
            evidenceTamper.constraints[index].evidenceIDs = [forgedEvidenceID]
        }
        evidenceTamper.tireCompound?.evidenceIDs = [forgedEvidenceID]
        XCTAssertTrue(evidenceTamper.isValid)
        XCTAssertFalse(factory.isValid(replacing(record, snapshot: evidenceTamper)))

        var tireTamper = record.internalValidationSnapshot
        tireTamper.tireCompound?.id = "different-valid-tire-id"
        XCTAssertTrue(tireTamper.isValid)
        XCTAssertFalse(factory.isValid(replacing(record, snapshot: tireTamper)))

        var stockSettingTamper = record.internalValidationSnapshot
        stockSettingTamper.capabilityProfile.stockAdjustableSettings[0].evidence.version =
            "different-valid-build"
        XCTAssertTrue(stockSettingTamper.isValid)
        XCTAssertFalse(factory.isValid(replacing(record, snapshot: stockSettingTamper)))

        var partTamper = record.internalValidationSnapshot
        partTamper.capabilityProfile.parts[0].availability =
            partTamper.capabilityProfile.parts[0].availability == .available
                ? .unavailable
                : .available
        XCTAssertTrue(partTamper.isValid)
        XCTAssertFalse(factory.isValid(replacing(record, snapshot: partTamper)))
    }

    func testDetachedSnapshotCannotPromoteOrMutateFH5PlanBoundary() async throws {
        let plan = try await makePlan()
        let record = try FH5ResearchObservationFactory().make(
            tune: plan,
            savedTune: plan,
            isStreaming: false,
            capture: validCapture(
                drivetrain: plan.request.car.drivetrain,
                gearCount: 6,
                availability: .adjustable,
                reuse: true
            ),
            capturedAt: capturedAt
        )
        var adversarial = plan
        adversarial.request.buildSnapshot = record.internalValidationSnapshot
        let projected = TuneResultBoundarySanitizer().sanitize(adversarial)

        XCTAssertEqual(projected.purpose, .fh5BuildPlan)
        XCTAssertTrue(projected.sections.isEmpty)
        XCTAssertNil(projected.providerInfo)
        XCTAssertNil(projected.rulesetReference)
        XCTAssertEqual(projected.projectionReport?.readyCount, 0)
        XCTAssertNil(TuneClipboardFormatter.verifiedSettingsText(for: projected))
        XCTAssertNil(VerifiedBuildShareCardFactory().make(for: projected, isStreaming: false))
        XCTAssertNil(TirePressureCaptureEligibility().snapshot(for: projected))
        XCTAssertNil(UpgradePartCaptureEligibility().snapshot(for: projected))
        XCTAssertFailure(
            FirstPartyValidationRecordFactory().eligibility(
                for: projected,
                savedTune: projected,
                isStreaming: false
            ),
            .incompleteStockContext
        )
    }

    @MainActor
    func testCopilotResearchEligibilityUsesPersistedCurrentRevisionAndFailsClosed() async throws {
        let plan = try await makePlan()
        let factory = CopilotContextFactory()
        let step = WorkflowStep.result(
            plan,
            savedTuneID: plan.id,
            adjustmentChanges: [],
            thumbnailData: nil,
            playerNotes: ""
        )

        XCTAssertTrue(factory.fh5ResearchLabEligibility(
            for: plan,
            persistedTune: plan,
            isStreaming: false
        ))
        XCTAssertFalse(factory.fh5ResearchLabEligibility(
            for: plan,
            persistedTune: nil,
            isStreaming: false
        ))
        XCTAssertFalse(factory.make(
            step: step,
            savedTuneCount: 1,
            catalogCarCount: 1
        ).projection?.fh5ResearchLabEligible ?? true)

        var stale = plan
        stale.generatedAt = stale.generatedAt.addingTimeInterval(1)
        XCTAssertFalse(factory.fh5ResearchLabEligibility(
            for: plan,
            persistedTune: stale,
            isStreaming: false
        ))

        var differentRevision = plan
        let reference = try XCTUnwrap(differentRevision.request.car.catalogReference)
        let changedReference = CatalogCarReference(
            entryID: reference.entryID,
            revision: "\(reference.revision)-different",
            reviewedAt: reference.reviewedAt,
            verificationStatus: reference.verificationStatus,
            sources: reference.sources
        )
        differentRevision.request.car.catalogReference = changedReference
        differentRevision.request.buildSnapshot?.car.catalogReference = changedReference
        XCTAssertFalse(factory.fh5ResearchLabEligibility(
            for: plan,
            persistedTune: differentRevision,
            isStreaming: false
        ))

        let fh6 = try await makeTune(game: .fh6)
        XCTAssertFalse(factory.fh5ResearchLabEligibility(
            for: fh6,
            persistedTune: fh6,
            isStreaming: false
        ))

        let corrupt = try SavedTune(tune: plan)
        corrupt.replaceTuneDataForTesting(Data("corrupt tuneData".utf8))
        XCTAssertNil(corrupt.tuneResult)
        XCTAssertFalse(factory.fh5ResearchLabEligibility(
            for: plan,
            persistedTune: corrupt.tuneResult,
            isStreaming: false
        ))
    }

    func testCopilotTreatsRecordedObservationAsEvidenceRatherThanTuneReadiness() async throws {
        let plan = try await makePlan()
        let factory = CopilotContextFactory()
        let step = WorkflowStep.result(
            plan,
            savedTuneID: plan.id,
            adjustmentChanges: [],
            thumbnailData: nil,
            playerNotes: ""
        )
        let available = factory.make(
            step: step,
            savedTuneCount: 1,
            catalogCarCount: 1,
            fh5ResearchLabEligible: true
        )
        let recorded = factory.make(
            step: step,
            savedTuneCount: 1,
            catalogCarCount: 1,
            fh5ResearchLabEligible: true,
            fh5ObservationRecorded: true
        )
        let engine = CopilotEngine()

        XCTAssertEqual(available.projection?.resultPurpose, .fh5BuildPlan)
        XCTAssertEqual(available.projection?.readyCount, 0)
        XCTAssertEqual(available.projection?.fh5ResearchLabEligible, true)
        XCTAssertTrue(
            engine.response(to: .nextStep, in: available).message
                .contains("Open FH5 Research Lab")
        )

        XCTAssertEqual(recorded.projection?.readyCount, 0)
        XCTAssertEqual(recorded.projection?.fh5ObservationRecorded, true)
        for intent in [CopilotIntent.nextStep, .trust, .missing] {
            let message = engine.response(to: intent, in: recorded).message.lowercased()
            XCTAssertTrue(
                message.contains("evidence"),
                "\(intent.rawValue) must identify the record as evidence: \(message)"
            )
            XCTAssertTrue(
                message.contains("not a tune") || message.contains("numeric"),
                "\(intent.rawValue) must preserve the numeric-tune boundary: \(message)"
            )
        }
    }

    func testReviewIngestorRequiresExactCanonicalValidPermissionReadyExport() async throws {
        let plan = try await makePlan()
        let export = try makeReviewExport(plan: plan)
        let data = try FH5ResearchReviewIngestor.canonicalData(for: export)
        let ingestor = FH5ResearchReviewIngestor()

        let validated = try ingestor.validate(data)
        XCTAssertEqual(validated.export, export)
        XCTAssertTrue(ingestor.matchesSavedPlan(validated, tune: plan))

        XCTAssertThrowsError(try ingestor.validate(data + Data("\n".utf8))) {
            XCTAssertEqual($0 as? FH5ResearchReviewError, .nonCanonicalJSON)
        }
        XCTAssertThrowsError(try ingestor.validate(insertingTopLevel(
            "\"unexpected\" : true",
            into: data
        ))) {
            XCTAssertEqual($0 as? FH5ResearchReviewError, .nonCanonicalJSON)
        }
        XCTAssertThrowsError(try ingestor.validate(insertingTopLevel(
            "\"schemaVersion\" : 1",
            into: data
        ))) {
            XCTAssertEqual($0 as? FH5ResearchReviewError, .nonCanonicalJSON)
        }
        XCTAssertThrowsError(try ingestor.validate(
            Data(repeating: 0x20, count: FH5ResearchReviewIngestor.maximumPayloadBytes + 1)
        )) {
            XCTAssertEqual($0 as? FH5ResearchReviewError, .payloadTooLarge)
        }

        let badFingerprint = replacingReviewExport(
            export,
            contentFingerprint: String(repeating: "0", count: 64)
        )
        XCTAssertThrowsError(try ingestor.validate(
            FH5ResearchReviewIngestor.canonicalData(for: badFingerprint)
        )) {
            XCTAssertEqual($0 as? FH5ResearchReviewError, .invalidContentFingerprint)
        }

        let reuseOffAttestations = FH5ResearchObservationRecord.Attestations(
            exactUntouchedStock: true,
            allSlidersRestored: true,
            personallyReadFromGame: true,
            firstPartyAuthorship: true,
            localStoragePermitted: true,
            deidentifiedStructuredReusePermitted: false
        )
        let reuseOff = try replacingReviewExport(
            export,
            attestations: reuseOffAttestations,
            recomputingFingerprint: true
        )
        XCTAssertThrowsError(try ingestor.validate(
            FH5ResearchReviewIngestor.canonicalData(for: reuseOff)
        )) {
            XCTAssertEqual($0 as? FH5ResearchReviewError, .invalidStructure)
        }

        let reordered = try replacingReviewExport(
            export,
            controls: Array(export.controls.reversed()),
            recomputingFingerprint: true
        )
        XCTAssertThrowsError(try ingestor.validate(
            FH5ResearchReviewIngestor.canonicalData(for: reordered)
        )) {
            XCTAssertEqual($0 as? FH5ResearchReviewError, .invalidStructure)
        }
    }

    func testReviewPermissionQuarantineAndAdministrativeReplayFailClosed() async throws {
        let plan = try await makePlan()
        let first = try makeReviewExport(plan: plan)
        let firstData = try FH5ResearchReviewIngestor.canonicalData(for: first)
        let firstInput = try reviewInput(for: firstData)
        let evaluator = FH5ResearchReviewEvaluator()

        let quarantined = evaluator.evaluate([
            FH5ResearchReviewInput(exportJSON: firstData, permission: nil)
        ])
        XCTAssertEqual(quarantined.quarantinedCount, 1)
        XCTAssertEqual(quarantined.verifiedUniqueObservationCount, 0)

        let wrongPermission = FH5ResearchReviewPermission(
            submissionID: first.submissionID,
            permissionReceiptID: first.permissionReceiptID,
            consentVersion: first.consentVersion,
            canonicalExportDigest: String(repeating: "0", count: 64),
            contentFingerprint: first.contentFingerprint,
            locallyReviewedAt: capturedAt
        )
        XCTAssertEqual(evaluator.evaluate([
            FH5ResearchReviewInput(
                exportJSON: firstData,
                permission: wrongPermission
            )
        ]).quarantinedCount, 1)

        let sameSubmissionConflict = try replacingReviewExport(
            first,
            permissionReceiptID: UUID(),
            capturedAt: capturedAt.addingTimeInterval(60),
            recomputingFingerprint: true
        )
        let sameSubmissionInput = try reviewInput(
            for: FH5ResearchReviewIngestor.canonicalData(for: sameSubmissionConflict)
        )
        let submissionReport = evaluator.evaluate([firstInput, sameSubmissionInput])
        XCTAssertEqual(submissionReport.administrativeConflictCount, 2)
        XCTAssertEqual(submissionReport.verifiedUniqueObservationCount, 0)
        XCTAssertTrue(submissionReport.groups.isEmpty)

        let receiptReplay = try replacingReviewExport(
            first,
            submissionID: UUID(),
            capturedAt: capturedAt.addingTimeInterval(120),
            recomputingFingerprint: true
        )
        let receiptInput = try reviewInput(
            for: FH5ResearchReviewIngestor.canonicalData(for: receiptReplay)
        )
        let receiptReport = evaluator.evaluate([firstInput, receiptInput])
        XCTAssertEqual(receiptReport.administrativeConflictCount, 2)
        XCTAssertEqual(receiptReport.receiptReplayCount, 2)
        XCTAssertEqual(
            receiptReport,
            evaluator.evaluate([receiptInput, firstInput])
        )
    }

    func testReviewSuppressesAdministrativeCopiesButCountsDistinctCaptureSessions() async throws {
        let plan = try await makePlan()
        let first = try makeReviewExport(plan: plan)
        let administrativeCopy = try replacingReviewExport(
            first,
            submissionID: UUID(),
            permissionReceiptID: UUID(),
            recomputingFingerprint: true
        )
        let firstInput = try reviewInput(
            for: FH5ResearchReviewIngestor.canonicalData(for: first)
        )
        let copyInput = try reviewInput(
            for: FH5ResearchReviewIngestor.canonicalData(for: administrativeCopy)
        )
        let copiedReport = FH5ResearchReviewEvaluator().evaluate([
            firstInput,
            copyInput
        ])
        XCTAssertEqual(copiedReport.verifiedUniqueObservationCount, 1)
        XCTAssertEqual(copiedReport.duplicateCount, 1)
        XCTAssertEqual(copiedReport.groups.first?.status, .insufficient)

        let secondSession = try replacingReviewExport(
            first,
            submissionID: UUID(),
            permissionReceiptID: UUID(),
            capturedAt: capturedAt.addingTimeInterval(60),
            recomputingFingerprint: true
        )
        let secondInput = try reviewInput(
            for: FH5ResearchReviewIngestor.canonicalData(for: secondSession)
        )
        let replicated = FH5ResearchReviewEvaluator().evaluate([
            firstInput,
            secondInput
        ])
        XCTAssertEqual(replicated.verifiedUniqueObservationCount, 2)
        XCTAssertEqual(replicated.groups.count, 1)
        XCTAssertEqual(replicated.groups.first?.status, .replicated)
        XCTAssertEqual(replicated.groups.first?.measurementVariantCount, 1)
    }

    func testReviewUsesExactConflictsAndNeverMergesBuildsOrPlatforms() async throws {
        let plan = try await makePlan()
        let first = try makeReviewExport(plan: plan)
        var changedControls = first.controls
        let changed = changedControls[0]
        changedControls[0] = FH5TuneFieldObservation(
            field: changed.field,
            availability: .shownLocked,
            current: 50,
            unit: changed.field.expectedUnit
        )
        let conflicting = try replacingReviewExport(
            first,
            submissionID: UUID(),
            permissionReceiptID: UUID(),
            capturedAt: capturedAt.addingTimeInterval(60),
            controls: changedControls,
            recomputingFingerprint: true
        )
        let conflictReport = FH5ResearchReviewEvaluator().evaluate([
            try reviewInput(for: FH5ResearchReviewIngestor.canonicalData(for: first)),
            try reviewInput(for: FH5ResearchReviewIngestor.canonicalData(for: conflicting))
        ])
        XCTAssertEqual(conflictReport.groups.count, 1)
        XCTAssertEqual(conflictReport.groups.first?.status, .conflicted)
        XCTAssertEqual(conflictReport.groups.first?.measurementVariantCount, 2)

        let otherBuild = try replacingReviewExport(
            first,
            submissionID: UUID(),
            permissionReceiptID: UUID(),
            capturedAt: capturedAt.addingTimeInterval(120),
            gameVersion: "different-build",
            recomputingFingerprint: true
        )
        let otherPlatform = try replacingReviewExport(
            first,
            submissionID: UUID(),
            permissionReceiptID: UUID(),
            capturedAt: capturedAt.addingTimeInterval(180),
            platform: .steamPC,
            recomputingFingerprint: true
        )
        let boundaryReport = FH5ResearchReviewEvaluator().evaluate([
            try reviewInput(for: FH5ResearchReviewIngestor.canonicalData(for: first)),
            try reviewInput(for: FH5ResearchReviewIngestor.canonicalData(for: otherBuild)),
            try reviewInput(for: FH5ResearchReviewIngestor.canonicalData(for: otherPlatform))
        ])
        XCTAssertEqual(boundaryReport.groups.count, 3)
        XCTAssertTrue(boundaryReport.groups.allSatisfy { $0.status == .insufficient })
    }

    @MainActor
    func testReviewPersistencePlanScopeCorruptionAndNonPromotion() async throws {
        let plan = try await makePlan()
        let export = try makeReviewExport(plan: plan)
        let data = try FH5ResearchReviewIngestor.canonicalData(for: export)
        let entry = try FH5ResearchReviewEntry.locallyReviewed(
            canonicalExportJSON: data,
            reviewerConfirmedDirectReceiptAndReusePermission: true,
            now: capturedAt
        )
        let container = try ModelContainer(
            for: SavedTune.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let saved = try SavedTune(tune: plan)
        context.insert(saved)
        try saved.appendFH5ResearchReviewEntry(entry)
        try context.save()

        XCTAssertEqual(saved.fh5ResearchReviewEntries(matching: plan), [entry])
        XCTAssertEqual(
            saved.fh5ResearchReviewReport(matching: plan).groups.first?.status,
            .insufficient
        )
        let persisted = try XCTUnwrap(saved.tuneResult)
        XCTAssertEqual(persisted.id, plan.id)
        XCTAssertTrue(persisted.sections.isEmpty)
        XCTAssertNil(persisted.providerInfo)
        XCTAssertNil(persisted.rulesetReference)
        XCTAssertEqual(persisted.projectionReport?.readyCount, 0)
        XCTAssertTrue(plan.sections.isEmpty)
        XCTAssertNil(plan.providerInfo)
        XCTAssertNil(plan.rulesetReference)
        XCTAssertEqual(plan.projectionReport?.readyCount, 0)
        XCTAssertFalse(plan.request.buildSnapshot?.constraints.contains {
            $0.verification == .productionEligible
        } ?? true)

        let reopened = try XCTUnwrap(
            context.fetch(FetchDescriptor<SavedTune>()).first
        )
        XCTAssertEqual(reopened.fh5ResearchReviewEntries(matching: plan), [entry])
        XCTAssertTrue(try reopened.deleteFH5ResearchReviewEntry(id: entry.id))
        XCTAssertTrue(reopened.fh5ResearchReviewEntries.isEmpty)

        let otherPlan = try await makePlan(fh5EntryOffset: 1)
        let otherExport = try makeReviewExport(plan: otherPlan)
        let otherEntry = try FH5ResearchReviewEntry.locallyReviewed(
            canonicalExportJSON: FH5ResearchReviewIngestor.canonicalData(for: otherExport),
            reviewerConfirmedDirectReceiptAndReusePermission: true
        )
        XCTAssertThrowsError(try reopened.appendFH5ResearchReviewEntry(otherEntry)) {
            XCTAssertEqual($0 as? FH5ResearchReviewError, .planMismatch)
        }

        let inconsistentReviewTimeEntry = FH5ResearchReviewEntry(
            canonicalExportJSON: data,
            permission: FH5ResearchReviewPermission(
                submissionID: export.submissionID,
                permissionReceiptID: export.permissionReceiptID,
                consentVersion: export.consentVersion,
                canonicalExportDigest:
                    try FH5ResearchReviewIngestor().validate(data).canonicalExportDigest,
                contentFingerprint: export.contentFingerprint,
                locallyReviewedAt: capturedAt.addingTimeInterval(1)
            )
        )
        XCTAssertThrowsError(
            try reopened.appendFH5ResearchReviewEntry(inconsistentReviewTimeEntry)
        ) {
            XCTAssertEqual($0 as? FH5ResearchReviewError, .permissionNotConfirmed)
        }

        reopened.replaceFH5ResearchReviewEntriesDataForTesting(Data("corrupt".utf8))
        XCTAssertTrue(reopened.fh5ResearchReviewEntries.isEmpty)
        XCTAssertThrowsError(try reopened.appendFH5ResearchReviewEntry(entry)) {
            XCTAssertEqual($0 as? FH5ResearchReviewError, .corruptStorage)
        }
        let stillPersisted = try XCTUnwrap(reopened.tuneResult)
        XCTAssertEqual(stillPersisted.id, plan.id)
        XCTAssertTrue(stillPersisted.sections.isEmpty)
        XCTAssertNil(stillPersisted.providerInfo)
        XCTAssertNil(stillPersisted.rulesetReference)
        XCTAssertTrue(reopened.fh5ResearchObservationRecords.isEmpty)
    }

    func testNumericReadinessRejectsUnregisteredAlgorithmAfterEveryEvidenceGatePasses() async throws {
        let plan = try await makePlan(upgradeBuild: "3.688.109.0")
        let record = try FH5ResearchObservationFactory().make(
            tune: plan,
            savedTune: plan,
            isStreaming: false,
            capture: validCapture(
                drivetrain: plan.request.car.drivetrain,
                gearCount: 6,
                availability: .adjustable,
                reuse: true
            ),
            capturedAt: capturedAt
        )
        let report = FH5ResearchReviewReport(
            receivedCount: 2,
            verifiedUniqueObservationCount: 2,
            invalidCount: 0,
            quarantinedCount: 0,
            duplicateCount: 0,
            administrativeConflictCount: 0,
            receiptReplayCount: 0,
            groups: [
                FH5ResearchReviewGroup(
                    associationFingerprint: "synthetic-matching-association",
                    association: FH5ResearchReviewAssociation(
                        platform: record.platform,
                        gameVersion: record.gameVersion,
                        vehicle: record.vehicle,
                        tireCompoundDisplayName: record.tireCompoundDisplayName,
                        forwardGearCount: record.forwardGearCount
                    ),
                    observationCount: 2,
                    measurementVariantCount: 1,
                    measurementFingerprint: FH5ResearchReviewIngestor()
                        .measurementFingerprint(for: record.controls),
                    status: .replicated
                )
            ]
        )
        let forged = try XCTUnwrap(TuneRulesetReference(descriptor: TuneRulesetDescriptor(
            id: FH5ExperimentalAlgorithmID.cleanRoomDirectionalV1.rawValue,
            game: .fh5,
            schemaVersion: 1,
            algorithmVersion: "1",
            knowledgeRevision: "unreviewed",
            validationStatus: .validated,
            provenanceIDs: ["self-asserted"]
        )))
        XCTAssertTrue(forged.isValid)

        let assessment = FH5NumericReadinessPolicy().assess(
            tune: plan,
            researchRecords: [record],
            reviewReport: report,
            candidateAlgorithmID: .cleanRoomDirectionalV1,
            controlledOutcomeReport: .unregistered(matchingRecordCount: 1)
        )

        XCTAssertFalse(assessment.canGenerateNumeric)
        XCTAssertEqual(assessment.policyVersion, "fh5-numeric-readiness-v2")
        XCTAssertEqual(
            assessment.items.prefix(4).map(\.state),
            Array(repeating: .complete, count: 4)
        )
        XCTAssertEqual(
            assessment.items.first { $0.gate == .rightsClearedRuleset }?.state,
            .blocked
        )
        XCTAssertEqual(
            assessment.items.first { $0.gate == .controlledOutcomes }?.state,
            .blocked
        )
        XCTAssertTrue(FH5TrustedNumericRulesetRegistry.production.isEmpty)
        XCTAssertNil(
            FH5TrustedNumericRulesetRegistry.production.registration(
                for: .cleanRoomDirectionalV1
            )
        )
    }

    func testNumericRulesetRegistrationBindsRightsThresholdAndCandidate() throws {
        let registration = try makeExperimentalRegistration()
        let registry = try FH5TrustedNumericRulesetRegistry(
            validating: [registration]
        )
        let threshold = registration.outcomeThreshold

        XCTAssertTrue(registration.isValid)
        XCTAssertFalse(registry.isEmpty)
        XCTAssertEqual(
            registry.registration(for: registration.algorithmID),
            registration
        )
        XCTAssertEqual(threshold.minimumUniqueRecords, 10)
        XCTAssertEqual(threshold.minimumVariantPreferred, 8)
        XCTAssertEqual(threshold.maximumBaselinePreferred, 0)
        XCTAssertEqual(threshold.maximumNonDecisive, 2)
        XCTAssertEqual(threshold.minimumDistinctUTCDays, 2)
        XCTAssertTrue(threshold.requiresDeidentifiedReusePermission)
        XCTAssertEqual(
            threshold.protocolVersion,
            FH5ControlledExperimentRecord.currentProtocolVersion
        )
        let sourceFingerprint = try XCTUnwrap(
            registration.sourceManifestFingerprint
        )
        XCTAssertEqual(
            sourceFingerprint,
            FH5NumericRulesetSourceManifest.fingerprint(
                for: Array(registration.sourceManifests.reversed())
            )
        )
        let changedSource = FH5NumericRulesetSourceManifest(
            sourceID: registration.sourceManifests[0].sourceID,
            sourceVersion: registration.sourceManifests[0].sourceVersion,
            owner: "Different rights owner",
            rightsBasis: registration.sourceManifests[0].rightsBasis,
            rightsEvidenceID:
                registration.sourceManifests[0].rightsEvidenceID,
            usagePermission:
                registration.sourceManifests[0].usagePermission
        )
        XCTAssertNotEqual(
            sourceFingerprint,
            FH5NumericRulesetSourceManifest.fingerprint(for: [changedSource])
        )

        let binding = FH5RulesetCandidateBinding(
            algorithmID: registration.algorithmID,
            rulesetReference: registration.reference,
            sourceManifestFingerprint: sourceFingerprint,
            outcomePolicyVersion: threshold.policyVersion,
            generatedCandidateFingerprint: String(repeating: "a", count: 64)
        )
        XCTAssertTrue(binding.isValid(for: registration))
        XCTAssertFalse(FH5RulesetCandidateBinding(
            algorithmID: binding.algorithmID,
            rulesetReference: binding.rulesetReference,
            sourceManifestFingerprint: binding.sourceManifestFingerprint,
            outcomePolicyVersion: binding.outcomePolicyVersion,
            generatedCandidateFingerprint: String(repeating: "A", count: 64)
        ).isValid(for: registration))
        XCTAssertFalse(FH5RulesetCandidateBinding(
            algorithmID: binding.algorithmID,
            rulesetReference: try XCTUnwrap(TuneRulesetReference(
                descriptor: TuneRulesetDescriptor(
                    id: binding.algorithmID.rawValue,
                    game: .fh5,
                    schemaVersion: 1,
                    algorithmVersion: "2",
                    knowledgeRevision: binding.sourceManifestFingerprint,
                    validationStatus: .experimental,
                    provenanceIDs: registration.reference.provenanceIDs
                )
            )),
            sourceManifestFingerprint: binding.sourceManifestFingerprint,
            outcomePolicyVersion: binding.outcomePolicyVersion,
            generatedCandidateFingerprint:
                binding.generatedCandidateFingerprint
        ).isValid(for: registration))
        XCTAssertFalse(FH5RulesetCandidateBinding(
            algorithmID: binding.algorithmID,
            rulesetReference: binding.rulesetReference,
            sourceManifestFingerprint: String(repeating: "b", count: 64),
            outcomePolicyVersion: binding.outcomePolicyVersion,
            generatedCandidateFingerprint:
                binding.generatedCandidateFingerprint
        ).isValid(for: registration))
        XCTAssertFalse(FH5RulesetCandidateBinding(
            algorithmID: binding.algorithmID,
            rulesetReference: binding.rulesetReference,
            sourceManifestFingerprint: binding.sourceManifestFingerprint,
            outcomePolicyVersion: "fh5-controlled-outcome-experimental-v2",
            generatedCandidateFingerprint:
                binding.generatedCandidateFingerprint
        ).isValid(for: registration))
        XCTAssertThrowsError(
            try JSONDecoder().decode(
                FH5ExperimentalAlgorithmID.self,
                from: Data("\"fh5.other-algorithm\"".utf8)
            )
        )
    }

    func testNumericRulesetRegistrationRejectsSelfAssertedOrWeakenedContracts() throws {
        let valid = try makeExperimentalRegistration()
        let unknownPermission = FH5NumericRulesetSourceManifest(
            sourceID: "first-party.clean-room",
            sourceVersion: "1",
            owner: "ForzAdvisor",
            rightsBasis: .firstPartyCleanRoom,
            rightsEvidenceID: "internal.clean-room-record",
            usagePermission: .unknown
        )
        let unknownRights = try makeExperimentalRegistration(
            sourceManifests: [unknownPermission]
        )
        XCTAssertTrue(unknownRights.validationIssues.contains(
            .invalidSourceManifest(unknownPermission.sourceID)
        ))

        let validatedClaim = FH5NumericRulesetRegistration(
            algorithmID: valid.algorithmID,
            reference: try XCTUnwrap(TuneRulesetReference(
                descriptor: TuneRulesetDescriptor(
                    id: valid.reference.id,
                    game: .fh5,
                    schemaVersion: valid.reference.schemaVersion,
                    algorithmVersion: valid.reference.algorithmVersion,
                    knowledgeRevision: valid.reference.knowledgeRevision,
                    validationStatus: .validated,
                    provenanceIDs: valid.reference.provenanceIDs
                )
            )),
            sourceManifests: valid.sourceManifests,
            outcomeThreshold: valid.outcomeThreshold
        )
        XCTAssertTrue(validatedClaim.validationIssues.contains(
            .nonExperimentalStatus
        ))

        let wrongGame = FH5NumericRulesetRegistration(
            algorithmID: valid.algorithmID,
            reference: try XCTUnwrap(TuneRulesetReference(
                descriptor: TuneRulesetDescriptor(
                    id: valid.reference.id,
                    game: .fh6,
                    schemaVersion: valid.reference.schemaVersion,
                    algorithmVersion: valid.reference.algorithmVersion,
                    knowledgeRevision: valid.reference.knowledgeRevision,
                    validationStatus: .experimental,
                    provenanceIDs: valid.reference.provenanceIDs
                )
            )),
            sourceManifests: valid.sourceManifests,
            outcomeThreshold: valid.outcomeThreshold
        )
        XCTAssertTrue(wrongGame.validationIssues.contains(.wrongGame))

        let provenanceMismatch = FH5NumericRulesetRegistration(
            algorithmID: valid.algorithmID,
            reference: try XCTUnwrap(TuneRulesetReference(
                descriptor: TuneRulesetDescriptor(
                    id: valid.reference.id,
                    game: .fh5,
                    schemaVersion: valid.reference.schemaVersion,
                    algorithmVersion: valid.reference.algorithmVersion,
                    knowledgeRevision: valid.reference.knowledgeRevision,
                    validationStatus: .experimental,
                    provenanceIDs: ["different.source"]
                )
            )),
            sourceManifests: valid.sourceManifests,
            outcomeThreshold: valid.outcomeThreshold
        )
        XCTAssertTrue(provenanceMismatch.validationIssues.contains(
            .provenanceMismatch
        ))

        let weakenedThreshold = FH5ControlledOutcomeThreshold(
            policyVersion: "fh5-controlled-outcome-experimental-v1",
            protocolVersion:
                FH5ControlledExperimentRecord.currentProtocolVersion,
            minimumUniqueRecords: 2,
            minimumVariantPreferred: 1,
            maximumBaselinePreferred: 1,
            maximumNonDecisive: 1,
            minimumDistinctUTCDays: 1,
            requiresDeidentifiedReusePermission: true
        )
        let weakened = FH5NumericRulesetRegistration(
            algorithmID: valid.algorithmID,
            reference: valid.reference,
            sourceManifests: valid.sourceManifests,
            outcomeThreshold: weakenedThreshold
        )
        XCTAssertTrue(weakened.validationIssues.contains(
            .unsupportedOutcomeThreshold
        ))
        XCTAssertThrowsError(
            try FH5TrustedNumericRulesetRegistry(
                validating: [weakened]
            )
        ) {
            XCTAssertEqual(
                $0 as? FH5NumericRulesetRegistryIssue,
                .invalidRegistration(weakened.algorithmID)
            )
        }
        XCTAssertThrowsError(
            try FH5TrustedNumericRulesetRegistry(
                validating: [valid, valid]
            )
        ) {
            XCTAssertEqual(
                $0 as? FH5NumericRulesetRegistryIssue,
                .duplicateAlgorithmID(valid.algorithmID)
            )
        }
    }

    func testRegisteredAlgorithmCompletesRightsGateButCannotActivateNumbers() async throws {
        let plan = try await makePlan(upgradeBuild: "3.688.109.0")
        let record = try FH5ResearchObservationFactory().make(
            tune: plan,
            savedTune: plan,
            isStreaming: false,
            capture: validCapture(
                drivetrain: plan.request.car.drivetrain,
                gearCount: 6,
                availability: .adjustable,
                reuse: true
            ),
            capturedAt: capturedAt
        )
        let report = FH5ResearchReviewReport(
            receivedCount: 2,
            verifiedUniqueObservationCount: 2,
            invalidCount: 0,
            quarantinedCount: 0,
            duplicateCount: 0,
            administrativeConflictCount: 0,
            receiptReplayCount: 0,
            groups: [
                FH5ResearchReviewGroup(
                    associationFingerprint: "synthetic-matching-association",
                    association: FH5ResearchReviewAssociation(
                        platform: record.platform,
                        gameVersion: record.gameVersion,
                        vehicle: record.vehicle,
                        tireCompoundDisplayName:
                            record.tireCompoundDisplayName,
                        forwardGearCount: record.forwardGearCount
                    ),
                    observationCount: 2,
                    measurementVariantCount: 1,
                    measurementFingerprint: FH5ResearchReviewIngestor()
                        .measurementFingerprint(for: record.controls),
                    status: .replicated
                )
            ]
        )
        let registration = try makeExperimentalRegistration()
        let registry = try FH5TrustedNumericRulesetRegistry(
            validating: [registration]
        )
        let assessment = FH5NumericReadinessPolicy(
            registry: registry
        ).assess(
            tune: plan,
            researchRecords: [record],
            reviewReport: report,
            candidateAlgorithmID: registration.algorithmID,
            controlledOutcomeReport: .unregistered(matchingRecordCount: 10)
        )

        XCTAssertEqual(
            assessment.items.first { $0.gate == .rightsClearedRuleset }?.state,
            .complete
        )
        XCTAssertEqual(
            assessment.items.first { $0.gate == .controlledOutcomes }?.state,
            .blocked
        )
        XCTAssertFalse(assessment.canGenerateNumeric)
        XCTAssertEqual(plan.purpose, .fh5BuildPlan)
        XCTAssertTrue(plan.sections.isEmpty)
        XCTAssertNil(plan.providerInfo)
        XCTAssertNil(plan.rulesetReference)
    }

    func testNumericReadinessExplainsMissingEvidenceWithoutUnlockingNumbers() async throws {
        let plan = try await makePlan()
        let assessment = FH5NumericReadinessPolicy().assess(
            tune: plan,
            researchRecords: [],
            reviewReport: .empty
        )

        XCTAssertFalse(assessment.canGenerateNumeric)
        XCTAssertEqual(
            assessment.items.first { $0.gate == .exactStockContext }?.state,
            .complete
        )
        XCTAssertEqual(
            assessment.items.first { $0.gate == .firstPartyMenuObservation }?.state,
            .pending
        )
        XCTAssertEqual(
            assessment.items.first { $0.gate == .completeUpgradeObservation }?.state,
            .pending
        )
        XCTAssertEqual(
            assessment.items.first { $0.gate == .replicatedMenuObservation }?.state,
            .pending
        )
        XCTAssertEqual(
            assessment.items.first { $0.gate == .rightsClearedRuleset }?.state,
            .blocked
        )

        var installedPlan = plan
        var installedSnapshot = try XCTUnwrap(installedPlan.request.buildSnapshot)
        installedSnapshot.capabilityProfile.parts.append(TuneVehiclePart(
            partID: .raceBrakes,
            availability: .installed,
            evidence: TuneEvidence(
                confidence: .medium,
                source: "test.first-party-installed-part",
                version: "test",
                usagePermission: .permitted
            )
        ))
        installedPlan.request.buildSnapshot = installedSnapshot
        let installedAssessment = FH5NumericReadinessPolicy().assess(
            tune: installedPlan,
            researchRecords: [],
            reviewReport: .empty
        )
        XCTAssertEqual(
            installedAssessment.items.first { $0.gate == .exactStockContext }?.state,
            .pending
        )
        XCTAssertFalse(installedAssessment.canGenerateNumeric)
    }

    private func makeReviewExport(
        plan: TuneResult,
        submissionID: UUID? = nil,
        permissionReceiptID: UUID? = nil,
        capturedAt: Date? = nil
    ) throws -> FH5ResearchObservationExport {
        let capturedAt = capturedAt ?? self.capturedAt
        let record = try FH5ResearchObservationFactory().make(
            tune: plan,
            savedTune: plan,
            isStreaming: false,
            capture: validCapture(
                drivetrain: plan.request.car.drivetrain,
                gearCount: 6,
                availability: .adjustable,
                reuse: true
            ),
            recordID: UUID(),
            submissionID: submissionID ?? self.submissionID,
            permissionReceiptID: permissionReceiptID ?? permissionID,
            capturedAt: capturedAt,
            snapshotID: UUID()
        )
        return try record.publicExport()
    }

    private func reviewInput(
        for data: Data
    ) throws -> FH5ResearchReviewInput {
        let validated = try FH5ResearchReviewIngestor().validate(data)
        return FH5ResearchReviewInput(
            exportJSON: data,
            permission: FH5ResearchReviewPermission(
                submissionID: validated.export.submissionID,
                permissionReceiptID: validated.export.permissionReceiptID,
                consentVersion: validated.export.consentVersion,
                canonicalExportDigest: validated.canonicalExportDigest,
                contentFingerprint: validated.export.contentFingerprint,
                locallyReviewedAt: capturedAt
            )
        )
    }

    private func replacingReviewExport(
        _ export: FH5ResearchObservationExport,
        contentFingerprint: String
    ) -> FH5ResearchObservationExport {
        FH5ResearchObservationExport(
            schemaVersion: export.schemaVersion,
            consentVersion: export.consentVersion,
            submissionID: export.submissionID,
            permissionReceiptID: export.permissionReceiptID,
            capturedAt: export.capturedAt,
            game: export.game,
            platform: export.platform,
            gameVersion: export.gameVersion,
            unitScope: export.unitScope,
            vehicle: export.vehicle,
            tireCompoundDisplayName: export.tireCompoundDisplayName,
            forwardGearCount: export.forwardGearCount,
            controls: export.controls,
            attestations: export.attestations,
            unknowns: export.unknowns,
            privacyExclusions: export.privacyExclusions,
            contentFingerprint: contentFingerprint
        )
    }

    private func replacingReviewExport(
        _ export: FH5ResearchObservationExport,
        submissionID: UUID? = nil,
        permissionReceiptID: UUID? = nil,
        capturedAt: Date? = nil,
        platform: FH5Platform? = nil,
        gameVersion: String? = nil,
        controls: [FH5TuneFieldObservation]? = nil,
        attestations: FH5ResearchObservationRecord.Attestations? = nil,
        recomputingFingerprint: Bool
    ) throws -> FH5ResearchObservationExport {
        let candidate = FH5ResearchObservationExport(
            schemaVersion: export.schemaVersion,
            consentVersion: export.consentVersion,
            submissionID: submissionID ?? export.submissionID,
            permissionReceiptID: permissionReceiptID ?? export.permissionReceiptID,
            capturedAt: capturedAt ?? export.capturedAt,
            game: export.game,
            platform: platform ?? export.platform,
            gameVersion: gameVersion ?? export.gameVersion,
            unitScope: export.unitScope,
            vehicle: export.vehicle,
            tireCompoundDisplayName: export.tireCompoundDisplayName,
            forwardGearCount: export.forwardGearCount,
            controls: controls ?? export.controls,
            attestations: attestations ?? export.attestations,
            unknowns: export.unknowns,
            privacyExclusions: export.privacyExclusions,
            contentFingerprint: export.contentFingerprint
        )
        guard recomputingFingerprint else { return candidate }
        return replacingReviewExport(
            candidate,
            contentFingerprint: try FH5ResearchObservationFactory()
                .publicSemanticFingerprint(for: candidate)
        )
    }

    private func insertingTopLevel(
        _ member: String,
        into data: Data
    ) throws -> Data {
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        let openingBrace = try XCTUnwrap(json.firstIndex(of: "{"))
        let insertion = json.index(after: openingBrace)
        var modified = json
        modified.insert(contentsOf: "\n  \(member),", at: insertion)
        return Data(modified.utf8)
    }

    func testControlledExperimentEligibilityRequiresMatchingCompleteResearch() async throws {
        let incompletePlan = try await makePlan()
        let factory = FH5ControlledExperimentFactory()

        XCTAssertFailure(
            factory.eligibility(
                tune: incompletePlan,
                savedTune: incompletePlan,
                isStreaming: false,
                researchRecords: []
            ),
            .missingResearchObservation
        )

        let incompleteRecord = try FH5ResearchObservationFactory().make(
            tune: incompletePlan,
            savedTune: incompletePlan,
            isStreaming: false,
            capture: validCapture(
                drivetrain: incompletePlan.request.car.drivetrain,
                gearCount: 6,
                availability: .adjustable
            ),
            capturedAt: capturedAt
        )
        XCTAssertFailure(
            factory.eligibility(
                tune: incompletePlan,
                savedTune: incompletePlan,
                isStreaming: false,
                researchRecords: [incompleteRecord]
            ),
            .incompleteUpgradeObservation
        )

        let plan = try await makePlan(upgradeBuild: "3.688.109.0")
        let record = try FH5ResearchObservationFactory().make(
            tune: plan,
            savedTune: plan,
            isStreaming: false,
            capture: validCapture(
                drivetrain: plan.request.car.drivetrain,
                gearCount: 6,
                availability: .adjustable
            ),
            capturedAt: capturedAt
        )
        let eligibility = factory.eligibility(
            tune: plan,
            savedTune: plan,
            isStreaming: false,
            researchRecords: [record]
        )
        if case .failure(let issue) = eligibility {
            XCTFail("Expected controlled experiment eligibility, got \(issue).")
        }
        XCTAssertFailure(
            factory.eligibility(
                tune: plan,
                savedTune: nil,
                isStreaming: false,
                researchRecords: [record]
            ),
            .notSaved
        )
        XCTAssertFailure(
            factory.eligibility(
                tune: plan,
                savedTune: plan,
                isStreaming: true,
                researchRecords: [record]
            ),
            .streaming
        )
    }

    func testControlledExperimentEnforcesOneLegalStepAndABBAAttestations() async throws {
        let plan = try await makePlan(upgradeBuild: "3.688.109.0")
        let record = try FH5ResearchObservationFactory().make(
            tune: plan,
            savedTune: plan,
            isStreaming: false,
            capture: validCapture(
                drivetrain: plan.request.car.drivetrain,
                gearCount: 6,
                availability: .adjustable
            ),
            capturedAt: capturedAt
        )
        let field = try XCTUnwrap(record.controls.first?.field)
        let factory = FH5ControlledExperimentFactory()
        let valid = experimentCapture(field: field, candidate: 49)

        let experiment = try factory.make(
            tune: plan,
            savedTune: plan,
            isStreaming: false,
            researchRecords: [record],
            capture: valid,
            recordID: recordID,
            submissionID: submissionID,
            permissionReceiptID: permissionID,
            createdAt: capturedAt.addingTimeInterval(60)
        )
        XCTAssertTrue(factory.isValid(experiment))
        XCTAssertEqual(experiment.game, .fh5)
        XCTAssertEqual(experiment.change.baselineValue, 50)
        XCTAssertEqual(experiment.change.candidateValue, 49)
        XCTAssertEqual(experiment.context.sequence, ["A", "B", "B", "A"])
        XCTAssertEqual(experiment.contentFingerprint.count, 64)
        XCTAssertTrue(factory.changeMatchesResearch(
            experiment.change,
            researchRecord: record
        ))
        let forgedChange = FH5ControlledExperimentRecord.Change(
            field: experiment.change.field,
            baselineValue: 40,
            candidateValue: 39,
            minimum: experiment.change.minimum,
            maximum: experiment.change.maximum,
            step: experiment.change.step,
            unit: experiment.change.unit
        )
        XCTAssertFalse(factory.changeMatchesResearch(
            forgedChange,
            researchRecord: record
        ))

        for (candidate, issue) in [
            (50.0, FH5ControlledExperimentIssue.candidateUnchanged),
            (48.0, .candidateNotOneStep),
            (48.5, .candidateOffLattice),
            (101.0, .candidateOutOfRange)
        ] {
            XCTAssertThrowsError(try factory.make(
                tune: plan,
                savedTune: plan,
                isStreaming: false,
                researchRecords: [record],
                capture: experimentCapture(field: field, candidate: candidate)
            )) {
                XCTAssertEqual($0 as? FH5ControlledExperimentIssue, issue)
            }
        }

        let incomplete = FH5ControlledExperimentCapture(
            field: field,
            candidateValue: 49,
            input: .controller,
            surface: .dry,
            targetSymptom: .pushesWide,
            outcome: .variantPreferred,
            sameRouteAndConditionsConfirmed: true,
            sameAssistsAndInputConfirmed: true,
            onlyDeclaredFieldChangedConfirmed: true,
            sequenceCompletedConfirmed: false,
            stockValuesRestoredConfirmed: true,
            firstPartyAuthorshipConfirmed: true,
            localStoragePermitted: true,
            deidentifiedReusePermitted: false
        )
        XCTAssertThrowsError(try factory.make(
            tune: plan,
            savedTune: plan,
            isStreaming: false,
            researchRecords: [record],
            capture: incomplete
        )) {
            XCTAssertEqual(
                $0 as? FH5ControlledExperimentIssue,
                .sequenceNotCompleted
            )
        }
    }

    func testControlledExperimentExportRequiresReusePermission() async throws {
        let plan = try await makePlan(upgradeBuild: "3.688.109.0")
        let research = try FH5ResearchObservationFactory().make(
            tune: plan,
            savedTune: plan,
            isStreaming: false,
            capture: validCapture(
                drivetrain: plan.request.car.drivetrain,
                gearCount: 6,
                availability: .adjustable
            ),
            capturedAt: capturedAt
        )
        let field = try XCTUnwrap(research.controls.first?.field)
        let record = try FH5ControlledExperimentFactory().make(
            tune: plan,
            savedTune: plan,
            isStreaming: false,
            researchRecords: [research],
            capture: experimentCapture(
                field: field,
                candidate: 49
            ),
            createdAt: capturedAt.addingTimeInterval(60)
        )

        XCTAssertFalse(record.canExport)
        XCTAssertNil(record.deterministicJSONString)
        XCTAssertThrowsError(try record.deterministicJSON()) {
            XCTAssertEqual(
                $0 as? FH5ControlledExperimentIssue,
                .reuseNotPermitted
            )
        }
        XCTAssertThrowsError(try record.publicExport()) {
            XCTAssertEqual(
                $0 as? FH5ControlledExperimentIssue,
                .reuseNotPermitted
            )
        }
    }

    func testControlledExperimentExportIsAllowListedAndRoundTrips() async throws {
        let plan = try await makePlan(upgradeBuild: "3.688.109.0")
        let research = try FH5ResearchObservationFactory().make(
            tune: plan,
            savedTune: plan,
            isStreaming: false,
            capture: validCapture(
                drivetrain: plan.request.car.drivetrain,
                gearCount: 6,
                availability: .adjustable
            ),
            capturedAt: capturedAt
        )
        let field = try XCTUnwrap(research.controls.first?.field)
        let record = try FH5ControlledExperimentFactory().make(
            tune: plan,
            savedTune: plan,
            isStreaming: false,
            researchRecords: [research],
            capture: experimentCapture(
                field: field,
                candidate: 49,
                reusePermitted: true
            ),
            recordID: recordID,
            submissionID: submissionID,
            permissionReceiptID: permissionID,
            createdAt: capturedAt.addingTimeInterval(60)
        )
        let factory = FH5ControlledExperimentFactory()
        let data = try record.deterministicJSON()
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let export = try decoder.decode(
            FH5ControlledExperimentExport.self,
            from: data
        )

        XCTAssertTrue(record.canExport)
        XCTAssertTrue(factory.isValid(export))
        XCTAssertEqual(export.submissionID, submissionID)
        XCTAssertEqual(export.permissionReceiptID, permissionID)
        XCTAssertEqual(
            export.privacyExclusions,
            FH5ControlledExperimentRecord.privacyExclusions
        )
        XCTAssertNotEqual(export.contentFingerprint, record.contentFingerprint)
        XCTAssertEqual(try record.deterministicJSON(), data)
        XCTAssertEqual(record.deterministicJSONString, json)

        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        XCTAssertEqual(Set(object.keys), Set([
            "schemaVersion",
            "consentVersion",
            "protocolVersion",
            "submissionID",
            "permissionReceiptID",
            "createdAt",
            "game",
            "measurementFingerprint",
            "context",
            "change",
            "targetSymptom",
            "outcome",
            "attestations",
            "privacyExclusions",
            "contentFingerprint"
        ]))
        let context = try XCTUnwrap(object["context"] as? [String: Any])
        XCTAssertEqual(Set(context.keys), Set([
            "platform",
            "gameVersion",
            "vehicle",
            "tireCompoundDisplayName",
            "forwardGearCount",
            "input",
            "surface",
            "route",
            "sequence"
        ]))
        let vehicle = try XCTUnwrap(context["vehicle"] as? [String: Any])
        XCTAssertEqual(Set(vehicle.keys), Set([
            "catalogID",
            "catalogRevision",
            "catalogReviewedAt",
            "catalogVerificationStatus",
            "year",
            "make",
            "model",
            "performanceClass",
            "performanceIndex",
            "drivetrain",
            "weightPounds",
            "frontWeightPercent",
            "peakHorsepower",
            "peakTorqueFootPounds",
            "stock"
        ]))
        let change = try XCTUnwrap(object["change"] as? [String: Any])
        XCTAssertEqual(Set(change.keys), Set([
            "field",
            "baselineValue",
            "candidateValue",
            "minimum",
            "maximum",
            "step",
            "unit"
        ]))
        let attestations = try XCTUnwrap(
            object["attestations"] as? [String: Any]
        )
        XCTAssertEqual(Set(attestations.keys), Set([
            "sameRouteAndConditions",
            "sameAssistsAndInput",
            "onlyDeclaredFieldChanged",
            "sequenceCompleted",
            "stockValuesRestored",
            "firstPartyAuthorship",
            "localStoragePermitted",
            "deidentifiedReusePermitted"
        ]))

        XCTAssertFalse(json.contains("\"recordID\""))
        XCTAssertFalse(json.contains("\"planRevisionFingerprint\""))
        XCTAssertFalse(json.contains("\"researchContentFingerprint\""))
        XCTAssertFalse(json.contains("\"providerInfo\""))
        XCTAssertFalse(json.contains("\"rulesetReference\""))
        XCTAssertFalse(json.contains(record.recordID.uuidString))
        XCTAssertFalse(json.contains(record.planRevisionFingerprint))
        XCTAssertFalse(json.contains(record.researchContentFingerprint))
    }

    func testControlledExperimentExportRejectsSemanticTampering() async throws {
        let plan = try await makePlan(upgradeBuild: "3.688.109.0")
        let research = try FH5ResearchObservationFactory().make(
            tune: plan,
            savedTune: plan,
            isStreaming: false,
            capture: validCapture(
                drivetrain: plan.request.car.drivetrain,
                gearCount: 6,
                availability: .adjustable
            ),
            capturedAt: capturedAt
        )
        let record = try FH5ControlledExperimentFactory().make(
            tune: plan,
            savedTune: plan,
            isStreaming: false,
            researchRecords: [research],
            capture: experimentCapture(
                field: try XCTUnwrap(research.controls.first?.field),
                candidate: 49,
                reusePermitted: true
            ),
            createdAt: capturedAt.addingTimeInterval(60)
        )
        let data = try record.deterministicJSON()
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        object["outcome"] = FH5ExperimentOutcome.baselinePreferred.rawValue
        let tamperedData = try JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys]
        )
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let tampered = try decoder.decode(
            FH5ControlledExperimentExport.self,
            from: tamperedData
        )

        XCTAssertFalse(FH5ControlledExperimentFactory().isValid(tampered))
        XCTAssertNotEqual(
            try FH5ControlledExperimentFactory()
                .publicSemanticFingerprint(for: tampered),
            tampered.contentFingerprint
        )
    }

    @MainActor
    func testControlledExperimentPersistenceIsolatedAndCannotUnlockNumeric() async throws {
        let plan = try await makePlan(upgradeBuild: "3.688.109.0")
        let research = try FH5ResearchObservationFactory().make(
            tune: plan,
            savedTune: plan,
            isStreaming: false,
            capture: validCapture(
                drivetrain: plan.request.car.drivetrain,
                gearCount: 6,
                availability: .adjustable
            ),
            capturedAt: capturedAt
        )
        let experiment = try FH5ControlledExperimentFactory().make(
            tune: plan,
            savedTune: plan,
            isStreaming: false,
            researchRecords: [research],
            capture: experimentCapture(
                field: try XCTUnwrap(research.controls.first?.field),
                candidate: 49
            ),
            createdAt: capturedAt.addingTimeInterval(60)
        )
        let directory = FileManager.default.temporaryDirectory
            .appending(
                path: "forzadvisor-fh5-outcome-\(UUID().uuidString)",
                directoryHint: .isDirectory
            )
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }
        let configuration = ModelConfiguration(
            url: directory.appending(path: "store.sqlite")
        )

        do {
            let container = try ModelContainer(
                for: SavedTune.self,
                configurations: configuration
            )
            let context = ModelContext(container)
            let saved = try SavedTune(tune: plan)
            context.insert(saved)
            try saved.appendFH5ResearchObservationRecord(research)
            try saved.appendFH5ControlledExperimentRecord(experiment)
            try saved.appendFH5ControlledExperimentRecord(experiment)
            try context.save()
        }

        do {
            let container = try ModelContainer(
                for: SavedTune.self,
                configurations: configuration
            )
            let context = ModelContext(container)
            let saved = try XCTUnwrap(
                context.fetch(FetchDescriptor<SavedTune>()).first
            )
            XCTAssertEqual(
                saved.fh5ControlledExperimentRecords(
                    matching: plan,
                    researchRecord: research
                ),
                [experiment]
            )
            XCTAssertEqual(saved.tuneResult?.purpose, .fh5BuildPlan)
            XCTAssertTrue(saved.tuneResult?.sections.isEmpty == true)
            XCTAssertNil(saved.tuneResult?.providerInfo)
            XCTAssertNil(saved.tuneResult?.rulesetReference)
            XCTAssertTrue(
                try saved.deleteFH5ControlledExperimentRecord(
                    id: experiment.recordID
                )
            )
            try context.save()
        }

        do {
            let container = try ModelContainer(
                for: SavedTune.self,
                configurations: configuration
            )
            let context = ModelContext(container)
            let saved = try XCTUnwrap(
                context.fetch(FetchDescriptor<SavedTune>()).first
            )
            XCTAssertTrue(saved.fh5ControlledExperimentRecords.isEmpty)
            XCTAssertEqual(
                saved.fh5ResearchObservationRecords(matching: plan),
                [research]
            )
            let tuneBeforeCorruption = saved.tuneResult
            let researchBeforeCorruption =
                saved.fh5ResearchObservationRecords(matching: plan)
            try saved.appendFH5ControlledExperimentRecord(experiment)
            saved.replaceFH5ControlledExperimentRecordsDataForTesting(
                Data("corrupt experiment storage".utf8)
            )
            XCTAssertTrue(saved.fh5ControlledExperimentRecords.isEmpty)
            XCTAssertThrowsError(
                try saved.appendFH5ControlledExperimentRecord(experiment)
            ) {
                XCTAssertEqual(
                    $0 as? SavedTuneFH5ControlledExperimentError,
                    .corruptStorage
                )
            }
            XCTAssertThrowsError(
                try saved.deleteFH5ControlledExperimentRecord(
                    id: experiment.recordID
                )
            ) {
                XCTAssertEqual(
                    $0 as? SavedTuneFH5ControlledExperimentError,
                    .corruptStorage
                )
            }
            XCTAssertEqual(saved.tuneResult, tuneBeforeCorruption)
            XCTAssertEqual(
                saved.fh5ResearchObservationRecords(matching: plan),
                researchBeforeCorruption
            )
        }

        let report = FH5ControlledExperimentFactory().outcomePolicyReport(
            records: [experiment],
            tune: plan,
            researchRecord: research
        )
        XCTAssertEqual(report.matchingRecordCount, 1)
        XCTAssertFalse(report.passes)
        let readiness = FH5NumericReadinessPolicy().assess(
            tune: plan,
            researchRecords: [research],
            reviewReport: .empty,
            controlledOutcomeReport: report
        )
        XCTAssertFalse(readiness.canGenerateNumeric)
        XCTAssertEqual(
            readiness.items.first { $0.gate == .controlledOutcomes }?.state,
            .blocked
        )
        XCTAssertTrue(
            readiness.items.first { $0.gate == .controlledOutcomes }?.detail
                .contains("1 matching paired experiment") ?? false
        )
    }

    private func experimentCapture(
        field: TuneFieldID,
        candidate: Double,
        reusePermitted: Bool = false
    ) -> FH5ControlledExperimentCapture {
        FH5ControlledExperimentCapture(
            field: field,
            candidateValue: candidate,
            input: .controller,
            surface: .dry,
            targetSymptom: .pushesWide,
            outcome: .variantPreferred,
            sameRouteAndConditionsConfirmed: true,
            sameAssistsAndInputConfirmed: true,
            onlyDeclaredFieldChangedConfirmed: true,
            sequenceCompletedConfirmed: true,
            stockValuesRestoredConfirmed: true,
            firstPartyAuthorshipConfirmed: true,
            localStoragePermitted: true,
            deidentifiedReusePermitted: reusePermitted
        )
    }

    private func makeExperimentalRegistration(
        sourceManifests: [FH5NumericRulesetSourceManifest]? = nil
    ) throws -> FH5NumericRulesetRegistration {
        let algorithmID = FH5ExperimentalAlgorithmID.cleanRoomDirectionalV1
        let sources = sourceManifests ?? [
            FH5NumericRulesetSourceManifest(
                sourceID: "first-party.clean-room",
                sourceVersion: "1",
                owner: "ForzAdvisor",
                rightsBasis: .firstPartyCleanRoom,
                rightsEvidenceID: "internal.clean-room-record",
                usagePermission: .permitted
            )
        ]
        let fingerprint = FH5NumericRulesetSourceManifest.fingerprint(
            for: sources
        ) ?? String(repeating: "0", count: 64)
        let reference = try XCTUnwrap(TuneRulesetReference(
            descriptor: TuneRulesetDescriptor(
                id: algorithmID.rawValue,
                game: .fh5,
                schemaVersion: 1,
                algorithmVersion: "1",
                knowledgeRevision: fingerprint,
                validationStatus: .experimental,
                provenanceIDs: sources.map(\.sourceID).sorted()
            )
        ))
        return FH5NumericRulesetRegistration(
            algorithmID: algorithmID,
            reference: reference,
            sourceManifests: sources,
            outcomeThreshold: .currentExperimental
        )
    }

    private func makePlan(
        upgradeBuild: String? = nil,
        fh5EntryOffset: Int = 0
    ) async throws -> TuneResult {
        let catalog = try BundledCarCatalog.load().get()
        let entries = catalog.entries.filter { $0.game == .fh5 }
        let entry = entries[fh5EntryOffset]
        let selection = catalog.selection(for: entry)
        var snapshot = selection.capabilityOnlyBuildSnapshot(capturedAt: capturedAt)
        if let upgradeBuild {
            snapshot = try UpgradePartCapture(
                gameBuildVersion: upgradeBuild,
                parts: TunePartID.allCases.map {
                    UpgradePartCaptureValue(partID: $0, status: .offered)
                },
                exactStockBuildConfirmed: true,
                localUsePermitted: true
            ).verifiedSnapshot(upgrading: snapshot, capturedAt: capturedAt)
        }
        return try await CapabilityProjectingTuneProvider(base: CompositeTuneProvider())
            .generateTune(for: TuneRequest(
                car: selection.carInput,
                discipline: .road,
                buildSnapshot: snapshot
            ))
    }

    private func makeTune(game: ForzaGame) async throws -> TuneResult {
        let catalog = try BundledCarCatalog.load().get()
        let entry = try XCTUnwrap(catalog.entries.first { $0.game == game })
        let selection = catalog.selection(for: entry)
        return try await CapabilityProjectingTuneProvider(base: LocalSampleTuneProvider())
            .generateTune(for: TuneRequest(
                car: selection.carInput,
                discipline: .road,
                buildSnapshot: selection.capabilityOnlyBuildSnapshot(capturedAt: capturedAt)
            ))
    }

    private func validCapture(
        drivetrain: Drivetrain,
        gearCount: Int,
        availability: FH5TuneFieldAvailability,
        build: String = "3.688.109.0",
        reuse: Bool = false
    ) -> FH5ResearchCapture {
        FH5ResearchCapture(
            platform: .xboxSeries,
            gameVersion: build,
            tireCompoundDisplayName: "Stock",
            forwardGearCount: gearCount,
            controls: TuneFieldID.expectedFields(
                drivetrain: drivetrain,
                gearCount: gearCount
            ).map { field in
                switch availability {
                case .adjustable:
                    adjustable(field)
                case .shownLocked:
                    FH5TuneFieldObservation(
                        field: field,
                        availability: .shownLocked,
                        current: 50,
                        unit: field.expectedUnit
                    )
                case .notShown:
                    FH5TuneFieldObservation(field: field, availability: .notShown)
                }
            },
            exactUntouchedStockConfirmed: true,
            allSlidersRestoredConfirmed: true,
            personallyReadFromGameConfirmed: true,
            firstPartyAuthorshipConfirmed: true,
            localStoragePermitted: true,
            deidentifiedStructuredReusePermitted: reuse
        )
    }

    private func adjustable(
        _ field: TuneFieldID,
        minimum: Double = 0,
        maximum: Double = 100,
        step: Double = 1,
        current: Double = 50,
        unit: TuneUnit? = nil
    ) -> FH5TuneFieldObservation {
        FH5TuneFieldObservation(
            field: field,
            availability: .adjustable,
            minimum: minimum,
            maximum: maximum,
            step: step,
            current: current,
            unit: unit ?? field.expectedUnit
        )
    }

    private func replacing(
        _ capture: FH5ResearchCapture,
        controls: [FH5TuneFieldObservation]
    ) -> FH5ResearchCapture {
        FH5ResearchCapture(
            platform: capture.platform,
            gameVersion: capture.gameVersion,
            tireCompoundDisplayName: capture.tireCompoundDisplayName,
            forwardGearCount: capture.forwardGearCount,
            controls: controls,
            exactUntouchedStockConfirmed: capture.exactUntouchedStockConfirmed,
            allSlidersRestoredConfirmed: capture.allSlidersRestoredConfirmed,
            personallyReadFromGameConfirmed: capture.personallyReadFromGameConfirmed,
            firstPartyAuthorshipConfirmed: capture.firstPartyAuthorshipConfirmed,
            localStoragePermitted: capture.localStoragePermitted,
            deidentifiedStructuredReusePermitted:
                capture.deidentifiedStructuredReusePermitted
        )
    }

    private func replacing(
        _ record: FH5ResearchObservationRecord,
        snapshot: VehicleBuildSnapshot
    ) -> FH5ResearchObservationRecord {
        FH5ResearchObservationRecord(
            schemaVersion: record.schemaVersion,
            consentVersion: record.consentVersion,
            recordID: record.recordID,
            submissionID: record.submissionID,
            permissionReceiptID: record.permissionReceiptID,
            capturedAt: record.capturedAt,
            game: record.game,
            platform: record.platform,
            gameVersion: record.gameVersion,
            unitScope: record.unitScope,
            vehicle: record.vehicle,
            upgradeParts: record.upgradeParts,
            tireCompoundDisplayName: record.tireCompoundDisplayName,
            forwardGearCount: record.forwardGearCount,
            controls: record.controls,
            attestations: record.attestations,
            unknowns: record.unknowns,
            privacyExclusions: record.privacyExclusions,
            contentFingerprint: record.contentFingerprint,
            planRevisionFingerprint: record.planRevisionFingerprint,
            internalValidationSnapshot: snapshot
        )
    }

    private func XCTAssertSuccess<Success>(
        _ result: Result<Success, FH5ResearchIssue>,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case .success = result else {
            return XCTFail("Expected success, received \(result)", file: file, line: line)
        }
    }

    private func XCTAssertFailure<Success, Failure: Error & Equatable>(
        _ result: Result<Success, Failure>,
        _ expected: Failure,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case .failure(let issue) = result else {
            return XCTFail("Expected \(expected), received success", file: file, line: line)
        }
        XCTAssertEqual(issue, expected, file: file, line: line)
    }
}
