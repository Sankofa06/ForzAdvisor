//
//  FirstPartyValidationOutcomeEvaluatorTests.swift
//  forzadvisorTests
//

import XCTest
@testable import forzadvisor

final class FirstPartyValidationOutcomeEvaluatorTests: XCTestCase {
    private let date = Date(timeIntervalSinceReferenceDate: 12_345)

    func testCanonicalGateRejectsUnknownDuplicateAndTrailingJSON() async throws {
        let fixture = try await makeFixture()
        let ingestor = FirstPartyValidationIngestor()

        XCTAssertNoThrow(try ingestor.validate(fixture.data))
        XCTAssertThrowsError(try ingestor.validate(insertingTopLevel(
            "\"unexpected\" : true",
            into: fixture.data
        ))) { error in
            XCTAssertEqual(error as? FirstPartyValidationIngestionError, .nonCanonicalJSON)
        }
        XCTAssertThrowsError(try ingestor.validate(insertingTopLevel(
            "\"schemaVersion\" : 1",
            into: fixture.data
        ))) { error in
            XCTAssertEqual(error as? FirstPartyValidationIngestionError, .nonCanonicalJSON)
        }
        XCTAssertThrowsError(try ingestor.validate(reorderingTopLevelKeys(in: fixture.data))) { error in
            XCTAssertEqual(error as? FirstPartyValidationIngestionError, .nonCanonicalJSON)
        }
        XCTAssertThrowsError(try ingestor.validate(fixture.data + Data("\n".utf8))) { error in
            XCTAssertEqual(error as? FirstPartyValidationIngestionError, .nonCanonicalJSON)
        }
    }

    func testPayloadBoundAndTamperedContentFingerprintFailClosed() async throws {
        let fixture = try await makeFixture()
        let oversized = Data(repeating: 0x20, count: FirstPartyValidationIngestor.maximumPayloadBytes + 1)
        XCTAssertThrowsError(try FirstPartyValidationIngestor().validate(oversized)) { error in
            XCTAssertEqual(error as? FirstPartyValidationIngestionError, .payloadTooLarge)
        }

        var tampered = fixture.export
        tampered.contentFingerprint = String(repeating: "0", count: 64)
        let tamperedData = try FirstPartyValidationIngestor.canonicalData(for: tampered)
        XCTAssertThrowsError(try FirstPartyValidationIngestor().validate(tamperedData)) { error in
            XCTAssertEqual(error as? FirstPartyValidationIngestionError, .invalidContentFingerprint)
        }
    }

    func testFH5AndMalformedStructuralValuesFailClosed() async throws {
        let fixture = try await makeFixture()

        var fh5 = fixture.export
        fh5.game = .fh5
        fh5.contentFingerprint = try FirstPartyValidationIngestor.contentFingerprint(for: fh5)
        XCTAssertThrowsError(try FirstPartyValidationIngestor().validate(
            FirstPartyValidationIngestor.canonicalData(for: fh5)
        )) { error in
            XCTAssertEqual(error as? FirstPartyValidationIngestionError, .invalidStructure)
        }

        var badGear = fixture.export
        badGear.appliedFields.append(.init(field: .gearRatio(11), value: 1.2, unit: .ratio))
        badGear.appliedFields.sort { $0.field.stableID < $1.field.stableID }
        badGear.contentFingerprint = try FirstPartyValidationIngestor.contentFingerprint(for: badGear)
        XCTAssertThrowsError(try FirstPartyValidationIngestor().validate(
            FirstPartyValidationIngestor.canonicalData(for: badGear)
        )) { error in
            XCTAssertEqual(error as? FirstPartyValidationIngestionError, .invalidStructure)
        }
    }

    func testJSONReceiptIsQuarantinedUntilExternalBindingMatches() async throws {
        let fixture = try await makeFixture()
        let validPermission = try permission(for: fixture.data)
        var wrongSubmission = validPermission
        wrongSubmission.submissionID = UUID()
        var wrongReceipt = validPermission
        wrongReceipt.permissionReceiptID = UUID()
        var wrongConsent = validPermission
        wrongConsent.consentVersion = "forged-consent"
        var wrongDigest = validPermission
        wrongDigest.canonicalExportDigest = String(repeating: "0", count: 64)
        var wrongContent = validPermission
        wrongContent.contentFingerprint = String(repeating: "f", count: 64)

        let report = FirstPartyValidationOutcomeEvaluator().evaluate([
            .init(exportJSON: fixture.data, verifiedPermission: nil),
            .init(exportJSON: fixture.data, verifiedPermission: wrongSubmission),
            .init(exportJSON: fixture.data, verifiedPermission: wrongReceipt),
            .init(exportJSON: fixture.data, verifiedPermission: wrongConsent),
            .init(exportJSON: fixture.data, verifiedPermission: wrongDigest),
            .init(exportJSON: fixture.data, verifiedPermission: wrongContent),
            .init(exportJSON: fixture.data, verifiedPermission: validPermission)
        ])

        XCTAssertEqual(report.receivedCount, 7)
        XCTAssertEqual(report.quarantinedCount, 6)
        XCTAssertEqual(report.verifiedUniqueSessionCount, 1)
        XCTAssertEqual(report.invalidCount, 0)
    }

    func testExactSubmissionReplayDeduplicates() async throws {
        let fixture = try await makeFixture()
        let originalPermission = try permission(for: fixture.data)

        let report = FirstPartyValidationOutcomeEvaluator().evaluate([
            .init(exportJSON: fixture.data, verifiedPermission: originalPermission),
            .init(exportJSON: fixture.data, verifiedPermission: originalPermission)
        ])

        XCTAssertEqual(report.verifiedUniqueSessionCount, 1)
        XCTAssertEqual(report.duplicateCount, 1)
        XCTAssertEqual(report.conflictCount, 0)
        XCTAssertEqual(report.receiptReplayCount, 0)
    }

    func testSubmissionConflictExcludesWholeGroupIndependentOfInputOrder() async throws {
        let fixture = try await makeFixture()
        let originalPermission = try permission(for: fixture.data)

        var conflict = fixture.export
        conflict.createdAt = fixture.export.createdAt.addingTimeInterval(60)
        conflict.permissionReceiptID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
        conflict.session = .init(courseType: .roadCircuit, surface: .wet, input: .wheel, runCount: 2)
        conflict.outcome = .init(verdict: .keep, feedback: [])
        conflict.contentFingerprint = try FirstPartyValidationIngestor.contentFingerprint(for: conflict)
        let conflictData = try FirstPartyValidationIngestor.canonicalData(for: conflict)
        let conflictPermission = try permission(for: conflictData)

        let inputs: [FirstPartyValidationIngestionInput] = [
            .init(exportJSON: fixture.data, verifiedPermission: originalPermission),
            .init(exportJSON: conflictData, verifiedPermission: conflictPermission)
        ]
        let forward = FirstPartyValidationOutcomeEvaluator().evaluate(inputs)
        let reversed = FirstPartyValidationOutcomeEvaluator().evaluate(Array(inputs.reversed()))

        XCTAssertEqual(forward, reversed)
        XCTAssertEqual(forward.verifiedUniqueSessionCount, 0)
        XCTAssertEqual(forward.duplicateCount, 0)
        XCTAssertEqual(forward.conflictCount, 2)
        XCTAssertEqual(forward.receiptReplayCount, 0)
        XCTAssertTrue(forward.groups.isEmpty)
    }

    func testReceiptReplayAcrossSubmissionsIsAConflict() async throws {
        let fixture = try await makeFixture()
        let originalPermission = try permission(for: fixture.data)

        var replay = fixture.export
        replay.submissionID = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
        replay.createdAt = fixture.export.createdAt.addingTimeInterval(60)
        replay.session = .init(courseType: .roadCircuit, surface: .wet, input: .wheel, runCount: 2)
        replay.outcome = .init(verdict: .reject, feedback: [.snapsOnLift])
        replay.contentFingerprint = try FirstPartyValidationIngestor.contentFingerprint(for: replay)
        let replayData = try FirstPartyValidationIngestor.canonicalData(for: replay)
        let replayPermission = try permission(for: replayData)

        let inputs: [FirstPartyValidationIngestionInput] = [
            .init(exportJSON: fixture.data, verifiedPermission: originalPermission),
            .init(exportJSON: replayData, verifiedPermission: replayPermission)
        ]
        let forward = FirstPartyValidationOutcomeEvaluator().evaluate(inputs)
        let reversed = FirstPartyValidationOutcomeEvaluator().evaluate(Array(inputs.reversed()))

        XCTAssertEqual(forward, reversed)
        XCTAssertEqual(forward.verifiedUniqueSessionCount, 0)
        XCTAssertEqual(forward.conflictCount, 2)
        XCTAssertEqual(forward.receiptReplayCount, 2)
        XCTAssertEqual(forward.duplicateCount, 0)
        XCTAssertTrue(forward.groups.isEmpty)
    }

    func testIdenticalContentAcrossAdministrativeSubmissionsDoesNotInflateSessions() async throws {
        let fixture = try await makeFixture()
        var duplicateSession = fixture.export
        duplicateSession.submissionID = UUID(uuidString: "66666666-6666-6666-6666-666666666666")!
        duplicateSession.permissionReceiptID = UUID(uuidString: "77777777-7777-7777-7777-777777777777")!
        duplicateSession.createdAt = fixture.export.createdAt.addingTimeInterval(60)
        let duplicateData = try FirstPartyValidationIngestor.canonicalData(for: duplicateSession)

        let report = FirstPartyValidationOutcomeEvaluator().evaluate([
            .init(exportJSON: fixture.data, verifiedPermission: try permission(for: fixture.data)),
            .init(exportJSON: duplicateData, verifiedPermission: try permission(for: duplicateData))
        ])

        XCTAssertEqual(fixture.export.contentFingerprint, duplicateSession.contentFingerprint)
        XCTAssertEqual(report.verifiedUniqueSessionCount, 1)
        XCTAssertEqual(report.duplicateCount, 1)
        XCTAssertEqual(report.groups.single?.sessionCount, 1)
    }

    func testSameTuneGroupsSessionsAndNegativeOutcomesRemainOutcomeEvidence() async throws {
        let fixture = try await makeFixture()

        var rejected = fixture.export
        rejected.submissionID = UUID(uuidString: "88888888-8888-8888-8888-888888888888")!
        rejected.permissionReceiptID = UUID(uuidString: "99999999-9999-9999-9999-999999999999")!
        rejected.createdAt = fixture.export.createdAt.addingTimeInterval(60)
        rejected.session = .init(courseType: .roadCircuit, surface: .wet, input: .wheel, runCount: 2)
        rejected.outcome = .init(verdict: .reject, feedback: [.pushesWide, .snapsOnLift])
        rejected.contentFingerprint = try FirstPartyValidationIngestor.contentFingerprint(for: rejected)
        let rejectedData = try FirstPartyValidationIngestor.canonicalData(for: rejected)

        var kept = fixture.export
        kept.submissionID = UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!
        kept.permissionReceiptID = UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!
        kept.createdAt = fixture.export.createdAt.addingTimeInterval(120)
        kept.session = .init(courseType: .testTrack, surface: .mixed, input: .keyboard, runCount: 4)
        kept.outcome = .init(verdict: .keep, feedback: [])
        kept.contentFingerprint = try FirstPartyValidationIngestor.contentFingerprint(for: kept)
        let keptData = try FirstPartyValidationIngestor.canonicalData(for: kept)

        let report = FirstPartyValidationOutcomeEvaluator().evaluate([
            .init(exportJSON: fixture.data, verifiedPermission: try permission(for: fixture.data)),
            .init(exportJSON: rejectedData, verifiedPermission: try permission(for: rejectedData)),
            .init(exportJSON: keptData, verifiedPermission: try permission(for: keptData))
        ])
        let group = try XCTUnwrap(report.groups.single)

        XCTAssertEqual(report.verifiedUniqueSessionCount, 3)
        XCTAssertEqual(group.sessionCount, 3)
        XCTAssertEqual(group.keepCount, 1)
        XCTAssertEqual(group.adjustCount, 1)
        XCTAssertEqual(group.rejectCount, 1)
        XCTAssertEqual(group.acceptanceRate, 1.0 / 3.0, accuracy: 0.0001)
        XCTAssertEqual(group.handlingSymptomCounts, [
            .init(value: TuneFeedback.pushesWide.rawValue, count: 2),
            .init(value: TuneFeedback.snapsOnLift.rawValue, count: 1)
        ])
        XCTAssertEqual(group.courseTypeCounts, [
            .init(value: ValidationCourseType.roadCircuit.rawValue, count: 1),
            .init(value: ValidationCourseType.testTrack.rawValue, count: 2)
        ])
        XCTAssertEqual(group.surfaceCounts, [
            .init(value: ValidationSurface.dry.rawValue, count: 1),
            .init(value: ValidationSurface.mixed.rawValue, count: 1),
            .init(value: ValidationSurface.wet.rawValue, count: 1)
        ])
        XCTAssertEqual(group.inputCounts, [
            .init(value: ValidationInput.controller.rawValue, count: 1),
            .init(value: ValidationInput.keyboard.rawValue, count: 1),
            .init(value: ValidationInput.wheel.rawValue, count: 1)
        ])
        XCTAssertEqual(group.associationContext.appliedFields, fixture.export.appliedFields)
        XCTAssertEqual(group.associationContext.shopAvailabilityFingerprint, fixture.export.shopAvailabilityFingerprint)
        XCTAssertFalse(report.sessionSummary.lowercased().contains("tester"))
        XCTAssertFalse(report.sessionSummary.lowercased().contains("community consensus"))
        XCTAssertFalse(report.sessionSummary.lowercased().contains("reference target"))
    }

    func testTestedTuneFingerprintExcludesSessionOutcomeAndAdministrativeFields() async throws {
        let fixture = try await makeFixture()
        var otherSession = fixture.export
        otherSession.submissionID = UUID()
        otherSession.permissionReceiptID = UUID()
        otherSession.createdAt = fixture.export.createdAt.addingTimeInterval(10)
        otherSession.tuneGeneratedAt = fixture.export.tuneGeneratedAt.addingTimeInterval(10)
        otherSession.session = .init(courseType: .drag, surface: .mixed, input: .keyboard, runCount: 7)
        otherSession.outcome = .init(verdict: .keep, feedback: [])

        XCTAssertEqual(
            try FirstPartyValidationIngestor.testedTuneFingerprint(for: fixture.export),
            try FirstPartyValidationIngestor.testedTuneFingerprint(for: otherSession)
        )

        otherSession.appliedFields[0].value += 0.5
        XCTAssertNotEqual(
            try FirstPartyValidationIngestor.testedTuneFingerprint(for: fixture.export),
            try FirstPartyValidationIngestor.testedTuneFingerprint(for: otherSession)
        )
    }

    private func makeFixture() async throws -> (export: FirstPartyValidationExport, data: Data) {
        let tune = try await eligibleTune()
        let record = try FirstPartyValidationRecordFactory().make(
            tune: tune,
            savedTune: tune,
            isStreaming: false,
            capture: FirstPartyValidationCapture(
                courseType: .testTrack,
                surface: .dry,
                input: .controller,
                runCount: 3,
                verdict: .adjust,
                feedback: [.pushesWide],
                exactSetupConfirmed: true,
                allExportedSettingsApplied: true,
                firstPartyAuthorshipConfirmed: true,
                deidentifiedReusePermitted: true
            ),
            recordID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            submissionID: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            permissionReceiptID: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            createdAt: date
        )
        return (record.publicExport, try record.deterministicJSON())
    }

    private func eligibleTune() async throws -> TuneResult {
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
            gameBuildVersion: "test-build",
            tireCompound: "Stock",
            gearCount: 6,
            front: .init(minimumPSI: 15, maximumPSI: 40, stepPSI: 0.5, currentPSI: 30),
            rear: .init(minimumPSI: 15, maximumPSI: 40, stepPSI: 0.5, currentPSI: 30),
            exactStockBuildConfirmed: true,
            localUsePermitted: true
        ).exactBuildSnapshot(upgrading: parts, capturedAt: date, evidenceID: "local-tire")
        let request = TuneRequest(car: exact.car, discipline: .road, buildSnapshot: exact)
        var tune = try await CapabilityProjectingTuneProvider(base: LocalSampleTuneProvider())
            .generateTune(for: request)
        tune.generatedAt = date
        return tune
    }

    private func permission(for data: Data) throws -> VerifiedFirstPartyPermission {
        let validated = try FirstPartyValidationIngestor().validate(data)
        return VerifiedFirstPartyPermission(
            submissionID: validated.export.submissionID,
            permissionReceiptID: validated.export.permissionReceiptID,
            consentVersion: validated.export.consentVersion,
            canonicalExportDigest: validated.canonicalExportDigest,
            contentFingerprint: validated.export.contentFingerprint
        )
    }

    private func insertingTopLevel(_ member: String, into data: Data) -> Data {
        let json = String(decoding: data, as: UTF8.self)
        precondition(json.first == "{")
        return Data(("{\n  \(member)," + json.dropFirst()).utf8)
    }

    private func reorderingTopLevelKeys(in data: Data) -> Data {
        var lines = String(decoding: data, as: UTF8.self)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
        let attestation = lines.firstIndex { $0.hasPrefix("  \"allExportedSettingsApplied\"") }!
        let fingerprint = lines.firstIndex { $0.hasPrefix("  \"contentFingerprint\"") }!
        lines.swapAt(attestation, fingerprint)
        return Data(lines.joined(separator: "\n").utf8)
    }
}

private extension Array {
    var single: Element? { count == 1 ? first : nil }
}
