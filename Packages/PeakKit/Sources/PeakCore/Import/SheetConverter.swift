import Foundation

/// Turns a sheet and its mapping into Peak JSON, which `PeakImporter` then previews and imports like any file.
///
/// - **Long and wide:** each row adds sets to a session and exercise. Rows with the same date and workout are one
///   session; an empty date, workout or exercise cell repeats the one above (sheets often write them once).
/// - **Block:** a lone name is an exercise, and when two come together the first is a section ("Göğüs (Chest)").
///   Session rows with the same date are one session across exercises. Undated rows ("1. Seans") are one session per
///   section and number, dated later by the importer.
///
/// Cells that cannot be read are skipped and reported as warnings with their place ("C7").
public enum SheetConverter {
    public typealias Result = (data: PeakExportV1, issues: [ImportIssue])

    public static func convert(_ table: RawTable, mapping: SheetMapping) -> Result {
        var builder = SessionBuilder(sheet: table.name)
        switch mapping.layout {
        case .long, .wide: readRows(table, mapping: mapping, into: &builder)
        case .block: readBlocks(table, mapping: mapping, into: &builder)
        }
        let data = PeakExportV1(units: .init(weight: mapping.weightUnit), sessions: builder.sessions)
        return (data, builder.issues)
    }

    // MARK: Long and wide

    private static func readRows(_ table: RawTable, mapping: SheetMapping, into builder: inout SessionBuilder) {
        let columns = { (role: ColumnRole) in mapping.roles.indices.filter { mapping.roles[$0] == role } }
        let pairs = Array(zip(columns(.weight), columns(.reps)))
        var date = ""
        var workout = ""
        var exercise = ""
        for index in table.rows.indices where index > (mapping.headerRow ?? -1) {
            let row = table.rows[index]
            let cell = { (role: ColumnRole) in columns(role).first.map { row[$0] } ?? "" }
            date = cell(.date).isEmpty ? date : cell(.date)
            workout = cell(.workout).isEmpty ? workout : cell(.workout)
            exercise = cell(.exercise).isEmpty ? exercise : cell(.exercise)
            var sets: [PeakExportV1.SetEntry] = []
            for (weightColumn, repsColumn) in pairs {
                let weight = row[weightColumn]
                let reps = row[repsColumn]
                if SetCell.isEmpty(weight) && SetCell.isEmpty(reps) { continue }
                if let set = pairSet(weight: weight, reps: reps, table: table) {
                    sets.append(set)
                } else {
                    builder.warn(row: index, column: SetCell.isEmpty(weight) ? repsColumn : weightColumn, text: weight)
                }
            }
            for column in columns(.setCell) where !SetCell.isEmpty(row[column]) {
                if let set = SetCell.parse(row[column]) {
                    sets.append(entry(set))
                } else {
                    builder.warn(row: index, column: column, text: row[column])
                }
            }
            guard !sets.isEmpty else { continue }
            guard !exercise.isEmpty else {
                builder.warn(row: index, column: columns(.exercise).first ?? 0, text: "")
                continue
            }
            let label = SessionLabel.parse(date, order: mapping.dateOrder)
            if !date.isEmpty, label?.date == nil, label?.number == nil {
                builder.warn(row: index, column: columns(.date).first ?? 0, text: date)
                continue
            }
            let place = Placement(
                key: .init(date: label?.date, number: label?.number, group: workout), title: workout, note: cell(.note))
            builder.add(sets, exercise: exercise, order: Int(cell(.setNumber)), to: place)
        }
    }

    private static func pairSet(weight: String, reps: String, table: RawTable) -> PeakExportV1.SetEntry? {
        let weightText = weight.replacing(#/(?i)\s*(kg|lbs|lb)\s*$/#, with: "")
        guard let kg = SetCell.isEmpty(weight) ? 0 : table.number(weightText),
            let count = table.number(reps), count >= 0, count == count.rounded()
        else { return nil }
        return PeakExportV1.SetEntry(weight: kg, reps: Int(count))
    }

    private static func entry(_ set: SetCell) -> PeakExportV1.SetEntry {
        PeakExportV1.SetEntry(
            weight: set.weight, reps: set.reps, targetWeight: set.targetReps == nil ? nil : set.weight,
            targetReps: set.targetReps)
    }

    // MARK: Block

    private static func readBlocks(_ table: RawTable, mapping: SheetMapping, into builder: inout SessionBuilder) {
        // Lone names seen since the last session row: the last is the exercise, the one before it a section.
        var names: [String] = []
        var section = ""
        var exercise = ""
        for (index, row) in table.rows.enumerated() {
            switch BlockRow(row) {
            case .name(let name):
                names.append(name)
            case .columnNames, .empty:
                break
            case .other:
                builder.warn(row: index, column: 0, text: row.first { !$0.isEmpty } ?? "")
                names = []
            case .session(let text, let cells):
                if let last = names.last {
                    exercise = last
                    section = names.count >= 2 ? names[names.count - 2] : section
                    names = []
                }
                let label = SessionLabel.parse(text, order: mapping.dateOrder)
                let sets = cells.compactMap(SetCell.parse).map(entry)
                guard !exercise.isEmpty, !sets.isEmpty else { continue }
                if label == nil, !text.isEmpty {
                    builder.warn(row: index, column: 0, text: text)
                    continue
                }
                // Undated rows group by section and number; without a section, by exercise.
                let group = label?.date == nil ? (section.isEmpty ? exercise : section) : ""
                let place = Placement(
                    key: .init(date: label?.date, number: label?.number, group: group), title: section, note: "")
                builder.add(sets, exercise: exercise, order: nil, to: place)
            }
        }
    }
}

/// The session a row's sets go to, and what it adds to that session.
private struct Placement {
    var key: SessionKey
    var title: String
    var note: String
}

private struct SessionKey: Hashable {
    var date: LocalDate?
    var number: Int?
    /// The workout (long, wide), or for undated block rows the section.
    var group: String
}

/// Collects sets into sessions in the order they first appear.
private struct SessionBuilder {
    typealias Key = SessionKey

    let sheet: String
    var sessions: [PeakExportV1.Session] = []
    var issues: [ImportIssue] = []
    private var index: [Key: Int] = [:]
    /// Set numbers per session and exercise, to order sets by the "Set" column.
    private var orders: [Key: [String: [Int?]]] = [:]

    init(sheet: String) {
        self.sheet = sheet
    }

    mutating func add(_ sets: [PeakExportV1.SetEntry], exercise: String, order: Int?, to place: Placement) {
        let (title, note) = (place.title, place.note)
        var key = place.key
        // A dated row belongs to that day's session whatever its number: in a block sheet each exercise counts its
        // own sessions, so the same day is "2. Seans" for one and "3. Seans" for another.
        if key.date != nil {
            key.number = nil
        }
        if index[key] == nil {
            index[key] = sessions.count
            sessions.append(
                PeakExportV1.Session(date: key.date, title: title.isEmpty ? nil : title, exercises: []))
        }
        let position = index[key] ?? 0
        var session = sessions[position]
        // Sections met on the same day: "Sırt (Back) & Biceps (Pazu)".
        if !title.isEmpty, let current = session.title, !current.contains(title) {
            session.title = "\(current) & \(title)"
        }
        if !note.isEmpty {
            session.note = [session.note, note].compactMap { $0 }.joined(separator: "; ")
        }
        let exerciseKey = exercise.matchingKey
        if let existing = session.exercises.firstIndex(where: { $0.exerciseName?.matchingKey == exerciseKey }) {
            session.exercises[existing].sets = (session.exercises[existing].sets ?? []) + sets
        } else {
            session.exercises.append(PeakExportV1.SessionExercise(exerciseName: exercise, sets: sets))
        }
        if let order {
            orders[key, default: [:]][exerciseKey, default: []].append(order)
            let exerciseIndex = session.exercises.firstIndex { $0.exerciseName?.matchingKey == exerciseKey } ?? 0
            let numbers = orders[key]?[exerciseKey] ?? []
            // Reorder only when every set of this exercise has a number.
            if let entries = session.exercises[exerciseIndex].sets, numbers.count == entries.count {
                session.exercises[exerciseIndex].sets = zip(numbers, entries).sorted { ($0.0 ?? 0) < ($1.0 ?? 0) }
                    .map(\.1)
            }
        }
        sessions[position] = session
    }

    mutating func warn(row: Int, column: Int, text: String) {
        issues.append(ImportIssue(.unreadableCell(text), at: CellName.of(row: row, column: column, sheet: sheet)))
    }
}

/// "Antrenman!C7": a cell's place as a spreadsheet shows it.
enum CellName {
    static func of(row: Int, column: Int, sheet: String) -> String {
        var letters = ""
        var number = column + 1
        while number > 0 {
            let remainder = (number - 1) % 26
            letters = String(UnicodeScalar(UInt8(65 + remainder))) + letters
            number = (number - 1) / 26
        }
        return sheet.isEmpty ? "\(letters)\(row + 1)" : "\(sheet)!\(letters)\(row + 1)"
    }
}
