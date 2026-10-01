import PeakCore
import PeakDesign
import SwiftUI

/// Settings › Reminders (F11-07): the morning reminder on workout days and its time. Turning it on asks for
/// notifications the first time; when they are off in the Settings app, the row says so and links there.
struct RemindersSection: View {
    @Environment(Reminders.self) private var reminders
    @Environment(\.openURL) private var openURL
    @State private var isTimeSheetShown = false

    var body: some View {
        @Bindable var reminders = reminders
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Reminders")
            Toggle(isOn: $reminders.isMorningOn) {
                Text("Workout Day Reminder")
                    .foregroundStyle(.peakTextPrimary)
            }
            .font(.peakRow)
            .padding(.horizontal, Spacing.xSmall)
            .frame(minHeight: Metrics.minTouchTarget)

            SettingsRow("Reminder Time", accessory: .value(Self.time(reminders.morningMinutes))) {
                isTimeSheetShown = true
            }
            .disabled(!reminders.isMorningOn)

            if reminders.isMorningOn && reminders.authorization == .notDetermined {
                // Someone who passed onboarding before reminders existed has never been asked.
                SettingsRow("Allow Notifications", accessory: .action("Allow")) {
                    Task { await reminders.requestAuthorization() }
                }
            }
            if reminders.isMorningOn && reminders.authorization == .denied {
                Text("Notifications are off for Peak. Turn them on in the Settings app to get reminders.")
                    .font(.peakDetail)
                    .foregroundStyle(.peakTextSecondary)
                    .padding(.horizontal, Spacing.xSmall)
                    .padding(.top, Spacing.xxSmall)
                SettingsRow("Open Settings", accessory: .icon("arrow.up.right")) {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                        openURL(url)
                    }
                }
            } else {
                Text("On days with a planned workout. A routine can add its own reminder.")
                    .font(.peakDetail)
                    .foregroundStyle(.peakTextTertiary)
                    .padding(.horizontal, Spacing.xSmall)
                    .padding(.top, Spacing.xxSmall)
            }
        }
        .task { await reminders.refreshAuthorization() }
        .onChange(of: reminders.isMorningOn) { _, isOn in
            guard isOn, reminders.authorization == .notDetermined else { return }
            Task { await reminders.requestAuthorization() }
        }
        .sheet(isPresented: $isTimeSheetShown) {
            ValuePickerSheet(
                titles: .init("Reminder Time", pickerLabel: "New Time", reset: "Reset", update: "Update"),
                current: reminders.morningMinutes,
                defaultValue: Reminders.defaultMorningMinutes,
                options: Array(stride(from: 5 * 60, through: 23 * 60, by: 15)),
                format: Self.time,
                onSave: { reminders.morningMinutes = $0 }
            )
        }
    }

    /// "09:00" or "9:00 AM", as the locale writes times.
    nonisolated static func time(_ minutes: Int) -> String {
        let start = Calendar.current.startOfDay(for: .now)
        return Calendar.current.date(byAdding: .minute, value: minutes, to: start)?
            .formatted(date: .omitted, time: .shortened) ?? ""
    }
}
