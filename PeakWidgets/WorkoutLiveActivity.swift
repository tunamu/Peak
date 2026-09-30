import ActivityKit
import AppIntents
import PeakCore
import PeakDesign
import SwiftUI
import WidgetKit

/// C-17: the running workout on the Lock Screen and in the Dynamic Island, with Pause/Resume. The app starts,
/// updates and ends it (`WorkoutActivity.sync`); the button's intent runs in the app's process.
struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            WorkoutActivityLockScreen(workoutName: context.attributes.workoutName, state: context.state) { label in
                Button(intent: TogglePauseIntent()) { label }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
            }
            .activityBackgroundTint(.peakCanvas)
            .activitySystemActionForegroundColor(.peakTextPrimary)
            .widgetURL(URL(string: "peak://workout/open"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(verbatim: context.attributes.workoutName).lineLimit(1)
                    } icon: {
                        Image(systemName: "figure.strengthtraining.traditional")
                    }
                    .font(.peakRow.weight(.semibold))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    WorkoutActivityClock(state: context.state)
                        .font(.peakRow.weight(.semibold))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: Spacing.medium) {
                        VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                            Text(verbatim: context.state.currentExercise)
                                .font(.peakDetail)
                                .lineLimit(1)
                            ProgressView(value: context.state.progress)
                                .tint(.peakTintPositive)
                        }
                        Button(intent: TogglePauseIntent()) {
                            Image(systemName: context.state.isPaused ? "play.fill" : "pause.fill")
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.circle)
                        .accessibilityLabel(context.state.isPaused ? Text("Resume") : Text("Pause"))
                    }
                }
            } compactLeading: {
                Image(systemName: "figure.strengthtraining.traditional")
                    .foregroundStyle(.peakTintPositive)
            } compactTrailing: {
                WorkoutActivityClock(state: context.state)
                    .frame(maxWidth: 56)
            } minimal: {
                Image(systemName: context.state.isPaused ? "pause.fill" : "figure.strengthtraining.traditional")
                    .foregroundStyle(.peakTintPositive)
            }
            .widgetURL(URL(string: "peak://workout/open"))
        }
    }
}

#Preview(
    "Lock Screen", as: .content, using: WorkoutActivityAttributes(sessionID: UUID(), workoutName: "Back & Triceps")
) {
    WorkoutLiveActivity()
} contentStates: {
    WorkoutActivityState.sample
}
