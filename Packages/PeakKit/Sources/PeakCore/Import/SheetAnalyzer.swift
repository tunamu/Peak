import Foundation

/// Works out how a sheet is laid out and proposes a mapping (docs/IMPORT_FORMAT.md › Spreadsheets).
///
/// 1. **Header:** among the first rows, the one whose cells name the most roles. With an exercise column and either
///    weight and reps or set cells, the sheet is long (one weight and reps column) or wide (set cells, or several
///    weight and reps pairs). Unnamed columns whose cells are mostly sets ("27.5 x 9") become set cells.
/// 2. **Block:** otherwise, rows with a lone name followed by session rows with set cells.
/// 3. Otherwise a long layout with whatever roles were found, marked unsure, so the mapping screen asks.
public enum SheetAnalyzer {
    /// How far down a header is looked for.
    static let headerSearchRows = 10

    public static func analyze(_ table: RawTable) -> SheetMapping {
        let dates = DateText.detectOrder(in: table.rows.flatMap { $0 })
        if var mapping = headerMapping(table) {
            mapping.dateOrder = dates.order
            mapping.isConfident = mapping.isConfident && dates.isSure
            return mapping
        }
        if isBlock(table) {
            return SheetMapping(
                layout: .block, headerRow: nil, roles: Array(repeating: .ignore, count: table.columnCount),
                dateOrder: dates.order, weightUnit: unit(in: table.rows.flatMap { $0 }), isConfident: dates.isSure)
        }
        let roles = guessedRoles(table)
        return SheetMapping(
            layout: .long, headerRow: nil, roles: roles, dateOrder: dates.order, weightUnit: .kg, isConfident: false)
    }

    /// The role a column name suggests ("Ağırlık (kg)" → weight), for the mapping screen's first guess.
    public static func role(ofHeader header: String) -> ColumnRole? {
        HeaderNames.role(of: header)
    }

    // MARK: Header layouts

    private static func headerMapping(_ table: RawTable) -> SheetMapping? {
        let candidates = table.rows.prefix(headerSearchRows).enumerated().map { index, row in
            (index, row.map { HeaderNames.role(of: $0) })
        }
        guard let (headerRow, named) = candidates.max(by: { named($0.1) < named($1.1) }), self.named(named) >= 2
        else { return nil }
        let data = Array(table.rows.dropFirst(headerRow + 1))
        var roles = named.map { $0 ?? .ignore }
        for column in roles.indices where roles[column] == .ignore && mostlySets(data, column: column) {
            roles[column] = .setCell
        }
        let count = { (role: ColumnRole) in roles.filter { $0 == role }.count }
        guard count(.exercise) >= 1 else { return nil }
        let hasPairs = count(.weight) >= 1 && count(.weight) == count(.reps)
        guard hasPairs || count(.setCell) >= 1 else { return nil }
        let layout: SheetLayout = count(.setCell) >= 1 || count(.weight) > 1 ? .wide : .long
        let header = table.rows[headerRow]
        let pounds =
            header.contains(where: HeaderNames.namesPounds)
            || unit(in: data.flatMap { $0 }) == .lb
        // Two exercise or date columns are a guess worth checking.
        let isConfident = count(.exercise) == 1 && count(.date) <= 1
        return SheetMapping(
            layout: layout, headerRow: headerRow, roles: roles, weightUnit: pounds ? .lb : .kg,
            isConfident: isConfident)
    }

    private static func named(_ roles: [ColumnRole?]) -> Int {
        Set(roles.compactMap { $0 }).count
    }

    /// Most non-empty cells of the column below the header are sets.
    private static func mostlySets(_ rows: [[String]], column: Int) -> Bool {
        let cells = rows.compactMap { column < $0.count ? $0[column] : nil }.filter { !SetCell.isEmpty($0) }
        guard !cells.isEmpty else { return false }
        return Double(cells.filter { SetCell.parse($0) != nil }.count) / Double(cells.count) >= 0.6
    }

    /// "lb" in set cells.
    private static func unit(in cells: [String]) -> PeakExportV1.WeightUnit {
        let units = cells.compactMap { SetCell.parse($0)?.unit }
        return units.filter { $0 == .lb }.count > units.count / 2 && !units.isEmpty ? .lb : .kg
    }

    // MARK: Block

    /// At least one lone name directly followed by a session row, and at least two session rows in all.
    private static func isBlock(_ table: RawTable) -> Bool {
        var sessions = 0
        var headedSessions = 0
        var previousWasName = false
        for row in table.rows {
            let kind = BlockRow(row)
            if case .session = kind {
                sessions += 1
                if previousWasName { headedSessions += 1 }
            }
            if case .name = kind {
                previousWasName = true
            } else if case .columnNames = kind {
                // A column name row between the name and its sessions keeps the link.
            } else {
                previousWasName = false
            }
        }
        return sessions >= 2 && headedSessions >= 1
    }

    // MARK: No header

    /// Roles from the cells alone: set cells, dates, then the first text column as the exercise.
    private static func guessedRoles(_ table: RawTable) -> [ColumnRole] {
        (0..<table.columnCount).map { column in
            let cells = table.rows.map { $0[column] }.filter { !$0.isEmpty }
            if mostlySets(table.rows, column: column) { return .setCell }
            if !cells.isEmpty, cells.allSatisfy({ DateText.find(in: $0) != nil }) { return .date }
            return .ignore
        }
    }
}

/// A row of a block sheet.
enum BlockRow: Equatable {
    /// One filled cell: an exercise, or above it a section ("Göğüs (Chest)").
    case name(String)
    /// "Tarih / Seans | 1. Set (Ağırlık x Tekrar) | …": skipped.
    case columnNames
    /// A label ("3. Seans (07.09.2026)") and set cells.
    case session(label: String, sets: [String])
    case empty
    case other

    init(_ row: [String]) {
        let filled = row.filter { !$0.isEmpty }
        if filled.isEmpty {
            self = .empty
        } else if filled.count == 1, !row[0].isEmpty, SetCell.parse(row[0]) == nil {
            self = .name(row[0])
        } else if row.dropFirst().contains(where: { SetCell.parse($0) != nil }),
            row.dropFirst().allSatisfy({ SetCell.isEmpty($0) || SetCell.parse($0) != nil })
        {
            self = .session(label: row[0], sets: Array(row.dropFirst()))
        } else if filled.contains(where: { HeaderNames.role(of: $0) != nil }) {
            self = .columnNames
        } else {
            self = .other
        }
    }
}
