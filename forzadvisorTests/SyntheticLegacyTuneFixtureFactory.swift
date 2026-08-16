import Foundation
@testable import forzadvisor

enum SyntheticLegacyTuneFixtureFactory {
    static func selection(
        game: ForzaGame = .fh6,
        drivetrain: Drivetrain = .rwd,
        variant: Int = 0,
        reviewedAt: Date
    ) -> CatalogCarSelection {
        let performanceIndex: Int
        let performanceClass: PerformanceClass
        switch game {
        case .fh5:
            performanceIndex = 750
            performanceClass = .a
        case .fh6:
            performanceIndex = 700
            performanceClass = .a
        }
        let entry = CatalogCarEntry(
            id: "test-only:\(game.rawValue):\(variant):fixture-coupe",
            game: game,
            year: 2020 + variant,
            make: "Fixture",
            model: variant == 0 ? "Coupe" : "Coupe Variant \(variant)",
            stock: CatalogStockSpecifications(
                performanceIndex: performanceIndex,
                performanceClass: performanceClass,
                drivetrain: drivetrain,
                weightPounds: 3_100,
                frontWeightPercent: 52,
                peakHorsepower: 350,
                peakTorqueFootPounds: 320
            ),
            verificationStatus: .inGameVerified,
            sources: []
        )
        return CarCatalogSnapshot(
            schemaVersion: 1,
            revision: "test-only-fixture-v1",
            reviewedAt: reviewedAt,
            entries: [entry]
        ).selection(for: entry)
    }

    static func eligibleValidationTune(
        capturedAt: Date,
        usesMenuCapture: Bool = false,
        discipline: DrivingDiscipline = .road
    ) async throws -> TuneResult {
        let selection = selection(reviewedAt: capturedAt)
        let capability = selection.capabilityOnlyBuildSnapshot(
            capturedAt: capturedAt
        )
        let parts = try UpgradePartCapture(
            gameBuildVersion: "test-build",
            parts: TunePartID.allCases.map {
                UpgradePartCaptureValue(partID: $0, status: .offered)
            },
            exactStockBuildConfirmed: true,
            localUsePermitted: true
        ).verifiedSnapshot(upgrading: capability, capturedAt: capturedAt)
        let exact = try usesMenuCapture
            ? menuSnapshot(upgrading: parts, capturedAt: capturedAt)
            : tireSnapshot(upgrading: parts, capturedAt: capturedAt)
        let request = TuneRequest(
            car: exact.car,
            discipline: discipline,
            buildSnapshot: exact
        )
        var tune = try await CapabilityProjectingTuneProvider(
            base: LocalSampleTuneProvider()
        ).generateTune(for: request)
        tune.generatedAt = capturedAt
        return tune
    }

    private static func tireSnapshot(
        upgrading parts: VehicleBuildSnapshot,
        capturedAt: Date
    ) throws -> VehicleBuildSnapshot {
        try TirePressureCapture(
            gameBuildVersion: "test-build",
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
            upgrading: parts,
            capturedAt: capturedAt,
            evidenceID: "test-only-tire"
        )
    }

    private static func menuSnapshot(
        upgrading parts: VehicleBuildSnapshot,
        capturedAt: Date
    ) throws -> VehicleBuildSnapshot {
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
        return try FH6TuneMenuCapture(
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
            capturedAt: capturedAt,
            evidenceID: "test-only-menu"
        )
    }
}
