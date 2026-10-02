import PeakCore
import PeakDesign
import SwiftData
import SwiftUI

/// S-07 Set Routine: name, the workouts it rotates through (in order), when it runs, and whether it is active.
/// Several routines can be active at once (D-15).
struct RoutineSheet: View {
    /// `nil` creates a new routine.
    let routine: Routine?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.calendar) private var calendar
    @Environment(Reminders.self) private var reminders
    @Query(filter: #Predicate<WorkoutTemplate> { !$0.isArchived }, sort: \WorkoutTemplate.sortIndex)
    private var templates: [WorkoutTemplate]

    @State private var name: String
    @State private var note: String
    @State private var chosen: [UUID]
    @State private var scheduleType: ScheduleType
    @State private var weekdays: Set<Weekday>
    @State private var intervalDays: Int
    @State private var startDate: Date
    @State private var isActive: Bool
    /// The routine's own reminder (F11-08); kept by `Reminders` on this device.
    @State private var hasReminder = false
    @State private var reminderTime = Date.now
    @State private var isDeleteConfirmationShown = false

    init(routine: Routine?) {
        self.routine = routine
        _name = State(initialValue: routine?.name ?? "")
        _note = State(initialValue: routine?.note ?? "")
        _chosen = State(initialValue: routine?.orderedEntries.compactMap { $0.template?.id } ?? [])
        _scheduleType = State(initialValue: routine?.scheduleType ?? .weekdays)
        _weekdays = State(initialValue: Set(routine?.weekdays ?? [.monday, .wednesday, .friday]))
        _intervalDays = State(initialValue: routine?.intervalDays ?? 2)
        _startDate = State(initialValue: routine?.startDate ?? .now)
        _isActive = State(initialValue: routine?.isActive ?? true)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Routine Name", text: $name)
                        .font(.peakCardValue)
                        .submitLabel(.done)
                } header: {
                    Text("Set Routine Name")
                }

                InclusionSections(
                    chosenTitle: "Workouts",
                    othersTitle: "Other Workouts",
                    emptyHint: "Tick the workouts to rotate through.",
                    items: templates,
                    chosen: $chosen,
                    title: \.name
                ) { _ in
                    EmptyView()
                }

                Section {
                    Picker("Routine Type", selection: $scheduleType) {
                        Text("Every Week Day").tag(ScheduleType.weekdays)
                        Text("Day After").tag(ScheduleType.interval)
                    }
                    .pickerStyle(.segmented)

                    switch scheduleType {
                    case .weekdays:
                        weekdayChips
                    case .interval:
                        Stepper(value: $intervalDays, in: 1...14) {
                            Text("Every \(intervalDays) days")
                                .monospacedDigit()
                        }
                        DatePicker("First Workout", selection: $startDate, displayedComponents: .date)
                    }
                } header: {
                    Text("Routine Type")
                } footer: {
                    Text("A missed day never skips a workout: the next one moves to the next routine day.")
                }

                Section {
                    Toggle("Remind Me", isOn: $hasReminder)
                    if hasReminder {
                        DatePicker("Reminder Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Text("Reminder")
                } footer: {
                    Text("A notification at this time on the routine's workout days, besides the morning one.")
                }

                Section {
                    Toggle("Active", isOn: $isActive)
                    TextField("Add Note", text: $note, axis: .vertical)
                        .lineLimit(1...4)
                }

                if routine != nil {
                    Section {
                        Button("Delete Routine", role: .destructive) {
                            isDeleteConfirmationShown = true
                        }
                    }
                }
            }
            .environment(\.editMode, .constant(.active))
            .scrollContentBackground(.hidden)
            .navigationTitle(routine == nil ? "New Routine" : "Set Routine")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                SheetActionBar(
                    cancel: "Cancel",
                    confirm: routine == nil ? "Create" : "Update",
                    isConfirmEnabled: isValid
                ) {
                    dismiss()
                } onConfirm: {
                    save()
                }
            }
            .confirmationDialog(
                "Delete this routine?",
                isPresented: $isDeleteConfirmationShown,
                titleVisibility: .visible
            ) {
                Button("Delete Routine", role: .destructive) {
                    delete()
                }
            } message: {
                Text("Its workouts and past sessions stay.")
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear(perform: loadReminder)
        .onChange(of: hasReminder) { _, isOn in
            guard isOn, reminders.authorization == .notDetermined else { return }
            Task { await reminders.requestAuthorization() }
        }
    }

    /// The routine's reminder, or 18:00 ready for when it is turned on.
    private func loadReminder() {
        let minutes = routine.flatMap { reminders.routineReminder(for: $0.id) }
        hasReminder = minutes != nil
        let start = calendar.startOfDay(for: .now)
        reminderTime = calendar.date(byAdding: .minute, value: minutes ?? 18 * 60, to: start) ?? start
    }

    private var reminderMinutes: Int {
        let parts = calendar.dateComponents([.hour, .minute], from: reminderTime)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var isValid: Bool {
        !trimmedName.isEmpty && !chosen.isEmpty && (scheduleType == .interval || !weekdays.isEmpty)
    }

    /// Seven day chips in the locale's week order.
    private var weekdayChips: some View {
        HStack(spacing: 0) {
            ForEach(orderedWeekdays, id: \.self) { day in
                let isOn = weekdays.contains(day)
                Button {
                    if isOn { weekdays.remove(day) } else { weekdays.insert(day) }
                } label: {
                    Text(verbatim: symbol(for: day, short: true))
                        .font(.peakCardLabel)
                        .foregroundStyle(isOn ? .peakTextPrimary : .peakTextSecondary)
                        .frame(width: Metrics.minTouchTarget, height: Metrics.minTouchTarget)
                        .background(isOn ? .peakFillControl : .clear, in: .circle)
                        .contentShape(.circle)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .accessibilityLabel(Text(verbatim: symbol(for: day, short: false)))
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
    }

    private var orderedWeekdays: [Weekday] {
        // Calendar weekdays are 1 = Sunday … 7 = Saturday; `Weekday` starts on Monday.
        let first = (calendar.firstWeekday + 5) % 7
        return (0..<7).compactMap { Weekday(rawValue: (first + $0) % 7) }
    }

    private func symbol(for day: Weekday, short: Bool) -> String {
        let symbols = short ? calendar.veryShortStandaloneWeekdaySymbols : calendar.standaloneWeekdaySymbols
        return symbols[(day.rawValue + 1) % 7]
    }

    private func save() {
        let repository = RoutineRepository(context: modelContext)
        let chosenTemplates = chosen.compactMap { id in templates.first { $0.id == id } }
        do {
            let target: Routine
            if let routine {
                target = routine
                repository.setTemplates(chosenTemplates, of: target)
            } else if scheduleType == .weekdays {
                target = try repository.create(
                    name: trimmedName, weekdays: Array(weekdays), templates: chosenTemplates)
            } else {
                target = try repository.create(
                    name: trimmedName, intervalDays: intervalDays, startDate: startDate, templates: chosenTemplates)
            }
            target.name = trimmedName
            target.note = note
            target.isActive = isActive
            target.scheduleType = scheduleType
            target.weekdays = Array(weekdays)
            target.intervalDays = intervalDays
            target.startDate = startDate
            reminders.setRoutineReminder(hasReminder ? reminderMinutes : nil, for: target.id)
            try modelContext.save()
            dismiss()
        } catch {
            assertionFailure("Could not save routine: \(error)")
        }
    }

    private func delete() {
        guard let routine else { return }
        reminders.setRoutineReminder(nil, for: routine.id)
        RoutineRepository(context: modelContext).delete(routine)
        try? modelContext.save()
        dismiss()
    }
}
