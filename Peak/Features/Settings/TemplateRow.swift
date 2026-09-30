import PeakCore
import PeakDesign
import SwiftUI
import UniformTypeIdentifiers

/// Settings › Import Template: an Excel, CSV or Peak JSON file with two example workouts, in the phone's language
/// (docs/import-templates/). Filled in and picked in Import Workout Data, it imports without questions.
struct TemplateRow: View {
    @State private var isChoosing = false
    @State private var file: ExportedFile?
    @State private var failure: String?

    var body: some View {
        SettingsRow("Import Template", accessory: .icon("tablecells")) { isChoosing = true }
            .confirmationDialog("Import Template", isPresented: $isChoosing, titleVisibility: .visible) {
                Button("Excel (.xlsx)") { prepare(.xlsx) }
                Button("CSV") { prepare(.csv) }
                Button("Peak JSON") { prepare(.json) }
            } message: {
                Text("A spreadsheet with the columns Peak reads and two example workouts to replace with yours.")
            }
            .fileExporter(
                isPresented: Binding(get: { file != nil }, set: { if !$0 { file = nil } }),
                document: file,
                contentType: file?.contentType ?? .data,
                defaultFilename: file?.name
            ) { result in
                if case .failure(let error) = result, (error as? CocoaError)?.code != .userCancelled {
                    failure = error.localizedDescription
                }
            }
            .alert("Export Failed", isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(verbatim: failure ?? "")
            }
            #if DEBUG
                // Screenshot helper: `-PeakTemplate xlsx|csv|json` chooses that template.
                .task {
                    let format = UserDefaults.standard.string(forKey: "PeakTemplate").flatMap(
                        ImportTemplate.Format.init)
                    if let format { prepare(format) }
                }
            #endif
    }

    private func contentType(_ format: ImportTemplate.Format) -> UTType {
        switch format {
        case .xlsx: ExportedFile.xlsx
        case .csv: .commaSeparatedText
        case .json: .json
        }
    }

    private func prepare(_ format: ImportTemplate.Format) {
        let language = ImportTemplate.Language(locale: .current)
        do {
            file = ExportedFile(
                data: try ImportTemplate.data(format, language: language),
                contentType: contentType(format),
                name: ImportTemplate.fileName(format, language: language))
        } catch {
            failure = error.localizedDescription
        }
    }
}
