import PeakCore
import PeakDesign
import SwiftUI

/// C-04: the day's steps against the goal, the weekly average and a ring. Tap to change the goal.
struct StepsCard: View {
    enum State {
        case loading
        case steps(StepSummary)
        /// A day that has not happened yet.
        case future
        case needsAccess
        /// Turned off in the Health app.
        case denied
        case unavailable
    }

    let state: State
    let goal: Int
    let onConnect: () -> Void

    @State private var isGoalSheetShown = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        switch state {
        case .needsAccess:
            connect(message: "See your steps from Apple Health.", button: "Connect Apple Health", action: onConnect)
        case .denied:
            connect(message: "Peak can't read steps. Allow it in the Health app.", button: "Open Health") {
                if let url = URL(string: "x-apple-health://") {
                    openURL(url)
                }
            }
        case .unavailable:
            connect(message: "Apple Health is not available on this device.", button: nil) {}
        case .loading, .steps, .future:
            Button {
                isGoalSheetShown = true
            } label: {
                content
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("Changes the daily step goal"))
            .sheet(isPresented: $isGoalSheetShown) {
                StepGoalSheet()
            }
        }
    }

    private var count: Int? {
        if case .steps(let summary) = state { summary.count } else { nil }
    }

    private var progress: Double {
        Double(count ?? 0) / Double(max(goal, 1))
    }

    private var content: some View {
        HStack(spacing: Spacing.large) {
            VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                Text("Daily Step Count")
                    .font(.peakCardLabel)
                    .foregroundStyle(.peakTextPrimary)
                Text(verbatim: "\(count.map { $0.formatted() } ?? "–") / \(goal.formatted())")
                    .font(.peakCardLabel)
                    .monospacedDigit()
                    .foregroundStyle(.peakTextPrimary)
                if case .steps(let summary) = state, let average = summary.dailyAverage {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Weekly Average")
                        Text("\(average.formatted()) / day")
                            .monospacedDigit()
                    }
                    .font(.peakCardLabel)
                    .foregroundStyle(.peakTextTertiary)
                    .padding(.top, Spacing.xxSmall)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .redacted(reason: isLoading ? .placeholder : [])

            VStack(spacing: Spacing.xxSmall) {
                ProgressRing(progress: progress, tint: .peakSteps)
                    .frame(width: 80, height: 80)
                    .accessibilityLabel(Text("Step goal"))
                // The real percentage, also above 100 %.
                Text(progress, format: .percent.precision(.fractionLength(0)))
                    .font(.peakDetail)
                    .monospacedDigit()
                    .foregroundStyle(.peakTextPrimary)
                    .accessibilityHidden(true)
            }
        }
        .glassCard()
        .contentShape(.rect(cornerRadius: Radius.card))
    }

    private var isLoading: Bool {
        if case .loading = state { true } else { false }
    }

    private func connect(message: LocalizedStringKey, button: LocalizedStringKey?, action: @escaping () -> Void)
        -> some View
    {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("Daily Step Count")
                .font(.peakCardLabel)
                .foregroundStyle(.peakTextPrimary)
            Text(message)
                .font(.peakDetail)
                .foregroundStyle(.peakTextTertiary)
            if let button {
                Button(action: action) {
                    Label {
                        Text(button)
                    } icon: {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.peakSteps)
                    }
                }
                .buttonStyle(.peakGlass)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }
}

#if DEBUG
    #Preview {
        ScrollView {
            VStack(spacing: Spacing.medium) {
                StepsCard(state: .steps(.init(count: 7_598, dailyAverage: 6_771)), goal: 10_000) {}
                StepsCard(state: .steps(.init(count: 12_430, dailyAverage: 9_100)), goal: 10_000) {}
                StepsCard(state: .loading, goal: 10_000) {}
                StepsCard(state: .needsAccess, goal: 10_000) {}
                StepsCard(state: .denied, goal: 10_000) {}
            }
            .padding()
        }
        .background(.peakCanvas)
        .previewEnvironment()
    }
#endif
