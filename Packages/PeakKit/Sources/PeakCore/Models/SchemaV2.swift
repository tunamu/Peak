import Foundation
import SwiftData

/// The second stored schema (F11): movement notes (F11-12) and progressive overload per workout and per movement
/// (F11-10). Reached from `SchemaV1` by a lightweight migration: every new property is optional or has a default.
///
/// CloudKit rules (docs/DATA_MODEL.md) hold for every model: each property has a default or is optional, there is no
/// `.unique`, every relationship is optional with an inverse, enums are stored as `String`, and order is an explicit
/// `order` field. Stored names are part of the schema; do not rename them.
public enum SchemaV2: VersionedSchema {
    public static let versionIdentifier = Schema.Version(2, 0, 0)

    public static var models: [any PersistentModel.Type] {
        [
            Exercise.self, WorkoutTemplate.self, TemplateItem.self, Routine.self, RoutineEntry.self,
            WorkoutSession.self, SessionExercise.self, SetEntry.self, CardioSegment.self, WaterLog.self,
        ]
    }
}

extension SchemaV2 {
    /// A movement in the library, such as "Dumbbell Chest Press".
    @Model
    public final class Exercise {
        public var id = UUID()
        public var name = ""
        public var muscleGroupRaw = MuscleGroup.other.rawValue
        public var kindRaw = ExerciseKind.strength.rawValue
        public var equipmentRaw = Equipment.other.rawValue
        /// How much weight goes up when the progression rule says so ("Artış Adımı").
        public var incrementKg = 2.5
        /// How the movement is set up: seat height, grip, cable position (F11-12).
        public var note = ""
        /// Progressive overload for this movement, over its workout's and the app-wide setting; `nil` follows them
        /// (F11-10).
        public var overloadThresholdReps: Int?
        public var overloadResetReps: Int?
        public var overloadRepStep: Int?
        public var isArchived = false
        public var createdAt = Date.now

        @Relationship(inverse: \TemplateItem.exercise) public var templateItems: [TemplateItem]? = []
        @Relationship(inverse: \SessionExercise.exercise) public var sessionExercises: [SessionExercise]? = []

        public init(name: String) {
            self.name = name
        }
    }

    /// A named workout, such as "Chest & Biceps" (the design's "Recorded Workouts").
    @Model
    public final class WorkoutTemplate {
        public var id = UUID()
        public var name = ""
        public var kindRaw = ExerciseKind.strength.rawValue
        public var note = ""
        /// Progressive overload for this workout, over the app-wide setting; `nil` follows the setting (F11-10).
        public var overloadThresholdReps: Int?
        public var overloadResetReps: Int?
        public var overloadRepStep: Int?
        public var sortIndex = 0
        public var isArchived = false
        public var createdAt = Date.now

        @Relationship(deleteRule: .cascade, inverse: \TemplateItem.template) public var items: [TemplateItem]? = []
        @Relationship(inverse: \RoutineEntry.template) public var routineEntries: [RoutineEntry]? = []
        @Relationship(inverse: \WorkoutSession.template) public var sessions: [WorkoutSession]? = []

        public init(name: String) {
            self.name = name
        }
    }

    /// An exercise inside a template, with how many sets it gets.
    @Model
    public final class TemplateItem {
        public var order = 0
        public var targetSets = 2
        public var exercise: Exercise?
        public var template: WorkoutTemplate?

        public init(order: Int, targetSets: Int, exercise: Exercise?) {
            self.order = order
            self.targetSets = targetSets
            self.exercise = exercise
        }
    }

    /// A schedule that rotates through templates. Several routines can be active at once (D-15).
    @Model
    public final class Routine {
        public var id = UUID()
        public var name = ""
        public var note = ""
        public var sortIndex = 0
        public var isActive = true
        public var scheduleTypeRaw = ScheduleType.weekdays.rawValue
        /// Bit 0 = Monday … bit 6 = Sunday (`Weekday.bit`).
        public var weekdaysMask = 0
        /// For `.interval`: the next workout is the last one plus this many days.
        public var intervalDays = 2
        /// For `.interval`: the reference date before the first workout.
        public var startDate = Date.now
        public var createdAt = Date.now

        @Relationship(deleteRule: .cascade, inverse: \RoutineEntry.routine) public var entries: [RoutineEntry]? = []
        @Relationship(inverse: \WorkoutSession.routine) public var sessions: [WorkoutSession]? = []

        public init(name: String) {
            self.name = name
        }
    }

    /// A template's place in a routine's rotation. The rotation cursor is derived from sessions, never stored.
    @Model
    public final class RoutineEntry {
        public var order = 0
        public var template: WorkoutTemplate?
        public var routine: Routine?

        public init(order: Int, template: WorkoutTemplate?) {
            self.order = order
            self.template = template
        }
    }

    /// A performed (or running) workout. Keeps a snapshot of names so history survives renames and archiving.
    @Model
    public final class WorkoutSession {
        public var id = UUID()
        public var statusRaw = SessionStatus.active.rawValue
        public var startedAt = Date.now
        public var endedAt: Date?
        /// Total paused time; duration = end − start − pausedTotal.
        public var pausedTotal: TimeInterval = 0
        public var pausedAt: Date?
        /// Snapshot of the template name.
        public var title = ""
        public var note = ""
        public var sourceRaw = SessionSource.app.rawValue
        /// Imported sessions without a date get an estimated one.
        public var isDateEstimated = false
        public var healthKitWorkoutID: UUID?

        public var template: WorkoutTemplate?
        public var routine: Routine?
        @Relationship(deleteRule: .cascade, inverse: \SessionExercise.session) public var exercises:
            [SessionExercise]? = []

        public init(title: String, startedAt: Date = .now) {
            self.title = title
            self.startedAt = startedAt
        }
    }

    /// An exercise inside a session.
    @Model
    public final class SessionExercise {
        public var order = 0
        /// Snapshot of the exercise name.
        public var exerciseName = ""
        /// How it went this time (F11-12); the movement's notes over time are these.
        public var note = ""
        public var isCompleted = false
        public var exercise: Exercise?
        public var session: WorkoutSession?
        @Relationship(deleteRule: .cascade, inverse: \SetEntry.sessionExercise) public var sets: [SetEntry]? = []
        @Relationship(deleteRule: .cascade, inverse: \CardioSegment.sessionExercise)
        public var segments: [CardioSegment]? = []

        public init(order: Int, exercise: Exercise?) {
            self.order = order
            self.exercise = exercise
            self.exerciseName = exercise?.name ?? ""
        }
    }

    /// One strength set.
    @Model
    public final class SetEntry {
        public var order = 0
        public var weightKg = 0.0
        public var reps = 0
        public var targetWeightKg: Double?
        public var targetReps: Int?
        public var isCompleted = false
        public var completedAt: Date?
        public var sessionExercise: SessionExercise?

        public init(order: Int, weightKg: Double = 0, reps: Int = 0) {
            self.order = order
            self.weightKg = weightKg
            self.reps = reps
        }
    }

    /// One cardio segment (D-12). Distance = Σ speed × duration.
    @Model
    public final class CardioSegment {
        public var order = 0
        public var speedKmh: Double?
        public var inclinePercent: Double?
        /// Empty means "the rest of the session".
        public var durationSec: Int?
        public var sessionExercise: SessionExercise?

        public init(order: Int) {
            self.order = order
        }
    }

    /// A change to the day's water total. Negative amounts are removals.
    @Model
    public final class WaterLog {
        public var id = UUID()
        public var date = Date.now
        public var amountMl = 0
        public var sourceRaw = WaterSource.app.rawValue

        public init(amountMl: Int, date: Date = .now, source: WaterSource = .app) {
            self.amountMl = amountMl
            self.date = date
            self.sourceRaw = source.rawValue
        }
    }
}
