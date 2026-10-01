import Foundation
import PeakCore
import SwiftData
import Testing

/// Settings › Delete All Data: everything goes, but only after a backup that brings it all back.
@MainActor
@Suite struct PeakDataEraserTests {
    func makeBackupDirectory() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "peak-eraser-\(UUID().uuidString)")
    }

    @Test func countsWhatIsStored() throws {
        let context = try makeContext()
        #expect(try PeakDataEraser(context: context).contents().isEmpty)

        try SampleProgram.install(into: context)
        try SampleProgram.installHistory(into: context)
        context.insert(WaterLog(amountMl: 500))
        try context.save()

        let contents = try PeakDataEraser(context: context).contents()
        #expect(contents.sessions == 3)
        #expect(contents.templates == 6)
        #expect(contents.routines == 1)
        #expect(contents.exercises == 13)
        #expect(contents.waterLogs == 1)
    }

    @Test func erasesEverythingAndTheBackupBringsItBack() throws {
        let context = try makeContext()
        try SampleProgram.install(into: context)
        try SampleProgram.installHistory(into: context)
        context.insert(WaterLog(amountMl: 500))
        try context.save()
        let before = try PeakDataEraser(context: context).contents()
        let directory = makeBackupDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let backup = try PeakDataEraser(context: context).eraseAll(backupDirectory: directory)

        #expect(try PeakDataEraser(context: context).contents().isEmpty)
        // Children went with their parents.
        #expect(try context.fetchCount(FetchDescriptor<SetEntry>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<TemplateItem>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<RoutineEntry>()) == 0)

        try PeakImporter(context: context).commit(try PeakJSON.decode(try Data(contentsOf: backup)))
        #expect(try PeakDataEraser(context: context).contents() == before)
    }

    @Test func nothingIsDeletedWithoutABackup() throws {
        let context = try makeContext()
        try SampleProgram.install(into: context)
        // A file where the folder should be: the backup cannot be written.
        let blocked = makeBackupDirectory()
        try Data().write(to: blocked)
        defer { try? FileManager.default.removeItem(at: blocked) }

        #expect(throws: (any Error).self) {
            try PeakDataEraser(context: context).eraseAll(backupDirectory: blocked)
        }
        #expect(try PeakDataEraser(context: context).contents().templates == 6)
    }

    @Test func theConfirmationWordIgnoresCaseAndAccents() {
        #expect(PeakDataEraser.isConfirmed(typed: "SİL", word: "SİL"))
        #expect(PeakDataEraser.isConfirmed(typed: "sil", word: "SİL"))
        #expect(PeakDataEraser.isConfirmed(typed: " Sil ", word: "SİL"))
        #expect(PeakDataEraser.isConfirmed(typed: "delete", word: "DELETE"))
        #expect(!PeakDataEraser.isConfirmed(typed: "si", word: "SİL"))
        #expect(!PeakDataEraser.isConfirmed(typed: "", word: "SİL"))
        #expect(!PeakDataEraser.isConfirmed(typed: "", word: ""))
    }
}
