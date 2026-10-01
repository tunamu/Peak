import PeakCore
import PeakDesign
import SwiftUI

/// C-15: the first launch. Welcome, Apple Health, goals, iCloud Sync, reminders, and how to start: import, the sample
/// program, or empty. Every step can be passed by; nothing here is needed to use the app.
struct OnboardingView: View {
    enum Start {
        case importData, sampleProgram, empty
    }

    /// What the last step decided; the app applies it (iCloud reopens the store, so it waits until the end).
    struct Outcome {
        var syncsWithICloud: Bool
        var start: Start
    }

    private enum Step: Int, CaseIterable {
        case welcome, health, goals, iCloud, reminders, start
    }

    let onFinish: (Outcome) -> Void

    @Environment(SettingsStore.self) private var settings
    @Environment(HealthConnection.self) private var health
    @Environment(Reminders.self) private var reminders
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step = Step.welcome
    @State private var syncsWithICloud = false

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Spacing.large)
                    .padding(.vertical, Spacing.large)
            }
            .scrollBounceBehavior(.basedOnSize)
            actions
                .padding(.horizontal, Spacing.large)
                .padding(.bottom, Spacing.medium)
        }
        .background(.peakCanvas)
        .animation(reduceMotion ? nil : .snappy, value: step)
        .task {
            await health.refresh()
            await reminders.refreshAuthorization()
        }
        #if DEBUG
            // Screenshot helper: `-PeakOnboarding YES -PeakOnboardingStep 2` opens on a step (0 welcome … 5 start).
            .onAppear {
                if let first = Step(rawValue: UserDefaults.standard.integer(forKey: "PeakOnboardingStep")) {
                    step = first
                }
            }
            // Screenshot helper: `-PeakOnboardingFinish import|sample|empty` picks a start, as a tap would.
            .task {
                let starts: [String: Start] = ["import": .importData, "sample": .sampleProgram, "empty": .empty]
                guard let start = UserDefaults.standard.string(forKey: "PeakOnboardingFinish").flatMap({ starts[$0] })
                else { return }
                try? await Task.sleep(for: .seconds(1))
                finish(start)
            }
        #endif
    }

    // MARK: Parts

    /// Back, and one dot per step.
    private var header: some View {
        HStack {
            Button {
                var target = Step(rawValue: step.rawValue - 1)
                if target == .reminders && reminders.authorization != .notDetermined {
                    target = .iCloud
                }
                if target == .health && health.status != .notDetermined {
                    target = .welcome
                }
                go(to: target)
            } label: {
                Label("Back", systemImage: "chevron.left")
                    .labelStyle(.iconOnly)
                    .frame(width: Metrics.minTouchTarget, height: Metrics.minTouchTarget)
            }
            .opacity(step == .welcome ? 0 : 1)
            .disabled(step == .welcome)
            Spacer()
            HStack(spacing: Spacing.xSmall) {
                ForEach(Step.allCases, id: \.self) { item in
                    Circle()
                        .fill(item == step ? Color.peakTextPrimary : Color.peakTextTertiary.opacity(0.4))
                        .frame(width: 8, height: 8)
                }
            }
            .accessibilityHidden(true)
            Spacer()
            Color.clear.frame(width: Metrics.minTouchTarget, height: Metrics.minTouchTarget)
        }
        .tint(.peakTextPrimary)
        .padding(.horizontal, Spacing.medium)
    }

    @ViewBuilder private var content: some View {
        switch step {
        case .welcome: welcome
        case .health: healthStep
        case .goals: goals
        case .iCloud: iCloud
        case .reminders: remindersStep
        case .start: start
        }
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: Spacing.large) {
            Image("Logo")
                .resizable()
                .scaledToFit()
                .padding(Spacing.small)
                .frame(width: 96, height: 96)
                .background(Color(red: 0.18, green: 0.18, blue: 0.18), in: .rect(cornerRadius: 22))
                .accessibilityHidden(true)
            title("Welcome to Peak")
            Text("Log your workouts, follow your next targets, and keep an eye on steps, water and energy.")
                .font(.peakCardLabel)
                .foregroundStyle(.peakTextSecondary)
        }
    }

    private var healthStep: some View {
        VStack(alignment: .leading, spacing: Spacing.large) {
            title("Apple Health")
            point(
                "figure.walk",
                "Reads steps, sleep, heart rate variability, resting heart rate and water for your Energy Level."
            )
            point("square.and.arrow.down", "Saves your water and finished workouts.")
            point("lock", "What Peak reads from Health stays on your iPhone. It is never stored in Peak or iCloud.")
        }
    }

    private var goals: some View {
        @Bindable var settings = settings
        return VStack(alignment: .leading, spacing: Spacing.large) {
            title("Your Goals")
            Text("You can change them any time in Settings.")
                .font(.peakCardLabel)
                .foregroundStyle(.peakTextSecondary)
            goalPicker("Daily Step Goal", selection: $settings.stepGoal) {
                ForEach(Array(stride(from: 1_000, through: 50_000, by: 500)), id: \.self) { value in
                    Text(verbatim: value.formatted()).tag(value)
                }
            }
            goalPicker("Daily Water Intake Goal", selection: $settings.waterGoalMl) {
                ForEach(Array(stride(from: 1_000, through: 6_000, by: 250)), id: \.self) { value in
                    Text(verbatim: Formatting.liters(value)).tag(value)
                }
            }
        }
    }

    private var iCloud: some View {
        VStack(alignment: .leading, spacing: Spacing.large) {
            title("iCloud Sync")
            point("icloud", "Sync your workouts between your devices through your own iCloud account.")
            point("iphone", "Off, everything stays on this iPhone. You can change this in Settings.")
        }
    }

    private var remindersStep: some View {
        VStack(alignment: .leading, spacing: Spacing.large) {
            title("Reminders")
            point("bell", "A reminder in the morning on days with a planned workout.")
            point("clock", "Change its time, or give a routine its own, in Settings.")
        }
    }

    private var start: some View {
        VStack(alignment: .leading, spacing: Spacing.large) {
            title("How do you want to start?")
            if syncsWithICloud {
                Text("Used Peak on another device? Its data arrives on its own, so start empty.")
                    .font(.peakDetail)
                    .foregroundStyle(.peakTextSecondary)
            }
            VStack(spacing: Spacing.small) {
                choice(
                    "Import My Data", detail: "From a Peak export, an Excel or a CSV file.",
                    systemImage: "square.and.arrow.down"
                ) {
                    finish(.importData)
                }
                choice(
                    "Start with a Sample Program",
                    detail: "Six workouts and a Monday, Wednesday, Friday routine. Change anything later.",
                    systemImage: "list.bullet.rectangle"
                ) {
                    finish(.sampleProgram)
                }
                choice(
                    "Start Empty", detail: "Set up your own workouts in Settings.", systemImage: "plus.square.dashed"
                ) {
                    finish(.empty)
                }
            }
        }
    }

    @ViewBuilder private var actions: some View {
        GlassEffectContainer(spacing: Spacing.medium) {
            HStack(spacing: Spacing.medium) {
                switch step {
                case .welcome, .goals:
                    primary("Continue") { next() }
                case .health:
                    secondary("Not Now") { next() }
                    primary("Connect") {
                        Task {
                            await health.requestAccess()
                            next()
                        }
                    }
                case .iCloud:
                    secondary("Not Now") {
                        syncsWithICloud = false
                        next()
                    }
                    primary("Turn On") {
                        syncsWithICloud = true
                        next()
                    }
                case .reminders:
                    secondary("Not Now") {
                        reminders.isMorningOn = false
                        next()
                    }
                    primary("Turn On") {
                        Task {
                            reminders.isMorningOn = true
                            await reminders.requestAuthorization()
                            next()
                        }
                    }
                case .start:
                    EmptyView()
                }
            }
        }
    }

    // MARK: Flow

    /// The next step; Apple Health and reminders are skipped where they are already decided (or Health does not
    /// exist, as on an iPad).
    private func next() {
        var target = Step(rawValue: step.rawValue + 1)
        if target == .health && health.status != .notDetermined {
            target = .goals
        }
        if target == .reminders && reminders.authorization != .notDetermined {
            target = .start
        }
        go(to: target)
    }

    private func go(to target: Step?) {
        guard let target else { return }
        step = target
    }

    private func finish(_ start: Start) {
        onFinish(Outcome(syncsWithICloud: syncsWithICloud, start: start))
    }
}

// MARK: Pieces

extension OnboardingView {
    fileprivate func title(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.peakScreenTitle)
            .foregroundStyle(.peakTextPrimary)
            .accessibilityAddTraits(.isHeader)
    }

    fileprivate func point(_ systemImage: String, _ text: LocalizedStringKey) -> some View {
        Label {
            Text(text)
                .font(.peakCardLabel)
                .foregroundStyle(.peakTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(.peakTextSecondary)
        }
    }

    fileprivate func goalPicker<Content: View>(
        _ label: LocalizedStringKey, selection: Binding<Int>, @ViewBuilder options: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(.peakRow)
                .foregroundStyle(.peakTextSecondary)
            Picker(label, selection: selection, content: options)
                .pickerStyle(.wheel)
                .frame(height: 120)
        }
        .glassCard()
    }

    /// A roomy choice card: its symbol, the title and a line on what it does, and a chevron.
    fileprivate func choice(
        _ title: LocalizedStringKey, detail: LocalizedStringKey, systemImage: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.medium) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(.peakTextPrimary)
                    .frame(width: 32)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                    Text(title)
                        .font(.peakCardValue)
                        .foregroundStyle(.peakTextPrimary)
                    Text(detail)
                        .font(.peakDetail)
                        .foregroundStyle(.peakTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.peakDetail)
                    .foregroundStyle(.peakTextTertiary)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, Spacing.medium)
            .frame(minHeight: 88)
        }
        .buttonStyle(PeakGlassButtonStyle(tone: .neutral))
    }

    fileprivate func primary(_ title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(role: .confirm, action: action) {
            Text(title).frame(maxWidth: .infinity)
        }
        .buttonStyle(.peakGlass)
    }

    fileprivate func secondary(_ title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).frame(maxWidth: .infinity)
        }
        .buttonStyle(PeakGlassButtonStyle(tone: .neutral))
    }
}

#if DEBUG
    #Preview {
        OnboardingView { _ in }
            .previewEnvironment()
    }
#endif
