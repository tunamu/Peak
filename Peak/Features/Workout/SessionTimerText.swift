import PeakCore
import SwiftUI

/// A workout's elapsed time: ticking while it runs, frozen while it is paused.
struct SessionTimerText: View {
    /// When the timer would have started had there been no pauses.
    let timerStart: Date
    /// The elapsed time to show while paused; `nil` while running.
    let pausedElapsed: TimeInterval?

    init(timerStart: Date, pausedElapsed: TimeInterval?) {
        self.timerStart = timerStart
        self.pausedElapsed = pausedElapsed
    }

    init(session: WorkoutSession) {
        self.init(
            timerStart: session.startedAt.addingTimeInterval(session.pausedTotal),
            pausedElapsed: session.status == .paused ? session.duration() : nil
        )
    }

    var body: some View {
        Self.text(timerStart: timerStart, pausedElapsed: pausedElapsed)
    }

    /// The same as a `Text`, for places that compose texts.
    static func text(timerStart: Date, pausedElapsed: TimeInterval?) -> Text {
        guard let pausedElapsed else {
            return Text(timerInterval: timerStart...Date.distantFuture, countsDown: false)
        }
        // Same shape as the running timer: 12:31, or 1:02:03 past an hour.
        let pattern: Duration.TimeFormatStyle.Pattern = pausedElapsed >= 3_600 ? .hourMinuteSecond : .minuteSecond
        return Text(verbatim: Duration.seconds(pausedElapsed.rounded(.down)).formatted(.time(pattern: pattern)))
    }
}
