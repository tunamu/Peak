import Foundation

/// How an import meets the data already in the store.
public enum ImportMode: Equatable, Sendable {
    /// Adds what is new; records already in the store are kept as they are and duplicates are skipped.
    case merge
    /// Writes a backup of the store into `backupDirectory`, deletes everything, then adds the file.
    case replaceAll(backupDirectory: URL)
}

/// A problem found in a file, with where it is ("sessions[2].exercises[0].sets[1]"). Errors block the import;
/// warnings are shown in the preview and the import goes ahead.
public struct ImportIssue: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        /// `schema` names another format.
        case notPeakData(String)
        /// `schemaVersion` is newer than this app reads.
        case unsupportedVersion(Int)
        /// A name that is empty or only spaces.
        case blankName
        /// A session movement with neither a known `exerciseId` nor an `exerciseName`.
        case missingExercise
        /// A field below its minimum, such as negative reps or an increment of 0.
        case outOfRange(field: String)
        /// A weekday schedule without days.
        case noWeekdays
        /// `endedAt` before `startedAt`.
        case endsBeforeStart
        /// An id that names nothing in the file or the store; the link is left out.
        case unknownReference(field: String, id: String)
        /// A session without a date, placed on this day.
        case estimatedDate(LocalDate)
        /// A spreadsheet cell that could not be read ("27.5 x", an unknown date); its row is skipped.
        case unreadableCell(String)

        public var isError: Bool {
            switch self {
            case .unknownReference, .estimatedDate, .unreadableCell: false
            default: true
            }
        }
    }

    public var kind: Kind
    public var path: String

    public init(_ kind: Kind, at path: String) {
        self.kind = kind
        self.path = path
    }

    public var isError: Bool { kind.isError }
}

/// What an import would do, for the preview screen (S-10). Nothing is written to make it.
public struct ImportPreview: Equatable, Sendable {
    public var issues: [ImportIssue] = []
    /// Sessions in the file.
    public var sessions = 0
    public var newSessions = 0
    /// Sessions skipped because the store already has them.
    public var duplicateSessions = 0
    /// Sets in the new sessions.
    public var newSets = 0
    /// First and last day of the new sessions.
    public var dateRange: ClosedRange<LocalDate>?
    /// Exercises the import creates, by name.
    public var newExercises: [String] = []
    public var newTemplates = 0
    public var newRoutines = 0
    public var newWaterLogs = 0
    /// The file has settings; applying them is up to the caller (`SettingsStore.apply`).
    public var hasSettings = false

    public init() {}

    public var errors: [ImportIssue] { issues.filter(\.isError) }
    public var warnings: [ImportIssue] { issues.filter { !$0.isError } }
    public var canImport: Bool { errors.isEmpty }
}

/// What an import added.
public struct PeakImportSummary: Equatable, Sendable {
    public var exercises = 0
    public var templates = 0
    public var routines = 0
    public var sessions = 0
    public var sets = 0
    public var waterLogs = 0
    /// The backup written before a replace.
    public var backup: URL?

    public init() {}
}

public enum PeakImportError: Error, Equatable {
    /// The file has errors; nothing was written.
    case invalid([ImportIssue])
}
