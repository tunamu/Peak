import Foundation
import Observation
import PeakCore
import SwiftData
import UserNotifications

/// F11-07 (ADR 0021): local reminders on workout days. The morning reminder is a setting of this device, like iCloud
/// Sync; what falls when comes from `ReminderPlanner`, and is planned again whenever the app opens or its data
/// changes, since the rotation moves with what was done.
@MainActor
@Observable
final class Reminders: NSObject {
    enum Authorization {
        case notDetermined, allowed, denied
    }

    static let identifierPrefix = "peak.reminder."
    static let defaultMorningMinutes = 9 * 60

    private(set) var authorization = Authorization.notDetermined

    /// "Today: Chest & Biceps. Ready?" on workout days. On until turned off; nothing is sent before notifications
    /// are allowed.
    var isMorningOn: Bool {
        didSet { defaults.set(isMorningOn, forKey: Keys.morningOn) }
    }
    /// Minutes after midnight.
    var morningMinutes: Int {
        didSet { defaults.set(morningMinutes, forKey: Keys.morningMinutes) }
    }
    /// Routines' own "time to train" reminders, minutes after midnight by routine. Kept on this device with the
    /// morning reminder rather than in the routine, so the stored schema does not change (D-29).
    private(set) var routineMinutes: [UUID: Int] {
        didSet {
            defaults.set(
                Dictionary(uniqueKeysWithValues: routineMinutes.map { ($0.uuidString, $1) }), forKey: Keys.routines)
        }
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let center = UNUserNotificationCenter.current()
    @ObservationIgnored private var pending: Task<Void, Never>?

    private enum Keys {
        static let morningOn = "reminders.morningOn"
        static let morningMinutes = "reminders.morningMinutes"
        static let routines = "reminders.routineMinutes"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isMorningOn = defaults.object(forKey: Keys.morningOn) as? Bool ?? true
        morningMinutes = defaults.object(forKey: Keys.morningMinutes) as? Int ?? Self.defaultMorningMinutes
        let stored = defaults.dictionary(forKey: Keys.routines) as? [String: Int] ?? [:]
        routineMinutes = Dictionary(
            uniqueKeysWithValues: stored.compactMap { key, value in UUID(uuidString: key).map { ($0, value) } })
        super.init()
        // Set before the app finishes launching, so a tap that launches it is still delivered.
        center.delegate = self
    }

    /// The routine's reminder time, or `nil` when it has none.
    func routineReminder(for routineID: UUID) -> Int? {
        routineMinutes[routineID]
    }

    func setRoutineReminder(_ minutes: Int?, for routineID: UUID) {
        routineMinutes[routineID] = minutes
    }

    // MARK: Permission

    func refreshAuthorization() async {
        let settings = await center.notificationSettings()
        authorization =
            switch settings.authorizationStatus {
            case .notDetermined: .notDetermined
            case .denied: .denied
            default: .allowed
            }
    }

    /// Asks once; afterwards iOS answers from the Settings app's switch.
    @discardableResult
    func requestAuthorization() async -> Bool {
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        await refreshAuthorization()
        return granted
    }

    // MARK: Scheduling

    /// Plans again a moment later; a burst of saves (a workout's sets) plans once.
    func schedule(in context: ModelContext) {
        pending?.cancel()
        pending = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            await reschedule(in: context)
        }
    }

    /// Replaces Peak's pending reminders with the ones the plan gives now.
    func reschedule(in context: ModelContext) async {
        await refreshAuthorization()
        let old = await center.pendingNotificationRequests().map(\.identifier)
            .filter { $0.hasPrefix(Self.identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: old)
        guard authorization == .allowed, let input = try? input(from: context) else { return }
        for reminder in ReminderPlanner().plan(input, now: .now) {
            try? await center.add(request(for: reminder))
        }
    }

    private func input(from context: ModelContext) throws -> ReminderInput {
        let routines = try context.fetch(FetchDescriptor<Routine>())
        let sessions = SessionRepository(context: context)
        let names = Dictionary(
            routines.flatMap(\.orderedEntries).compactMap(\.template).map { ($0.id, $0.name) },
            uniquingKeysWith: { first, _ in first })
        return ReminderInput(
            routines: routines.map(\.snapshot),
            history: try sessions.completed().map(\.record),
            templateNames: names,
            morningMinutes: isMorningOn ? morningMinutes : nil,
            routineMinutes: routineMinutes,
            hasRunningSession: (try? sessions.current()) != nil
        )
    }

    private func request(for reminder: PlannedReminder) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        let workouts = reminder.workoutNames.formatted(.list(type: .and))
        switch reminder.kind {
        case .morning:
            content.title = String(localized: "Workout Day")
            content.body = String(localized: "Today: \(workouts). Ready?")
        case .routine:
            content.title = String(localized: "Time to Train")
            content.body = String(localized: "\(workouts) is waiting for you.")
        }
        content.sound = .default
        content.userInfo = ["link": PeakLink.home.url.absoluteString]
        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.date)
        return UNNotificationRequest(
            identifier: reminder.id, content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false))
    }

    #if DEBUG
        /// Screenshot helper: `-PeakReminderNow YES` sends the next morning reminder's text in five seconds. Its
        /// identifier is outside the reminders' prefix, so planning again does not take it back.
        func sendTestReminder(in context: ModelContext) async {
            guard authorization == .allowed, let input = try? input(from: context) else { return }
            var morning = input
            morning.morningMinutes = 0
            let next = ReminderPlanner().plan(morning, now: Calendar.current.startOfDay(for: .now)).first
            let reminder = PlannedReminder(
                id: "peak.test-reminder", kind: .morning, date: .now,
                workoutNames: next?.workoutNames ?? ["Chest & Biceps"])
            let request = request(for: reminder)
            try? await center.add(
                UNNotificationRequest(
                    identifier: request.identifier, content: request.content,
                    trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)))
        }
    #endif
}

extension Reminders: UNUserNotificationCenterDelegate {
    // The completion-handler forms, finished on the main thread: with the async forms UIKit finishes the tap's
    // handling off the main thread and asserts.

    /// Shown as a banner while Peak is open, too.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping @Sendable (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    /// A tap opens Home, where today's workout waits.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping @Sendable () -> Void
    ) {
        let address = response.notification.request.content.userInfo["link"] as? String
        Task { @MainActor in
            LinkRouter.shared.pending = address.flatMap(URL.init(string:)).flatMap(PeakLink.init(url:)) ?? .home
            completionHandler()
        }
    }
}
