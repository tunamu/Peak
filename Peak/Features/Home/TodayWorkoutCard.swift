import PeakDesign
import SwiftUI

/// C-03: one workout of the selected day, with the action that fits its state.
struct TodayWorkoutCard: View {
    enum State {
        /// Planned and not started: Start.
        case planned(name: String, movements: Int, sets: Int)
        /// Running or paused: Pause or Resume, and the time so far. `timerStart` is the start moved forward by the
        /// paused time; `pausedElapsed` is set while paused.
        case active(name: String, timerStart: Date, pausedElapsed: TimeInterval? = nil)
        /// Done: duration and movements done.
        case completed(name: String, duration: TimeInterval, movementsDone: Int, movements: Int)
        /// Nothing planned; `next` is the next planned day.
        case restDay(next: Date?)
        /// A past day without a workout.
        case noWorkout
        /// No active routine: a way to Settings.
        case noRoutine
    }

    /// "Today's Workout", or the day's date on other days.
    let label: Text
    let state: State
    /// The button's action; without one (days other than today) the card has no button.
    let action: (() -> Void)?
    /// Tapping the rest of the card: opens the running workout.
    var open: (() -> Void)?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // At accessibility text sizes the button goes under the text, so words are not broken (F10-02).
        let layout =
            dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.medium))
            : AnyLayout(HStackLayout(spacing: Spacing.medium))
        layout {
            if let open {
                Button(action: open) { text.contentShape(.rect) }
                    .buttonStyle(.plain)
                    .accessibilityHint(Text("Opens the workout"))
            } else {
                text
            }

            trailing
        }
        .glassCard()
    }

    private var text: some View {
        VStack(alignment: .leading, spacing: Spacing.xxSmall) {
            label
                .font(.peakCardLabel)
                .foregroundStyle(.peakTextSecondary)
            title
                .font(.peakEmphasis)
                .foregroundStyle(.peakTextPrimary)
            subtitle
                .font(.peakDetail)
                .monospacedDigit()
                .foregroundStyle(.peakTextTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: Parts

    private var title: Text {
        switch state {
        case .planned(let name, _, _), .active(let name, _, _), .completed(let name, _, _, _): Text(verbatim: name)
        case .restDay: Text("Rest day")
        case .noWorkout: Text("No workout")
        case .noRoutine: Text("No routine yet")
        }
    }

    private var subtitle: Text? {
        switch state {
        case .planned(_, let movements, let sets):
            // A walk has no sets: "1 Movement" alone.
            var parts = [String(localized: "\(movements) Movements")]
            if sets > 0 {
                parts.append(String(localized: "\(sets) Sets"))
            }
            return Text(verbatim: parts.joined(separator: " · "))
        case .active(_, let timerStart, let pausedElapsed):
            return SessionTimerText.text(timerStart: timerStart, pausedElapsed: pausedElapsed)
        case .completed(_, let duration, let done, let movements):
            // Imported sessions have no duration: just the movements.
            guard duration >= 60 else { return Text(verbatim: "\(done)/\(movements)") }
            let time = Duration.seconds(duration).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
            return Text(verbatim: "\(time) · \(done)/\(movements)")
        case .restDay(let next?):
            let date = next.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
            return Text("Next workout: \(date)")
        case .noRoutine:
            return Text("Plan your week with a routine.")
        case .restDay(nil), .noWorkout:
            return nil
        }
    }

    @ViewBuilder
    private var trailing: some View {
        switch state {
        case .planned:
            if let action { button("Start", systemImage: "play.fill", action: action) }
        case .active(_, _, nil):
            if let action { button("Pause", systemImage: "pause.fill", action: action) }
        case .active:
            if let action { button("Resume", systemImage: "play.fill", action: action) }
        case .noRoutine:
            if let action { button("Set Up", systemImage: "plus", action: action) }
        case .completed:
            VStack(spacing: Spacing.xxSmall) {
                Image(systemName: "checkmark")
                    .font(.title2)
                    .foregroundStyle(.peakEnergyReady)
                    .accessibilityHidden(true)
                Text("Completed")
                    .font(.peakDetail)
                    .foregroundStyle(.peakTextSecondary)
            }
        case .restDay, .noWorkout:
            EmptyView()
        }
    }

    /// The design's 102 × 68 glass button: symbol above the title.
    private func button(_ title: LocalizedStringKey, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .accessibilityHidden(true)
                // Sized for the widest title, so switching between Start, Pause and Resume never resizes the button.
                ZStack {
                    Text("Start").hidden()
                    Text("Pause").hidden()
                    Text("Resume").hidden()
                    Text(title)
                }
            }
            .padding(.vertical, Spacing.xSmall)
        }
        .buttonStyle(.peakGlass)
    }
}

#if DEBUG
    #Preview("All states") {
        let label = Text("Today's Workout")
        ScrollView {
            VStack(spacing: Spacing.medium) {
                TodayWorkoutCard(label: label, state: .planned(name: "Chest & Biceps", movements: 5, sets: 13)) {}
                TodayWorkoutCard(
                    label: label, state: .active(name: "Chest & Biceps", timerStart: .now.addingTimeInterval(-751))
                ) {}
                TodayWorkoutCard(
                    label: label,
                    state: .completed(name: "Chest & Biceps", duration: 42 * 60, movementsDone: 5, movements: 5)
                ) {}
                TodayWorkoutCard(label: label, state: .restDay(next: .now.addingTimeInterval(86_400)), action: nil)
                TodayWorkoutCard(label: label, state: .noRoutine) {}
                TodayWorkoutCard(label: Text(verbatim: "Mon, 28 Sep"), state: .noWorkout, action: nil)
                // Several routines on one day: cards stack.
                TodayWorkoutCard(label: label, state: .planned(name: "Incline Walk", movements: 1, sets: 0)) {}
            }
            .padding()
        }
        .background(.peakCanvas)
    }
#endif
