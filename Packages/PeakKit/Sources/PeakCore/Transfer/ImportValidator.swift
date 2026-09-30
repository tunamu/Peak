import Foundation

/// Checks a decoded file on its own, without the store: the rules the JSON Schema states that Swift types cannot
/// (ranges, blank names, schedules), so a file typed by hand or by an LLM gets a clear message per field.
enum ImportValidator {
    static func issues(in data: PeakExportV1) -> [ImportIssue] {
        var issues: [ImportIssue] = []
        func check(_ isValid: Bool, _ kind: ImportIssue.Kind, _ path: String) {
            if !isValid { issues.append(ImportIssue(kind, at: path)) }
        }

        if let schema = data.schema, schema != PeakExportV1.schemaName {
            check(false, .notPeakData(schema), "schema")
        }
        if let version = data.schemaVersion, version > PeakExportV1.schemaVersion {
            check(false, .unsupportedVersion(version), "schemaVersion")
        }

        for (index, exercise) in (data.exercises ?? []).enumerated() {
            let path = "exercises[\(index)]"
            check(!exercise.name.matchingKey.isEmpty, .blankName, "\(path).name")
            check((exercise.incrementKg ?? 1) > 0, .outOfRange(field: "incrementKg"), "\(path).incrementKg")
        }
        for (index, template) in (data.workoutTemplates ?? []).enumerated() {
            let path = "workoutTemplates[\(index)]"
            check(!template.name.matchingKey.isEmpty, .blankName, "\(path).name")
            for (itemIndex, item) in (template.items ?? []).enumerated() {
                let itemPath = "\(path).items[\(itemIndex)]"
                check(item.exerciseId != nil || item.exerciseName != nil, .missingExercise, itemPath)
                check((item.targetSets ?? 1) >= 1, .outOfRange(field: "targetSets"), "\(itemPath).targetSets")
            }
        }
        for (index, routine) in (data.routines ?? []).enumerated() {
            let path = "routines[\(index)]"
            check(!routine.name.matchingKey.isEmpty, .blankName, "\(path).name")
            if let schedule = routine.schedule {
                switch schedule.type {
                case .weekdays: check(!(schedule.days ?? []).isEmpty, .noWeekdays, "\(path).schedule.days")
                case .interval:
                    check(
                        (schedule.everyDays ?? 1) >= 1, .outOfRange(field: "everyDays"), "\(path).schedule.everyDays")
                }
            }
        }
        for (index, session) in data.sessions.enumerated() {
            issues += sessionIssues(session, at: "sessions[\(index)]")
        }
        return issues
    }

    private static func sessionIssues(_ session: PeakExportV1.Session, at path: String) -> [ImportIssue] {
        var issues: [ImportIssue] = []
        func check(_ isValid: Bool, _ kind: ImportIssue.Kind, _ path: String) {
            if !isValid { issues.append(ImportIssue(kind, at: path)) }
        }
        if let start = session.startedAt, let end = session.endedAt {
            check(end >= start, .endsBeforeStart, "\(path).endedAt")
        }
        check((session.pausedTotalSec ?? 0) >= 0, .outOfRange(field: "pausedTotalSec"), "\(path).pausedTotalSec")
        for (index, exercise) in session.exercises.enumerated() {
            let exercisePath = "\(path).exercises[\(index)]"
            let name = exercise.exerciseName.map(\.matchingKey)
            check(name.map { !$0.isEmpty } ?? true, .blankName, "\(exercisePath).exerciseName")
            check(exercise.exerciseId != nil || name != nil, .missingExercise, exercisePath)
            for (setIndex, set) in (exercise.sets ?? []).enumerated() {
                let setPath = "\(exercisePath).sets[\(setIndex)]"
                check(set.weight >= 0, .outOfRange(field: "weight"), "\(setPath).weight")
                check(set.reps >= 0, .outOfRange(field: "reps"), "\(setPath).reps")
                check((set.targetWeight ?? 0) >= 0, .outOfRange(field: "targetWeight"), "\(setPath).targetWeight")
                check((set.targetReps ?? 0) >= 0, .outOfRange(field: "targetReps"), "\(setPath).targetReps")
            }
            for (segmentIndex, segment) in (exercise.segments ?? []).enumerated() {
                let segmentPath = "\(exercisePath).segments[\(segmentIndex)]"
                check((segment.speedKmh ?? 0) >= 0, .outOfRange(field: "speedKmh"), "\(segmentPath).speedKmh")
                check((segment.durationMin ?? 1) > 0, .outOfRange(field: "durationMin"), "\(segmentPath).durationMin")
            }
        }
        return issues
    }
}
