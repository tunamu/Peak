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
    @Environment(\.modelContext) private var modelContext
    @Environment(\.calendar) private var calendar

    @Query(sort: \Routine.sortIndex) private var routines: [Routine]
    @Query(sort: \WorkoutSession.startedAt) private var sessions: [WorkoutSession]

    func body(content: Content) -> some View {
        if #available(iOS 26.1, *) {
            let pending = pendingWorkout
            content.tabViewBottomAccessory(isEnabled: pending != nil) {
                if let pending {
                    AccessoryContent(workout: pending) { perform(pending) }
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
        case .planned(let template, let routine): launcher.start(template, routine: routine, in: modelContext)
        case .active(let session): launcher.resume(session)
        case .completed: break
        }
    }
}

private struct AccessoryContent: View {
    let workout: DayWorkout
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xSmall) {
                switch workout {
                case .active(let session):
                    Image(systemName: "figure.strengthtraining.traditional")
                        .accessibilityHidden(true)
                    Text(verbatim: session.title)
                        .lineLimit(1)
                    Text(verbatim: "·")
                        .accessibilityHidden(true)
                    Text(
                        timerInterval: session.startedAt.addingTimeInterval(session.pausedTotal)...Date.distantFuture,
                        countsDown: false
                    )
                    .monospacedDigit()
                default:
                    Image(systemName: "play.fill")
                        .accessibilityHidden(true)
                    Text("Start Today's Workout")
                        .lineLimit(1)
                }
            }
            .font(.peakRow)
            .foregroundStyle(.peakTextPrimary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
