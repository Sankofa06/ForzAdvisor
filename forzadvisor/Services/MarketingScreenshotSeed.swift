import Foundation
import SwiftData

/// Local demonstration data only. Never installed in a persistent user store.
enum MarketingScreenshotSeed {
    static let launchArgument = "-marketing-screenshots-seed"

    static var isEnabled: Bool { isEnabled(arguments: CommandLine.arguments) }

    static func isEnabled(arguments: [String]) -> Bool {
#if DEBUG && targetEnvironment(simulator)
        return arguments.contains("-ui-testing")
            && arguments.contains(launchArgument)
#else
        return false
#endif
    }

    static var manualDraft: ManualEntryDraft {
        ManualEntryDraft(car: demonstrationCar(
            year: 1997, make: "Mazda", model: "MX-5 Miata",
            weight: 2345, frontWeight: 52, index: 650
        ))
    }

    @MainActor
    static func install(in container: ModelContainer) throws {
        guard isEnabled else { return }
        // The caller additionally enforces an in-memory configuration. Refuse
        // to seed a persistent container even if launch wiring changes later.
        guard container.configurations.allSatisfy(\.isStoredInMemoryOnly) else {
            return
        }
        let context = container.mainContext
        guard try context.fetchCount(FetchDescriptor<SavedTune>()) == 0 else {
            return
        }
        let examples: [(CarInput, DrivingDiscipline)] = [
            (demonstrationCar(year: 1997, make: "Mazda", model: "MX-5 Miata",
                              weight: 2345, frontWeight: 52, index: 650), .road),
            (demonstrationCar(year: 2019, make: "Toyota", model: "GR Supra",
                              weight: 3340, frontWeight: 53, index: 680), .touge),
            (demonstrationCar(year: 2005, make: "Subaru", model: "Impreza WRX STI",
                              weight: 3298, frontWeight: 59, index: 690,
                              drivetrain: .awd), .dirt)
        ]
        for (offset, example) in examples.enumerated() {
            let date = Date(timeIntervalSince1970: 1_791_936_000 - Double(offset) * 86400)
            let request = TuneRequest(car: example.0, discipline: example.1)
            // No fabricated build, validation records, numeric values, or
            // provider calls. The production projector determines withholding.
            let candidate = TuneResult(
                id: UUID(uuidString: "A0000000-0000-4000-8000-00000000000\(offset + 1)")!,
                request: request,
                sections: [],
                notes: TuneNotes(
                    bias: "Demonstration setup plan.",
                    ifPushesWide: "Confirm the installed build in game.",
                    ifSnapsOnLift: "Confirm tuning-menu ranges in game.",
                    retuneTrigger: "Generate again after confirming evidence."
                ),
                generatedAt: date
            )
            let plan = TuneOutputProjector().project(candidate, for: request)
            context.insert(try SavedTune(
                tune: plan,
                playerNotes: "Demo only — local example plan. Vehicle details are illustrative; confirm your own build in game. No test-drive evidence recorded.",
                now: date
            ))
        }
        try context.save()
    }

    private static func demonstrationCar(
        year: Int, make: String, model: String,
        weight: Int, frontWeight: Double, index: Int,
        drivetrain: Drivetrain = .rwd
    ) -> CarInput {
        CarInput(
            game: .fh6, year: year, make: make, model: model,
            weightPounds: weight, frontWeightPercent: frontWeight,
            performanceIndex: index, performanceClass: .a,
            drivetrain: drivetrain, peakHorsepower: nil,
            peakTorqueFootPounds: nil
        )
    }
}
