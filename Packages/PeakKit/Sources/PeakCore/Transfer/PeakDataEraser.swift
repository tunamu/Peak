import Foundation
import SwiftData

/// What the store holds, counted for the "Delete All Data" screen.
public struct StoreContents: Equatable, Sendable {
    public var sessions = 0
    public var templates = 0
    public var routines = 0
    public var exercises = 0
    public var waterLogs = 0

    public init(sessions: Int = 0, templates: Int = 0, routines: Int = 0, exercises: Int = 0, waterLogs: Int = 0) {
        self.sessions = sessions
        self.templates = templates
        self.routines = routines
        self.exercises = exercises
        self.waterLogs = waterLogs
    }

    public var isEmpty: Bool { self == StoreContents() }
}

/// Deletes everything in the store, after writing a backup that imports back (Settings › Delete All Data, and an
/// import's "replace all"). Settings are not store data and stay; so does what Peak saved to Apple Health.
public struct PeakDataEraser {
    private let context: ModelContext
    private let calendar: Calendar
    private let now: Date

    public init(context: ModelContext, calendar: Calendar = .current, now: Date = .now) {
        self.context = context
        self.calendar = calendar
        self.now = now
    }

    /// Whether the user typed the confirmation word ("DELETE", "SİL"), ignoring case, accents and spaces, so "sil" and
    /// "SİL" both count.
    public static func isConfirmed(typed: String, word: String) -> Bool {
        !word.matchingKey.isEmpty && typed.matchingKey == word.matchingKey
    }

    public func contents() throws -> StoreContents {
        StoreContents(
            sessions: try context.fetchCount(FetchDescriptor<WorkoutSession>()),
            templates: try context.fetchCount(FetchDescriptor<WorkoutTemplate>()),
            routines: try context.fetchCount(FetchDescriptor<Routine>()),
            exercises: try context.fetchCount(FetchDescriptor<Exercise>()),
            waterLogs: try context.fetchCount(FetchDescriptor<WaterLog>())
        )
    }

    /// Writes the backup, deletes everything and saves. Nothing is deleted if the backup cannot be written.
    /// - Returns: The backup file.
    @discardableResult
    public func eraseAll(backupDirectory: URL) throws -> URL {
        let backup = try writeBackup(to: backupDirectory)
        try deleteEverything()
        try context.save()
        return backup
    }

    /// "peak-backup-2026-09-30-181502.json" with everything in the store, in Peak JSON.
    func writeBackup(to directory: URL) throws -> URL {
        let data = try PeakJSON.encode(
            PeakExporter(context: context, calendar: calendar).export(settings: nil, at: now))
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: now)
        let stamp = String(
            format: "%04d-%02d-%02d-%02d%02d%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0, parts.hour ?? 0,
            parts.minute ?? 0, parts.second ?? 0)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: "peak-backup-\(stamp).json")
        try data.write(to: url, options: .atomic)
        return url
    }

    /// Deletes object by object rather than in a batch, so iCloud sync sees every deletion. Top-level records; their
    /// children go with them (cascade). Does not save.
    func deleteEverything() throws {
        for session in try context.fetch(FetchDescriptor<WorkoutSession>()) { context.delete(session) }
        for routine in try context.fetch(FetchDescriptor<Routine>()) { context.delete(routine) }
        for template in try context.fetch(FetchDescriptor<WorkoutTemplate>()) { context.delete(template) }
        for exercise in try context.fetch(FetchDescriptor<Exercise>()) { context.delete(exercise) }
        for log in try context.fetch(FetchDescriptor<WaterLog>()) { context.delete(log) }
    }
}
