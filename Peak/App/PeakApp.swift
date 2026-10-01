//
//  PeakApp.swift
//  Peak
//
//  Created by Tuna Mus on 29.09.2026.
//

import PeakCore
import SwiftData
import SwiftUI

@main
struct PeakApp: App {
    /// The store, held here for the app's lifetime (a `ModelContext` does not keep its container alive), and the
    /// iCloud sync choice.
    @State private var data: AppData
    /// Settings follow the user's iCloud account through the key-value store while sync is on; the widget reads the
    /// App Group copy.
    @State private var settings: SettingsStore
    @State private var health = HealthConnection(service: PeakApp.makeHealthService())
    @State private var launcher = WorkoutLauncher()
    /// Kept outside the view tree, so the open tab survives reopening the store when sync is turned on or off.
    @State private var tab = RootTabView.TabID.home
    @State private var router = LinkRouter.shared
    /// Onboarding's choices, applied once its cover has gone (a file picker cannot open while it is still closing).
    @State private var onboardingOutcome: OnboardingView.Outcome?

    init() {
        let data: AppData
        do {
            // In the App Group so the widget reads the same store. Only the app syncs with iCloud, and only when the
            // user turned it on; without an iCloud account SwiftData keeps working locally.
            data = try AppData()
        } catch {
            fatalError("Could not open the Peak store: \(error)")
        }
        _data = State(initialValue: data)
        #if DEBUG
            // Screenshot helper: `-PeakOpenLink peak://workout/start` opens a link as a widget tap would.
            if let link = UserDefaults.standard.string(forKey: "PeakOpenLink").flatMap(URL.init(string:))
                .flatMap(PeakLink.init(url:))
            {
                LinkRouter.shared.pending = link
            }
        #endif
        let settings = SettingsStore(
            defaults: SettingsStore.appGroupDefaults(),
            mirror: data.isSyncEnabled ? UbiquitousSettingsMirror() : nil
        )
        // Someone who used Peak before onboarding existed (or has data from iCloud) skips it.
        if !settings.hasCompletedOnboarding,
            let contents = try? PeakDataEraser(context: data.container.mainContext).contents(), !contents.isEmpty
        {
            settings.hasCompletedOnboarding = true
        }
        #if DEBUG
            // Screenshot helper: `-PeakOnboarding YES` shows onboarding whatever the data.
            if UserDefaults.standard.bool(forKey: "PeakOnboarding") {
                settings.hasCompletedOnboarding = false
            }
            // UI tests: `-PeakSkipOnboarding YES` goes straight to the tabs on an empty simulator.
            if UserDefaults.standard.bool(forKey: "PeakSkipOnboarding") {
                settings.hasCompletedOnboarding = true
            }
        #endif
        _settings = State(initialValue: settings)
    }

    var body: some Scene {
        WindowGroup {
            RootTabView(selection: $tab)
                .modifier(WidgetSync())
                // A new container (sync turned on or off) rebuilds the screens, so none keeps a record of the old one.
                .id(data.generation)
                .modelContainer(data.container)
                // Registers the step observer at launch, so background delivery can wake the app.
                .task { await health.refresh() }
                // `peak://` links from the widgets and the Live Activity, and shortcuts that open the app.
                .onOpenURL { url in
                    if let link = PeakLink(url: url) { open(link) }
                }
                .onChange(of: router.pending, initial: true) {
                    guard let link = router.pending else { return }
                    router.pending = nil
                    open(link)
                }
                .fullScreenCover(isPresented: needsOnboarding, onDismiss: applyOnboarding) {
                    OnboardingView { outcome in
                        onboardingOutcome = outcome
                        settings.hasCompletedOnboarding = true
                    }
                }
                .onChange(of: data.generation) {
                    launcher.presented = nil
                    launcher.pendingStart = nil
                    settings.setMirror(data.isSyncEnabled ? UbiquitousSettingsMirror() : nil)
                }
        }
        .environment(data)
        .environment(settings)
        .environment(health)
        .environment(launcher)
    }

    private var needsOnboarding: Binding<Bool> {
        Binding(get: { !settings.hasCompletedOnboarding }, set: { _ in })
    }

    /// Applies onboarding's choices: iCloud first (it reopens the store), then how to start.
    private func applyOnboarding() {
        guard let outcome = onboardingOutcome else { return }
        onboardingOutcome = nil
        if outcome.syncsWithICloud {
            try? data.setSyncEnabled(true)
        }
        switch outcome.start {
        case .importData:
            tab = .settings
            router.opensImportPicker = true
        case .sampleProgram:
            try? SampleProgram.install(into: data.container.mainContext)
            tab = .home
        case .empty:
            tab = .home
        }
    }

    /// Goes where a link points. Starting follows the Start button: today's next workout, or the running one.
    private func open(_ link: PeakLink) {
        let context = data.container.mainContext
        switch link {
        case .home:
            tab = .home
        case .settings:
            tab = .settings
        case .startWorkout:
            tab = .home
            switch try? DayPlanner().nextWorkoutToday(in: context) {
            case .planned(let template, let routine)?:
                launcher.start(template, routine: routine, rule: settings.progressionRule, in: context)
            case .active(let session)?:
                launcher.resume(session)
            case .completed?, nil:
                break
            }
        case .openWorkout:
            tab = .home
            if let session = try? SessionRepository(context: context).current() {
                launcher.resume(session)
            }
        }
    }

    private static func makeHealthService() -> any HealthService {
        #if DEBUG
            // Screenshot helper: `-PeakMockHealth YES` shows sample Health data (the simulator has none).
            if UserDefaults.standard.bool(forKey: "PeakMockHealth") {
                return MockHealthService()
            }
        #endif
        return HealthKitService()
    }
}
