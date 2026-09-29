import PeakCore
import PeakDesign
import SwiftUI

/// S-02: the daily step goal, opened from Settings and from the Home step card.
struct StepGoalSheet: View {
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        ValuePickerSheet(
            titles: .init("Daily Step Goal", pickerLabel: "New Goal", reset: "Reset", update: "Update"),
            current: settings.stepGoal,
            defaultValue: SettingsStore.Defaults.stepGoal,
            options: Array(stride(from: 1_000, through: 50_000, by: 500)),
            format: { $0.formatted() },
            onSave: { settings.stepGoal = $0 }
        )
    }
}
