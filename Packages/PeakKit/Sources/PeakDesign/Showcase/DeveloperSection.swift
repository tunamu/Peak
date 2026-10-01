#if DEBUG
    import PeakCore
    import SwiftData
    import SwiftUI

    /// The "Developer" section of Settings: Component Gallery and test data. Debug builds only.
    ///
    /// It lives in the package on purpose: Xcode does not extract strings from package sources, so these debug-only
    /// labels stay out of the app's String Catalog (a Release build would otherwise mark them stale). Place it inside
    /// a `NavigationStack` with a model container in the environment.
    public struct DeveloperSection: View {
        @State private var isGalleryShown = false
        @State private var sampleResult: ResultKind?
        @State private var sampleError: String?
        @State private var successMessage = "Sample program loaded"
        @Environment(\.modelContext) private var modelContext

        public init() {}

        public var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                SectionHeader("Developer")
                SettingsRow("Component Gallery", accessory: .icon("chevron.right")) {
                    isGalleryShown = true
                }
                // Until onboarding (F10-05) offers it, this is how the sample program gets in.
                SettingsRow("Load Sample Program", accessory: .icon("square.and.arrow.down")) {
                    loadSampleProgram()
                }
                // Three finished sessions before today, so Home has history to show.
                SettingsRow("Load Sample History", accessory: .icon("clock.arrow.circlepath")) {
                    loadSampleHistory()
                }
                // Before deploying the CloudKit schema to production: creates every record type in development.
                SettingsRow("Initialize CloudKit Schema", accessory: .icon("icloud.and.arrow.up")) {
                    Task { await initializeCloudKitSchema() }
                }
            }
            .navigationDestination(isPresented: $isGalleryShown) {
                DesignShowcase()
                    .navigationTitle(Text(verbatim: "Component Gallery"))
                    .inlineNavigationTitle()
            }
            .onAppear {
                // Screenshot helpers: launch with `-PeakTab settings` and one of these.
                if UserDefaults.standard.bool(forKey: "PeakOpenGallery") {
                    isGalleryShown = true
                }
                // Screenshot helper: `-PeakLoadSampleProgram YES` taps "Load Sample Program".
                if UserDefaults.standard.bool(forKey: "PeakLoadSampleProgram") {
                    loadSampleProgram()
                }
                // Screenshot helper: `-PeakLoadSecondRoutine YES` adds an everyday routine (two workouts a day).
                if UserDefaults.standard.bool(forKey: "PeakLoadSecondRoutine") {
                    try? SampleProgram.install(into: modelContext)
                    try? SampleProgram.installSecondRoutine(into: modelContext)
                }
                // Screenshot helper: `-PeakLoadSampleHistory YES` loads the program and its history.
                if UserDefaults.standard.bool(forKey: "PeakLoadSampleHistory") {
                    loadSampleHistory()
                }
            }
            .sheet(isPresented: isResultShown) {
                ResultSheet(
                    sampleResult ?? .failure,
                    title: sampleResult == .success ? "Success" : "Error",
                    message: Text(verbatim: sampleError ?? successMessage)
                ) {
                    Button(role: .confirm) {
                        sampleResult = nil
                    } label: {
                        Text(verbatim: "Done").frame(maxWidth: .infinity)
                    }
                }
            }
        }

        private var isResultShown: Binding<Bool> {
            Binding {
                sampleResult != nil
            } set: {
                if !$0 { sampleResult = nil }
            }
        }

        private func initializeCloudKitSchema() async {
            do {
                // Blocks until CloudKit answers, so it runs off the main actor.
                try await Task.detached { try PeakStore.initializeCloudKitSchema() }.value
                successMessage = "CloudKit schema initialized in the development environment"
                sampleError = nil
                sampleResult = .success
            } catch {
                sampleError = error.localizedDescription
                sampleResult = .failure
            }
        }

        private func loadSampleHistory() {
            successMessage = "Sample program loaded"
            do {
                try SampleProgram.install(into: modelContext)
                try SampleProgram.installHistory(into: modelContext)
                sampleError = nil
                sampleResult = .success
            } catch {
                sampleError = error.localizedDescription
                sampleResult = .failure
            }
        }

        private func loadSampleProgram() {
            successMessage = "Sample program loaded"
            do {
                try SampleProgram.install(into: modelContext)
                sampleError = nil
                sampleResult = .success
            } catch {
                sampleError = error.localizedDescription
                sampleResult = .failure
            }
        }
    }

    extension View {
        // The inline title mode exists only on iOS; the package also builds on a Mac host for `swift test`.
        fileprivate func inlineNavigationTitle() -> some View {
            #if os(iOS)
                navigationBarTitleDisplayMode(.inline)
            #else
                self
            #endif
        }
    }
#endif
