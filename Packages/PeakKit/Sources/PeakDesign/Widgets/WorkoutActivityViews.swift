import PeakCore
import SwiftUI

// The workout's Live Activity (C-17): the Lock Screen banner and the Dynamic Island's pieces. Here rather than in the
// extension so the Component Gallery can show them; the extension adds the Pause/Resume intent.

/// The Lock Screen: workout and current movement, set progress, the clock and Pause/Resume.
public struct WorkoutActivityLockScreen<Toggle: View>: View {
    let workoutName: String
    let state: WorkoutActivityState
    /// The Pause/Resume button, given its label: `Button(intent:)` in the widget, a plain button elsewhere.
    let toggle: (Image) -> Toggle

    public init(workoutName: String, state: WorkoutActivityState, @ViewBuilder toggle: @escaping (Image) -> Toggle) {
        self.workoutName = workoutName
        self.state = state
        self.toggle = toggle
    }

    public var body: some View {
        HStack(spacing: Spacing.medium) {
            VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                Text(verbatim: workoutName)
                    .font(.peakCardValue)
                    .foregroundStyle(.peakTextPrimary)
                    .lineLimit(1)
                Text(verbatim: state.currentExercise)
                    .font(.peakDetail)
                    .foregroundStyle(.peakTextSecondary)
                    .lineLimit(1)
                ProgressView(value: state.progress)
                    .tint(.peakTintPositive)
                Text("\(state.completedSets) of \(state.totalSets) sets")
                    .font(.peakMeta)
                    .foregroundStyle(.peakTextTertiary)
            }
            VStack(alignment: .trailing, spacing: Spacing.xSmall) {
                WorkoutActivityClock(state: state)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.peakTextPrimary)
                toggle(Image(systemName: state.isPaused ? "play.fill" : "pause.fill"))
                    .font(.peakCardValue)
                    .foregroundStyle(.peakTextPrimary)
                    .accessibilityLabel(state.isPaused ? Text("Resume") : Text("Pause"))
            }
        }
        .padding(Spacing.medium)
    }
}

/// The clock: counting while running, standing still while paused.
public struct WorkoutActivityClock: View {
    let state: WorkoutActivityState

    public init(state: WorkoutActivityState) {
        self.state = state
    }

    public var body: some View {
        Group {
            if let paused = state.pausedElapsed {
                Text(
                    Duration.seconds(paused.rounded(.down)).formatted(
                        .time(pattern: paused >= 3_600 ? .hourMinuteSecond : .minuteSecond)))
            } else {
                Text(timerInterval: state.timerAnchor...Date.distantFuture, countsDown: false)
            }
        }
        .monospacedDigit()
        .multilineTextAlignment(.trailing)
    }
}
