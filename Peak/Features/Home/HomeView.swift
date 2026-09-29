import PeakDesign
import SwiftUI

/// Home tab. Skeleton only; the week strip, workout card and dashboard arrive in F5.
struct HomeView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.section) {
                Text("Welcome Back")
                    .font(.peakScreenTitle)
                    .foregroundStyle(.peakTextPrimary)
                    .accessibilityAddTraits(.isHeader)
                SectionHeader("Dashboard")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.screenMargin)
            .padding(.top, Spacing.medium)
        }
        .background(.peakCanvas)
    }
}

#Preview("Dark") {
    HomeView()
        .preferredColorScheme(.dark)
}

#Preview("Light") {
    HomeView()
        .preferredColorScheme(.light)
}
