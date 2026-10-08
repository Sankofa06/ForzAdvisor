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
            Group {
#if DEBUG
                if Self.isAccessibilityXXXLUITesting {
                    ContentView().dynamicTypeSize(.accessibility5)
                } else if CommandLine.arguments.contains("-ui-test-legacy-settings") {
                    LegacyTuneSettingsUITestHarness()
                } else if CommandLine.arguments.contains("-ui-test-capture-actions") {
                    TuneCaptureActionUITestHarness()
                } else if CommandLine.arguments.contains("-ui-test-ocr-manual-values") {
                    OCRManualValuesUITestHarness()
                } else {
                    ContentView()
                }
#else
                ContentView()
#endif
            }
#if DEBUG
            .preferredColorScheme(Self.uiTestColorScheme)
#endif
        }
        .modelContainer(modelContainer)
    }
}

private extension forzadvisorApp {
    static var isUITesting: Bool {
        CommandLine.arguments.contains("-ui-testing")
    }

#if DEBUG
    static var isAccessibilityXXXLUITesting: Bool {
        isUITesting && CommandLine.arguments.contains("-ui-test-accessibility-xxxl")
    }

    static var uiTestColorScheme: ColorScheme? {
        guard isUITesting,
              CommandLine.arguments.contains("-ui-test-dark-appearance")
        else {
            return nil
        }
        return .dark
    }
#endif

    static func makeModelContainer() throws -> ModelContainer {
        let schema = Schema([SavedTune.self])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: isUITesting
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
