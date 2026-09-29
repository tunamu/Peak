import Foundation
import SwiftData

/// The sample program offered in onboarding: the design's six templates ("Recorded Workouts") and one routine that
/// rotates through them on Monday, Wednesday and Friday. Loaded only when the user picks it.
@MainActor
public enum SampleProgram {
    struct ExerciseSpec {
        let name: String
        let muscleGroup: MuscleGroup
        let equipment: Equipment
        let incrementKg: Double
    }

    static let chestPress = ExerciseSpec(
        name: "Dumbbell Chest Press", muscleGroup: .chest, equipment: .dumbbell, incrementKg: 2.5)
    static let inclineSmithPress = ExerciseSpec(
        name: "Incline Smith Machine Press", muscleGroup: .chest, equipment: .smith, incrementKg: 5)
    static let fly = ExerciseSpec(name: "Fly", muscleGroup: .chest, equipment: .machine, incrementKg: 5)
    static let latPulldown = ExerciseSpec(
        name: "Lat Pulldown", muscleGroup: .back, equipment: .machine, incrementKg: 5)
    static let closeGripPulldown = ExerciseSpec(
        name: "Close Grip Pulldown", muscleGroup: .back, equipment: .machine, incrementKg: 5)
    static let row = ExerciseSpec(name: "Row", muscleGroup: .back, equipment: .machine, incrementKg: 5)
    static let shoulderPress = ExerciseSpec(
        name: "Smith Machine Shoulder Press", muscleGroup: .shoulders, equipment: .smith, incrementKg: 5)
    static let lateralRaise = ExerciseSpec(
        name: "Lateral Raise", muscleGroup: .shoulders, equipment: .dumbbell, incrementKg: 2.5)
    static let rearDeltFly = ExerciseSpec(
        name: "Rear Delt Fly", muscleGroup: .shoulders, equipment: .machine, incrementKg: 5)
    static let inclineCurl = ExerciseSpec(
        name: "Incline Dumbbell Curl", muscleGroup: .biceps, equipment: .dumbbell, incrementKg: 2.5)
    static let gobletCurl = ExerciseSpec(
        name: "Dumbbell Curl Goblet", muscleGroup: .biceps, equipment: .dumbbell, incrementKg: 2.5)
    static let pushdown = ExerciseSpec(
        name: "V Bar Triceps Pushdown", muscleGroup: .triceps, equipment: .cable, incrementKg: 5)
    static let barbellTriceps = ExerciseSpec(
        name: "Triceps Barbell Curl", muscleGroup: .triceps, equipment: .barbell, incrementKg: 5)

    static let chest = [chestPress, inclineSmithPress, fly]
    static let back = [latPulldown, closeGripPulldown, row]
    static let shoulders = [shoulderPress, lateralRaise, rearDeltFly]
    static let biceps = [inclineCurl, gobletCurl]
    static let triceps = [pushdown, barbellTriceps]

    /// Template names and exercises, in rotation order.
    static let templates: [(name: String, exercises: [ExerciseSpec])] = [
        ("Chest & Biceps", chest + biceps),
        ("Back & Triceps", back + triceps),
        ("Shoulder & Biceps", shoulders + biceps),
        ("Chest & Triceps", chest + triceps),
        ("Back & Biceps", back + biceps),
        ("Shoulder & Triceps", shoulders + triceps),
    ]

    static let routineName = "Main Routine"

    /// Sets per exercise; everything else gets two.
    static func targetSets(for spec: ExerciseSpec) -> Int {
        spec.name == row.name ? 3 : 2
    }

    /// Loads the program. Running it again adds nothing: exercises are matched by name and existing templates with
    /// the same name are left alone.
    public static func install(into context: ModelContext) throws {
        let exercises = ExerciseRepository(context: context)
        let templates = TemplateRepository(context: context)
        let routines = RoutineRepository(context: context)

        let existingNames = Set(try templates.all(includingArchived: true).map(\.name.matchingKey))
        var rotation: [WorkoutTemplate] = []
        for spec in Self.templates {
            if existingNames.contains(spec.name.matchingKey) { continue }
            let template = try templates.create(name: spec.name)
            let items = try spec.exercises.map { exercise in
                let model = try exercises.findOrCreate(
                    name: exercise.name,
                    muscleGroup: exercise.muscleGroup,
                    equipment: exercise.equipment,
                    incrementKg: exercise.incrementKg
                )
                return (exercise: model, targetSets: targetSets(for: exercise))
            }
            templates.setItems(items, of: template)
            rotation.append(template)
        }

        let hasRoutine = try routines.all().contains { $0.name.matchingKey == routineName.matchingKey }
        if !rotation.isEmpty && !hasRoutine {
            try routines.create(name: routineName, weekdays: [.monday, .wednesday, .friday], templates: rotation)
        }
        try context.save()
    }

    /// Debug only: three completed sessions of the sample routine on its last three scheduled days before `now`, so
    /// Home has history to show. Needs the program installed; does nothing when the routine already has sessions.
    public static func installHistory(into context: ModelContext, now: Date = .now, calendar: Calendar = .current)
        throws
    {
        guard
            let routine = try RoutineRepository(context: context).all().first(where: {
                $0.name.matchingKey == routineName.matchingKey
            }),
            (routine.sessions ?? []).isEmpty
        else { return }

        let weekdays = Set(routine.weekdays)
        var days: [Date] = []
        var day = calendar.startOfDay(for: now)
        while days.count < 3, let previous = calendar.date(byAdding: .day, value: -1, to: day) {
            day = previous
            if weekdays.contains(Weekday(of: day, calendar: calendar)) {
                days.insert(day, at: 0)
            }
        }

        let sessions = SessionRepository(context: context)
        for (template, day) in zip(routine.orderedEntries.compactMap(\.template), days) {
            let start = calendar.date(bySettingHour: 18, minute: 30, second: 0, of: day) ?? day
            let session = sessions.start(from: template, routine: routine, at: start)
            for exercise in session.orderedExercises {
                for set in exercise.orderedSets {
                    set.weightKg = exercise.exercise?.equipment == .dumbbell ? 15 : 40
                    set.reps = 10
                    set.isCompleted = true
                    set.completedAt = start
                }
                exercise.isCompleted = true
            }
            sessions.complete(session, at: start.addingTimeInterval(48 * 60))
        }
        try context.save()
    }
}
