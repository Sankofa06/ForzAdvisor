import SwiftData
import XCTest
@testable import forzadvisor

extension FH5ResearchTestCase {
    func makePlan(
        upgradeBuild: String? = nil,
        fh5EntryOffset: Int = 0
    ) async throws -> TuneResult {
        let selection = SyntheticLegacyTuneFixtureFactory.selection(
            game: .fh5,
            variant: fh5EntryOffset,
            reviewedAt: capturedAt
        )
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

    func makeTune(game: ForzaGame) async throws -> TuneResult {
        let selection = SyntheticLegacyTuneFixtureFactory.selection(
            game: game,
            reviewedAt: capturedAt
        )
        return try await CapabilityProjectingTuneProvider(base: LocalSampleTuneProvider())
            .generateTune(for: TuneRequest(
                car: selection.carInput,
                discipline: .road,
                buildSnapshot: selection.capabilityOnlyBuildSnapshot(capturedAt: capturedAt)
            ))
    }

    func validCapture(
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

    func adjustable(
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

    func replacing(
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

    func replacing(
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

    func XCTAssertSuccess<Success>(
        _ result: Result<Success, FH5ResearchIssue>,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case .success = result else {
            return XCTFail("Expected success, received \(result)", file: file, line: line)
        }
    }

    func XCTAssertFailure<Success, Failure: Error & Equatable>(
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

extension FH5ControlledExperimentFactory {
    func makeCandidateBoundForTesting(
        tune: TuneResult,
        savedTune: TuneResult?,
        isStreaming: Bool,
        researchRecords: [FH5ResearchObservationRecord],
        capture: FH5ControlledExperimentCapture,
        candidateAlgorithmID: FH5ExperimentalAlgorithmID,
        registry: FH5TrustedNumericRulesetRegistry,
        recordID: UUID = UUID(),
        submissionID: UUID = UUID(),
        permissionReceiptID: UUID = UUID(),
        createdAt: Date = .now
    ) throws -> FH5ControlledExperimentRecord {
        let artifact = try makeCandidateArtifactForTesting(
            tune: tune,
            savedTune: savedTune,
            isStreaming: isStreaming,
            researchRecords: researchRecords,
            capture: capture,
            candidateAlgorithmID: candidateAlgorithmID,
            registry: registry
        )
        return try makeCandidateBound(
            tune: tune,
            savedTune: savedTune,
            isStreaming: isStreaming,
            researchRecords: researchRecords,
            capture: capture,
            candidateArtifact: artifact,
            registry: registry,
            recordID: recordID,
            submissionID: submissionID,
            permissionReceiptID: permissionReceiptID,
            createdAt: createdAt
        )
    }
}
