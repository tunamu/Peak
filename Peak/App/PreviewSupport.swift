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
                return container
            } catch {
                fatalError("Could not build the preview store: \(error)")
            }
        }()

        static let settings = SettingsStore(defaults: UserDefaults(suiteName: "peak.previews") ?? .standard)
    }

    extension View {
        /// The environment the app's screens expect: a model container and the settings store.
        func previewEnvironment() -> some View {
            modelContainer(PreviewData.container)
                .environment(PreviewData.settings)
        }
    }
#endif
