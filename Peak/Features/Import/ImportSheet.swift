import PeakCore
import PeakDesign
import SwiftUI

/// S-10 (not in the design): how a picked file will be read, and what it adds, before anything is written.
///
/// Spreadsheets show the sheet, layout and column roles the analyzer chose (docs/IMPORT_FORMAT.md › Spreadsheets),
/// each changeable, with the first sessions as they will be imported. Every file shows the summary (new and known
/// workouts, sets, dates, new exercises, problems) and the choice between merging and replacing everything.
struct ImportSheet: View {
    @Bindable var model: ImportModel
    /// Called after the import with its outcome; the presenter closes the sheet and shows S-09.
    let onFinish: (ImportOutcome) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(SettingsStore.self) private var settings
    @State private var isReplaceConfirmationShown = false

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                List {
                    if let mapping = model.draft.mapping, !mapping.isConfident {
                        Section {
                            Label(ImportText.unsureNotice, systemImage: "questionmark.circle")
                                .foregroundStyle(.peakTextSecondary)
                        }
                    }
                    fileSection
                    if model.draft.mapping != nil {
                        mappingSection
                        previewSection.id("preview")
                    }
                    summarySection.id("summary")
                    if !model.issues.isEmpty {
                        issuesSection.id("problems")
                    }
                    modeSection.id("mode")
                }
                #if DEBUG
                    // Screenshot helper: `-PeakImportScroll preview|summary|mode` scrolls to that section.
                    .task {
                        guard let section = UserDefaults.standard.string(forKey: "PeakImportScroll") else { return }
                        try? await Task.sleep(for: .milliseconds(300))
                        proxy.scrollTo(section, anchor: .top)
                    }
                #endif
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Import")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                SheetActionBar(cancel: "Cancel", confirm: "Import", isConfirmEnabled: model.canImport) {
                    dismiss()
                } onConfirm: {
                    if model.mode == .replaceAll {
                        isReplaceConfirmationShown = true
                    } else {
                        commit()
                    }
                }
            }
            .confirmationDialog(
                "Replace all data?", isPresented: $isReplaceConfirmationShown, titleVisibility: .visible
            ) {
                Button("Replace All", role: .destructive) { commit() }
            } message: {
                Text(ImportText.replaceWarning)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func commit() {
        do {
            onFinish(.imported(try model.commit(settings: settings)))
        } catch {
            onFinish(.failed(Text(verbatim: error.localizedDescription)))
        }
    }

    // MARK: File and mapping

    private var fileSection: some View {
        Section {
            LabeledContent("File", value: model.draft.fileName)
            if model.draft.sheets.count > 1 {
                Picker(
                    "Sheet", selection: Binding(get: { model.draft.sheetIndex }, set: { model.draft.selectSheet($0) })
                ) {
                    ForEach(model.draft.sheets.indices, id: \.self) { index in
                        Text(verbatim: model.draft.sheets[index].name).tag(index)
                    }
                }
            }
            if let format = model.draft.csvFormat {
                Picker(
                    "Separator", selection: Binding(get: { format.delimiter }, set: { model.draft.setDelimiter($0) })
                ) {
                    ForEach(CSVReader.delimiters, id: \.self) { delimiter in
                        Text(verbatim: delimiter == "\t" ? "Tab" : String(delimiter)).tag(delimiter)
                    }
                }
                Picker(
                    "Decimal Separator",
                    selection: Binding(get: { format.decimalSeparator }, set: { model.draft.setDecimalSeparator($0) })
                ) {
                    Text(verbatim: "27,5").tag(Character(","))
                    Text(verbatim: "27.5").tag(Character("."))
                }
            }
        }
    }

    @ViewBuilder
    private var mappingSection: some View {
        if let mapping = model.draft.mapping, let table = model.draft.table {
            Section {
                Picker("Layout", selection: layoutBinding) {
                    Text("Table").tag(false)
                    Text("Blocks").tag(true)
                }
                .pickerStyle(.segmented)
                if mapping.layout != .block {
                    Picker("Column Names", selection: headerBinding) {
                        Text("None").tag(Int?.none)
                        ForEach(0..<min(10, table.rows.count), id: \.self) { row in
                            Text("Row \(row + 1)").tag(Int?.some(row))
                        }
                    }
                    ForEach(0..<table.columnCount, id: \.self) { column in
                        Picker(selection: roleBinding(column)) {
                            ForEach(ColumnRole.allCases, id: \.self) { role in
                                Text(ImportText.name(of: role)).tag(role)
                            }
                        } label: {
                            Text(verbatim: ImportText.columnName(column, in: table, headerRow: mapping.headerRow))
                        }
                    }
                }
                Picker("Dates", selection: mappingBinding(\.dateOrder, default: .dayMonthYear)) {
                    Text(verbatim: "31.12.2026").tag(DateOrder.dayMonthYear)
                    Text(verbatim: "12/31/2026").tag(DateOrder.monthDayYear)
                    Text(verbatim: "2026-12-31").tag(DateOrder.yearMonthDay)
                }
                Picker("Weight Unit", selection: mappingBinding(\.weightUnit, default: .kg)) {
                    Text(verbatim: "kg").tag(PeakExportV1.WeightUnit.kg)
                    Text(verbatim: "lb").tag(PeakExportV1.WeightUnit.lb)
                }
                .pickerStyle(.segmented)
            } header: {
                Text("How to Read It")
            } footer: {
                Text(mapping.layout == .block ? ImportText.blockHint : ImportText.tableHint)
            }
        }
    }

    private var previewSection: some View {
        Section {
            let sessions = model.converted.data.sessions.prefix(5)
            if sessions.isEmpty {
                Text("Nothing to import with these settings.")
                    .foregroundStyle(.peakTextSecondary)
            }
            ForEach(Array(sessions.enumerated()), id: \.offset) { _, session in
                VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                    Text(ImportText.heading(of: session))
                        .font(.peakRow.weight(.semibold))
                    Text(verbatim: ImportText.sets(of: session, unit: model.draft.mapping?.weightUnit ?? .kg))
                        .font(.peakDetail)
                        .foregroundStyle(.peakTextSecondary)
                        .lineLimit(3)
                }
            }
        } header: {
            Text("First Workouts")
        }
    }

    // MARK: Summary

    private var summarySection: some View {
        Section {
            let preview = model.preview
            LabeledContent("New Workouts", value: preview.newSessions, format: .number)
            LabeledContent("Already in Peak", value: preview.duplicateSessions, format: .number)
            LabeledContent("Sets", value: preview.newSets, format: .number)
            if let range = preview.dateRange {
                LabeledContent("Dates") {
                    Text(verbatim: ImportText.range(range))
                }
            }
            if !preview.newExercises.isEmpty {
                LabeledContent("New Exercises") {
                    Text(verbatim: preview.newExercises.formatted(.list(type: .and)))
                        .multilineTextAlignment(.trailing)
                }
            }
        } header: {
            Text("Summary")
        }
    }

    private var issuesSection: some View {
        Section {
            ForEach(Array(model.issues.prefix(30).enumerated()), id: \.offset) { _, issue in
                VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                    Label {
                        ImportText.describe(issue.kind)
                    } icon: {
                        Image(systemName: issue.isError ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(issue.isError ? .peakEnergyNotReady : .peakTextSecondary)
                    }
                    Text(verbatim: issue.path)
                        .font(.peakDetail)
                        .foregroundStyle(.peakTextTertiary)
                }
            }
        } header: {
            Text("Problems (\(model.issues.count))")
        } footer: {
            Text(ImportText.problemsFooter)
        }
    }

    private var modeSection: some View {
        Section {
            Picker("Import Mode", selection: $model.mode) {
                Text("Merge").tag(ImportModel.Mode.merge)
                Text("Replace All").tag(ImportModel.Mode.replaceAll)
            }
            .pickerStyle(.segmented)
            if model.fileSettings != nil {
                Toggle("Apply the File's Settings", isOn: $model.appliesSettings)
            }
        } footer: {
            Text(
                model.mode == .merge
                    ? "Adds what is new. Workouts already in Peak are skipped, so importing a file twice adds nothing."
                    : "Deletes everything in Peak first, after saving a backup."
            )
        }
    }
}

extension ImportSheet {
    // MARK: Bindings

    fileprivate var layoutBinding: Binding<Bool> {
        Binding {
            model.draft.mapping?.layout == .block
        } set: { isBlock in
            guard let table = model.draft.table else { return }
            if isBlock {
                model.draft.mapping?.layout = .block
            } else {
                model.draft.mapping?.layout = .long
                model.draft.setHeaderRow(model.draft.mapping?.headerRow ?? SheetAnalyzer.analyze(table).headerRow)
            }
        }
    }

    fileprivate var headerBinding: Binding<Int?> {
        Binding {
            model.draft.mapping?.headerRow
        } set: {
            model.draft.setHeaderRow($0)
        }
    }

    fileprivate func roleBinding(_ column: Int) -> Binding<ColumnRole> {
        Binding {
            model.draft.mapping.map { column < $0.roles.count ? $0.roles[column] : .ignore } ?? .ignore
        } set: { role in
            guard var mapping = model.draft.mapping, column < mapping.roles.count else { return }
            mapping.roles[column] = role
            model.draft.mapping = mapping
        }
    }

    fileprivate func mappingBinding<Value>(_ keyPath: WritableKeyPath<SheetMapping, Value>, default value: Value)
        -> Binding<Value>
    {
        Binding {
            model.draft.mapping?[keyPath: keyPath] ?? value
        } set: { newValue in
            model.draft.mapping?[keyPath: keyPath] = newValue
        }
    }
}

/// How an import ended, for S-09.
enum ImportOutcome {
    case imported(PeakImportSummary)
    case failed(Text)
}
