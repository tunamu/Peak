import PeakCore
import PeakDesign
import SwiftData
import SwiftUI

/// Settings › Delete All Data: for starting over, such as before importing a history. The row only opens a screen;
/// nothing is deleted from a single tap.
struct DeleteAllDataRow: View {
    @State private var isSheetShown = false

    var body: some View {
        SettingsRow("Delete All Data", accessory: .icon("trash")) {
            isSheetShown = true
        }
        .sheet(isPresented: $isSheetShown) {
            DeleteAllDataSheet()
        }
        #if DEBUG
            // Screenshot helper: `-PeakTab settings -PeakDeleteAll YES` taps the row.
            .task {
                if UserDefaults.standard.bool(forKey: "PeakDeleteAll") { isSheetShown = true }
            }
        #endif
    }
}

/// What will go and what stays, with three guards before anything is deleted: the counts are shown, the confirmation
/// word has to be typed, and a backup is written first (nothing is deleted if it cannot be). Not while a workout runs.
private struct DeleteAllDataSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppData.self) private var data

    @State private var contents = StoreContents()
    @State private var isWorkoutRunning = false
    @State private var typed = ""
    @State private var backup: URL?
    @State private var failure: String?

    /// "DELETE" in English, "SİL" in Turkish.
    private let word = String(localized: "DELETE", comment: "Typed to confirm Delete All Data")

    var body: some View {
        if let backup {
            ResultSheet(
                .success,
                title: "Everything Was Deleted",
                message: Text("The backup is in Files › Peak › Backups: \(backup.lastPathComponent)")
            ) {
                Button(role: .confirm) {
                    dismiss()
                } label: {
                    Text("Done").frame(maxWidth: .infinity)
                }
            }
            .fittedSheet()
        } else {
            form
        }
    }

    private var form: some View {
        NavigationStack {
            List {
                if isWorkoutRunning {
                    Section {
                        Text("A workout is running. Finish or discard it first.")
                    }
                } else if contents.isEmpty {
                    Section {
                        Text("There is nothing to delete.")
                    }
                } else {
                    Section {
                        LabeledContent("Workouts", value: contents.sessions.formatted())
                        LabeledContent("Recorded Workouts", value: contents.templates.formatted())
                        LabeledContent("Routines", value: contents.routines.formatted())
                        LabeledContent("Movements", value: contents.exercises.formatted())
                        LabeledContent("Water Entries", value: contents.waterLogs.formatted())
                    } header: {
                        Text("Will Be Deleted")
                    } footer: {
                        Text("Your settings and what Peak saved to Apple Health stay.")
                    }

                    if data.isSyncEnabled {
                        Section {
                            Label(
                                "iCloud Sync is on, so this also deletes the data from iCloud and your other devices.",
                                systemImage: "exclamationmark.icloud"
                            )
                            .foregroundStyle(.peakEnergyNotReady)
                        }
                    }

                    Section {
                        TextField(word, text: $typed)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .submitLabel(.done)
                    } header: {
                        Text("Type \(word) to Confirm")
                    } footer: {
                        Text("A backup is saved first in Files › Peak › Backups. Import it to bring everything back.")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Delete All Data")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                GlassEffectContainer(spacing: Spacing.medium) {
                    HStack(spacing: Spacing.medium) {
                        Button {
                            dismiss()
                        } label: {
                            Text("Cancel").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PeakGlassButtonStyle(tone: .neutral))
                        Button(role: .destructive) {
                            erase()
                        } label: {
                            Text("Delete").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.peakGlass)
                        .disabled(!canErase)
                    }
                }
                .padding(.horizontal, Spacing.large)
                .padding(.vertical, Spacing.small)
            }
            .alert(
                "Nothing Was Deleted",
                isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(verbatim: failure ?? "")
            }
            .task { refresh() }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var canErase: Bool {
        !isWorkoutRunning && !contents.isEmpty && PeakDataEraser.isConfirmed(typed: typed, word: word)
    }

    private func refresh() {
        contents = (try? PeakDataEraser(context: modelContext).contents()) ?? StoreContents()
        isWorkoutRunning = (try? SessionRepository(context: modelContext).current()) != nil
    }

    private func erase() {
        refresh()
        guard canErase else { return }
        do {
            backup = try PeakDataEraser(context: modelContext).eraseAll(backupDirectory: ImportModel.backupDirectory)
        } catch {
            modelContext.rollback()
            failure = error.localizedDescription
        }
    }
}
