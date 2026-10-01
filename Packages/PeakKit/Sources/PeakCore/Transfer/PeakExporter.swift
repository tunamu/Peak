import Foundation
import SwiftData

/// Writes everything in the store as Peak JSON v1 (docs/IMPORT_FORMAT.md › Export).
///
/// The output is complete and deterministic: every record is written, archived ones included, ids are the stored
/// UUIDs, weights are kg, and records come in a fixed order. Imported into an empty store with `PeakImporter`, the
/// file recreates the same data, so exporting again gives the same bytes (`PeakRoundTripTests`).
public struct PeakExporter {
    private let context: ModelContext
    private let calendar: Calendar

    public init(context: ModelContext, calendar: Calendar = .current) {
        self.context = context
        self.calendar = calendar
    }

    /// "peak-export-2026-09-30.json".
    public static func fileName(on date: Date = .now, calendar: Calendar = .current) -> String {
        "peak-export-\(LocalDate(date, calendar: calendar)).json"
    }

    public func export(settings: PeakExportV1.Settings?, at date: Date = .now) throws -> PeakExportV1 {
        PeakExportV1(
            exportedAt: date,
            units: .init(weight: .kg),
            exercises: try fetch(Exercise.self).sorted(by: Self.creationOrder).map(exercise),
            workoutTemplates: try fetch(WorkoutTemplate.self).sorted(by: Self.listOrder).map(template),
            routines: try fetch(Routine.self).sorted(by: Self.listOrder).map(routine),
            sessions: try fetch(WorkoutSession.self).sorted(by: Self.sessionOrder).map(session),
            waterLogs: try fetch(WaterLog.self).sorted(by: Self.waterOrder).map(waterLog),
            settings: settings
        )
    }

    // MARK: Records

    private func exercise(_ exercise: Exercise) -> PeakExportV1.Exercise {
        PeakExportV1.Exercise(
            id: exercise.id.uuidString, name: exercise.name, muscleGroup: exercise.muscleGroup, kind: exercise.kind,
            equipment: exercise.equipment, incrementKg: exercise.incrementKg,
            note: exercise.note.isEmpty ? nil : exercise.note, overload: Self.overload(exercise.overloadOverride),
            archived: exercise.isArchived, createdAt: exercise.createdAt
        )
    }

    /// A workout's or movement's own overload, left out when it has none.
    private static func overload(_ override: OverloadOverride) -> PeakExportV1.Overload? {
        override.isEmpty
            ? nil
            : PeakExportV1.Overload(
                thresholdReps: override.thresholdReps, resetReps: override.resetReps, repStep: override.repStep)
    }

    private func template(_ template: WorkoutTemplate) -> PeakExportV1.WorkoutTemplate {
        PeakExportV1.WorkoutTemplate(
            id: template.id.uuidString, name: template.name, kind: template.kind, note: template.note,
            overload: Self.overload(template.overloadOverride), archived: template.isArchived,
            createdAt: template.createdAt,
            items: template.orderedItems.compactMap { item in
                item.exercise.map { .init(exerciseId: $0.id.uuidString, targetSets: item.targetSets) }
            }
        )
    }

    private func routine(_ routine: Routine) -> PeakExportV1.Routine {
        let schedule: PeakExportV1.Schedule =
            switch routine.scheduleType {
            case .weekdays: .init(type: .weekdays, days: routine.weekdays.map(PeakExportV1.WeekdayCode.init))
            case .interval:
                .init(
                    type: .interval, everyDays: routine.intervalDays,
                    startDate: LocalDate(routine.startDate, calendar: calendar))
            }
        return PeakExportV1.Routine(
            id: routine.id.uuidString, name: routine.name, note: routine.note, active: routine.isActive,
            schedule: schedule, templateIds: routine.orderedEntries.compactMap { $0.template?.id.uuidString },
            createdAt: routine.createdAt
        )
    }

    private func session(_ session: WorkoutSession) -> PeakExportV1.Session {
        PeakExportV1.Session(
            id: session.id.uuidString, date: LocalDate(session.startedAt, calendar: calendar),
            startedAt: session.startedAt, endedAt: session.endedAt, pausedTotalSec: session.pausedTotal,
            pausedAt: session.pausedAt, status: session.status, title: session.title,
            templateId: session.template?.id.uuidString, routineId: session.routine?.id.uuidString,
            note: session.note, source: session.source, dateEstimated: session.isDateEstimated,
            healthKitWorkoutId: session.healthKitWorkoutID,
            exercises: session.orderedExercises.map(sessionExercise)
        )
    }

    private func sessionExercise(_ exercise: SessionExercise) -> PeakExportV1.SessionExercise {
        let sets = exercise.orderedSets.map { set in
            PeakExportV1.SetEntry(
                weight: set.weightKg, reps: set.reps, targetWeight: set.targetWeightKg, targetReps: set.targetReps,
                completed: set.isCompleted, completedAt: set.completedAt
            )
        }
        let segments = exercise.orderedSegments.map { segment in
            PeakExportV1.Segment(
                speedKmh: segment.speedKmh, inclinePercent: segment.inclinePercent,
                durationMin: segment.durationSec.map { Double($0) / 60 }
            )
        }
        return PeakExportV1.SessionExercise(
            exerciseId: exercise.exercise?.id.uuidString, exerciseName: exercise.exerciseName,
            note: exercise.note.isEmpty ? nil : exercise.note, completed: exercise.isCompleted,
            sets: sets.isEmpty ? nil : sets,
            segments: segments.isEmpty ? nil : segments
        )
    }

    private func waterLog(_ log: WaterLog) -> PeakExportV1.WaterLog {
        PeakExportV1.WaterLog(loggedAt: log.date, amountMl: log.amountMl, source: log.source)
    }

    // MARK: Order

    private func fetch<Model: PersistentModel>(_: Model.Type) throws -> [Model] {
        try context.fetch(FetchDescriptor<Model>())
    }

    // Times compare in whole milliseconds, as written; ties fall back to the id. Two exports of the same data list
    // records the same way.

    private static func ms(_ date: Date) -> Int64 { PeakJSON.milliseconds(date) }

    private static func creationOrder(_ lhs: Exercise, _ rhs: Exercise) -> Bool {
        (ms(lhs.createdAt), lhs.id.uuidString) < (ms(rhs.createdAt), rhs.id.uuidString)
    }

    private static func listOrder(_ lhs: WorkoutTemplate, _ rhs: WorkoutTemplate) -> Bool {
        (lhs.sortIndex, ms(lhs.createdAt), lhs.id.uuidString) < (rhs.sortIndex, ms(rhs.createdAt), rhs.id.uuidString)
    }

    private static func listOrder(_ lhs: Routine, _ rhs: Routine) -> Bool {
        (lhs.sortIndex, ms(lhs.createdAt), lhs.id.uuidString) < (rhs.sortIndex, ms(rhs.createdAt), rhs.id.uuidString)
    }

    private static func sessionOrder(_ lhs: WorkoutSession, _ rhs: WorkoutSession) -> Bool {
        (ms(lhs.startedAt), lhs.id.uuidString) < (ms(rhs.startedAt), rhs.id.uuidString)
    }

    private static func waterOrder(_ lhs: WaterLog, _ rhs: WaterLog) -> Bool {
        (ms(lhs.date), lhs.amountMl, lhs.sourceRaw) < (ms(rhs.date), rhs.amountMl, rhs.sourceRaw)
    }
}
