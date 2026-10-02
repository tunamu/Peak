import Foundation

// Enums stored in SwiftData as their `String` raw value (CloudKit rule, docs/DATA_MODEL.md). Raw values are part of
// the stored data and the JSON format: never rename one, add a new case instead.

public enum MuscleGroup: String, CaseIterable, Codable, Sendable {
    case chest, back, shoulders, biceps, triceps, legs, core, cardio, other
}

public enum ExerciseKind: String, CaseIterable, Codable, Sendable {
    case strength, cardio
}

public enum Equipment: String, CaseIterable, Codable, Sendable {
    case dumbbell, barbell, machine, smith, cable, bodyweight, other
}

public enum ScheduleType: String, CaseIterable, Codable, Sendable {
    /// Fixed weekdays ("Every Week Day").
    case weekdays
    /// Every N days after the last workout ("Day After").
    case interval
}

public enum SessionStatus: String, CaseIterable, Codable, Sendable {
    case active, paused, completed, discarded
    /// Being entered after the fact (F11-13): not running, not yet in the history. Never exported.
    case logging
}

public enum SessionSource: String, CaseIterable, Codable, Sendable {
    case app, importJSON, importSheet
}

public enum WaterSource: String, CaseIterable, Codable, Sendable {
    case app, widget, intent
}

/// A weekday with its bit in `Routine.weekdaysMask` (bit 0 = Monday … bit 6 = Sunday).
public enum Weekday: Int, CaseIterable, Codable, Sendable {
    case monday, tuesday, wednesday, thursday, friday, saturday, sunday

    public var bit: Int { 1 << rawValue }

    /// The weekday of `date` in `calendar`.
    public init(of date: Date, calendar: Calendar = .current) {
        // Calendar weekdays are 1 = Sunday … 7 = Saturday.
        let sundayFirst = calendar.component(.weekday, from: date)
        self = Weekday(rawValue: (sundayFirst + 5) % 7) ?? .monday
    }

    public static func mask(_ days: some Sequence<Weekday>) -> Int {
        days.reduce(0) { $0 | $1.bit }
    }

    public static func days(in mask: Int) -> [Weekday] {
        allCases.filter { mask & $0.bit != 0 }
    }
}
