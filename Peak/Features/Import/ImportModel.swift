import Foundation
import Observation
import PeakCore
import SwiftData

/// The state behind the import screen (S-10): the file and its mapping (`ImportDraft`), what it would add
/// (`ImportPreview`), and the user's choices. Every change reconverts the sheet and refreshes the preview.
@MainActor
@Observable
final class ImportModel: Identifiable {
    enum Mode: Hashable {
        case merge, replaceAll
    }

    let id = UUID()
    var draft: ImportDraft {
        didSet { refresh() }
    }
    var mode = Mode.merge {
        didSet { refresh() }
    }
    /// Applies the file's settings too (Peak JSON exports carry them).
    var appliesSettings = false
    private(set) var converted: SheetConverter.Result = (PeakExportV1(sessions: []), [])
    private(set) var preview = ImportPreview()
    @ObservationIgnored private let context: ModelContext

    /// Where a replace writes its backup first: Files › On My iPhone › Peak › Backups.
    static var backupDirectory: URL {
        URL.documentsDirectory.appending(path: "Backups", directoryHint: .isDirectory)
    }

    init(draft: ImportDraft, context: ModelContext) {
        self.draft = draft
        self.context = context
        refresh()
    }

    var fileSettings: PeakExportV1.Settings? { converted.data.settings }

    /// Something to import, and nothing blocking it.
    var canImport: Bool {
        guard preview.canImport else { return false }
        let adds =
            preview.newSessions + preview.newTemplates + preview.newRoutines + preview.newWaterLogs
            + preview.newExercises.count
        return adds > 0 || (appliesSettings && fileSettings != nil) || mode == .replaceAll
    }

    /// Cells that could not be read, then the importer's own findings.
    var issues: [ImportIssue] {
        converted.issues + preview.issues
    }

    func commit(settings: SettingsStore) throws -> PeakImportSummary {
        let summary = try PeakImporter(context: context).commit(converted.data, mode: importMode)
        if appliesSettings, let fileSettings {
            settings.apply(fileSettings)
        }
        return summary
    }

    private var importMode: ImportMode {
        switch mode {
        case .merge: .merge
        case .replaceAll: .replaceAll(backupDirectory: Self.backupDirectory)
        }
    }

    private func refresh() {
        converted = draft.converted()
        preview = (try? PeakImporter(context: context).preview(converted.data, mode: importMode)) ?? ImportPreview()
    }
}
