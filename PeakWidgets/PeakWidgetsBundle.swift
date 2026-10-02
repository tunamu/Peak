import SwiftUI
import WidgetKit

/// Peak's widgets (C-16): water with a one-tap add (W-01), steps (W-02), today's workout (W-03), energy, the
/// dashboard and the week (F11-11), each on the Home Screen and, where it fits, the Lock Screen; Control Center's
/// Log Water and Start Workout; and the running workout's Live Activity (C-17).
@main
struct PeakWidgetsBundle: WidgetBundle {
    var body: some Widget {
        WaterWidget()
        StepsWidget()
        TodayWidget()
        EnergyWidget()
        DashboardWidget()
        WeekWidget()
        LogWaterControl()
        StartWorkoutControl()
        WorkoutLiveActivity()
    }
}
