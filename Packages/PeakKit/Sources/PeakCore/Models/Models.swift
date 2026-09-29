import Foundation

// The current schema's models under short names. When `SchemaV2` arrives, these point at it.
public typealias Exercise = SchemaV1.Exercise
public typealias WorkoutTemplate = SchemaV1.WorkoutTemplate
public typealias TemplateItem = SchemaV1.TemplateItem
public typealias Routine = SchemaV1.Routine
public typealias RoutineEntry = SchemaV1.RoutineEntry
public typealias WorkoutSession = SchemaV1.WorkoutSession
public typealias SessionExercise = SchemaV1.SessionExercise
public typealias SetEntry = SchemaV1.SetEntry
public typealias CardioSegment = SchemaV1.CardioSegment
public typealias WaterLog = SchemaV1.WaterLog

// Typed access to the enums stored as raw strings, and relationship arrays in their `order`.

extension Exercise {
    public var muscleGroup: MuscleGroup {
        get { MuscleGroup(rawValue: muscleGroupRaw) ?? .other }
        set { muscleGroupRaw = newValue.rawValue }
    }

    public var kind: ExerciseKind {
        get { ExerciseKind(rawValue: kindRaw) ?? .strength }
        set { kindRaw = newValue.rawValue }
    }

    public var equipment: Equipment {
        get { Equipment(rawValue: equipmentRaw) ?? .other }
        set { equipmentRaw = newValue.rawValue }
    }
}

extension WorkoutTemplate {
    public var kind: ExerciseKind {
        get { ExerciseKind(rawValue: kindRaw) ?? .strength }
        set { kindRaw = newValue.rawValue }
    }

    public var orderedItems: [TemplateItem] {
        (items ?? []).sorted { $0.order < $1.order }
    }
}

extension Routine {
    public var scheduleType: ScheduleType {
        get { ScheduleType(rawValue: scheduleTypeRaw) ?? .weekdays }
        set { scheduleTypeRaw = newValue.rawValue }
    }

    public var weekdays: [Weekday] {
        get { Weekday.days(in: weekdaysMask) }
        set { weekdaysMask = Weekday.mask(newValue) }
    }

    public var orderedEntries: [RoutineEntry] {
        (entries ?? []).sorted { $0.order < $1.order }
    }
}

extension WorkoutSession {
    public var status: SessionStatus {
        get { SessionStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }

    public var source: SessionSource {
        get { SessionSource(rawValue: sourceRaw) ?? .app }
        set { sourceRaw = newValue.rawValue }
    }

    public var orderedExercises: [SessionExercise] {
        (exercises ?? []).sorted { $0.order < $1.order }
    }

    /// Time spent working out: end (or `now` while running) − start − paused time.
    public func duration(now: Date = .now) -> TimeInterval {
        let end = endedAt ?? pausedAt ?? now
        return max(0, end.timeIntervalSince(startedAt) - pausedTotal)
    }
}

extension SessionExercise {
    public var orderedSets: [SetEntry] {
        (sets ?? []).sorted { $0.order < $1.order }
    }

    public var orderedSegments: [CardioSegment] {
        (segments ?? []).sorted { $0.order < $1.order }
    }
}

extension WaterLog {
    public var source: WaterSource {
        get { WaterSource(rawValue: sourceRaw) ?? .app }
        set { sourceRaw = newValue.rawValue }
    }
}
