import PeakCore
import PeakDesign
import SwiftData
import SwiftUI

/// C-13: the bar above the tab bar, like Music's mini player. "Start Today's Workout" while today's workout waits,
/// the running workout and its time while one runs, and hidden otherwise.
///
/// Hiding needs iOS 26.1 (`tabViewBottomAccessory(isEnabled:)`); on iOS 26.0 an empty accessory would still show its
/// glass, so there the bar is left out and Home's Start button does the job.
struct WorkoutAccessory: ViewModifier {
    @Environment(WorkoutLauncher.self) private var launcher
    @Environment(SettingsStore.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @Environment(\.calendar) private var calendar

    @Query(sort: \Routine.sortIndex) private var routines: [Routine]
    @Query(sort: \WorkoutSession.startedAt) private var sessions: [WorkoutSession]

    func body(content: Content) -> some View {
        accessory(content)
    }

    @ViewBuilder
    private func accessory(_ content: Content) -> some View {
        if #available(iOS 26.1, *) {
            let pending = pendingWorkout
            content.tabViewBottomAccessory(isEnabled: pending != nil) {
                if let pending {
                    AccessoryContent(workout: pending, action: { perform(pending) }, togglePause: togglePause)
                }
            }
        } else {
            content
        }
    }

    private var pendingWorkout: DayWorkout? {
        DayPlanner(calendar: calendar)
            .overview(of: .now, today: .now, routines: routines, sessions: sessions)
            .firstPending
    }

    private func perform(_ workout: DayWorkout) {
        switch workout {
        case .planned(let template, let routine):
            launcher.start(template, routine: routine, rule: settings.progressionRule, in: modelContext)
        case .active(let session): launcher.resume(session)
        case .completed: break
        }
    }

    private func togglePause(_ session: WorkoutSession) {
        let controller = WorkoutSessionController(session: session, context: modelContext)
        if session.status == .paused {
            try? controller.resume()
        } else {
            try? controller.pause()
        }
    }
}

private struct AccessoryContent: View {
    let workout: DayWorkout
    let action: () -> Void
    let togglePause: (WorkoutSession) -> Void

    var body: some View {
        Group {
            switch workout {
            case .active(let session): running(session)
            default: start
            }
        }
        .font(.peakRow)
        .foregroundStyle(.peakTextPrimary)
        // The bar above the tab bar has a fixed height: capped like the tab bar, with the large content viewer
        // (F10-02). The identifier lets the accessibility audit know the cap is meant.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityShowsLargeContentViewer()
        .accessibilityIdentifier("peak.capped.accessory")
    }

    private var start: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xSmall) {
                Image(systemName: "play.fill")
                    .accessibilityHidden(true)
                Text("Start Today's Workout")
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    /// Like Music's mini player: the workout on the left opens it, Pause/Resume sits on the right.
    private func running(_ session: WorkoutSession) -> some View {
        let isPaused = session.status == .paused
        return HStack(spacing: 0) {
            Button(action: action) {
                HStack(spacing: Spacing.xSmall) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .accessibilityHidden(true)
                    Text(verbatim: session.title)
                        .lineLimit(1)
                    Spacer(minLength: Spacing.xSmall)
                    SessionTimerText(session: session)
                        .monospacedDigit()
                        .foregroundStyle(isPaused ? .peakTextSecondary : .peakTextPrimary)
                }
                .padding(.leading, Spacing.medium)
                .frame(maxHeight: .infinity)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            Button {
                togglePause(session)
            } label: {
                Image(systemName: isPaused ? "play.fill" : "pause.fill")
                    .frame(width: Metrics.minTouchTarget, height: Metrics.minTouchTarget)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPaused ? "Resume" : "Pause")
            .padding(.trailing, Spacing.xxSmall)
        }
    }
}

/// D-23: a firm tap when a workout begins and a light one on pause and resume, wherever they come from (Home, the bar
/// above the tab bar, the workout sheet, a shortcut, a link). An invisible view beside the tab view: as a modifier on
/// the tab view itself, its feedback kept the tab selection from being set at launch.
struct WorkoutHaptics: View {
    @Query(sort: \WorkoutSession.startedAt) private var sessions: [WorkoutSession]

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .peakHaptic(trigger: runningStatus) { old, new in
                switch (old, new) {
                case (nil, .active?): .workoutStarted
                case (.active?, .paused?), (.paused?, .active?): .pauseToggled
                default: nil
                }
            }
    }

    private var runningStatus: SessionStatus? {
        sessions.last { $0.status == .active || $0.status == .paused }?.status
    }
}
