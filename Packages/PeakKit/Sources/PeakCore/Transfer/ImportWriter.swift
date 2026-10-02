import Foundation
import SwiftData

// MARK: - Writer

/// Inserts what the plan says is new.
struct Writer {
    var plan: ImportPlan
    let context: ModelContext
    let calendar: Calendar
    var summary = PeakImportSummary()
    var exercises: [Int: Exercise] = [:]
    var created: [String: Exercise] = [:]
    var templates: [Int: WorkoutTemplate] = [:]
    var routines: [Int: Routine] = [:]

    init(plan: ImportPlan, context: ModelContext, calendar: Calendar) {
        self.plan = plan
        self.context = context
        self.calendar = calendar
    }

    mutating func write() -> PeakImportSummary {
        let data = plan.data
        for (index, dto) in (data.exercises ?? []).enumerated() {
            exercises[index] = plan.existingExercises[index] ?? insert(dto)
        }
        for key in plan.createdOrder {
            if let spec = plan.createdExercises[key] {
                created[key] = insert(PeakExportV1.Exercise(name: spec.name, kind: spec.kind))
            }
        }
        for (index, dto) in (data.workoutTemplates ?? []).enumerated() {
            templates[index] = plan.existingTemplates[index] ?? insert(dto, at: index)
        }
        for (index, dto) in (data.routines ?? []).enumerated() {
            routines[index] = plan.existingRoutines[index] ?? insert(dto, at: index)
        }
        for (index, dto) in data.sessions.enumerated() {
            if let placement = plan.newSessions[index] {
                insert(dto, index: index, startedAt: placement.startedAt, estimated: placement.estimated)
            }
        }
        for index in plan.newWaterLogs {
            if let log = data.waterLogs?[index] {
                context.insert(WaterLog(amountMl: log.amountMl, date: log.loggedAt, source: log.source ?? .app))
                summary.waterLogs += 1
            }
        }
        return summary
    }

    private static func override(_ overload: PeakExportV1.Overload?) -> OverloadOverride {
        OverloadOverride(
            thresholdReps: overload?.thresholdReps, resetReps: overload?.resetReps, repStep: overload?.repStep)
    }

    private mutating func insert(_ dto: PeakExportV1.Exercise) -> Exercise {
        let exercise = Exercise(name: dto.name.trimmingCharacters(in: .whitespacesAndNewlines))
        exercise.id = ImportPlan.uuid(dto.id) ?? UUID()
        exercise.muscleGroup = dto.muscleGroup ?? (dto.kind == .cardio ? .cardio : .other)
        exercise.kind = dto.kind ?? .strength
        exercise.equipment = dto.equipment ?? .other
        exercise.incrementKg = dto.incrementKg ?? 2.5
        exercise.note = dto.note ?? ""
        exercise.overloadOverride = Self.override(dto.overload)
        exercise.isArchived = dto.archived ?? false
        exercise.createdAt = dto.createdAt ?? .now
        context.insert(exercise)
        summary.exercises += 1
        return exercise
    }

    private mutating func insert(_ dto: PeakExportV1.WorkoutTemplate, at index: Int) -> WorkoutTemplate {
        let template = WorkoutTemplate(name: dto.name.trimmingCharacters(in: .whitespacesAndNewlines))
        template.id = ImportPlan.uuid(dto.id) ?? UUID()
        template.kind = dto.kind ?? .strength
        template.note = dto.note ?? ""
        template.overloadOverride = Self.override(dto.overload)
        template.sortIndex = index
        template.isArchived = dto.archived ?? false
        template.createdAt = dto.createdAt ?? .now
        context.insert(template)
        for (order, item) in (dto.items ?? []).enumerated() {
            let exercise = resolve(
                plan.exercise(id: item.exerciseId, name: item.exerciseName, kind: template.kind, at: ""))
            template.items?.append(TemplateItem(order: order, targetSets: item.targetSets ?? 2, exercise: exercise))
        }
        summary.templates += 1
        return template
    }

    private mutating func insert(_ dto: PeakExportV1.Routine, at index: Int) -> Routine {
        let routine = Routine(name: dto.name.trimmingCharacters(in: .whitespacesAndNewlines))
        routine.id = ImportPlan.uuid(dto.id) ?? UUID()
        routine.note = dto.note ?? ""
        routine.sortIndex = index
        routine.isActive = dto.active ?? true
        routine.createdAt = dto.createdAt ?? .now
        if let schedule = dto.schedule {
            routine.scheduleType = schedule.type
            routine.weekdays = (schedule.days ?? []).map(\.weekday)
            routine.intervalDays = schedule.everyDays ?? routine.intervalDays
            routine.startDate = schedule.startDate?.date(in: calendar) ?? routine.createdAt
        }
        context.insert(routine)
        let entries = (dto.templateIds ?? []).compactMap { plan.template($0).flatMap(resolve) }
        for (order, template) in entries.enumerated() {
            routine.entries?.append(RoutineEntry(order: order, template: template))
        }
        summary.routines += 1
        return routine
    }

    private mutating func insert(_ dto: PeakExportV1.Session, index: Int, startedAt: Date, estimated: Bool) {
        let template = dto.templateId.flatMap(plan.template).flatMap(resolve)
        let session = WorkoutSession(title: dto.title ?? template?.name ?? "", startedAt: startedAt)
        session.id = ImportPlan.uuid(dto.id) ?? UUID()
        session.status = dto.status ?? .completed
        // A finished workout without an end has no known length: zero rather than "until now".
        session.endedAt = dto.endedAt ?? (session.status == .completed ? startedAt : nil)
        session.pausedTotal = dto.pausedTotalSec ?? 0
        session.pausedAt = dto.pausedAt
        session.note = dto.note ?? ""
        session.source = dto.source ?? .importJSON
        session.isDateEstimated = estimated || dto.dateEstimated == true
        session.healthKitWorkoutID = dto.healthKitWorkoutId
        session.template = template
        session.routine = dto.routineId.flatMap(plan.routine).flatMap(resolve)
        context.insert(session)
        for (order, item) in dto.exercises.enumerated() {
            session.exercises?.append(sessionExercise(item, order: order))
        }
        summary.sessions += 1
    }

    private mutating func sessionExercise(_ dto: PeakExportV1.SessionExercise, order: Int) -> SessionExercise {
        let kind: ExerciseKind = dto.segments?.isEmpty == false ? .cardio : .strength
        let exercise = resolve(plan.exercise(id: dto.exerciseId, name: dto.exerciseName, kind: kind, at: ""))
        let item = SessionExercise(order: order, exercise: exercise)
        if let name = dto.exerciseName {
            item.exerciseName = name
        }
        item.isCompleted = dto.completed ?? false
        item.note = dto.note ?? ""
        for (index, set) in (dto.sets ?? []).enumerated() {
            let entry = SetEntry(order: index, weightKg: plan.kilograms(set.weight), reps: set.reps)
            entry.targetWeightKg = set.targetWeight.map(plan.kilograms)
            entry.targetReps = set.targetReps
            entry.isCompleted = set.completed ?? true
            entry.completedAt = set.completedAt
            item.sets?.append(entry)
            summary.sets += 1
        }
        for (index, segment) in (dto.segments ?? []).enumerated() {
            let entry = CardioSegment(order: index)
            entry.speedKmh = segment.speedKmh
            entry.inclinePercent = segment.inclinePercent
            entry.durationSec = segment.durationMin.map { Int(($0 * 60).rounded()) }
            item.segments?.append(entry)
        }
        return item
    }

    private func resolve(_ target: Target<Exercise>?) -> Exercise? {
        switch target {
        case .file(let index)?: exercises[index]
        case .existing(let id)?: plan.storeExercises[id]
        case .created(let key)?: created[key]
        case nil: nil
        }
    }

    private func resolve(_ target: Target<WorkoutTemplate>) -> WorkoutTemplate? {
        switch target {
        case .file(let index): templates[index]
        case .existing(let id): plan.storeTemplates[id]
        case .created: nil
        }
    }

    private func resolve(_ target: Target<Routine>) -> Routine? {
        switch target {
        case .file(let index): routines[index]
        case .existing(let id): plan.storeRoutines[id]
        case .created: nil
        }
    }
}
