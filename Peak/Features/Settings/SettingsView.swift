import PeakCore
import PeakDesign
import SwiftData
import SwiftUI

/// Settings tab (design: `Settings`): goals, workout data, recorded workouts, routines and general settings.
struct SettingsView: View {
    enum Sheet: Identifiable {
        case stepGoal, waterGoal, overload
        case workout(WorkoutTemplate?)
        case routine(Routine?)

        var id: String {
            switch self {
            case .stepGoal: "stepGoal"
            case .waterGoal: "waterGoal"
            case .overload: "overload"
            case .workout(let template): "workout-\(template?.id.uuidString ?? "new")"
            case .routine(let routine): "routine-\(routine?.id.uuidString ?? "new")"
            }
        }
    }

    @Environment(SettingsStore.self) private var settings
    @Environment(\.calendar) private var calendar
    @Environment(\.openURL) private var openURL
    @Query(filter: #Predicate<WorkoutTemplate> { !$0.isArchived }, sort: \WorkoutTemplate.sortIndex)
    private var templates: [WorkoutTemplate]
    @Query(sort: \Routine.sortIndex) private var routines: [Routine]

    @State private var sheet: Sheet?
    @Environment(HealthConnection.self) private var health

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.section) {
                    // The design's title is 28 pt regular, not the navigation bar's 34 pt bold large title.
                    Text("Settings")
                        .font(.peakScreenTitle)
                        .foregroundStyle(.peakTextPrimary)
                        .accessibilityAddTraits(.isHeader)

                    goalSection
                    workoutDataSection
                    recordedWorkoutsSection
                    routinesSection
                    generalSection

                    #if DEBUG
                        DeveloperSection()
                    #endif
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.screenMargin)
                .padding(.vertical, Spacing.medium)
            }
            .background(.peakCanvas)
            .toolbarVisibility(.hidden, for: .navigationBar)
            .sheet(item: $sheet) { sheet in
                view(for: sheet)
            }
            .task {
                await health.refresh()
                #if DEBUG
                    // Screenshot helper: `-PeakRequestHealth YES` taps the Apple Health row.
                    if UserDefaults.standard.bool(forKey: "PeakRequestHealth") {
                        await health.requestAccess()
                    }
                #endif
            }
            #if DEBUG
                .onAppear(perform: openSheetFromLaunchArgument)
            #endif
        }
    }

    // MARK: Sections

    private var goalSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Goal Settings")
            SettingsRow("Daily Step Goal", accessory: .value(settings.stepGoal.formatted())) {
                sheet = .stepGoal
            }
            SettingsRow("Daily Water Intake Goal", accessory: .value(Formatting.liters(settings.waterGoalMl))) {
                sheet = .waterGoal
            }
            SettingsRow("Progressive Overload", accessory: .value(">\(settings.overloadThresholdReps)")) {
                sheet = .overload
            }
        }
    }

    /// Import arrives with F7-06.
    private var workoutDataSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Workout Settings")
            SettingsRow("Import Workout Data", accessory: .icon("square.and.arrow.down")) {}
                .disabled(true)
            ExportDataRow()
        }
    }

    private var recordedWorkoutsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Recorded Workouts", action: .init("New") { sheet = .workout(nil) })
            if templates.isEmpty {
                emptyText("No workouts yet.")
            }
            ForEach(templates) { template in
                SettingsRow(verbatim: template.name, accessory: .action("Edit")) {
                    sheet = .workout(template)
                }
            }
        }
    }

    private var routinesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Routines", action: .init("New") { sheet = .routine(nil) })
            if routines.isEmpty {
                emptyText("No routines yet.")
            }
            ForEach(routines) { routine in
                SettingsRow(verbatim: routine.name, accessory: .value(summary(of: routine))) {
                    sheet = .routine(routine)
                }
            }
        }
    }

    private var generalSection: some View {
        @Bindable var settings = settings
        return VStack(alignment: .leading, spacing: 0) {
            SectionHeader("General")
            HStack {
                Text("Units")
                    .foregroundStyle(.peakTextPrimary)
                Spacer()
                Picker("Units", selection: $settings.unitSystem) {
                    Text(verbatim: "kg").tag(UnitSystem.metric)
                    Text(verbatim: "lb").tag(UnitSystem.imperial)
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }
            .font(.peakRow)
            .padding(.horizontal, Spacing.xSmall)
            .frame(minHeight: Metrics.minTouchTarget)

            SettingsRow("Apple Health", accessory: .value(healthStatusText)) {
                Task { await health.requestAccess() }
            }
            .disabled(health.status == .unavailable)

            SettingsRow("Version", accessory: .value(Self.version)) {}
                .disabled(true)
            SettingsRow("Source Code", accessory: .icon("arrow.up.right")) {
                open("https://github.com/tunamu/Peak")
            }
            SettingsRow("License", accessory: .value("MIT")) {
                open("https://github.com/tunamu/Peak/blob/main/LICENSE")
            }
            // Licenses of the third-party code in the app (ZIPFoundation, MIT), as the licenses ask.
            SettingsRow("Third-Party Notices", accessory: .icon("arrow.up.right")) {
                open("https://github.com/tunamu/Peak/blob/main/THIRD_PARTY_NOTICES.md")
            }
            SettingsRow("Privacy Policy", accessory: .icon("arrow.up.right")) {
                open("https://github.com/tunamu/Peak/blob/main/docs/privacy.md")
            }
        }
    }

    private func emptyText(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.peakRow)
            .foregroundStyle(.peakTextTertiary)
            .padding(.horizontal, Spacing.xSmall)
            .frame(minHeight: Metrics.minTouchTarget)
    }

    // MARK: Sheets

    @ViewBuilder
    private func view(for sheet: Sheet) -> some View {
        @Bindable var settings = settings
        switch sheet {
        case .stepGoal:
            StepGoalSheet()
        case .waterGoal:
            ValuePickerSheet(
                titles: .init("Daily Water Intake Goal", pickerLabel: "New Goal", reset: "Reset", update: "Update"),
                current: settings.waterGoalMl,
                defaultValue: SettingsStore.Defaults.waterGoalMl,
                options: Array(stride(from: 1_000, through: 6_000, by: 250)),
                format: { Formatting.liters($0) },
                onSave: { settings.waterGoalMl = $0 }
            )
        case .overload:
            ValuePickerSheet(
                titles: .init(
                    "Progressive Overload", pickerLabel: "Update Rep Goal", reset: "Reset", update: "Update",
                    footnote: "The weight goes up automatically when a set passes this rep count."
                ),
                current: settings.overloadThresholdReps,
                defaultValue: SettingsStore.Defaults.overloadThresholdReps,
                options: Array(SettingsStore.Limits.overloadReps),
                format: { ">\($0)" },
                onSave: { settings.overloadThresholdReps = $0 }
            )
        case .workout(let template):
            WorkoutTemplateSheet(template: template)
        case .routine(let routine):
            RoutineSheet(routine: routine)
        }
    }

    // MARK: Helpers

    static var version: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }

    private var healthStatusText: String {
        switch health.status {
        case .unavailable: String(localized: "Not available")
        case .notDetermined: String(localized: "Connect")
        case .connected: String(localized: "Connected")
        case .denied: String(localized: "Off in the Health app")
        }
    }

    /// "Mon, Wed, Fri" or "Every 2 days"; "Off" when inactive.
    private func summary(of routine: Routine) -> String {
        guard routine.isActive else { return String(localized: "Off") }
        switch routine.scheduleType {
        case .weekdays:
            let first = (calendar.firstWeekday + 5) % 7
            return (0..<7).compactMap { Weekday(rawValue: (first + $0) % 7) }
                .filter { routine.weekdays.contains($0) }
                .map { calendar.shortStandaloneWeekdaySymbols[($0.rawValue + 1) % 7] }
                .joined(separator: ", ")
        case .interval:
            return String(localized: "Every \(routine.intervalDays) days")
        }
    }

    private func open(_ address: String) {
        if let url = URL(string: address) {
            openURL(url)
        }
    }

    #if DEBUG
        /// Screenshot helper: `-PeakSettingsSheet` with `stepGoal`, `waterGoal`, `overload`, `newWorkout`,
        /// `editWorkout`, `newRoutine` or `editRoutine`.
        private func openSheetFromLaunchArgument() {
            switch UserDefaults.standard.string(forKey: "PeakSettingsSheet") {
            case "stepGoal": sheet = .stepGoal
            case "waterGoal": sheet = .waterGoal
            case "overload": sheet = .overload
            case "newWorkout": sheet = .workout(nil)
            case "editWorkout": sheet = .workout(templates.first)
            case "newRoutine": sheet = .routine(nil)
            case "editRoutine": sheet = .routine(routines.first)
            default: break
            }
        }
    #endif
}

#if DEBUG
    #Preview("Dark") {
        SettingsView()
            .previewEnvironment()
            .preferredColorScheme(.dark)
    }

    #Preview("Light") {
        SettingsView()
            .previewEnvironment()
            .preferredColorScheme(.light)
    }
#endif
