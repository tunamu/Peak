import PeakCore
import PeakDesign
import SwiftUI

/// D-26: green arrow up, red arrow down, grey dash between. A shape as well as a color; VoiceOver reads it as words.
struct TrendArrow: View {
    let trend: TrendChange?

    var body: some View {
        if let trend {
            Image(systemName: symbol(trend.trend))
                .font(.peakRow.weight(.bold))
                .foregroundStyle(color(trend.trend))
                .accessibilityLabel(label(trend.trend))
        }
    }

    private func symbol(_ trend: Trend) -> String {
        switch trend {
        case .rising: "arrow.up"
        case .steady: "minus"
        case .falling: "arrow.down"
        }
    }

    private func color(_ trend: Trend) -> Color {
        switch trend {
        case .rising: .peakTrendRising
        case .steady: .peakTextTertiary
        case .falling: .peakTrendFalling
        }
    }

    private func label(_ trend: Trend) -> Text {
        switch trend {
        case .rising: Text("Rising")
        case .steady: Text("Steady")
        case .falling: Text("Falling")
        }
    }
}

/// A number on the Performance page with its change against the period before: "12 · ↑ 20%".
struct StatTile: View {
    let title: LocalizedStringKey
    let value: String
    var change: TrendChange?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxSmall) {
            Text(title)
                .font(.peakDetail)
                .foregroundStyle(.peakTextSecondary)
            Text(verbatim: value)
                .font(.peakSectionTitle.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.peakTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            HStack(spacing: Spacing.xxSmall) {
                TrendArrow(trend: change)
                Text(verbatim: change.map { Formatting.percent(abs($0.change)) } ?? " ")
                    .font(.peakDetail)
                    .monospacedDigit()
                    .foregroundStyle(.peakTextSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
        .accessibilityElement(children: .combine)
    }
}

/// A row that opens a chart: the name, its arrow, and a value on the right.
struct AnalysisRow: View {
    let title: String
    let detail: String
    var trend: TrendChange?

    var body: some View {
        HStack(spacing: Spacing.xSmall) {
            Text(verbatim: title)
                .foregroundStyle(.peakTextPrimary)
                .multilineTextAlignment(.leading)
            TrendArrow(trend: trend)
            Spacer(minLength: Spacing.xSmall)
            Text(verbatim: detail)
                .monospacedDigit()
                .foregroundStyle(.peakTextTertiary)
                .multilineTextAlignment(.trailing)
            Image(systemName: "chevron.right")
                .font(.peakDetail)
                .foregroundStyle(.peakTextTertiary)
                .accessibilityHidden(true)
        }
        .font(.peakRow)
        .padding(.horizontal, Spacing.xSmall)
        .frame(minHeight: Metrics.minTouchTarget)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

extension AnalysisPeriod {
    var title: LocalizedStringKey {
        switch self {
        case .fourWeeks: "Last 4 Weeks"
        case .threeMonths: "Last 3 Months"
        case .sixMonths: "Last 6 Months"
        case .year: "Last Year"
        case .all: "All Time"
        }
    }
}
