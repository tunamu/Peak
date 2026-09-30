import PeakCore
import PeakDesign
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Settings › Import Workout Data, for Peak JSON files: pick a file, see what it adds, confirm, and it is merged
/// (`PeakImporter`, docs/IMPORT_FORMAT.md). Workouts already in Peak are skipped, so a file can be imported again
/// safely. Spreadsheets, the mapping screen and the full preview (S-10) arrive with F7-06.
struct ImportDataRow: View {
    /// A file read and checked, waiting for the user's yes.
    struct Pending {
        let data: PeakExportV1
        let preview: ImportPreview
    }

    enum Outcome {
        case imported(sessions: Int)
        case nothingNew
        case failed(Text)
    }

    @Environment(\.modelContext) private var modelContext
    @State private var isPicking = false
    @State private var pending: Pending?
    @State private var outcome: Outcome?

    var body: some View {
        SettingsRow("Import Workout Data", accessory: .icon("square.and.arrow.down")) { isPicking = true }
            .fileImporter(isPresented: $isPicking, allowedContentTypes: [.json]) { result in
                if case .success(let url) = result { read(url) }
            }
            .alert("Import Workouts?", isPresented: isPresent($pending), presenting: pending) { pending in
                Button("Import") { commit(pending) }
                Button("Cancel", role: .cancel) {}
            } message: { pending in
                summary(pending.preview)
            }
            .alert(title, isPresented: isPresent($outcome), presenting: outcome) { _ in
                Button("OK", role: .cancel) {}
            } message: { outcome in
                message(outcome)
            }
            #if DEBUG
                // Screenshot helpers: `-PeakImportFile /path/file.json` reads that file as if it was picked, and
                // `-PeakImportConfirm YES` also taps Import.
                .task {
                    guard let path = UserDefaults.standard.string(forKey: "PeakImportFile") else { return }
                    read(URL(filePath: path))
                    if UserDefaults.standard.bool(forKey: "PeakImportConfirm"), let pending {
                        self.pending = nil
                        commit(pending)
                    }
                }
            #endif
    }

    // MARK: Steps

    private func read(_ url: URL) {
        let isScoped = url.startAccessingSecurityScopedResource()
        defer { if isScoped { url.stopAccessingSecurityScopedResource() } }
        guard let bytes = try? Data(contentsOf: url), let data = try? PeakJSON.decode(bytes) else {
            outcome = .failed(Text("This file is not Peak JSON. Excel and CSV files arrive in a later update."))
            return
        }
        do {
            let preview = try PeakImporter(context: modelContext).preview(data)
            if let error = preview.errors.first {
                outcome = .failed(Text("Problems in the file: \(preview.errors.count). The first is at \(error.path)."))
            } else if preview.newSessions == 0 && preview.newExercises.isEmpty {
                outcome = .nothingNew
            } else {
                pending = Pending(data: data, preview: preview)
            }
        } catch {
            outcome = .failed(Text(verbatim: error.localizedDescription))
        }
    }

    private func commit(_ pending: Pending) {
        do {
            let summary = try PeakImporter(context: modelContext).commit(pending.data)
            outcome = .imported(sessions: summary.sessions)
        } catch {
            outcome = .failed(Text(verbatim: error.localizedDescription))
        }
    }

    // MARK: Text

    private func summary(_ preview: ImportPreview) -> Text {
        let (new, sets, known) = (preview.newSessions, preview.newSets, preview.duplicateSessions)
        var text = Text("Workouts: \(new) new (\(sets) sets), \(known) already in Peak.")
        // A few names help; a long list (a first import) would fill the alert.
        let exercises = preview.newExercises
        if exercises.count > 3 {
            text = text + Text(verbatim: "\n") + Text("New exercises: \(exercises.count)")
        } else if !exercises.isEmpty {
            text = text + Text(verbatim: "\n") + Text("New exercises: \(exercises.formatted(.list(type: .and)))")
        }
        if !preview.warnings.isEmpty {
            text = text + Text(verbatim: "\n") + Text("Warnings: \(preview.warnings.count)")
        }
        return text
    }

    private var title: LocalizedStringKey {
        switch outcome {
        case .imported: "Imported"
        case .nothingNew: "Nothing to Import"
        case .failed, nil: "Import Failed"
        }
    }

    private func message(_ outcome: Outcome) -> Text {
        switch outcome {
        case .imported(let sessions): Text("Workouts added: \(sessions)")
        case .nothingNew: Text("Every workout in this file is already in Peak.")
        case .failed(let text): text
        }
    }

    private func isPresent<Value>(_ value: Binding<Value?>) -> Binding<Bool> {
        Binding(get: { value.wrappedValue != nil }, set: { if !$0 { value.wrappedValue = nil } })
    }
}
