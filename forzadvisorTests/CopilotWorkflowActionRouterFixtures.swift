import Foundation
@testable import forzadvisor

enum CopilotRouterFixtureFactory {
    static func car(game: ForzaGame) -> CarInput {
        let entryID = "fixture:\(game.rawValue):2020-codex-coupe"
        return CarInput(
            game: game,
            year: 2020,
            make: "Codex",
            model: "Coupe",
            weightPounds: 3_100,
            frontWeightPercent: 52,
            performanceIndex: game == .fh5 ? 800 : 700,
            performanceClass: .a,
            drivetrain: .rwd,
            peakHorsepower: 350,
            peakTorqueFootPounds: 320,
            catalogReference: CatalogCarReference(
                entryID: entryID,
                revision: "router-fixture-v1",
                reviewedAt: Date(timeIntervalSinceReferenceDate: 800),
                verificationStatus: .inGameVerified,
                sources: []
            )
        )
    }

    static func capabilitySnapshot(
        car: CarInput,
        capturedAt: Date
    ) -> VehicleBuildSnapshot {
        VehicleBuildSnapshot(
            schemaVersion: VehicleBuildSnapshot.currentSchemaVersion,
            id: UUID(),
            kind: .capabilityOnly,
            capturedAt: capturedAt,
            gameBuild: GameBuildReference(
                game: car.game,
                version: nil,
                capturedAt: nil
            ),
            car: car,
            capabilityProfile: TuneVehicleCapabilityProfile(
                vehicle: TuneVehicleIdentity(
                    game: car.game,
                    catalogID:
                        car.catalogReference?.entryID
                        ?? "fixture:missing-reference",
                    year: car.year ?? 2020,
                    make: car.make,
                    model: car.model
                ),
                drivetrain: car.drivetrain,
                parts: [],
                stockAdjustableSettings: []
            ),
            tireCompound: nil,
            gearCount: nil,
            constraints: [],
            evidenceSources: []
        )
    }
}
