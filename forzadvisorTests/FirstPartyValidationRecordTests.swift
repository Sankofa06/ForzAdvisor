//
//  FirstPartyValidationRecordTests.swift
//  forzadvisorTests
//

import SwiftData
import XCTest
@testable import forzadvisor

final class FirstPartyValidationRecordTests: XCTestCase {
    let date = Date(timeIntervalSinceReferenceDate: 12_345)

    func testEligibleRecordIsCanonicalDeterministicAndPrivacyAllowListed() async throws {
        var tune = try await eligibleTune()
        tune.notes.bias = "PRIVATE-NOTE-SENTINEL"
        tune.providerInfo = .direct(.anthropicAPI)
        let capture = validCapture()
        let fixedRecord = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let fixedSubmission = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let fixedReceipt = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        let factory = FirstPartyValidationRecordFactory()

        let first = try factory.make(
            tune: tune, savedTune: tune, isStreaming: false, capture: capture,
            recordID: fixedRecord, submissionID: fixedSubmission,
            permissionReceiptID: fixedReceipt, createdAt: date
        )
        let second = try factory.make(
            tune: tune, savedTune: tune, isStreaming: false, capture: capture,
            recordID: fixedRecord, submissionID: fixedSubmission,
            permissionReceiptID: fixedReceipt, createdAt: date
        )

        XCTAssertEqual(first, second)
        XCTAssertEqual(try first.deterministicJSON(), try second.deterministicJSON())
        XCTAssertEqual(first.shopParts.map(\.partID), TunePartID.allCases.sorted { $0.rawValue < $1.rawValue })
        XCTAssertEqual(first.appliedFields.map(\.field), first.appliedFields.map(\.field).sorted { $0.stableID < $1.stableID })
        XCTAssertEqual(first.appliedFields.count, tune.projectionReport?.readyCount)
        XCTAssertTrue(first.appliedFields.allSatisfy { $0.value.isFinite && $0.unit == $0.field.expectedUnit })
        XCTAssertEqual(first.vehicle.tireCompoundDisplayName, "Stock")
        XCTAssertEqual(first.session.courseType, .testTrack)

        let json = try XCTUnwrap(first.deterministicJSONString)
        for sentinel in [
            "PRIVATE-NOTE-SENTINEL", "requestedMode", "provenanceIDs",
            "evidenceSources", "thumbnail", "playerNotes"
        ] {
            XCTAssertFalse(json.contains(sentinel), "Leaked \(sentinel)")
        }
        let exportObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: try first.deterministicJSON()) as? [String: Any]
        )
        XCTAssertNil(exportObject["recordID"])
        XCTAssertNil(exportObject["tuneID"])
        XCTAssertNil(exportObject["tuneRevisionFingerprint"])
        XCTAssertEqual(exportObject["submissionID"] as? String, fixedSubmission.uuidString)
        XCTAssertEqual(exportObject["permissionReceiptID"] as? String, fixedReceipt.uuidString)
        XCTAssertNoThrow(try JSONDecoder.iso8601.decode(
            FirstPartyValidationExport.self,
            from: first.deterministicJSON()
        ))

        let changedAdministrativeFields = try factory.make(
            tune: tune, savedTune: tune, isStreaming: false, capture: capture,
            recordID: UUID(), submissionID: UUID(), permissionReceiptID: UUID(),
            createdAt: date.addingTimeInterval(900)
        )
        XCTAssertEqual(first.contentFingerprint, changedAdministrativeFields.contentFingerprint)
        XCTAssertEqual(first.tuneRevisionFingerprint, changedAdministrativeFields.tuneRevisionFingerprint)

        var renamedTireTune = tune
        renamedTireTune.request.buildSnapshot?.tireCompound?.displayName = "Observed Street"
        let renamedTireRecord = try factory.make(
            tune: renamedTireTune, savedTune: renamedTireTune, isStreaming: false,
            capture: capture, createdAt: date
        )
        XCTAssertEqual(renamedTireRecord.vehicle.tireCompoundDisplayName, "Observed Street")
        XCTAssertNotEqual(first.contentFingerprint, renamedTireRecord.contentFingerprint)
        XCTAssertNotEqual(first.tuneRevisionFingerprint, renamedTireRecord.tuneRevisionFingerprint)
    }

    func testEligibilityFailsClosedAtSavedStreamingLegacySnapshotStockRulesetAndProjectionGates() async throws {
        let tune = try await eligibleTune()
        let factory = FirstPartyValidationRecordFactory()
        XCTAssertSuccess(factory.eligibility(for: tune, savedTune: tune, isStreaming: false))
        XCTAssertFailure(factory.eligibility(for: tune, savedTune: nil, isStreaming: false), .notSaved)
        XCTAssertFailure(factory.eligibility(for: tune, savedTune: tune, isStreaming: true), .streaming)

        var legacy = tune
        legacy.projectionReport = nil
        XCTAssertFailure(factory.eligibility(for: legacy, savedTune: legacy, isStreaming: false), .legacyTune)

        var stale = tune
        stale.generatedAt = tune.generatedAt.addingTimeInterval(1)
        XCTAssertFailure(factory.eligibility(for: stale, savedTune: tune, isStreaming: false), .staleSavedRevision)

        var unsavedValueChange = tune
        unsavedValueChange.sections[0].lines[0].value = "27.0"
        XCTAssertFailure(
            factory.eligibility(for: unsavedValueChange, savedTune: tune, isStreaming: false),
            .staleSavedRevision
        )

        var unsavedBuildDate = tune
        unsavedBuildDate.request.buildSnapshot?.gameBuild.capturedAt = date.addingTimeInterval(1)
        XCTAssertFailure(
            factory.eligibility(for: unsavedBuildDate, savedTune: tune, isStreaming: false),
            .staleSavedRevision
        )

        var unsavedTireName = tune
        unsavedTireName.request.buildSnapshot?.tireCompound?.displayName = "Sport"
        XCTAssertFailure(
            factory.eligibility(for: unsavedTireName, savedTune: tune, isStreaming: false),
            .staleSavedRevision
        )

        var modified = tune
        modified.request.car.weightPounds += 1
        XCTAssertFailure(factory.eligibility(for: modified, savedTune: modified, isStreaming: false), .invalidSnapshot)

        var capabilityOnly = tune
        capabilityOnly.request.buildSnapshot?.kind = .capabilityOnly
        XCTAssertFailure(factory.eligibility(for: capabilityOnly, savedTune: capabilityOnly, isStreaming: false), .invalidSnapshot)

        var unknownBuild = tune
        unknownBuild.request.buildSnapshot?.gameBuild.version = nil
        unknownBuild.request.buildSnapshot?.gameBuild.capturedAt = nil
        XCTAssertFailure(factory.eligibility(for: unknownBuild, savedTune: unknownBuild, isStreaming: false), .invalidSnapshot)

        var missingHorsepower = tune
        missingHorsepower.request.buildSnapshot?.car.peakHorsepower = nil
        missingHorsepower.request.car.peakHorsepower = nil
        XCTAssertFailure(factory.eligibility(for: missingHorsepower, savedTune: missingHorsepower, isStreaming: false), .invalidSnapshot)

        var missingTorque = tune
        missingTorque.request.buildSnapshot?.car.peakTorqueFootPounds = nil
        missingTorque.request.car.peakTorqueFootPounds = nil
        XCTAssertFailure(factory.eligibility(for: missingTorque, savedTune: missingTorque, isStreaming: false), .invalidSnapshot)

        var missingTire = tune
        missingTire.request.buildSnapshot?.tireCompound = nil
        XCTAssertFailure(factory.eligibility(for: missingTire, savedTune: missingTire, isStreaming: false), .invalidSnapshot)

        var missingGears = tune
        missingGears.request.buildSnapshot?.gearCount = nil
        XCTAssertFailure(factory.eligibility(for: missingGears, savedTune: missingGears, isStreaming: false), .invalidSnapshot)

        var incomplete = tune
        incomplete.request.buildSnapshot?.capabilityProfile.parts.removeLast()
        XCTAssertFailure(factory.eligibility(for: incomplete, savedTune: incomplete, isStreaming: false), .incompleteStockContext)

        var installed = tune
        installed.request.buildSnapshot?.capabilityProfile.parts[0].availability = .installed
        XCTAssertFailure(factory.eligibility(for: installed, savedTune: installed, isStreaming: false), .incompleteStockContext)

        var unknown = tune
        unknown.request.buildSnapshot?.capabilityProfile.parts[0].availability = .unknown
        XCTAssertFailure(factory.eligibility(for: unknown, savedTune: unknown, isStreaming: false), .incompleteStockContext)

        var thirdPartyParts = tune
        thirdPartyParts.request.buildSnapshot?.capabilityProfile.parts[0].evidence.source = "third-party"
        XCTAssertFailure(factory.eligibility(for: thirdPartyParts, savedTune: thirdPartyParts, isStreaming: false), .incompleteStockContext)

        var stalePartBuild = tune
        stalePartBuild.request.buildSnapshot?.capabilityProfile.parts[0].evidence.version = "old-build"
        XCTAssertFailure(factory.eligibility(for: stalePartBuild, savedTune: stalePartBuild, isStreaming: false), .incompleteStockContext)

        var thirdPartyTires = tune
        thirdPartyTires.request.buildSnapshot?.evidenceSources[0].source = "third-party"
        XCTAssertFailure(factory.eligibility(for: thirdPartyTires, savedTune: thirdPartyTires, isStreaming: false), .incompleteStockContext)

        var staleTireEvidence = tune
        staleTireEvidence.request.buildSnapshot?.evidenceSources[0].version = "1"
        XCTAssertFailure(factory.eligibility(for: staleTireEvidence, savedTune: staleTireEvidence, isStreaming: false), .incompleteStockContext)

        var detachedTireCompound = tune
        detachedTireCompound.request.buildSnapshot?.tireCompound?.evidenceIDs = ["other-evidence"]
        XCTAssertFailure(factory.eligibility(for: detachedTireCompound, savedTune: detachedTireCompound, isStreaming: false), .invalidSnapshot)

        var oneSidedConstraint = tune
        oneSidedConstraint.request.buildSnapshot?.constraints[0].evidenceIDs = []
        XCTAssertFailure(factory.eligibility(for: oneSidedConstraint, savedTune: oneSidedConstraint, isStreaming: false), .invalidSnapshot)

        var noRuleset = tune
        noRuleset.rulesetReference = nil
        XCTAssertFailure(factory.eligibility(for: noRuleset, savedTune: noRuleset, isStreaming: false), .invalidRuleset)

        var deprecated = tune
        let old = try XCTUnwrap(tune.rulesetReference)
        deprecated.rulesetReference = TuneRulesetReference(descriptor: TuneRulesetDescriptor(
            id: old.id, game: old.game, schemaVersion: old.schemaVersion,
            algorithmVersion: old.algorithmVersion, knowledgeRevision: old.knowledgeRevision,
            validationStatus: .deprecated, provenanceIDs: old.provenanceIDs
        ))
        XCTAssertFailure(factory.eligibility(for: deprecated, savedTune: deprecated, isStreaming: false), .invalidRuleset)

        var forgedRuleset = tune
        forgedRuleset.rulesetReference = TuneRulesetReference(descriptor: TuneRulesetDescriptor(
            id: "forged.valid.ruleset", game: .fh6, schemaVersion: 1,
            algorithmVersion: "1.0.0", knowledgeRevision: "current",
            validationStatus: .validated, provenanceIDs: old.provenanceIDs
        ))
        XCTAssertFailure(factory.eligibility(for: forgedRuleset, savedTune: forgedRuleset, isStreaming: false), .invalidRuleset)

        var staleRuleset = tune
        staleRuleset.rulesetReference = TuneRulesetReference(descriptor: TuneRulesetDescriptor(
            id: FH6LocalTirePressureRuleset.id, game: .fh6,
            schemaVersion: FH6LocalTirePressureRuleset.schemaVersion,
            algorithmVersion: "0.9.0",
            knowledgeRevision: FH6LocalTirePressureRuleset.knowledgeRevision,
            validationStatus: .experimental, provenanceIDs: old.provenanceIDs
        ))
        XCTAssertFailure(factory.eligibility(for: staleRuleset, savedTune: staleRuleset, isStreaming: false), .invalidRuleset)

        var detachedRuleset = tune
        detachedRuleset.rulesetReference = FH6LocalTirePressureRuleset.reference(provenanceIDs: ["other-evidence"])
        XCTAssertFailure(factory.eligibility(for: detachedRuleset, savedTune: detachedRuleset, isStreaming: false), .invalidRuleset)

        var unsafeTireName = tune
        unsafeTireName.request.buildSnapshot?.tireCompound?.displayName = "Stock\u{202E}secret"
        XCTAssertFailure(factory.eligibility(for: unsafeTireName, savedTune: unsafeTireName, isStreaming: false), .invalidRuleset)

        var hiddenFormatTireName = tune
        hiddenFormatTireName.request.buildSnapshot?.tireCompound?.displayName = "Stock\u{00AD}secret"
        XCTAssertFailure(
            factory.eligibility(for: hiddenFormatTireName, savedTune: hiddenFormatTireName, isStreaming: false),
            .invalidRuleset
        )

        var unsafeBuild = tune
        unsafeBuild.request.buildSnapshot?.gameBuild.version = "build\nsecret"
        unsafeBuild.request.buildSnapshot?.capabilityProfile.parts.indices.forEach {
            unsafeBuild.request.buildSnapshot?.capabilityProfile.parts[$0].evidence.version = "build\nsecret"
        }
        unsafeBuild.request.buildSnapshot?.evidenceSources.indices.forEach {
            unsafeBuild.request.buildSnapshot?.evidenceSources[$0].gameBuildVersion = "build\nsecret"
        }
        XCTAssertFailure(factory.eligibility(for: unsafeBuild, savedTune: unsafeBuild, isStreaming: false), .invalidRuleset)

        var malformed = tune
        malformed.sections[0].lines[0].value = "not-a-number"
        let reprojected = try factory.eligibility(
            for: malformed, savedTune: malformed, isStreaming: false
        ).get()
        XCTAssertEqual(reprojected.projectionReport?.readyCount, 1)
        XCTAssertFalse(reprojected.sections.flatMap(\.lines).contains { $0.value == "not-a-number" })

        var empty = tune
        empty.sections = []
        XCTAssertFailure(factory.eligibility(for: empty, savedTune: empty, isStreaming: false), .invalidProjection)

        var duplicate = tune
        duplicate.sections[0].lines.append(duplicate.sections[0].lines[0])
        let duplicateProjection = TuneOutputProjector().project(duplicate)
        XCTAssertFalse(duplicateProjection.sections.flatMap(\.lines).contains {
            $0.fieldID == duplicate.sections[0].lines[0].fieldID
        })
    }

    func testLegacyTireRulesetAcceptsOnlyTirePressureFields() async throws {
        let factory = FirstPartyValidationRecordFactory()
        var tireOnly = try await eligibleTune()
        let tireEvidence = try XCTUnwrap(
            tireOnly.request.buildSnapshot?.tireCompound?.evidenceIDs
        )
        tireOnly.rulesetReference = try XCTUnwrap(
            FH6LocalTirePressureRuleset.reference(
                provenanceIDs: tireEvidence.sorted()
            )
        )
        XCTAssertSuccess(factory.eligibility(
            for: tireOnly,
            savedTune: tireOnly,
            isStreaming: false
        ))

        var fullMenu = try await eligibleMenuTune()
        let menuEvidence = try XCTUnwrap(
            fullMenu.request.buildSnapshot?.tireCompound?.evidenceIDs
        )
        fullMenu.rulesetReference = try XCTUnwrap(
            FH6LocalTirePressureRuleset.reference(
                provenanceIDs: menuEvidence.sorted()
            )
        )
        XCTAssertTrue(fullMenu.projectionReport?.readyFieldIDs.contains(.frontARB) == true)
        XCTAssertFailure(
            factory.eligibility(
                for: fullMenu,
                savedTune: fullMenu,
                isStreaming: false
            ),
            .invalidProjection
        )
    }

    func testExactRulesetRequiresReadyFieldProvenanceWithoutExtras() async throws {
        let factory = FirstPartyValidationRecordFactory()
        let tune = try await eligibleMenuTune()
        let primaryID = try XCTUnwrap(tune.rulesetReference?.provenanceIDs.first)
        let sourceEvidence = try XCTUnwrap(
            tune.request.buildSnapshot?.evidenceSources.first {
                $0.id == primaryID
            }
        )

        var missing = tune
        var missingSnapshot = try XCTUnwrap(missing.request.buildSnapshot)
        var secondEvidence = sourceEvidence
        secondEvidence.id = "fh6-menu.second-ready-field"
        missingSnapshot.evidenceSources.append(secondEvidence)
        let frontARBIndex = try XCTUnwrap(
            missingSnapshot.constraints.firstIndex { $0.field == .frontARB }
        )
        missingSnapshot.constraints[frontARBIndex].evidenceIDs = [
            secondEvidence.id
        ]
        XCTAssertTrue(missingSnapshot.isValid)
        missing.request.buildSnapshot = missingSnapshot
        missing.request.car = missingSnapshot.car
        XCTAssertFailure(
            factory.eligibility(
                for: missing,
                savedTune: missing,
                isStreaming: false
            ),
            .invalidProjection
        )

        var extra = tune
        var extraSnapshot = try XCTUnwrap(extra.request.buildSnapshot)
        var unusedEvidence = sourceEvidence
        unusedEvidence.id = "fh6-menu.provider-omitted-gear"
        extraSnapshot.evidenceSources.append(unusedEvidence)
        let gearIndex = try XCTUnwrap(
            extraSnapshot.constraints.firstIndex { $0.field == .gearRatio(1) }
        )
        extraSnapshot.constraints[gearIndex].evidenceIDs.append(
            unusedEvidence.id
        )
        XCTAssertTrue(extraSnapshot.isValid)
        extra.request.buildSnapshot = extraSnapshot
        extra.request.car = extraSnapshot.car
        extra.rulesetReference = try XCTUnwrap(
            FH6ExactConstraintRuleset.reference(
                provenanceIDs: [primaryID, unusedEvidence.id].sorted()
            )
        )
        XCTAssertFailure(
            factory.eligibility(
                for: extra,
                savedTune: extra,
                isStreaming: false
            ),
            .invalidProjection
        )
    }

    func testCaptureValidationRejectsRequiredFactsButAllowsLocalOnlyReuseScope() async throws {
        let tune = try await eligibleTune()
        let factory = FirstPartyValidationRecordFactory()
        var capture = validCapture()

        capture.runCount = 100
        XCTAssertThrows(factory, tune, capture, .invalidRunCount)
        capture = validCapture(); capture.verdict = .adjust; capture.feedback = []
        XCTAssertThrows(factory, tune, capture, .missingFeedback)
        capture = validCapture(); capture.verdict = .keep; capture.feedback = [.pushesWide]
        XCTAssertThrows(factory, tune, capture, .unexpectedFeedback)
        capture = validCapture(); capture.exactSetupConfirmed = false
        XCTAssertThrows(factory, tune, capture, .setupNotConfirmed)
        capture = validCapture(); capture.allExportedSettingsApplied = false
        XCTAssertThrows(factory, tune, capture, .settingsNotApplied)
        capture = validCapture(); capture.firstPartyAuthorshipConfirmed = false
        XCTAssertThrows(factory, tune, capture, .authorshipNotConfirmed)
        capture = validCapture(); capture.deidentifiedReusePermitted = false
        let local = try factory.make(
            tune: tune, savedTune: tune, isStreaming: false,
            capture: capture
        )
        XCTAssertTrue(factory.isValidLocalObservation(local))
        XCTAssertFalse(local.deidentifiedReusePermitted)
        XCTAssertThrowsError(try local.deterministicJSON()) {
            XCTAssertEqual(
                $0 as? FirstPartyValidationError,
                .reuseNotPermitted
            )
        }
    }

    func testLocalizedCommaDecimalAppliedFieldIsParsedNumerically() async throws {
        var tune = try await eligibleTune()
        let index = try XCTUnwrap(tune.sections[0].lines.firstIndex {
            $0.fieldID == .frontTirePressure
        })
        tune.sections[0].lines[index].value = "26,5"
        let factory = FirstPartyValidationRecordFactory(locale: Locale(identifier: "de_DE"))

        let record = try factory.make(
            tune: tune, savedTune: tune, isStreaming: false, capture: validCapture(), createdAt: date
        )

        XCTAssertEqual(record.appliedFields.first { $0.field == .frontTirePressure }?.value, 26.5)
    }

    @MainActor
    func testSavedTunePersistsFiltersOldRevisionAndDeletesLatestRecord() async throws {
        let tune = try await eligibleTune()
        let record = try FirstPartyValidationRecordFactory().make(
            tune: tune, savedTune: tune, isStreaming: false, capture: validCapture(), createdAt: date
        )
        let container = try ModelContainer(
            for: SavedTune.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let saved = try SavedTune(tune: tune)
        context.insert(saved)
        try saved.appendValidationRecord(record)
        try context.save()

        let reopened = try XCTUnwrap(context.fetch(FetchDescriptor<SavedTune>()).first)
        XCTAssertEqual(reopened.firstPartyValidationRecords, [record])
        XCTAssertEqual(reopened.validationRecords(matching: tune), [record])

        var adjusted = tune
        let frontIndex = try XCTUnwrap(adjusted.sections[0].lines.firstIndex {
            $0.fieldID == .frontTirePressure
        })
        adjusted.sections[0].lines[frontIndex].value = "27.0"
        adjusted = TuneOutputProjector().project(adjusted)
        XCTAssertEqual(adjusted.id, tune.id)
        XCTAssertEqual(adjusted.generatedAt, tune.generatedAt)
        try reopened.update(with: adjusted)
        try context.save()
        XCTAssertEqual(reopened.firstPartyValidationRecords, [record])
        XCTAssertTrue(reopened.validationRecords(matching: adjusted).isEmpty)

        XCTAssertTrue(try reopened.deleteValidationRecord(id: record.recordID))
        try context.save()
        XCTAssertTrue(reopened.firstPartyValidationRecords.isEmpty)
    }

    func testTamperedRecordCannotBePersistedOrShared() async throws {
        let tune = try await eligibleTune()
        let factory = FirstPartyValidationRecordFactory()
        var record = try factory.make(
            tune: tune, savedTune: tune, isStreaming: false, capture: validCapture(), createdAt: date
        )
        record.session.runCount += 1

        XCTAssertFalse(factory.isValid(record))
        XCTAssertThrowsError(try record.deterministicJSON()) { error in
            XCTAssertEqual(error as? FirstPartyValidationError, .invalidStoredRecord)
        }

        let saved = try SavedTune(tune: tune)
        XCTAssertThrowsError(try saved.appendValidationRecord(record)) { error in
            XCTAssertEqual(error as? FirstPartyValidationError, .invalidStoredRecord)
        }

        var contradictory = try factory.make(
            tune: tune, savedTune: tune, isStreaming: false, capture: validCapture(), createdAt: date
        )
        contradictory.outcome.verdict = .keep
        XCTAssertFalse(factory.isValid(contradictory))
        XCTAssertThrowsError(try contradictory.deterministicJSON()) { error in
            XCTAssertEqual(error as? FirstPartyValidationError, .invalidStoredRecord)
        }
    }

    @MainActor
    func testCorruptSavedRecordBlobCannotBeOverwrittenByAppendOrDelete() async throws {
        let tune = try await eligibleTune()
        let record = try FirstPartyValidationRecordFactory().make(
            tune: tune, savedTune: tune, isStreaming: false, capture: validCapture(), createdAt: date
        )
        let saved = try SavedTune(tune: tune)
        saved.replaceValidationRecordsDataForTesting(Data("not-json".utf8))

        XCTAssertTrue(saved.firstPartyValidationRecords.isEmpty)
        XCTAssertThrowsError(try saved.appendValidationRecord(record)) { error in
            XCTAssertEqual(error as? SavedTuneValidationRecordError, .corruptStorage)
        }
        XCTAssertThrowsError(try saved.deleteValidationRecord(id: record.recordID)) { error in
            XCTAssertEqual(error as? SavedTuneValidationRecordError, .corruptStorage)
        }
        XCTAssertThrowsError(try saved.appendValidationRecord(record)) { error in
            XCTAssertEqual(error as? SavedTuneValidationRecordError, .corruptStorage)
        }
    }

    @MainActor
    func testDiskStoreReopenPreservesNilDefaultAndValidationRecord() async throws {
        let tune = try await eligibleTune()
        let record = try FirstPartyValidationRecordFactory().make(
            tune: tune, savedTune: tune, isStreaming: false, capture: validCapture(), createdAt: date
        )
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "forzadvisor-validation-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let configuration = ModelConfiguration(url: directory.appending(path: "store.sqlite"))

        do {
            let container = try ModelContainer(for: SavedTune.self, configurations: configuration)
            let context = ModelContext(container)
            context.insert(try SavedTune(tune: tune))
            try context.save()
        }
        do {
            let container = try ModelContainer(for: SavedTune.self, configurations: configuration)
            let context = ModelContext(container)
            let saved = try XCTUnwrap(context.fetch(FetchDescriptor<SavedTune>()).first)
            XCTAssertTrue(saved.firstPartyValidationRecords.isEmpty)
            try saved.appendValidationRecord(record)
            try context.save()
        }
        do {
            let container = try ModelContainer(for: SavedTune.self, configurations: configuration)
            let context = ModelContext(container)
            let saved = try XCTUnwrap(context.fetch(FetchDescriptor<SavedTune>()).first)
            XCTAssertEqual(saved.firstPartyValidationRecords, [record])
            XCTAssertEqual(saved.validationRecords(matching: tune), [record])
        }
    }

    func eligibleTune() async throws -> TuneResult {
        let catalog = try BundledCarCatalog.load().get()
        let entry = try XCTUnwrap(catalog.entries.first { $0.game == .fh6 })
        let selection = catalog.selection(for: entry)
        let capability = selection.capabilityOnlyBuildSnapshot(capturedAt: date)
        let parts = try UpgradePartCapture(
            gameBuildVersion: "test-build",
            parts: TunePartID.allCases.map {
                UpgradePartCaptureValue(partID: $0, status: .offered)
            },
            exactStockBuildConfirmed: true,
            localUsePermitted: true
        ).verifiedSnapshot(upgrading: capability, capturedAt: date)
        let exact = try TirePressureCapture(
            gameBuildVersion: "test-build", tireCompound: "Stock", gearCount: 6,
            front: .init(minimumPSI: 15, maximumPSI: 40, stepPSI: 0.5, currentPSI: 30),
            rear: .init(minimumPSI: 15, maximumPSI: 40, stepPSI: 0.5, currentPSI: 30),
            exactStockBuildConfirmed: true, localUsePermitted: true
        ).exactBuildSnapshot(upgrading: parts, capturedAt: date, evidenceID: "local-tire")
        let request = TuneRequest(car: exact.car, discipline: .road, buildSnapshot: exact)
        var tune = try await CapabilityProjectingTuneProvider(base: LocalSampleTuneProvider()).generateTune(for: request)
        tune.generatedAt = date
        return tune
    }

    private func eligibleMenuTune() async throws -> TuneResult {
        let catalog = try BundledCarCatalog.load().get()
        let entry = try XCTUnwrap(catalog.entries.first {
            $0.game == .fh6 && $0.stock.drivetrain == .rwd
        })
        let selection = catalog.selection(for: entry)
        let capability = selection.capabilityOnlyBuildSnapshot(
            capturedAt: date
        )
        let parts = try UpgradePartCapture(
            gameBuildVersion: "test-build",
            parts: TunePartID.allCases.map {
                UpgradePartCaptureValue(partID: $0, status: .offered)
            },
            exactStockBuildConfirmed: true,
            localUsePermitted: true
        ).verifiedSnapshot(upgrading: capability, capturedAt: date)
        let controls = TuneFieldID.expectedFields(
            drivetrain: parts.car.drivetrain,
            gearCount: 6
        ).map { field in
            let minimum = field.expectedUnit == .degrees ? -10.0 : 0
            return FH6TuneMenuFieldObservation(
                field: field,
                availability: .adjustable,
                minimum: minimum,
                maximum: minimum + 5_000,
                step: 0.5,
                current: minimum + 5,
                unit: field.expectedUnit
            )
        }
        let exact = try FH6TuneMenuCapture(
            gameBuildVersion: "test-build",
            tireCompoundDisplayName: "Stock",
            forwardGearCount: 6,
            controls: controls,
            exactUntouchedStockConfirmed: true,
            allSlidersRestoredConfirmed: true,
            personallyReadFromGameConfirmed: true,
            localStoragePermitted: true
        ).exactBuildSnapshot(
            upgrading: parts,
            capturedAt: date,
            evidenceID: "fh6-menu.validation-test"
        )
        let request = TuneRequest(
            car: exact.car,
            discipline: .road,
            buildSnapshot: exact
        )
        var tune = try await CapabilityProjectingTuneProvider(
            base: LocalSampleTuneProvider()
        ).generateTune(for: request)
        tune.generatedAt = date
        return tune
    }

    func validCapture() -> FirstPartyValidationCapture {
        FirstPartyValidationCapture(
            courseType: .testTrack, surface: .dry, input: .controller,
            runCount: 3, verdict: .adjust, feedback: [.pushesWide],
            exactSetupConfirmed: true, allExportedSettingsApplied: true,
            firstPartyAuthorshipConfirmed: true, deidentifiedReusePermitted: true
        )
    }

    private func XCTAssertSuccess(
        _ result: Result<TuneResult, FirstPartyValidationError>,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        guard case .success = result else { return XCTFail("Expected success: \(result)", file: file, line: line) }
    }

    private func XCTAssertFailure(
        _ result: Result<TuneResult, FirstPartyValidationError>,
        _ expected: FirstPartyValidationError,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        guard case .failure(let actual) = result else { return XCTFail("Expected \(expected): \(result)", file: file, line: line) }
        XCTAssertEqual(actual, expected, file: file, line: line)
    }

    private func XCTAssertThrows(
        _ factory: FirstPartyValidationRecordFactory,
        _ tune: TuneResult,
        _ capture: FirstPartyValidationCapture,
        _ expected: FirstPartyValidationError,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertThrowsError(try factory.make(
            tune: tune, savedTune: tune, isStreaming: false, capture: capture
        ), file: file, line: line) { error in
            XCTAssertEqual(error as? FirstPartyValidationError, expected, file: file, line: line)
        }
    }
}

private extension JSONDecoder {
    static var iso8601: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
