import AppIntents
import PeakCore
import PeakDesign
import SwiftUI
import WidgetKit

// C-16: the widgets' configurations. The views are in PeakDesign (WidgetViews.swift); the background is left to
// the system in accented and clear Home Screen styles (`containerBackground`).

/// W-01: today's water against the goal, with a button that adds the quick amount.
struct WaterWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Water", provider: PeakTimeline()) { entry in
            WaterWidgetView(content: entry.content) { label in
                Button(intent: AddWaterIntent()) { label.frame(maxWidth: .infinity) }
            }
            .containerBackground(for: .widget) { Color.peakCanvas }
        }
        .configurationDisplayName("Water")
        .description("Today's water, and a button to log more.")
        .supportedFamilies([.systemSmall])
    }
}

/// W-02: today's steps as a ring against the goal.
struct StepsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Steps", provider: PeakTimeline()) { entry in
            StepsWidgetView(content: entry.content)
                .containerBackground(for: .widget) { Color.peakCanvas }
                .widgetURL(URL(string: "peak://home"))
        }
        .configurationDisplayName("Steps")
        .description("Today's steps against your goal.")
        .supportedFamilies([.systemSmall])
    }
}

/// W-03: today's workout and Energy Level; tapping starts or opens the workout.
struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Today", provider: PeakTimeline()) { entry in
            TodayWidgetView(content: entry.content)
                .containerBackground(for: .widget) { Color.peakCanvas }
                .widgetURL(TodayWidgetView.url(for: entry.content.workout))
        }
        .configurationDisplayName("Today's Workout")
        .description("Today's workout and your Energy Level.")
        .supportedFamilies([.systemMedium])
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
