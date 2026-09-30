import SwiftUI
import WidgetKit

/// Peak's Home Screen widgets (C-16): water with a one-tap add (W-01), steps (W-02) and today's workout (W-03), and
/// the running workout's Live Activity (C-17).
@main
struct PeakWidgetsBundle: WidgetBundle {
    var body: some Widget {
        WaterWidget()
        StepsWidget()
        TodayWidget()
        WorkoutLiveActivity()
    }
}
