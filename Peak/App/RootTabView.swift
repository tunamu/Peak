import PeakDesign
import SwiftUI

/// The three tabs (C-01). iOS 26 draws the design's floating glass tab bar by itself.
struct RootTabView: View {
    enum TabID: String, Hashable {
        case home
        case analysis
        case settings
    }

    @State private var selection: TabID = .home

    var body: some View {
        // iOS 26 draws every tab symbol filled; the selected tab is marked by the glass pill and the tint. Filling
        // only the selected symbol (V-01) was tried, but the tab bar ignores the override on the first render.
        TabView(selection: $selection) {
            Tab("Home", systemImage: "house", value: .home) {
                HomeView().tint(Color?.none)
            }
            Tab("Analysis", systemImage: "chart.line.uptrend.xyaxis", value: .analysis) {
                AnalysisPlaceholderView().tint(Color?.none)
            }
            Tab("Settings", systemImage: "gearshape", value: .settings) {
                SettingsView().tint(Color?.none)
            }
        }
        // The design's selected tab is white (black in light mode), not the system blue. Tab contents get the
        // default tint back so their own controls are unaffected.
        .tint(.peakTextPrimary)
        .tabBarMinimizeBehavior(.onScrollDown)
        #if DEBUG
            // Screenshot helper: launch with `-PeakTab settings`.
            .onAppear {
                if let tab = UserDefaults.standard.string(forKey: "PeakTab").flatMap(TabID.init(rawValue:)) {
                    selection = tab
                }
            }
        #endif
    }
}

#Preview {
    RootTabView()
}
