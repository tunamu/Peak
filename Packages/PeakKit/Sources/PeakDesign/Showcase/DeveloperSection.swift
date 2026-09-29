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
            }
            .sheet(isPresented: isResultShown) {
                ResultSheet(
                    sampleResult ?? .failure,
                    title: sampleResult == .success ? "Success" : "Error",
                    message: Text(verbatim: sampleError ?? "Sample program loaded")
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

        private func loadSampleProgram() {
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
