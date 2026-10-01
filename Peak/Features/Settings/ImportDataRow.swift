import PeakCore
import PeakDesign
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Settings › Import Workout Data: pick a Peak JSON, Excel, CSV or TSV file, check how it is read and what it adds
/// (S-10, `ImportSheet`), import, and see the result (S-09). docs/IMPORT_FORMAT.md.
struct ImportDataRow: View {
    /// S-09's content.
    struct Result: Identifiable {
        let id = UUID()
        let kind: ResultKind
        let title: LocalizedStringKey
        let message: Text
    }

    static let fileTypes: [UTType] = [
        .json, .commaSeparatedText, .tabSeparatedText, .delimitedText, .plainText,
        UTType("org.openxmlformats.spreadsheetml.sheet") ?? .data,
    ]

    @Environment(\.modelContext) private var modelContext
    @Environment(SettingsStore.self) private var settings
    @State private var isPicking = false
    @State private var router = LinkRouter.shared
    @State private var model: ImportModel?
    @State private var result: Result?
    /// Shown once the import sheet has closed: SwiftUI presents one sheet at a time.
    @State private var pendingResult: Result?

    var body: some View {
        SettingsRow("Import Workout Data", accessory: .icon("square.and.arrow.down")) { isPicking = true }
            .fileImporter(isPresented: $isPicking, allowedContentTypes: Self.fileTypes) { picked in
                if case .success(let url) = picked { open(url) }
            }
            .onChange(of: router.opensImportPicker, initial: true) {
                guard router.opensImportPicker else { return }
                router.opensImportPicker = false
                isPicking = true
            }
            .sheet(item: $model, onDismiss: showPendingResult) { model in
                ImportSheet(model: model) { outcome in
                    pendingResult = Self.result(of: outcome)
                    self.model = nil
                }
            }
            .sheet(item: $result) { result in
                ResultSheet(result.kind, title: result.title, message: result.message) {
                    Button(role: .confirm) {
                        self.result = nil
                    } label: {
                        Text("Done").frame(maxWidth: .infinity)
                    }
                }
            }
            #if DEBUG
                // Screenshot helpers: `-PeakImportFile /path/file` opens that file as if it was picked, and
                // `-PeakImportConfirm YES` also imports it (merge).
                .task {
                    guard let path = UserDefaults.standard.string(forKey: "PeakImportFile") else { return }
                    open(URL(filePath: path))
                    // As a tap on Import would: the sheet is up, then closes, then S-09 shows.
                    guard UserDefaults.standard.bool(forKey: "PeakImportConfirm") else { return }
                    try? await Task.sleep(for: .seconds(1))
                    guard let model else { return }
                    let outcome: ImportOutcome
                    do {
                        outcome = .imported(try model.commit(settings: settings))
                    } catch {
                        outcome = .failed(Text(verbatim: error.localizedDescription))
                    }
                    pendingResult = Self.result(of: outcome)
                    self.model = nil
                }
            #endif
    }

    private func open(_ url: URL) {
        let isScoped = url.startAccessingSecurityScopedResource()
        defer { if isScoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let draft = try ImportDraft.load(Data(contentsOf: url), fileName: url.lastPathComponent)
            model = ImportModel(draft: draft, context: modelContext)
        } catch let error as ImportFileError {
            result = Result(kind: .failure, title: "Import Failed", message: Self.message(for: error))
        } catch {
            result = Result(kind: .failure, title: "Import Failed", message: Text(verbatim: error.localizedDescription))
        }
    }

    private func showPendingResult() {
        result = pendingResult
        pendingResult = nil
    }

    private static func result(of outcome: ImportOutcome) -> Result {
        switch outcome {
        case .imported(let summary):
            let backup = summary.backup.map { _ in Text(verbatim: "\n") + Text("A backup was saved first.") }
            return Result(
                kind: .success, title: "Import Complete",
                message: Text("Workouts added: \(summary.sessions)") + (backup ?? Text(verbatim: "")))
        case .failed(let message):
            return Result(kind: .failure, title: "Import Failed", message: message)
        }
    }

    private static func message(for error: ImportFileError) -> Text {
        switch error {
        case .notPeakJSON: Text("This JSON file is not Peak data.")
        case .invalidJSON(let detail): Text("The Peak file is damaged: \(detail)")
        case .damagedWorkbook: Text("The Excel file is damaged. Open it in Excel or Numbers and save it again.")
        case .tooLarge: Text("The file is too large for a training log.")
        case .notASpreadsheet: Text("This is not a spreadsheet. Use Peak JSON, Excel (.xlsx), CSV or TSV.")
        case .legacyExcel: Text("Old Excel files (.xls) cannot be read. Save it as .xlsx in Excel or Numbers.")
        case .empty: Text("The file has no rows to import.")
        case .unreadable: Text("Peak cannot read this file. Use Peak JSON, Excel (.xlsx), CSV or TSV.")
        }
    }
}
