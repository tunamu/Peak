import Foundation
import PeakCore
import SwiftUI

/// The words of the import screen: role names, problem descriptions, and one-line sessions for the preview.
enum ImportText {
    static let tableHint: LocalizedStringKey =
        "One row per set, or per exercise with sets across. Give each column its role; Ignore leaves it out."
    static let blockHint: LocalizedStringKey =
        "An exercise name alone on a row, then one row per session with its sets, as in the /coach history."

    static let unsureNotice: LocalizedStringKey = "Check the columns: Peak is not sure how this file is laid out."
    static let replaceWarning: LocalizedStringKey =
        "Everything in Peak is replaced with this file. A backup is saved first in Files › Peak › Backups."
    static let problemsFooter: LocalizedStringKey =
        "Warnings do not stop the import; errors must be fixed in the file first."

    static func name(of role: ColumnRole) -> LocalizedStringKey {
        switch role {
        case .date: "Date"
        case .exercise: "Exercise"
        case .setNumber: "Set #"
        case .weight: "Weight"
        case .reps: "Reps"
        case .setCell: "Set (27.5 x 9)"
        case .workout: "Workout"
        case .note: "Note"
        case .ignore: "Ignore"
        }
    }

    /// The column's name in the header row, else its letter ("Column C").
    static func columnName(_ column: Int, in table: RawTable, headerRow: Int?) -> String {
        if let headerRow, table.rows.indices.contains(headerRow), !table.rows[headerRow][column].isEmpty {
            return table.rows[headerRow][column]
        }
        return String(localized: "Column \(letters(column))")
    }

    static func letters(_ column: Int) -> String {
        var letters = ""
        var number = column + 1
        while number > 0 {
            letters = String(UnicodeScalar(UInt8(65 + (number - 1) % 26))) + letters
            number = (number - 1) / 26
        }
        return letters
    }

    /// "Mon, 28 Sep · Chest & Biceps", or "No date · …" for a session Peak will place.
    static func heading(of session: PeakExportV1.Session) -> String {
        let day = session.date?.date().map { $0.formatted(.dateTime.weekday(.abbreviated).day().month()) }
        let parts = [day ?? String(localized: "No date"), session.title].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.joined(separator: " · ")
    }

    /// "Row 60×8, 55×9 · Fly 50×7".
    static func sets(of session: PeakExportV1.Session, unit: PeakExportV1.WeightUnit) -> String {
        session.exercises.map { exercise in
            let sets = (exercise.sets ?? []).map {
                "\($0.weight.formatted(.number.precision(.fractionLength(0...2))))×\($0.reps)"
            }
            return ([exercise.exerciseName ?? "?"] + [sets.joined(separator: ", ")]).joined(separator: " ")
        }
        .joined(separator: " · ") + (unit == .lb ? " (lb)" : "")
    }

    static func range(_ range: ClosedRange<LocalDate>) -> String {
        let format = Date.FormatStyle.dateTime.day().month().year()
        let first = range.lowerBound.date().map { $0.formatted(format) } ?? range.lowerBound.description
        let last = range.upperBound.date().map { $0.formatted(format) } ?? range.upperBound.description
        return first == last ? first : "\(first) – \(last)"
    }

    static func describe(_ kind: ImportIssue.Kind) -> Text {
        switch kind {
        case .notPeakData(let schema): Text("Not a Peak file (“\(schema)”)")
        case .unsupportedVersion(let version): Text("Made by a newer Peak (version \(version))")
        case .blankName: Text("A name is empty")
        case .missingExercise: Text("A movement has no exercise name")
        case .outOfRange(let field): Text("“\(field)” is out of range")
        case .noWeekdays: Text("A routine has no days")
        case .endsBeforeStart: Text("A workout ends before it starts")
        case .unknownReference(_, let id): Text("“\(id)” was not found; the link is left out")
        case .estimatedDate(let day): Text("No date; placed on \(range(day...day))")
        case .unreadableCell(let text): Text("Could not read “\(text)”; the row is left out")
        }
    }
}
