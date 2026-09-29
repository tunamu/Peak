//
//  PeakApp.swift
//  Peak
//
//  Created by Tuna Mus on 29.09.2026.
//

import PeakCore
import SwiftData
import SwiftUI

@main
struct PeakApp: App {
    /// Held here for the app's lifetime: a `ModelContext` does not keep its container alive.
    private let container: ModelContainer
    @State private var settings = SettingsStore(defaults: SettingsStore.appGroupDefaults())

    init() {
        do {
            // In the App Group so the widget reads the same store. iCloud sync stays off until F8.
            container = try PeakStore.makeContainer(.appGroup)
        } catch {
            fatalError("Could not open the Peak store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(container)
        .environment(settings)
    }
}
