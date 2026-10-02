import Foundation

// Optional booleans are deliberate here: a missing field means "use the default" (`completed` defaults to true).
// swiftlint:disable discouraged_optional_boolean

/// Peak JSON v1: the file format for import and export (docs/IMPORT_FORMAT.md). The machine-readable schema is
/// `docs/schema/peak-workout-data.v1.schema.json`; the two must change together (`PeakJSONSchemaTests` checks).
///
/// Only `sessions` is required, so a hand-written or LLM-generated file can be as small as a list of workouts.
/// Everything else is optional and filled with the app's defaults on import. Ids are free strings ("chest-biceps" or a
/// UUID) that only link records inside one file.
public struct PeakExportV1: Codable, Equatable, Sendable {
    public static let schemaName = "peak.workout-data"
    public static let schemaVersion = 1

    public var schema: String?
    public var schemaVersion: Int?
    public var exportedAt: Date?
    public var units: Units?
    public var exercises: [Exercise]?
    public var workoutTemplates: [WorkoutTemplate]?
    public var routines: [Routine]?
    public var sessions: [Session]
    public var waterLogs: [WaterLog]?
    public var settings: Settings?

    public init(
        schema: String? = Self.schemaName, schemaVersion: Int? = Self.schemaVersion, exportedAt: Date? = nil,
        units: Units? = nil, exercises: [Exercise]? = nil, workoutTemplates: [WorkoutTemplate]? = nil,
        routines: [Routine]? = nil, sessions: [Session], waterLogs: [WaterLog]? = nil, settings: Settings? = nil
    ) {
        self.schema = schema
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.units = units
        self.exercises = exercises
        self.workoutTemplates = workoutTemplates
        self.routines = routines
        self.sessions = sessions
        self.waterLogs = waterLogs
        self.settings = settings
    }
}

extension PeakExportV1 {
    public enum WeightUnit: String, Codable, Sendable {
        case kg, lb
    }

    /// The unit of every `weight` and `targetWeight` in the file. Fields named `…Kg` are always kilograms.
    public struct Units: Codable, Equatable, Sendable {
        public var weight: WeightUnit

        public init(weight: WeightUnit) {
            self.weight = weight
        }
    }

    public struct Exercise: Codable, Equatable, Sendable {
        public var id: String?
        public var name: String
        public var muscleGroup: MuscleGroup?
        public var kind: ExerciseKind?
        public var equipment: Equipment?
        public var incrementKg: Double?
        /// How the movement is set up (F11-12).
        public var note: String?
        /// The movement's own progressive overload (F11-10).
        public var overload: Overload?
        public var archived: Bool?
        public var createdAt: Date?

        public init(
            id: String? = nil, name: String, muscleGroup: MuscleGroup? = nil, kind: ExerciseKind? = nil,
            equipment: Equipment? = nil, incrementKg: Double? = nil, note: String? = nil, overload: Overload? = nil,
            archived: Bool? = nil, createdAt: Date? = nil
        ) {
            self.id = id
            self.name = name
            self.muscleGroup = muscleGroup
            self.kind = kind
            self.equipment = equipment
            self.incrementKg = incrementKg
            self.note = note
            self.overload = overload
            self.archived = archived
            self.createdAt = createdAt
        }
    }

    /// An exercise inside a template. Found by `exerciseId`, else by name (case and accent insensitive).
    public struct TemplateItem: Codable, Equatable, Sendable {
        public var exerciseId: String?
        public var exerciseName: String?
        public var targetSets: Int?

        public init(exerciseId: String? = nil, exerciseName: String? = nil, targetSets: Int? = nil) {
            self.exerciseId = exerciseId
            self.exerciseName = exerciseName
            self.targetSets = targetSets
        }
    }

    /// Array order is the templates' list order.
    public struct WorkoutTemplate: Codable, Equatable, Sendable {
        public var id: String?
        public var name: String
        public var kind: ExerciseKind?
        public var note: String?
        /// The workout's own progressive overload (F11-10).
        public var overload: Overload?
        public var archived: Bool?
        public var createdAt: Date?
        public var items: [TemplateItem]?

        public init(
            id: String? = nil, name: String, kind: ExerciseKind? = nil, note: String? = nil, overload: Overload? = nil,
            archived: Bool? = nil, createdAt: Date? = nil, items: [TemplateItem]? = nil
        ) {
            self.id = id
            self.name = name
            self.kind = kind
            self.note = note
            self.overload = overload
            self.archived = archived
            self.createdAt = createdAt
            self.items = items
        }
    }

    public enum WeekdayCode: String, Codable, CaseIterable, Sendable {
        case mon, tue, wed, thu, fri, sat, sun

        public init(_ weekday: Weekday) {
            self = Self.allCases[weekday.rawValue]
        }

        public var weekday: Weekday {
            Weekday(rawValue: Self.allCases.firstIndex(of: self) ?? 0) ?? .monday
        }
    }

    /// `weekdays` uses `days`; `interval` uses `everyDays` and `startDate`.
    public struct Schedule: Codable, Equatable, Sendable {
        public var type: ScheduleType
        public var days: [WeekdayCode]?
        public var everyDays: Int?
        public var startDate: LocalDate?

        public init(
            type: ScheduleType, days: [WeekdayCode]? = nil, everyDays: Int? = nil, startDate: LocalDate? = nil
        ) {
            self.type = type
            self.days = days
            self.everyDays = everyDays
            self.startDate = startDate
        }
    }

    /// Array order is the routines' list order; `templateIds` is the rotation.
    public struct Routine: Codable, Equatable, Sendable {
        public var id: String?
        public var name: String
        public var note: String?
        public var active: Bool?
        public var schedule: Schedule?
        public var templateIds: [String]?
        public var createdAt: Date?

        public init(
            id: String? = nil, name: String, note: String? = nil, active: Bool? = nil, schedule: Schedule? = nil,
            templateIds: [String]? = nil, createdAt: Date? = nil
        ) {
            self.id = id
            self.name = name
            self.note = note
            self.active = active
            self.schedule = schedule
            self.templateIds = templateIds
            self.createdAt = createdAt
        }
    }

    /// A performed workout. `date` alone is enough ("2026-09-28"); without `date` or `startedAt` the date is estimated
    /// on import. `status` defaults to completed.
    public struct Session: Codable, Equatable, Sendable {
        public var id: String?
        public var date: LocalDate?
        public var startedAt: Date?
        public var endedAt: Date?
        public var pausedTotalSec: Double?
        public var pausedAt: Date?
        public var status: SessionStatus?
        public var title: String?
        public var templateId: String?
        public var routineId: String?
        public var note: String?
        public var source: SessionSource?
        public var dateEstimated: Bool?
        public var healthKitWorkoutId: UUID?
        public var exercises: [SessionExercise]

        public init(
            id: String? = nil, date: LocalDate? = nil, startedAt: Date? = nil, endedAt: Date? = nil,
            pausedTotalSec: Double? = nil, pausedAt: Date? = nil, status: SessionStatus? = nil, title: String? = nil,
            templateId: String? = nil, routineId: String? = nil, note: String? = nil, source: SessionSource? = nil,
            dateEstimated: Bool? = nil, healthKitWorkoutId: UUID? = nil, exercises: [SessionExercise]
        ) {
            self.id = id
            self.date = date
            self.startedAt = startedAt
            self.endedAt = endedAt
            self.pausedTotalSec = pausedTotalSec
            self.pausedAt = pausedAt
            self.status = status
            self.title = title
            self.templateId = templateId
            self.routineId = routineId
            self.note = note
            self.source = source
            self.dateEstimated = dateEstimated
            self.healthKitWorkoutId = healthKitWorkoutId
            self.exercises = exercises
        }
    }

    /// A movement in a session: strength `sets` or cardio `segments`. Needs `exerciseId` or `exerciseName`.
    public struct SessionExercise: Codable, Equatable, Sendable {
        public var exerciseId: String?
        public var exerciseName: String?
        /// How it went this time (F11-12).
        public var note: String?
        public var completed: Bool?
        public var sets: [SetEntry]?
        public var segments: [Segment]?

        public init(
            exerciseId: String? = nil, exerciseName: String? = nil, note: String? = nil, completed: Bool? = nil,
            sets: [SetEntry]? = nil, segments: [Segment]? = nil
        ) {
            self.exerciseId = exerciseId
            self.exerciseName = exerciseName
            self.note = note
            self.completed = completed
            self.sets = sets
            self.segments = segments
        }
    }

    /// One strength set; weights in `units.weight`. `completed` defaults to true.
    public struct SetEntry: Codable, Equatable, Sendable {
        public var weight: Double
        public var reps: Int
        public var targetWeight: Double?
        public var targetReps: Int?
        public var completed: Bool?
        public var completedAt: Date?

        public init(
            weight: Double, reps: Int, targetWeight: Double? = nil, targetReps: Int? = nil, completed: Bool? = nil,
            completedAt: Date? = nil
        ) {
            self.weight = weight
            self.reps = reps
            self.targetWeight = targetWeight
            self.targetReps = targetReps
            self.completed = completed
            self.completedAt = completedAt
        }
    }

    /// One cardio segment. A missing duration means "the rest of the session".
    public struct Segment: Codable, Equatable, Sendable {
        public var speedKmh: Double?
        public var inclinePercent: Double?
        public var durationMin: Double?

        public init(speedKmh: Double? = nil, inclinePercent: Double? = nil, durationMin: Double? = nil) {
            self.speedKmh = speedKmh
            self.inclinePercent = inclinePercent
            self.durationMin = durationMin
        }
    }

    /// A change to a day's water total; negative amounts are removals.
    public struct WaterLog: Codable, Equatable, Sendable {
        public var loggedAt: Date
        public var amountMl: Int
        public var source: WaterSource?

        public init(loggedAt: Date, amountMl: Int, source: WaterSource? = nil) {
            self.loggedAt = loggedAt
            self.amountMl = amountMl
            self.source = source
        }
    }

    public struct Overload: Codable, Equatable, Sendable {
        public var thresholdReps: Int?
        public var resetReps: Int?
        /// Reps added to the target while the weight stays. Older files do not have it.
        public var repStep: Int?

        public init(thresholdReps: Int? = nil, resetReps: Int? = nil, repStep: Int? = nil) {
            self.thresholdReps = thresholdReps
            self.resetReps = resetReps
            self.repStep = repStep
        }
    }

    /// Values outside the app's ranges are clamped on import (`SettingsStore.Limits`).
    public struct Settings: Codable, Equatable, Sendable {
        public var stepGoal: Int?
        public var waterGoalMl: Int?
        public var overload: Overload?
        public var unitSystem: UnitSystem?
        public var quickWaterAmounts: [Int]?

        public init(
            stepGoal: Int? = nil, waterGoalMl: Int? = nil, overload: Overload? = nil, unitSystem: UnitSystem? = nil,
            quickWaterAmounts: [Int]? = nil
        ) {
            self.stepGoal = stepGoal
            self.waterGoalMl = waterGoalMl
            self.overload = overload
            self.unitSystem = unitSystem
            self.quickWaterAmounts = quickWaterAmounts
        }
    }
}

// swiftlint:enable discouraged_optional_boolean
