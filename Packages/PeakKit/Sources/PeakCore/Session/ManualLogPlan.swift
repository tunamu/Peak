import Foundation

/// When a workout entered after the fact (F11-13) starts and how long it lasts, before the user changes either.
///
/// The time and length come from the same workout's last session, else 18:00 for an hour. A workout never ends in
/// the future: on today it is moved back to end now.
public struct ManualLogPlan: Equatable, Sendable {
    public var start: Date
    public var duration: TimeInterval

    public static let fallbackHour = 18
    public static let fallbackDuration: TimeInterval = 60 * 60
    /// The duration picker's step; defaults are rounded to it.
    public static let step: TimeInterval = 5 * 60

    public init(start: Date, duration: TimeInterval) {
        self.start = start
        self.duration = duration
    }

    public var end: Date { start.addingTimeInterval(duration) }

    /// Whether the workout can be saved: it lasts a while and is over by `now`.
    public func isValid(now: Date) -> Bool {
        duration > 0 && end <= now
    }

    /// - Parameters:
    ///   - day: Any time on the day the workout is entered for.
    ///   - previousStart: When the same workout last started, for its time of day.
    ///   - previousDuration: How long it lasted then.
    public static func defaults(
        on day: Date,
        now: Date,
        previousStart: Date?,
        previousDuration: TimeInterval?,
        calendar: Calendar
    ) -> ManualLogPlan {
        let duration = previousDuration.map(rounded) ?? fallbackDuration
        let time =
            previousStart.map { calendar.dateComponents([.hour, .minute], from: $0) }
            ?? DateComponents(hour: fallbackHour, minute: 0)
        let dayStart = calendar.startOfDay(for: day)
        let start =
            calendar.date(
                bySettingHour: time.hour ?? fallbackHour, minute: time.minute ?? 0, second: 0, of: dayStart) ?? dayStart
        let plan = ManualLogPlan(start: start, duration: duration)
        guard plan.end > now else { return plan }
        // Today: end now, starting no earlier than midnight.
        let earliest = max(dayStart, now.addingTimeInterval(-duration))
        return ManualLogPlan(start: earliest, duration: now.timeIntervalSince(earliest))
    }

    /// To the picker's step, at least one step.
    private static func rounded(_ duration: TimeInterval) -> TimeInterval {
        max(step, (duration / step).rounded() * step)
    }
}
