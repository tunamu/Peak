import PeakDesign
import SwiftUI

/// Analysis tab (C-14). A placeholder in v1; charts come after release.
struct AnalysisPlaceholderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Analysis")
                .font(.peakScreenTitle)
                .foregroundStyle(.peakTextPrimary)
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, Spacing.screenMargin)
                .padding(.top, Spacing.medium)

            ContentUnavailableView {
                Label("Coming soon", systemImage: "chart.line.uptrend.xyaxis")
            } description: {
                Text("Charts and trends for your workouts will appear here.")
            }
            .foregroundStyle(.peakTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.peakCanvas)
    }
}

#Preview("Dark") {
    AnalysisPlaceholderView()
        .preferredColorScheme(.dark)
}

#Preview("Light") {
    AnalysisPlaceholderView()
        .preferredColorScheme(.light)
}
