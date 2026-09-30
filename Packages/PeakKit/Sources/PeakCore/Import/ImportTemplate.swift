import Foundation
import ZIPFoundation

/// Ready-to-fill import templates in English and Turkish: Excel and CSV in the long layout (one row per set), and the
/// same workouts as Peak JSON (docs/import-templates/). The app shares them from Settings; the files in the repository
/// are the same bytes (`ImportTemplateTests`).
///
/// Each follows its language's conventions, so a spreadsheet app opens it as its users expect: the Turkish CSV uses
/// `;`, decimal commas and day-first dates, with a byte order mark so Excel reads it as UTF-8. The Excel files hold
/// real dates and numbers, shown in the phone's or computer's own format.
public enum ImportTemplate {
    public enum Language: String, CaseIterable, Sendable {
        case english = "en"
        case turkish = "tr"

        /// Turkish for a Turkish device, English otherwise.
        public init(locale: Locale) {
            self = locale.language.languageCode?.identifier == "tr" ? .turkish : .english
        }
    }

    public enum Format: String, CaseIterable, Sendable {
        case xlsx, csv, json
    }

    /// "peak-template.xlsx", "peak-sablon.csv".
    public static func fileName(_ format: Format, language: Language) -> String {
        "\(language == .turkish ? "peak-sablon" : "peak-template").\(format.rawValue)"
    }

    public static func data(_ format: Format, language: Language) throws -> Data {
        switch format {
        case .csv: csv(language)
        case .xlsx: try xlsx(language)
        case .json: try json(language)
        }
    }

    // MARK: Content

    struct Row {
        var date: LocalDate
        var workout: String
        var exercise: String
        var set: Int
        var weight: Double
        var reps: Int
        var note: String
    }

    static func header(_ language: Language) -> [String] {
        switch language {
        case .english: ["Date", "Workout", "Exercise", "Set", "Weight (kg)", "Reps", "Note"]
        case .turkish: ["Tarih", "Antrenman", "Hareket", "Set", "Ağırlık (kg)", "Tekrar", "Not"]
        }
    }

    /// Two example workouts, to be replaced with the user's own.
    static func rows(_ language: Language) -> [Row] {
        let note = language == .turkish ? "Bu örnek satırları kendi antrenmanlarınla değiştir" : "Replace these rows"
        let monday = LocalDate(year: 2026, month: 9, day: 28)
        let wednesday = LocalDate(year: 2026, month: 9, day: 30)
        return [
            Row(
                date: monday, workout: "Chest & Biceps", exercise: "Dumbbell Chest Press", set: 1, weight: 27.5,
                reps: 9, note: note),
            Row(
                date: monday, workout: "Chest & Biceps", exercise: "Dumbbell Chest Press", set: 2, weight: 22.5,
                reps: 13, note: ""),
            Row(
                date: monday, workout: "Chest & Biceps", exercise: "Incline Dumbbell Curl", set: 1, weight: 15, reps: 9,
                note: ""),
            Row(
                date: wednesday, workout: "Back & Triceps", exercise: "Lat Pulldown", set: 1, weight: 60, reps: 8,
                note: ""),
            Row(
                date: wednesday, workout: "Back & Triceps", exercise: "Lat Pulldown", set: 2, weight: 55, reps: 9,
                note: ""),
        ]
    }

    // MARK: JSON

    /// The example workouts as Peak JSON: exercises with their muscle group and increment, then sessions by day.
    static func json(_ language: Language) throws -> Data {
        let exercises: [PeakExportV1.Exercise] = [
            .init(
                name: "Dumbbell Chest Press", muscleGroup: .chest, kind: .strength, equipment: .dumbbell,
                incrementKg: 2.5),
            .init(
                name: "Incline Dumbbell Curl", muscleGroup: .biceps, kind: .strength, equipment: .dumbbell,
                incrementKg: 2.5),
            .init(name: "Lat Pulldown", muscleGroup: .back, kind: .strength, equipment: .machine, incrementKg: 5),
        ]
        var sessions: [PeakExportV1.Session] = []
        for row in rows(language) {
            if sessions.last?.date != row.date {
                sessions.append(PeakExportV1.Session(date: row.date, title: row.workout, exercises: []))
            }
            var session = sessions.removeLast()
            if !row.note.isEmpty {
                session.note = row.note
            }
            let set = PeakExportV1.SetEntry(weight: row.weight, reps: row.reps)
            if let index = session.exercises.firstIndex(where: { $0.exerciseName == row.exercise }) {
                session.exercises[index].sets?.append(set)
            } else {
                session.exercises.append(PeakExportV1.SessionExercise(exerciseName: row.exercise, sets: [set]))
            }
            sessions.append(session)
        }
        let file = PeakExportV1(units: .init(weight: .kg), exercises: exercises, sessions: sessions)
        return try PeakJSON.encode(file)
    }

    // MARK: CSV

    static func csv(_ language: Language) -> Data {
        let turkish = language == .turkish
        let delimiter = turkish ? ";" : ","
        let lines =
            [header(language)]
            + rows(language).map { row in
                let date =
                    turkish
                    ? String(format: "%02d.%02d.%04d", row.date.day, row.date.month, row.date.year)
                    : row.date.description
                var weight = number(row.weight)
                if turkish { weight = weight.replacingOccurrences(of: ".", with: ",") }
                return [date, row.workout, row.exercise, String(row.set), weight, String(row.reps), row.note]
            }
        let text =
            lines.map { $0.map { quoted($0, delimiter: delimiter) }.joined(separator: delimiter) }
            .joined(separator: "\r\n") + "\r\n"
        return Data([0xEF, 0xBB, 0xBF]) + Data(text.utf8)
    }

    private static func quoted(_ field: String, delimiter: String) -> String {
        guard field.contains(delimiter) || field.contains("\"") || field.contains("\n") else { return field }
        return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    /// "27.5", "60".
    private static func number(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }

    // MARK: XLSX

    /// A fixed time for the ZIP entries, so the same template is the same bytes.
    private static let entryDate = Date(timeIntervalSince1970: 1_790_000_000)

    static func xlsx(_ language: Language) throws -> Data {
        let archive = try Archive(accessMode: .create)
        let sheetName = language == .turkish ? "Antrenmanlar" : "Workouts"
        let parts: [(String, String)] = [
            ("[Content_Types].xml", XLSXParts.contentTypes),
            ("_rels/.rels", XLSXParts.rootRelations),
            ("xl/workbook.xml", XLSXParts.workbook(sheetName: sheetName)),
            ("xl/_rels/workbook.xml.rels", XLSXParts.workbookRelations),
            ("xl/styles.xml", XLSXParts.styles),
            ("xl/worksheets/sheet1.xml", sheet(language)),
        ]
        for (path, xml) in parts {
            let bytes = Data(xml.utf8)
            try archive.addEntry(
                with: path, type: .file, uncompressedSize: Int64(bytes.count), modificationDate: entryDate,
                compressionMethod: .deflate
            ) { position, size in
                bytes.subdata(in: Int(position)..<min(bytes.count, Int(position) + size))
            }
        }
        guard let data = archive.data else { throw CocoaError(.fileWriteUnknown) }
        return data
    }

    /// Header in bold (style 1), dates as Excel dates (style 2), weights and reps as numbers, text inline.
    private static func sheet(_ language: Language) -> String {
        var lines = [XLSXParts.row(1, header(language).map { .text($0, style: 1) })]
        for (index, row) in rows(language).enumerated() {
            lines.append(
                XLSXParts.row(
                    index + 2,
                    [
                        .number(Double(serial(row.date)), style: 2), .text(row.workout), .text(row.exercise),
                        .number(Double(row.set)), .number(row.weight), .number(Double(row.reps)), .text(row.note),
                    ]))
        }
        return XLSXParts.worksheet(rows: lines, widths: [12, 18, 26, 6, 12, 8, 44])
    }

    /// Days since 1899-12-30, Excel's day 0.
    private static func serial(_ date: LocalDate) -> Int {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        guard let start = utc.date(from: DateComponents(year: 1899, month: 12, day: 30)), let day = date.date(in: utc)
        else { return 0 }
        return utc.dateComponents([.day], from: start, to: day).day ?? 0
    }
}
