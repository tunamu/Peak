import PeakCore
import PeakDesign
import SwiftUI

/// Settings › General › iCloud Sync: an opt-in switch, off until the user turns it on, and while it is on, the
/// sync status. Turning it off asks first.
struct ICloudSyncRows: View {
    @Environment(AppData.self) private var data
    @State private var isTurnOffConfirmationShown = false
    @State private var failure: String?

    var body: some View {
        HStack {
            Text("iCloud Sync")
                .foregroundStyle(.peakTextPrimary)
            Spacer()
            Toggle("iCloud Sync", isOn: isOn)
                .labelsHidden()
        }
        .font(.peakRow)
        .padding(.horizontal, Spacing.xSmall)
        .frame(minHeight: Metrics.minTouchTarget)
        #if DEBUG
            .task { toggleFromLaunchArgument() }
        #endif
        .alert("Turn off iCloud Sync?", isPresented: $isTurnOffConfirmationShown) {
            Button("Turn Off", role: .destructive) { apply(false) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This iPhone stops syncing. Your data stays on it, and what is already in iCloud stays there.")
        }
        .alert(
            "iCloud Sync",
            isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(verbatim: failure ?? "")
        }

        if let sync = data.sync {
            ICloudStatusRow(sync: sync)
        } else {
            Text("Your data stays on this iPhone. Turn on to sync it through your iCloud account.")
                .font(.peakDetail)
                .foregroundStyle(.peakTextTertiary)
                .padding(.horizontal, Spacing.xSmall)
        }
    }

    #if DEBUG
        /// Screenshot helper: `-PeakToggleSync YES` flips the switch once after launch, without the question.
        private static var didToggleFromLaunchArgument = false

        private func toggleFromLaunchArgument() {
            let isAsked = UserDefaults.standard.bool(forKey: "PeakToggleSync")
            guard isAsked, !Self.didToggleFromLaunchArgument else { return }
            Self.didToggleFromLaunchArgument = true
            apply(!data.isSyncEnabled)
        }
    #endif

    private var isOn: Binding<Bool> {
        Binding {
            data.isSyncEnabled
        } set: { isOn in
            if isOn {
                apply(true)
            } else {
                isTurnOffConfirmationShown = true
            }
        }
    }

    private func apply(_ enabled: Bool) {
        do {
            try data.setSyncEnabled(enabled)
        } catch {
            failure = error.localizedDescription
        }
    }
}

/// While iCloud sync is on (F8-04): whether workouts sync, and why not when they don't. Tapping explains in one
/// sentence and, when the fix is in the Settings app, offers to open it. Peak keeps working on the device either way.
struct ICloudStatusRow: View {
    let sync: SyncMonitor
    @Environment(\.openURL) private var openURL
    @State private var isExplanationShown = false

    var body: some View {
        SettingsRow("iCloud", accessory: .value(value)) {
            isExplanationShown = true
        }
        .alert("iCloud", isPresented: $isExplanationShown) {
            if opensSettings, let url = URL(string: UIApplication.openSettingsURLString) {
                Button("Open Settings") { openURL(url) }
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text(explanation)
        }
        .task {
            await sync.refreshAccount()
            #if DEBUG
                // Screenshot helper: `-PeakTab settings -PeakShowICloud YES` taps the row once sync reports a problem,
                // or after 30 seconds (an open alert keeps the text it opened with).
                if UserDefaults.standard.bool(forKey: "PeakShowICloud") {
                    for _ in 0..<30 where sync.state.problem == nil {
                        try? await Task.sleep(for: .seconds(1))
                    }
                    isExplanationShown = true
                }
            #endif
        }
    }

    private var value: String {
        switch sync.status {
        case .checking: String(localized: "Checking…")
        case .noAccount: String(localized: "Not signed in")
        case .restricted: String(localized: "Restricted")
        case .unavailable: String(localized: "Not available")
        case .storageFull: String(localized: "Storage full")
        case .uploadRejected: String(localized: "Not uploaded")
        case .offline: String(localized: "Offline")
        case .failed: String(localized: "Not synced")
        case .synced(nil): String(localized: "On")
        case .synced: String(localized: "Synced")
        }
    }

    private var explanation: LocalizedStringKey {
        switch sync.status {
        case .checking:
            "Peak is checking your iCloud account."
        case .noAccount:
            "Sign in to iCloud in the Settings app to sync your workouts between devices."
        case .restricted:
            "iCloud is restricted on this iPhone, so your workouts stay on it."
        case .unavailable:
            "iCloud can't be reached right now; Peak syncs when it can."
        case .storageFull:
            "Your iCloud storage is full, so new workouts stay on this iPhone until there's room."
        case .uploadRejected:
            "iCloud didn't accept some changes, most often because iCloud storage is full."
        case .offline:
            "There's no connection; Peak syncs when you're back online."
        case .failed:
            "The last sync didn't go through; Peak tries again on its own."
        case .synced(let date?):
            "Your workouts sync with iCloud. Last synced at \(date.formatted(date: .omitted, time: .shortened))."
        case .synced(nil):
            "Your workouts sync with iCloud."
        }
    }

    private var opensSettings: Bool {
        switch sync.status {
        case .noAccount, .restricted, .storageFull, .uploadRejected: true
        default: false
        }
    }
}
