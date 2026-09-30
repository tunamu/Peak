#if DEBUG
    import SwiftUI

    /// Design system primitives and components with sample content from the design. Debug builds only; grows into
    /// the Component Gallery in F1-05.
    public struct DesignShowcase: View {
        private let horizontalMargin: CGFloat

        @State private var stepGoal = 10_000
        @State private var isStepGoalShown = false
        @State private var result: ResultKind?

        /// - Parameter horizontalMargin: Pass 0 when the parent already applies the screen margin.
        public init(horizontalMargin: CGFloat = Spacing.screenMargin) {
            self.horizontalMargin = horizontalMargin
        }

        public var body: some View {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.section) {
                        dashboard.id("dashboard")
                        buttons.id("buttons")
                        settings.id("settings")
                        WidgetShowcase().id("widgets")
                    }
                    .padding(.horizontal, horizontalMargin)
                    .padding(.vertical, Spacing.large)
                }
                .onAppear { applyLaunchArguments(proxy) }
            }
            .background(.peakCanvas)
            .sheet(isPresented: $isStepGoalShown) {
                ValuePickerSheet(
                    titles: .init("Daily Step Goal", pickerLabel: "New Goal", reset: "Reset", update: "Update"),
                    current: stepGoal,
                    defaultValue: 10_000,
                    options: Array(stride(from: 1_000, through: 50_000, by: 500)),
                    format: { $0.formatted() },
                    onSave: { stepGoal = $0 }
                )
            }
            .sheet(isPresented: isResultShown) {
                resultSheet
            }
        }

        /// Screenshot helpers: launch with `-PeakShowcaseSection settings|widgets` or
        /// `-PeakShowcaseSheet stepGoal|success|failure`.
        /// Launch arguments of the form `-key value` land in `UserDefaults`.
        private func applyLaunchArguments(_ proxy: ScrollViewProxy) {
            let defaults = UserDefaults.standard
            if let section = defaults.string(forKey: "PeakShowcaseSection") {
                // After the push animation: scrolling during it is ignored.
                Task {
                    try? await Task.sleep(for: .milliseconds(600))
                    proxy.scrollTo(section, anchor: .top)
                }
            }
            switch defaults.string(forKey: "PeakShowcaseSheet") {
            case "stepGoal": isStepGoalShown = true
            case "success": result = .success
            case "failure": result = .failure
            default: break
            }
        }

        // MARK: Dashboard

        private var dashboard: some View {
            VStack(alignment: .leading, spacing: Spacing.small) {
                SectionHeader("Dashboard")
                VStack(spacing: Spacing.medium) {
                    stepsCard
                    // Neighbouring glass shares one container.
                    GlassEffectContainer(spacing: Spacing.medium) {
                        HStack(spacing: Spacing.medium) {
                            tile(symbol: "bolt.fill", color: .peakEnergyReady, label: "Energy Level", value: "Ready")
                            tile(symbol: "drop.fill", color: .peakWater, label: "Water", value: "1.2 L")
                        }
                    }
                    setTable
                }
            }
        }

        private var stepsCard: some View {
            HStack(spacing: Spacing.xLarge + Spacing.xSmall) {
                VStack(alignment: .leading, spacing: Spacing.xSmall) {
                    Text(verbatim: "Daily Step Count")
                        .font(.peakCardLabel)
                        .foregroundStyle(.peakTextPrimary)
                    Text(verbatim: "\(7_598.formatted()) / \(stepGoal.formatted())")
                        .font(.peakCardValue)
                        .monospacedDigit()
                        .foregroundStyle(.peakTextPrimary)
                    Text(verbatim: "Weekly Average \(6_771.formatted()) / day")
                        .font(.peakDetail)
                        .foregroundStyle(.peakTextTertiary)
                }
                Spacer(minLength: 0)
                VStack(spacing: Spacing.xxSmall) {
                    ProgressRing(progress: 7_598 / Double(stepGoal), tint: .peakSteps)
                        .frame(width: 80, height: 80)
                        .accessibilityLabel(Text(verbatim: "Steps"))
                    Text(7_598 / Double(stepGoal), format: .percent.precision(.fractionLength(0)))
                        .font(.peakDetail)
                        .monospacedDigit()
                        .foregroundStyle(.peakTextPrimary)
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity)
            .glassCard()
        }

        private func tile(symbol: String, color: Color, label: String, value: String) -> some View {
            VStack(alignment: .leading, spacing: Spacing.xSmall) {
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(color)
                    .accessibilityHidden(true)
                Text(verbatim: label)
                    .font(.peakCardLabel)
                    .foregroundStyle(.peakTextSecondary)
                Text(verbatim: value)
                    .font(.peakCardValue)
                    .foregroundStyle(.peakTextPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard()
        }

        private var setTable: some View {
            VStack(spacing: 0) {
                ForEach(Array(["60 kg × 12", "62.5 kg × 10", "65 kg × 8"].enumerated()), id: \.offset) { index, set in
                    HStack {
                        Text(verbatim: "Set \(index + 1)")
                            .foregroundStyle(.peakTextSecondary)
                        Spacer()
                        Text(verbatim: set)
                            .monospacedDigit()
                            .foregroundStyle(.peakTextPrimary)
                    }
                    .font(.peakDetail)
                    .padding(.horizontal, Spacing.small)
                    .frame(minHeight: Metrics.minTouchTarget)
                }
            }
            .glassTable()
        }

        // MARK: Buttons

        private var buttons: some View {
            VStack(alignment: .leading, spacing: Spacing.medium) {
                SectionHeader("Buttons")

                GlassEffectContainer(spacing: Spacing.medium) {
                    HStack(spacing: Spacing.medium) {
                        Button(role: .destructive) {
                        } label: {
                            Text(verbatim: "Reset").frame(maxWidth: .infinity)
                        }
                        Button(role: .confirm) {
                        } label: {
                            Text(verbatim: "Update").frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.peakGlass)
                }

                HStack(spacing: Spacing.medium) {
                    Button {
                    } label: {
                        Text(verbatim: "Start")
                    }
                    .buttonStyle(.peakGlass)

                    Button {
                    } label: {
                        Text(verbatim: "Finish Workout").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.peakGlass(.positive))
                }

                HStack(spacing: Spacing.medium) {
                    Text(verbatim: "200ml")
                        .font(.peakDetail)
                        .foregroundStyle(.peakTextPrimary)
                        .glassPill()

                    Button {
                    } label: {
                        Label {
                            Text(verbatim: "Start Today's Workout")
                        } icon: {
                            Image(systemName: "play.fill")
                        }
                        .font(.peakDetail)
                    }
                    .buttonStyle(.peakGlassPill)
                }

                Button {
                } label: {
                    Text(verbatim: "Disabled").frame(maxWidth: .infinity)
                }
                .buttonStyle(.peakGlass)
                .disabled(true)
            }
        }

        // MARK: Settings

        private var settings: some View {
            VStack(alignment: .leading, spacing: Spacing.section) {
                VStack(alignment: .leading, spacing: 0) {
                    SectionHeader("Goal Settings")
                    SettingsRow("Daily Step Goal", accessory: .value(stepGoal.formatted())) {
                        isStepGoalShown = true
                    }
                    SettingsRow("Daily Water Intake Goal", accessory: .value("4.0L")) {}
                    SettingsRow("Progressive Overload", accessory: .value(">12")) {}
                }

                VStack(alignment: .leading, spacing: 0) {
                    SectionHeader("Workout Settings")
                    SettingsRow("Import Workout Data (shows success)", accessory: .icon("square.and.arrow.down")) {
                        result = .success
                    }
                    SettingsRow("Export Workout Data (shows error)", accessory: .icon("square.and.arrow.up")) {
                        result = .failure
                    }
                }

                VStack(alignment: .leading, spacing: 0) {
                    SectionHeader("Recorded Workouts", action: .init("New") {})
                    ForEach(["Chest & Biceps", "Back & Triceps", "Shoulder & Biceps"], id: \.self) { name in
                        SettingsRow(verbatim: name, accessory: .action("Edit")) {}
                    }
                }
            }
        }

        // MARK: Result sheet

        private var isResultShown: Binding<Bool> {
            Binding {
                result != nil
            } set: {
                if !$0 { result = nil }
            }
        }

        private var resultSheet: some View {
            let isSuccess = result == .success
            return ResultSheet(
                isSuccess ? .success : .failure,
                title: isSuccess ? "Success" : "Error",
                message: Text(verbatim: isSuccess ? "42 workouts imported" : "The file could not be read")
            ) {
                if !isSuccess {
                    Button(role: .cancel) {
                        result = nil
                    } label: {
                        Text(verbatim: "Cancel").frame(maxWidth: .infinity)
                    }
                }
                Button(role: .confirm) {
                    result = nil
                } label: {
                    Text(verbatim: isSuccess ? "Done" : "Retry").frame(maxWidth: .infinity)
                }
            }
        }
    }

    #Preview("Dark") {
        DesignShowcase()
            .preferredColorScheme(.dark)
    }

    #Preview("Light") {
        DesignShowcase()
            .preferredColorScheme(.light)
    }

    #Preview("Dynamic Type XXXL") {
        DesignShowcase()
            .preferredColorScheme(.dark)
            .dynamicTypeSize(.xxxLarge)
    }

    #Preview("Result: success") {
        Color.clear.sheet(isPresented: .constant(true)) {
            ResultSheet(.success, title: "Success", message: Text(verbatim: "1.8 / 4.0 L")) {
                Button(role: .confirm) {
                } label: {
                    Text(verbatim: "Done").frame(maxWidth: .infinity)
                }
            }
        }
    }
#endif
