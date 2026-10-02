import PeakCore
import SwiftUI
import WidgetKit

// The accessory families exist on iOS only; the package also builds for the Mac host tests.
#if os(iOS)

    // F11-11: the Lock Screen widgets (and the watch-style accessory families). iOS draws them in one tint, so they use
    // gauges and symbols rather than colors.

    /// Water as a ring against the goal, liters in the middle.
    public struct WaterAccessoryView: View {
        let content: WidgetContent

        public init(content: WidgetContent) {
            self.content = content
        }

        public var body: some View {
            Gauge(value: min(1, Double(content.waterMl) / Double(max(1, content.waterGoalMl)))) {
                Image(systemName: "drop.fill")
            } currentValueLabel: {
                Text(verbatim: (Double(content.waterMl) / 1_000).formatted(.number.precision(.fractionLength(1))))
            }
            .gaugeStyle(.accessoryCircular)
            .accessibilityLabel(Text("Water"))
            .accessibilityValue(Text(verbatim: "\(content.waterMl.formatted()) ml"))
        }
    }

    /// Steps as a ring against the goal, thousands in the middle ("7.6K").
    public struct StepsAccessoryView: View {
        let content: WidgetContent

        public init(content: WidgetContent) {
            self.content = content
        }

        public var body: some View {
            Gauge(value: min(1, Double(content.steps ?? 0) / Double(max(1, content.stepGoal)))) {
                Image(systemName: "figure.walk")
            } currentValueLabel: {
                Text(verbatim: content.steps.map { $0.formatted(.number.notation(.compactName)) } ?? "–")
            }
            .gaugeStyle(.accessoryCircular)
            .accessibilityLabel(Text("Steps"))
            .accessibilityValue(Text(verbatim: content.steps.map { $0.formatted() } ?? "–"))
        }
    }

    /// Energy Level: the bolt, and a ring filled by level (full when Ready).
    public struct EnergyAccessoryView: View {
        let content: WidgetContent

        public init(content: WidgetContent) {
            self.content = content
        }

        public var body: some View {
            Gauge(value: level) {
                Text("Energy")
            } currentValueLabel: {
                Image(systemName: "bolt.fill")
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .accessibilityLabel(Text("Energy"))
            .accessibilityValue(EnergyStyle.title(content.energy))
        }

        private var level: Double {
            switch content.energy {
            case .ready: 1
            case .low: 0.5
            case .notReady: 0.15
            case nil: 0
            }
        }
    }

    /// Today's workout on the Lock Screen: what it is and how far it is, or the next workout day.
    public struct TodayAccessoryView: View {
        let content: WidgetContent
        /// The family to draw, for the Component Gallery; in a widget, the one WidgetKit gives.
        let shownFamily: WidgetFamily?

        @Environment(\.widgetFamily) private var family

        public init(content: WidgetContent, family: WidgetFamily? = nil) {
            self.content = content
            shownFamily = family
        }

        public var body: some View {
            switch shownFamily ?? family {
            case .accessoryInline:
                Label {
                    Text(verbatim: inline)
                } icon: {
                    Image(systemName: "dumbbell.fill")
                }
            default:
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: Spacing.xxSmall) {
                        Image(systemName: "dumbbell.fill")
                            .accessibilityHidden(true)
                        Text(label)
                    }
                    .font(.peakMeta.weight(.semibold))
                    .widgetAccentable()
                    Text(verbatim: name)
                        .font(.peakCardValue)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    detail
                        .font(.peakDetail)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
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

        /// "Back & Triceps", "Back & Triceps ✓", or "Rest day · Wednesday".
        private var inline: String {
            switch content.workout {
            case .planned(let name, _, _), .active(let name, _, _): name
            case .completed(let name, _): "\(name) ✓"
            case .rest(let next?): "\(String(localized: "Rest day")) · \(next.formatted(.dateTime.weekday(.wide)))"
            case .rest(nil): String(localized: "Rest day")
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
    }
#endif
