import PeakCore
import SwiftData
import SwiftUI

/// Keeps the reminders (F11-07) in step with the plan: at launch, on coming back, after every save (a finished
/// workout moves the rotation, an edited routine moves its days) and when the reminder settings change.
struct ReminderSync: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @Environment(Reminders.self) private var reminders

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { _ in
                reminders.schedule(in: modelContext)
            }
            .task {
                await reminders.reschedule(in: modelContext)
                #if DEBUG
                    if UserDefaults.standard.bool(forKey: "PeakReminderNow") {
                        await reminders.sendTestReminder(in: modelContext)
                    }
                #endif
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { reminders.schedule(in: modelContext) }
            }
            .onChange(of: reminders.isMorningOn) { reminders.schedule(in: modelContext) }
            .onChange(of: reminders.morningMinutes) { reminders.schedule(in: modelContext) }
            .onChange(of: reminders.routineMinutes) { reminders.schedule(in: modelContext) }
    }
}
