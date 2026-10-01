import AppIntents
import PeakCore
import SwiftData
import WidgetKit

/// Shortcuts and Siri (F9-04). Water is logged without opening Peak; a workout opens it.
struct PeakShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogWaterIntent(),
            phrases: [
                "Log water in \(.applicationName)",
                "Add water in \(.applicationName)",
            ],
            shortTitle: "Log Water",
            systemImageName: "drop.fill"
        )
        AppShortcut(
            intent: StartTodaysWorkoutIntent(),
            phrases: [
                "Start today's workout in \(.applicationName)",
                "Start my workout in \(.applicationName)",
            ],
            shortTitle: "Start Today's Workout",
            systemImageName: "figure.strengthtraining.traditional"
        )
    }
}

/// Adds water to today: the given amount, or the water sheet's first quick amount. Apple Health gets the day's total
/// the next time Peak opens, as with the widget's button.
struct LogWaterIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Water"
    static let description = IntentDescription("Adds water to today. Without an amount, your quick amount.")

    @Parameter(title: "Amount (ml)", inclusiveRange: (1, 2_000))
    var amountMl: Int?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // The app's container when Peak is running; otherwise the shared store, without iCloud sync (the app uploads
        // the change the next time it syncs).
        let container = try WorkoutActivity.container ?? PeakStore.makeContainer(.appGroup)
        let settings = SettingsStore(defaults: SettingsStore.appGroupDefaults())
        let amount = amountMl ?? settings.quickWaterAmounts.first ?? 200
        let total = try WaterRepository(context: container.mainContext).add(amount, source: .intent)
        try container.mainContext.save()
        WidgetCenter.shared.reloadAllTimelines()
        let logged = Formatting.waterAmount(amount)
        let today = Formatting.liters(total, of: settings.waterGoalMl)
        return .result(dialog: "Logged \(logged). Today: \(today).")
    }
}

/// Opens Peak and starts today's next workout, or reopens the one already running; on a rest day it opens Home.
struct StartTodaysWorkoutIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Today's Workout"
    static let description = IntentDescription("Opens Peak and starts today's next workout, or the running one.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        LinkRouter.shared.pending = .startWorkout
        return .result()
    }
}
