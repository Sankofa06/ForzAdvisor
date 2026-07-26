//
//  CatalogUpgradeEvidenceReuseFixtures.swift
//  forzadvisorTests
//

import XCTest
@testable import forzadvisor

extension CatalogUpgradeEvidenceReuseTests {
    func selection(
        game: ForzaGame = .fh6
    ) throws -> CatalogCarSelection {
        let catalog = try BundledCarCatalog.load().get()
        let entry = try XCTUnwrap(
            catalog.entries.first { $0.game == game }
        )
        return catalog.selection(for: entry)
    }

    func sourceSnapshot(
        for selection: CatalogCarSelection,
        build: String = "current-build",
        observedAt: Date? = nil
    ) throws -> VehicleBuildSnapshot {
        let date = observedAt ?? Date(
            timeIntervalSinceReferenceDate: 900
        )
        let exact: VehicleBuildSnapshot
        if selection.entry.game == .fh6 {
            exact = try TirePressureCapture(
                gameBuildVersion: build,
                tireCompound: "Stock",
                gearCount: 6,
                front: .init(
                    minimumPSI: 15,
                    maximumPSI: 40,
                    stepPSI: 0.5,
                    currentPSI: 30
                ),
                rear: .init(
                    minimumPSI: 15,
                    maximumPSI: 40,
                    stepPSI: 0.5,
                    currentPSI: 30
                ),
                exactStockBuildConfirmed: true,
                localUsePermitted: true
            ).exactBuildSnapshot(
                upgrading:
                    selection.capabilityOnlyBuildSnapshot(),
                capturedAt: date,
                evidenceID:
                    "reuse-tire-\(date.timeIntervalSinceReferenceDate)"
            )
        } else {
            var source =
                selection.capabilityOnlyBuildSnapshot(
                    capturedAt: date
                )
            source.kind = .exactBuildObservation
            source.gameBuild.version = build
            source.gameBuild.capturedAt = date
            exact = source
        }
        return try UpgradePartCapture(
            gameBuildVersion: build,
            parts: TunePartID.allCases.map {
                .init(partID: $0, status: .offered)
            },
            exactStockBuildConfirmed: true,
            localUsePermitted: true
        ).verifiedSnapshot(
            upgrading: exact,
            capturedAt: date,
            snapshotID: fixedUUID(
                Int(date.timeIntervalSinceReferenceDate)
            )
        )
    }

    func tune(
        snapshot: VehicleBuildSnapshot
    ) -> TuneResult {
        TuneResult(
            request: TuneRequest(
                car: snapshot.car,
                discipline: .road,
                buildSnapshot: snapshot
            ),
            sections: [],
            notes: .init(
                bias: "",
                ifPushesWide: "",
                ifSnapsOnLift: "",
                retuneTrigger: ""
            )
        )
    }

    func evidence(build: String) -> TuneEvidence {
        TuneEvidence(
            confidence: .medium,
            source: UpgradePartCapture.provenanceSource,
            version: build,
            usagePermission: .permitted
        )
    }

    func fixedUUID(_ value: Int) -> UUID {
        UUID(
            uuidString: String(
                format:
                    "00000000-0000-0000-0000-%012d",
                abs(value) % 1_000_000_000_000
            )
        )!
    }
}
