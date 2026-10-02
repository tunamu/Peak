import PeakCore
import SwiftUI
import WidgetKit

// F11-11: more Home Screen widgets. Energy (small), Dashboard (medium: steps, water and energy together) and Week
// (large: the week's workout days, today's workout and the week's totals). Like WidgetViews.swift, the views live here
// so the Component Gallery can show them.

/// Energy Level on its own: the bolt in the level's color and what it means for today.
public struct EnergyWidgetView: View {
    let content: WidgetContent

    public init(content: WidgetContent) {
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxSmall) {
            HStack {
                Image(systemName: "bolt.fill")
                    .font(.title2)
                    .foregroundStyle(EnergyStyle.color(content.energy))
                    .widgetAccentable()
                    .accessibilityHidden(true)
                Spacer()
                Text("Energy")
                    .font(.peakDetail)
                    .foregroundStyle(.peakTextSecondary)
            }
            Spacer(minLength: 0)
            EnergyStyle.title(content.energy)
                .font(.peakEmphasis)
                .foregroundStyle(.peakTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            EnergyStyle.message(content.energy)
                .font(.peakDetail)
                .foregroundStyle(.peakTextSecondary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .accessibilityElement(children: .combine)
    }
}

/// The day at a glance: steps, water with its add button, and energy.
public struct DashboardWidgetView<AddButton: View>: View {
    let content: WidgetContent
    let addButton: (Text) -> AddButton

    public init(content: WidgetContent, @ViewBuilder addButton: @escaping (Text) -> AddButton) {
        self.content = content
        self.addButton = addButton
    }

    public var body: some View {
        HStack(spacing: Spacing.medium) {
            VStack(spacing: Spacing.xxSmall) {
                ZStack {
                    ProgressRing(progress: stepProgress, tint: .peakSteps, lineWidth: 8)
                        .widgetAccentable()
                    Image(systemName: "figure.walk")
                        .font(.peakRow)
                        .foregroundStyle(.peakSteps)
                        .widgetAccentable()
                        .accessibilityHidden(true)
                }
                Text(content.steps.map { $0.formatted() } ?? "–")
                    .font(.peakRow.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.peakTextPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Steps"))
            .accessibilityValue(Text(verbatim: content.steps.map { $0.formatted() } ?? "–"))

            VStack(alignment: .leading, spacing: Spacing.xSmall) {
                HStack(spacing: Spacing.xxSmall) {
                    Image(systemName: "drop.fill")
                        .foregroundStyle(.peakWater)
                        .widgetAccentable()
                        .accessibilityHidden(true)
                    Text(verbatim: "\(liters(content.waterMl)) / \(liters(content.waterGoalMl)) L")
                        .foregroundStyle(.peakTextPrimary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .font(.peakRow.weight(.semibold))
                ProgressView(value: min(1, Double(content.waterMl) / Double(max(1, content.waterGoalMl))))
                    .tint(.peakWater)
                    .widgetAccentable()
                    .accessibilityHidden(true)
                addButton(Text("+\(content.quickWaterMl) ml"))
                    .font(.peakDetail.weight(.semibold))
                    .buttonStyle(.borderedProminent)
                    .tint(.peakWater)
                    .widgetAccentable()
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: Spacing.xxSmall) {
                Image(systemName: "bolt.fill")
                    .font(.title2)
                    .foregroundStyle(EnergyStyle.color(content.energy))
                    .widgetAccentable()
                    .accessibilityHidden(true)
                EnergyStyle.title(content.energy)
                    .font(.peakDetail.weight(.semibold))
                    .foregroundStyle(.peakTextPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
        }
    }

    private var stepProgress: Double {
        guard let steps = content.steps else { return 0 }
        return min(1, Double(steps) / Double(max(1, content.stepGoal)))
    }

    private func liters(_ milliliters: Int) -> String {
        (Double(milliliters) / 1_000).formatted(.number.precision(.fractionLength(1)))
    }
}

/// The week: a dot per day (done, planned, free), today's workout, and the week's workouts, volume and streak.
public struct WeekWidgetView: View {
    let content: WidgetContent

    @Environment(\.calendar) private var calendar

    public init(content: WidgetContent) {
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            HStack {
                Text("This Week")
                    .font(.peakCardValue)
                    .foregroundStyle(.peakTextPrimary)
                Spacer()
                Image(systemName: "flame.fill")
                    .foregroundStyle(.peakSteps)
                    .widgetAccentable()
                    .accessibilityHidden(true)
                Text("\(content.week.streakWeeks) weeks in a row")
                    .font(.peakDetail)
                    .foregroundStyle(.peakTextSecondary)
            }
            days
            today
                .padding(Spacing.small)
                .background(.peakFillControl.opacity(0.5), in: .rect(cornerRadius: Radius.control))
            Spacer(minLength: 0)
            HStack(spacing: Spacing.medium) {
                stat("Workouts", value: content.week.workouts.formatted())
                stat("Volume", value: volume)
            }
        }
    }

    /// Today's workout in one row: what it is, its state, and the bolt in the Energy Level's color.
    private var today: some View {
        HStack(spacing: Spacing.small) {
            VStack(alignment: .leading, spacing: 2) {
                #if os(iOS)
                    TodayAccessoryView(content: content, family: .accessoryRectangular)
                        .foregroundStyle(.peakTextPrimary)
                #endif
            }
            Spacer(minLength: 0)
            VStack(spacing: 2) {
                Image(systemName: "bolt.fill")
                    .font(.title3)
                    .foregroundStyle(EnergyStyle.color(content.energy))
                    .widgetAccentable()
                    .accessibilityHidden(true)
                EnergyStyle.title(content.energy)
                    .font(.peakMeta.weight(.semibold))
                    .foregroundStyle(.peakTextPrimary)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var volume: String {
        let value = WeightUnits.displayValue(kg: content.week.volumeKg, in: content.unitSystem)
        return
            "\(value.formatted(.number.precision(.fractionLength(0)))) \(content.unitSystem == .metric ? "kg" : "lb")"
    }

    private var days: some View {
        HStack(spacing: 0) {
            ForEach(content.week.days, id: \.date) { day in
                let isToday = calendar.isDate(day.date, inSameDayAs: content.date)
                VStack(spacing: Spacing.xxSmall) {
                    Text(
                        verbatim: calendar.veryShortStandaloneWeekdaySymbols[
                            calendar.component(.weekday, from: day.date) - 1]
                    )
                    .font(.peakMeta)
                    .foregroundStyle(isToday ? .peakTextPrimary : .peakTextSecondary)
                    dot(day.status)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(day.date, format: .dateTime.weekday(.wide)))
                .accessibilityValue(statusText(day.status))
            }
        }
    }

    @ViewBuilder
    private func dot(_ status: WeekDayStatus) -> some View {
        switch status {
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.peakEnergyReady)
                .widgetAccentable()
                .accessibilityHidden(true)
        case .planned:
            Image(systemName: "circle")
                .foregroundStyle(.peakTextPrimary)
                .accessibilityHidden(true)
        case .none:
            Image(systemName: "circle")
                .foregroundStyle(.peakTextTertiary.opacity(0.4))
                .accessibilityHidden(true)
        }
    }

    private func statusText(_ status: WeekDayStatus) -> Text {
        switch status {
        case .done: Text("Done")
        case .planned: Text("Planned")
        case .none: Text(verbatim: "")
        }
    }

    private func stat(_ title: LocalizedStringKey, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.peakMeta)
                .foregroundStyle(.peakTextSecondary)
            Text(verbatim: value)
                .font(.peakCardValue.monospacedDigit())
                .foregroundStyle(.peakTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// Energy Level's wording and color, shared by the widgets.
enum EnergyStyle {
    static func title(_ level: EnergyLevel?) -> Text {
        switch level {
        case .ready: Text("Ready")
        case .low: Text("Low")
        case .notReady: Text("Not Ready")
        case nil: Text(verbatim: "–")
        }
    }

    static func message(_ level: EnergyLevel?) -> Text {
        switch level {
        case .ready: Text("You can workout now")
        case .low: Text("You can workout a bit")
        case .notReady: Text("You can't workout now")
        case nil: Text("Open Peak to update")
        }
    }

    static func color(_ level: EnergyLevel?) -> Color {
        switch level {
        case .ready: .peakEnergyReady
        case .low: .peakEnergyLow
        case .notReady: .peakEnergyNotReady
        case nil: .peakTextTertiary
        }
    }
}
