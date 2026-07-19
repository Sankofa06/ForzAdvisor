//
//  forzadvisorApp.swift
//  forzadvisor
//
//  Created by Michael Williams on 5/20/26.
//

import SwiftUI
import SwiftData
import AppIntents

@main
struct forzadvisorApp: App {
    private let modelContainer: ModelContainer

    init() {
        if Self.isUITesting {
            UserDefaults.standard.setVolatileDomain(
                ["tuneProviderMode": TuneProviderMode.offlineFormula.rawValue],
                forName: UserDefaults.argumentDomain
            )
        }

        do {
            modelContainer = try Self.makeModelContainer()
        } catch {
            fatalError("Could not create model container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}

private extension forzadvisorApp {
    static var isUITesting: Bool {
        CommandLine.arguments.contains("-ui-testing")
    }

    static func makeModelContainer() throws -> ModelContainer {
        let schema = Schema([SavedTune.self])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: isUITesting
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
