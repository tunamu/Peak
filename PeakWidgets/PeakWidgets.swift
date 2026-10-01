import AppIntents
import PeakCore
import PeakDesign
import SwiftUI
import WidgetKit

// C-16: the widgets' configurations. The views are in PeakDesign (WidgetViews.swift, GlanceWidgetViews.swift,
// AccessoryWidgetViews.swift); the background is left to the system in accented and clear Home Screen styles
// (`containerBackground`), and the Lock Screen families draw on the system's own.

/// W-01: today's water against the goal, with a button that adds the quick amount; a ring on the Lock Screen.
struct WaterWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Water", provider: PeakTimeline()) { entry in
            FamilyView(entry: entry) { content in
                WaterWidgetView(content: content) { label in
                    Button(intent: AddWaterIntent()) { label.frame(maxWidth: .infinity) }
                }
            } accessory: { content in
                WaterAccessoryView(content: content)
            }
        }
        .configurationDisplayName("Water")
        .description("Today's water, and a button to log more.")
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}

/// W-02: today's steps as a ring against the goal, on the Home Screen and the Lock Screen.
struct StepsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Steps", provider: PeakTimeline()) { entry in
            FamilyView(entry: entry) { content in
                StepsWidgetView(content: content)
            } accessory: { content in
                StepsAccessoryView(content: content)
            }
            .widgetURL(PeakLink.home.url)
        }
        .configurationDisplayName("Steps")
        .description("Today's steps against your goal.")
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}

/// W-03: today's workout and Energy Level; tapping starts or opens the workout. On the Lock Screen, the workout in a
/// line or a few.
struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Today", provider: PeakTimeline()) { entry in
            FamilyView(entry: entry) { content in
                TodayWidgetView(content: content)
            } accessory: { content in
                TodayAccessoryView(content: content)
            }
            .widgetURL(TodayWidgetView.url(for: entry.content.workout))
        }
        .configurationDisplayName("Today's Workout")
        .description("Today's workout and your Energy Level.")
        .supportedFamilies([.systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

/// F11-11: Energy Level on its own.
struct EnergyWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Energy", provider: PeakTimeline()) { entry in
            FamilyView(entry: entry) { content in
                EnergyWidgetView(content: content)
            } accessory: { content in
                EnergyAccessoryView(content: content)
            }
            .widgetURL(PeakLink.home.url)
        }
        .configurationDisplayName("Energy")
        .description("Your Energy Level and what it means for today.")
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}

/// F11-11: steps, water (with its button) and energy in one.
struct DashboardWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Dashboard", provider: PeakTimeline()) { entry in
            DashboardWidgetView(content: entry.content) { label in
                Button(intent: AddWaterIntent()) { label.frame(maxWidth: .infinity) }
            }
            .containerBackground(for: .widget) { Color.peakCanvas }
            .widgetURL(PeakLink.home.url)
        }
        .configurationDisplayName("Dashboard")
        .description("Steps, water and energy at a glance.")
        .supportedFamilies([.systemMedium])
    }
}

/// F11-11: the week's workout days, today's workout and the week's totals.
struct WeekWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Week", provider: PeakTimeline()) { entry in
            WeekWidgetView(content: entry.content)
                .containerBackground(for: .widget) { Color.peakCanvas }
                .widgetURL(TodayWidgetView.url(for: entry.content.workout))
        }
        .configurationDisplayName("This Week")
        .description("Your workout days, today's workout and the week so far.")
        .supportedFamilies([.systemLarge])
    }
}

/// The Home Screen view on Peak's canvas, or the Lock Screen view on the system's background.
private struct FamilyView<Home: View, Accessory: View>: View {
    let entry: PeakEntry
    @ViewBuilder let home: (WidgetContent) -> Home
    @ViewBuilder let accessory: (WidgetContent) -> Accessory

    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular, .accessoryRectangular, .accessoryInline:
            accessory(entry.content)
                .containerBackground(for: .widget) { AccessoryWidgetBackground() }
        default:
            home(entry.content)
                .containerBackground(for: .widget) { Color.peakCanvas }
        }
    }
}

// MARK: - Controls

/// F11-11: Control Center (and the Lock Screen and Action button): log the quick water amount without opening Peak.
struct LogWaterControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "LogWaterControl") {
            ControlWidgetButton(action: AddWaterIntent()) {
                Label("Log Water", systemImage: "drop.fill")
            }
        }
        .displayName("Log Water")
        .description("Adds your quick water amount to today.")
    }
}

/// F11-11: opens Peak on today's workout, as the Start button does.
struct StartWorkoutControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "StartWorkoutControl") {
            ControlWidgetButton(action: OpenURLIntent(PeakLink.startWorkout.url)) {
                Label("Start Workout", systemImage: "figure.strengthtraining.traditional")
            }
        }
        .displayName("Start Workout")
        .description("Opens Peak on today's workout.")
    }
}

// MARK: - Previews

#Preview("Water", as: .systemSmall) {
    WaterWidget()
} timeline: {
    PeakEntry(date: .now, content: .sample)
}

#Preview("Steps", as: .systemSmall) {
    StepsWidget()
} timeline: {
    PeakEntry(date: .now, content: .sample)
}

#Preview("Today", as: .systemMedium) {
    TodayWidget()
} timeline: {
    PeakEntry(date: .now, content: .sample)
}

#Preview("Dashboard", as: .systemMedium) {
    DashboardWidget()
} timeline: {
    PeakEntry(date: .now, content: .sample)
}

#Preview("Week", as: .systemLarge) {
    WeekWidget()
} timeline: {
    PeakEntry(date: .now, content: .sample)
}

#Preview("Today, Lock Screen", as: .accessoryRectangular) {
    TodayWidget()
} timeline: {
    PeakEntry(date: .now, content: .sample)
}
