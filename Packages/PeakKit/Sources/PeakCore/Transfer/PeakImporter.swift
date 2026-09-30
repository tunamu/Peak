import Foundation
import SwiftData

/// Imports a Peak JSON v1 file (docs/IMPORT_FORMAT.md › Merge and replace).
///
/// `preview` works out what the import would do without writing anything; `commit` does the same work, then writes
/// it in one save, and refuses a file with errors. In a merge, records already in the store win:
/// - Exercises, templates and routines are the same record when their id is a UUID the store has, or, for records
///   without such an id, when the store has one of that name (case and accent insensitive). Otherwise they are added.
/// - A session is a duplicate when the store has its UUID, or a session on the same day with the same movements and
///   sets. Duplicates are skipped, so importing a file twice adds nothing the second time.
/// - Sessions without a date go one day apart, in file order, before the earliest dated session (or today), and are
///   marked `isDateEstimated`. Their duplicate check ignores the day, so a later import still finds them.
///
/// Ids that are UUIDs are kept, so an export imported into an empty store is the same data (`PeakRoundTripTests`).
/// Missing fields get the app's defaults; weights in pounds are stored in kg. Settings are left to the caller.
public struct PeakImporter {
    private let context: ModelContext
    private let calendar: Calendar
    private let now: Date

    public init(context: ModelContext, calendar: Calendar = .current, now: Date = .now) {
        self.context = context
        self.calendar = calendar
        self.now = now
    }

    public func preview(_ data: PeakExportV1, mode: ImportMode = .merge) throws -> ImportPreview {
        try plan(data, mode: mode).preview
    }

    @discardableResult
    public func commit(_ data: PeakExportV1, mode: ImportMode = .merge) throws -> PeakImportSummary {
        let plan = try plan(data, mode: mode)
        guard plan.preview.canImport else { throw PeakImportError.invalid(plan.preview.errors) }
        var backup: URL?
        if case .replaceAll(let directory) = mode {
            backup = try writeBackup(to: directory)
            try deleteEverything()
        }
        var writer = Writer(plan: plan, context: context, calendar: calendar)
        var summary = writer.write()
        try context.save()
        summary.backup = backup
        return summary
    }

    private func plan(_ data: PeakExportV1, mode: ImportMode) throws -> ImportPlan {
        let store = mode == .merge ? try StoreIndex(context: context, calendar: calendar) : StoreIndex()
        return ImportPlan(data: data, store: store, calendar: calendar, now: now)
    }

    /// "peak-backup-2026-09-30-181502.json" with everything in the store, written before a replace.
    private func writeBackup(to directory: URL) throws -> URL {
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

    /// Top-level records; their children go with them (cascade).
    private func deleteEverything() throws {
        for session in try context.fetch(FetchDescriptor<WorkoutSession>()) { context.delete(session) }
        for routine in try context.fetch(FetchDescriptor<Routine>()) { context.delete(routine) }
        for template in try context.fetch(FetchDescriptor<WorkoutTemplate>()) { context.delete(template) }
        for exercise in try context.fetch(FetchDescriptor<Exercise>()) { context.delete(exercise) }
        for log in try context.fetch(FetchDescriptor<WaterLog>()) { context.delete(log) }
    }
}
