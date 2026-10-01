import AppIntents
import PeakCore
import SwiftData
import WidgetKit

/// W-01's button: adds the water sheet's first amount (200 ml by default) to today, right in the widget. The app
/// copies the day's total to Apple Health when it next opens.
struct AddWaterIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Water"
    static let description = IntentDescription("Adds your quick water amount to today.")
    /// Only the widget's button: Shortcuts offers the app's Log Water, which takes an amount.
    static let isDiscoverable = false

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let container = SharedStore.container else { return .result() }
        let settings = SettingsStore(defaults: SettingsStore.appGroupDefaults())
        let amount = settings.quickWaterAmounts.first ?? 200
        _ = try WaterRepository(context: container.mainContext).add(amount, source: .widget)
        try container.mainContext.save()
        return .result()
    }
}
