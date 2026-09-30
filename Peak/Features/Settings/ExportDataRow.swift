import PeakCore
import PeakDesign
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Settings › Export Workout Data: writes everything as Peak JSON and lets the user save it with the system file
/// exporter (Files, iCloud Drive, another app's folder). Format: docs/IMPORT_FORMAT.md.
struct ExportDataRow: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SettingsStore.self) private var settings
    @State private var document: PeakJSONDocument?
    @State private var failure: String?

    var body: some View {
        SettingsRow("Export Workout Data", accessory: .icon("square.and.arrow.up")) { prepare() }
            .fileExporter(
                isPresented: Binding(get: { document != nil }, set: { if !$0 { document = nil } }),
                document: document,
                contentType: .json,
                defaultFilename: PeakExporter.fileName()
            ) { result in
                if case .failure(let error) = result, (error as? CocoaError)?.code != .userCancelled {
                    failure = error.localizedDescription
                }
            }
            .alert(
                "Export Failed",
                isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(verbatim: failure ?? "")
            }
            #if DEBUG
                // Screenshot helper: `-PeakExport YES` taps the row.
                .task {
                    if UserDefaults.standard.bool(forKey: "PeakExport") { prepare() }
                }
            #endif
    }

    private func prepare() {
        do {
            let data = try PeakExporter(context: modelContext).export(settings: settings.transferSettings)
            document = PeakJSONDocument(data: try PeakJSON.encode(data))
        } catch {
            failure = error.localizedDescription
        }
    }
}

/// A Peak JSON file for the file exporter.
struct PeakJSONDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json]

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
