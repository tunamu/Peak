import PeakDesign
import SwiftUI

/// Settings tab. Skeleton only; goal, workout, routine and general settings arrive in F4.
struct SettingsView: View {
    @State private var isGalleryShown = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.section) {
                    // The design's title is 28 pt regular, not the navigation bar's 34 pt bold large title.
                    Text("Settings")
                        .font(.peakScreenTitle)
                        .foregroundStyle(.peakTextPrimary)
                        .accessibilityAddTraits(.isHeader)

                    #if DEBUG
                        developerSection
                    #endif
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.screenMargin)
                .padding(.top, Spacing.medium)
            }
            .background(.peakCanvas)
            .toolbarVisibility(.hidden, for: .navigationBar)
            #if DEBUG
                .navigationDestination(isPresented: $isGalleryShown) {
                    DesignShowcase()
                    .navigationTitle("Component Gallery")
                    .navigationBarTitleDisplayMode(.inline)
                }
                .onAppear {
                    // Screenshot helper: launch with `-PeakTab settings -PeakOpenGallery YES`.
                    if UserDefaults.standard.bool(forKey: "PeakOpenGallery") {
                        isGalleryShown = true
                    }
                }
            #endif
        }
    }

    #if DEBUG
        private var developerSection: some View {
            VStack(alignment: .leading, spacing: 0) {
                SectionHeader("Developer")
                SettingsRow("Component Gallery", accessory: .icon("chevron.right")) {
                    isGalleryShown = true
                }
            }
        }
    #endif
}

#Preview("Dark") {
    SettingsView()
        .preferredColorScheme(.dark)
}

#Preview("Light") {
    SettingsView()
        .preferredColorScheme(.light)
}
