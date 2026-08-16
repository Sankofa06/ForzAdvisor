import SwiftData
import XCTest
@testable import forzadvisor

extension FH5ResearchTestCase {
    func makeReviewExport(
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

    func reviewInput(
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

    func reviewedInput(
        for export: FH5ResearchObservationExport
    ) throws -> FH5ResearchReviewInput {
        let data = try FH5ResearchReviewIngestor.canonicalData(for: export)
        let entry = try FH5ResearchReviewEntry.locallyReviewed(
            canonicalExportJSON: data,
            reviewerConfirmedDirectReceiptAndReusePermission: true,
            now: capturedAt
        )
        return FH5ResearchReviewInput(entry: entry)
    }

    func reviewedReplicationInputs(
        plan: TuneResult
    ) throws -> [FH5ResearchReviewInput] {
        let first = try makeReviewExport(
            plan: plan,
            submissionID: UUID(),
            permissionReceiptID: UUID(),
            capturedAt: capturedAt
        )
        let second = try makeReviewExport(
            plan: plan,
            submissionID: UUID(),
            permissionReceiptID: UUID(),
            capturedAt: capturedAt.addingTimeInterval(60)
        )
        return try [
            reviewedInput(for: first),
            reviewedInput(for: second)
        ]
    }

    func replacingReviewExport(
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

    func replacingReviewExport(
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

    func insertingTopLevel(
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
}
