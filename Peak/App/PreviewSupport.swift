#if DEBUG
    import Foundation
    import PeakCore
    import SwiftData
    import SwiftUI

    /// An in-memory store with the sample program, and throwaway settings, for SwiftUI previews.
    @MainActor
    enum PreviewData {
        static let container: ModelContainer = {
            do {
                let container = try PeakStore.makeContainer(.inMemory)
                try SampleProgram.install(into: container.mainContext)
                try SampleProgram.installHistory(into: container.mainContext)
                return container
            } catch {
                fatalError("Could not build the preview store: \(error)")
            }
        }()

        static let settings = SettingsStore(defaults: UserDefaults(suiteName: "peak.previews") ?? .standard)
        static let health = HealthConnection(service: MockHealthService())
        static let launcher = WorkoutLauncher()
        static let data: AppData = {
            do {
                // Sync off: previews never reach iCloud.
                let preferences = UserDefaults(suiteName: "peak.previews") ?? .standard
                return try AppData(preferences: preferences) { _ in container }
            } catch {
                fatalError("Could not build the preview app data: \(error)")
            }
        }()
    }

    extension View {
        /// The environment the app's screens expect: a model container, settings, Health and the workout launcher.
        func previewEnvironment() -> some View {
            modelContainer(PreviewData.container)
                .environment(PreviewData.settings)
                .environment(PreviewData.health)
                .environment(PreviewData.launcher)
                .environment(PreviewData.data)
                .task {
                    await PreviewData.health.refresh()
                }
        }
    }
#endif
