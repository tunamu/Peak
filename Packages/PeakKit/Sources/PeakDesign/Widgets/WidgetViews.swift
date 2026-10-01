import PeakCore
import SwiftUI
import WidgetKit

// The Home Screen widgets' views (C-16), here rather than in the extension so the app's Component Gallery can show
// them (debug builds) and they can be checked in both themes. The extension adds the configuration, the timeline and
// the water button's intent.
//
// Each keeps to the design's small dashboard tile and marks what should take the tint in accented and clear Home
// Screen styles (`widgetAccentable`).

public struct WaterWidgetView<AddButton: View>: View {
    let content: WidgetContent
    /// The button that adds water: the widget's `Button(intent:)`, a plain button elsewhere.
    let addButton: (Text) -> AddButton

    public init(content: WidgetContent, @ViewBuilder addButton: @escaping (Text) -> AddButton) {
        self.content = content
        self.addButton = addButton
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            HStack {
                Image(systemName: "drop.fill")
                    .font(.title2)
                    .foregroundStyle(.peakWater)
                    .widgetAccentable()
                    .accessibilityHidden(true)
                Spacer()
                Text("Water")
                    .font(.peakDetail)
                    .foregroundStyle(.peakTextSecondary)
            }
            Spacer(minLength: 0)
            Text(verbatim: "\(liters(content.waterMl)) / \(liters(content.waterGoalMl)) L")
                .font(.peakCardValue)
                .foregroundStyle(.peakTextPrimary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            ProgressView(value: min(1, Double(content.waterMl) / Double(max(1, content.waterGoalMl))))
                .tint(.peakWater)
                .widgetAccentable()
                .accessibilityHidden(true)
            addButton(Text("+\(content.quickWaterMl) ml"))
                .font(.peakRow.weight(.semibold))
                .buttonStyle(.borderedProminent)
                .tint(.peakWater)
                .widgetAccentable()
        }
        .accessibilityElement(children: .contain)
    }

    private func liters(_ milliliters: Int) -> String {
        (Double(milliliters) / 1_000).formatted(.number.precision(.fractionLength(1)))
    }
}

public struct StepsWidgetView: View {
    let content: WidgetContent

    public init(content: WidgetContent) {
        self.content = content
    }

    public var body: some View {
        VStack(spacing: Spacing.xSmall) {
            ZStack {
                ProgressRing(progress: progress, tint: .peakSteps, lineWidth: 10)
                    .widgetAccentable()
                VStack(spacing: 0) {
                    Image(systemName: "figure.walk")
                        .font(.peakRow)
                        .foregroundStyle(.peakSteps)
                        .widgetAccentable()
                        .accessibilityHidden(true)
                    Text(content.steps.map { $0.formatted() } ?? "–")
                        .font(.peakCardValue.monospacedDigit())
                        .foregroundStyle(.peakTextPrimary)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
                .padding(.horizontal, Spacing.small)
            }
            Text(content.steps == nil ? "Open Peak to update" : "Goal: \(content.stepGoal.formatted()) steps")
                .font(.peakMeta)
                .foregroundStyle(.peakTextSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .accessibilityElement(children: .combine)
    }

    private var progress: Double {
        guard let steps = content.steps else { return 0 }
        return min(1, Double(steps) / Double(max(1, content.stepGoal)))
    }
}

public struct TodayWidgetView: View {
    let content: WidgetContent

    public init(content: WidgetContent) {
        self.content = content
    }

    public var body: some View {
        HStack(alignment: .top, spacing: Spacing.medium) {
            VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                Text(label)
                    .font(.peakDetail)
                    .foregroundStyle(.peakTextSecondary)
                Text(verbatim: name)
                    .font(.peakEmphasis)
                    .foregroundStyle(.peakTextPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                detail
                    .font(.peakDetail)
                    .foregroundStyle(.peakTextTertiary)
                Spacer(minLength: 0)
                if let action {
                    Label(action, systemImage: actionSymbol)
                        .font(.peakRow.weight(.semibold))
                        .foregroundStyle(.peakTextPrimary)
                        .padding(.horizontal, Spacing.medium)
                        .padding(.vertical, Spacing.xSmall)
                        .background(.peakFillControl, in: .capsule)
                        .widgetAccentable()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            energy
        }
    }

    private var label: LocalizedStringKey {
        switch content.workout {
        case .completed: "Done Today"
        case .active: "Workout Running"
        default: "Today's Workout"
        }
    }

    private var name: String {
        switch content.workout {
        case .planned(let name, _, _), .active(let name, _, _), .completed(let name, _): name
        case .rest: String(localized: "Rest day")
        case .none: String(localized: "No routine yet")
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch content.workout {
        case .planned(_, let movements, let sets):
            Text("\(movements) Movements · \(sets) Sets")
        case .active(_, let startedAt, let isPaused):
            if isPaused {
                Text("Paused")
            } else {
                Text(timerInterval: startedAt...Date.distantFuture, countsDown: false)
                    .monospacedDigit()
            }
        case .completed(_, let duration):
            Text(Duration.seconds(duration).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated)))
        case .rest(let next?):
            Text("Next: \(next.formatted(.dateTime.weekday(.wide)))")
        case .rest(nil):
            Text("Nothing planned soon")
        case .none:
            Text("Set one up in Peak")
        }
    }

    private var action: LocalizedStringKey? {
        switch content.workout {
        case .planned: "Start"
        case .active: "Open"
        default: nil
        }
    }

    private var actionSymbol: String {
        if case .active = content.workout { "arrow.up.right" } else { "play.fill" }
    }

    private var energy: some View {
        VStack(spacing: Spacing.xxSmall) {
            Image(systemName: "bolt.fill")
                .font(.title)
                .foregroundStyle(energyColor)
                .widgetAccentable()
                .accessibilityHidden(true)
            Text("Energy")
                .font(.peakMeta)
                .foregroundStyle(.peakTextSecondary)
            Text(energyTitle)
                .font(.peakRow.weight(.semibold))
                .foregroundStyle(.peakTextPrimary)
                .multilineTextAlignment(.center)
        }
        .frame(width: 88)
        .accessibilityElement(children: .combine)
    }

    private var energyTitle: LocalizedStringKey {
        switch content.energy {
        case .ready: "Ready"
        case .low: "Low"
        case .notReady: "Not Ready"
        case nil: "–"
        }
    }

    private var energyColor: Color {
        switch content.energy {
        case .ready: .peakEnergyReady
        case .low: .peakEnergyLow
        case .notReady: .peakEnergyNotReady
        case nil: .peakTextTertiary
        }
    }

    /// Where a tap goes: start today's workout, open the running one, or Home (handled by the app, F9-04).
    public static func url(for workout: WidgetContent.Workout) -> URL? {
        switch workout {
        case .planned: PeakLink.startWorkout.url
        case .active: PeakLink.openWorkout.url
        default: PeakLink.home.url
        }
    }
}
