import Foundation
import SwiftData

// The planning half of `PeakImporter`: what the store has, what the file means, and every decision, made without
// writing.

// MARK: - Store index

/// What the store already has, for matching. Empty for a replace.
struct StoreIndex {
    var exercisesByID: [UUID: Exercise] = [:]
    var exercisesByName: [String: Exercise] = [:]
    var templatesByID: [UUID: WorkoutTemplate] = [:]
    var templatesByName: [String: WorkoutTemplate] = [:]
    var routinesByID: [UUID: Routine] = [:]
    var routinesByName: [String: Routine] = [:]
    var sessionIDs: Set<UUID> = []
    /// How many stored sessions have each fingerprint.
    var fingerprints: [String: Int] = [:]
    var waterLogs: Set<String> = []

    init() {}

    init(context: ModelContext, calendar: Calendar) throws {
        for exercise in try context.fetch(FetchDescriptor<Exercise>()) {
            exercisesByID[exercise.id] = exercise
            exercisesByName[exercise.name.matchingKey] = exercisesByName[exercise.name.matchingKey] ?? exercise
        }
        for template in try context.fetch(FetchDescriptor<WorkoutTemplate>()) {
            templatesByID[template.id] = template
            templatesByName[template.name.matchingKey] = templatesByName[template.name.matchingKey] ?? template
        }
        for routine in try context.fetch(FetchDescriptor<Routine>()) {
            routinesByID[routine.id] = routine
            routinesByName[routine.name.matchingKey] = routinesByName[routine.name.matchingKey] ?? routine
        }
        for session in try context.fetch(FetchDescriptor<WorkoutSession>()) {
            sessionIDs.insert(session.id)
            let key = Fingerprint.session(
                day: session.isDateEstimated ? nil : LocalDate(session.startedAt, calendar: calendar),
                exercises: session.orderedExercises.map { exercise in
                    Fingerprint.exercise(
                        name: exercise.exerciseName,
                        sets: exercise.orderedSets.map { ($0.weightKg, $0.reps) },
                        segments: exercise.orderedSegments.map {
                            [$0.speedKmh, $0.inclinePercent, $0.durationSec.map { Double($0) / 60 }]
                        })
                })
            fingerprints[key, default: 0] += 1
        }
        for log in try context.fetch(FetchDescriptor<WaterLog>()) {
            waterLogs.insert(Fingerprint.water(log.date, log.amountMl, log.source))
        }
    }
}

/// Keys that say "the same record" across a file and the store.
enum Fingerprint {
    static func exercise(
        name: String, sets: [(Double, Int)], segments: [[Double?]]
    ) -> String {
        let setsKey = sets.map { "\(number($0.0))x\($0.1)" }.joined(separator: ",")
        let segmentsKey = segments.map { $0.map(number).joined(separator: "/") }.joined(separator: ",")
        return "\(name.matchingKey)[\(setsKey)][\(segmentsKey)]"
    }

    /// `day` is nil for a session with an estimated date: those match on their content alone.
    static func session(day: LocalDate?, exercises: [String]) -> String {
        "\(day?.description ?? "estimated")|\(exercises.joined(separator: "|"))"
    }

    static func water(_ date: Date, _ amountMl: Int, _ source: WaterSource) -> String {
        "\(PeakJSON.milliseconds(date))|\(amountMl)|\(source.rawValue)"
    }

    /// Two decimals, so 61.23496 kg from pounds and the same value read back compare equal.
    private static func number(_ value: Double?) -> String {
        value.map { String(format: "%.2f", $0) } ?? "-"
    }
}

// MARK: - Plan

/// Where a reference in the file points.
enum Target<Model>: Equatable {
    /// A record of the file, by index; it may itself be an existing record.
    case file(Int)
    case existing(PersistentIdentifier)
    /// An exercise made from a name that nothing else matched, by its matching key.
    case created(String)
}

/// Every decision of an import, made without writing. The writer follows it.
struct ImportPlan {
    let data: PeakExportV1
    let unit: PeakExportV1.WeightUnit
    var preview = ImportPreview()

    /// File records that are already in the store.
    var existingExercises: [Int: Exercise] = [:]
    var existingTemplates: [Int: WorkoutTemplate] = [:]
    var existingRoutines: [Int: Routine] = [:]
    /// Exercises made from names, by matching key, with the spelling and kind they get.
    var createdExercises: [String: (name: String, kind: ExerciseKind)] = [:]
    var createdOrder: [String] = []
    /// New sessions by index, with their start and whether it is estimated.
    var newSessions: [Int: (startedAt: Date, estimated: Bool)] = [:]
    var newWaterLogs: [Int] = []

    private var store: StoreIndex
    private var fileExerciseIDs: [String: Int] = [:]
    private var fileExerciseNames: [String: Int] = [:]
    private var fileTemplateIDs: [String: Int] = [:]
    private var fileRoutineIDs: [String: Int] = [:]
    // Lookups for the writer: model objects by persistent id.
    var storeExercises: [PersistentIdentifier: Exercise] = [:]
    var storeTemplates: [PersistentIdentifier: WorkoutTemplate] = [:]
    var storeRoutines: [PersistentIdentifier: Routine] = [:]

    init(data: PeakExportV1, store: StoreIndex, calendar: Calendar, now: Date) {
        self.data = data
        self.unit = data.units?.weight ?? .kg
        self.store = store
        for exercise in store.exercisesByID.values { storeExercises[exercise.persistentModelID] = exercise }
        for template in store.templatesByID.values { storeTemplates[template.persistentModelID] = template }
        for routine in store.routinesByID.values { storeRoutines[routine.persistentModelID] = routine }

        preview.issues = ImportValidator.issues(in: data)
        preview.sessions = data.sessions.count
        preview.hasSettings = data.settings != nil
        planExercises()
        planTemplates()
        planRoutines()
        planSessions(calendar: calendar, now: now)
        planWater()
    }

    // MARK: Records

    private mutating func planExercises() {
        for (index, exercise) in (data.exercises ?? []).enumerated() {
            if let id = exercise.id {
                fileExerciseIDs[id] = fileExerciseIDs[id] ?? index
            }
            let key = exercise.name.matchingKey
            fileExerciseNames[key] = fileExerciseNames[key] ?? index
            if let existing = Self.uuid(exercise.id).flatMap({ store.exercisesByID[$0] })
                ?? (Self.uuid(exercise.id) == nil ? store.exercisesByName[key] : nil)
            {
                existingExercises[index] = existing
            } else if !key.isEmpty {
                preview.newExercises.append(exercise.name)
            }
        }
    }

    private mutating func planTemplates() {
        for (index, template) in (data.workoutTemplates ?? []).enumerated() {
            if let id = template.id {
                fileTemplateIDs[id] = fileTemplateIDs[id] ?? index
            }
            let uuid = Self.uuid(template.id)
            if let existing = uuid.flatMap({ store.templatesByID[$0] })
                ?? (uuid == nil ? store.templatesByName[template.name.matchingKey] : nil)
            {
                existingTemplates[index] = existing
                continue
            }
            preview.newTemplates += 1
            for (itemIndex, item) in (template.items ?? []).enumerated() {
                _ = exercise(
                    id: item.exerciseId, name: item.exerciseName, kind: template.kind ?? .strength,
                    at: "workoutTemplates[\(index)].items[\(itemIndex)]")
            }
        }
    }

    private mutating func planRoutines() {
        for (index, routine) in (data.routines ?? []).enumerated() {
            if let id = routine.id {
                fileRoutineIDs[id] = fileRoutineIDs[id] ?? index
            }
            let uuid = Self.uuid(routine.id)
            if let existing = uuid.flatMap({ store.routinesByID[$0] })
                ?? (uuid == nil ? store.routinesByName[routine.name.matchingKey] : nil)
            {
                existingRoutines[index] = existing
                continue
            }
            preview.newRoutines += 1
            for (entry, id) in (routine.templateIds ?? []).enumerated() where template(id) == nil {
                preview.issues.append(
                    ImportIssue(
                        .unknownReference(field: "templateIds", id: id), at: "routines[\(index)].templateIds[\(entry)]")
                )
            }
        }
    }

    private mutating func planSessions(calendar: Calendar, now: Date) {
        let estimated = estimatedDays(calendar: calendar, now: now)
        var remaining = store.fingerprints
        var days: [LocalDate] = []
        for (index, session) in data.sessions.enumerated() {
            let estimatedDay = estimated[index]
            let day = estimatedDay ?? session.date ?? session.startedAt.map { LocalDate($0, calendar: calendar) }
            let key = fingerprint(of: session, day: estimatedDay == nil ? day : nil)
            let isKnownID = Self.uuid(session.id).map { store.sessionIDs.contains($0) } == true
            if isKnownID || (remaining[key] ?? 0) > 0 {
                if let count = remaining[key], count > 0 { remaining[key] = count - 1 }
                preview.duplicateSessions += 1
                continue
            }
            planNew(session, at: index, estimatedDay: estimatedDay)
            // A day without a time is placed at noon, so it stays on that day in nearby time zones.
            let noon = day?.date(in: calendar).flatMap { calendar.date(byAdding: .hour, value: 12, to: $0) }
            newSessions[index] = (session.startedAt ?? noon ?? now, estimatedDay != nil)
            if let day { days.append(day) }
        }
        if let first = days.min(), let last = days.max() {
            preview.dateRange = first...last
        }
    }

    /// Days for sessions without `date` and `startedAt`, by index: one apart, in file order, ending the day before
    /// the earliest dated session (or before today).
    private func estimatedDays(calendar: Calendar, now: Date) -> [Int: LocalDate] {
        let dated = data.sessions.compactMap { session in
            session.date ?? session.startedAt.map { LocalDate($0, calendar: calendar) }
        }
        let anchor = (dated.min() ?? LocalDate(now, calendar: calendar)).date(in: calendar)
        let undated = data.sessions.indices.filter {
            data.sessions[$0].date == nil && data.sessions[$0].startedAt == nil
        }
        var days: [Int: LocalDate] = [:]
        for (position, index) in undated.enumerated() {
            if let anchor, let day = calendar.date(byAdding: .day, value: position - undated.count, to: anchor) {
                days[index] = LocalDate(day, calendar: calendar)
            }
        }
        return days
    }

    /// The session's duplicate key; `day` is nil for an estimated date.
    private func fingerprint(of session: PeakExportV1.Session, day: LocalDate?) -> String {
        Fingerprint.session(
            day: day,
            exercises: session.exercises.map { item in
                Fingerprint.exercise(
                    name: name(id: item.exerciseId, fallback: item.exerciseName),
                    sets: (item.sets ?? []).map { (kilograms($0.weight), $0.reps) },
                    segments: (item.segments ?? []).map { [$0.speedKmh, $0.inclinePercent, $0.durationMin] })
            })
    }

    /// Counts a new session and resolves its references, noting the ones that find nothing.
    private mutating func planNew(_ session: PeakExportV1.Session, at index: Int, estimatedDay: LocalDate?) {
        let path = "sessions[\(index)]"
        for (field, id) in [("templateId", session.templateId), ("routineId", session.routineId)] {
            guard let id else { continue }
            let found = field == "templateId" ? template(id) != nil : routine(id) != nil
            if !found {
                preview.issues.append(ImportIssue(.unknownReference(field: field, id: id), at: "\(path).\(field)"))
            }
        }
        for (exerciseIndex, item) in session.exercises.enumerated() {
            _ = exercise(
                id: item.exerciseId, name: item.exerciseName,
                kind: item.segments?.isEmpty == false ? .cardio : .strength,
                at: "\(path).exercises[\(exerciseIndex)]")
        }
        if let estimatedDay {
            preview.issues.append(ImportIssue(.estimatedDate(estimatedDay), at: path))
        }
        preview.newSessions += 1
        preview.newSets += session.exercises.reduce(0) { $0 + ($1.sets ?? []).count }
    }

    private mutating func planWater() {
        var seen = store.waterLogs
        for (index, log) in (data.waterLogs ?? []).enumerated() {
            let key = Fingerprint.water(log.loggedAt, log.amountMl, log.source ?? .app)
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            newWaterLogs.append(index)
        }
        preview.newWaterLogs = newWaterLogs.count
    }

    // MARK: References

    /// The exercise a reference means: by id in the file or the store, else by name in the file or the store, else
    /// one made from the name. An id that finds nothing and no name to fall back on is an error.
    mutating func exercise(id: String?, name: String?, kind: ExerciseKind, at path: String) -> Target<Exercise>? {
        if let id, let index = fileExerciseIDs[id] {
            return .file(index)
        }
        if let exercise = Self.uuid(id).flatMap({ store.exercisesByID[$0] }) {
            return .existing(exercise.persistentModelID)
        }
        guard let name, !name.matchingKey.isEmpty else {
            if let id {
                preview.issues.append(
                    ImportIssue(.unknownReference(field: "exerciseId", id: id), at: "\(path).exerciseId"))
            }
            return nil
        }
        let key = name.matchingKey
        if let index = fileExerciseNames[key] {
            return .file(index)
        }
        if let exercise = store.exercisesByName[key] {
            return .existing(exercise.persistentModelID)
        }
        if createdExercises[key] == nil {
            createdExercises[key] = (name.trimmingCharacters(in: .whitespacesAndNewlines), kind)
            createdOrder.append(key)
            preview.newExercises.append(name.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return .created(key)
    }

    func template(_ id: String) -> Target<WorkoutTemplate>? {
        if let index = fileTemplateIDs[id] { return .file(index) }
        return UUID(uuidString: id).flatMap { store.templatesByID[$0] }.map { .existing($0.persistentModelID) }
    }

    func routine(_ id: String) -> Target<Routine>? {
        if let index = fileRoutineIDs[id] { return .file(index) }
        return UUID(uuidString: id).flatMap { store.routinesByID[$0] }.map { .existing($0.persistentModelID) }
    }

    /// The name a session movement is known by: its own snapshot, else the name of the exercise its id finds.
    private func name(id: String?, fallback: String?) -> String {
        if let fallback { return fallback }
        if let id, let index = fileExerciseIDs[id] { return data.exercises?[index].name ?? "" }
        return Self.uuid(id).flatMap { store.exercisesByID[$0]?.name } ?? ""
    }

    func kilograms(_ weight: Double) -> Double {
        switch unit {
        case .kg: weight
        case .lb: WeightUnits.kilograms(fromDisplayValue: weight, in: .imperial)
        }
    }

    static func uuid(_ id: String?) -> UUID? {
        id.flatMap(UUID.init(uuidString:))
    }
}
