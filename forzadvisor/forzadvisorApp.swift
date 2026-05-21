//
//  forzadvisorApp.swift
//  forzadvisor
//
//  Created by Michael Williams on 5/20/26.
//

import SwiftUI
import SwiftData

@main
struct forzadvisorApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: SavedTune.self)
    }
}
