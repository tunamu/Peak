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
    @State private var health = HealthConnection(service: PeakApp.makeHealthService())
    @State private var launcher = WorkoutLauncher()

    init() {
        do {
            // In the App Group so the widget reads the same store. iCloud sync stays off until F8.
            container = try PeakStore.makeContainer(.appGroup)
            // The Live Activity's Pause/Resume intent runs in this process: it works on the same container.
            WorkoutActivity.container = container
        } catch {
            fatalError("Could not open the Peak store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                // Registers the step observer at launch, so background delivery can wake the app.
                .task { await health.refresh() }
                .modifier(WidgetSync())
        }
        .modelContainer(container)
        .environment(settings)
        .environment(health)
        .environment(launcher)
    }

    private static func makeHealthService() -> any HealthService {
        #if DEBUG
            // Screenshot helper: `-PeakMockHealth YES` shows sample Health data (the simulator has none).
            if UserDefaults.standard.bool(forKey: "PeakMockHealth") {
                return MockHealthService()
            }
        #endif
        return HealthKitService()
    }
}
