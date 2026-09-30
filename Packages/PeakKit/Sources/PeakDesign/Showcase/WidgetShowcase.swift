#if DEBUG
    import PeakCore
    import SwiftUI

    /// The Home Screen widgets (C-16) at their real sizes on a wallpaper, in the states they can show: the Component
    /// Gallery's "widgets" section (`-PeakShowcaseSection widgets`).
    struct WidgetShowcase: View {
        private static let small = CGSize(width: 170, height: 170)
        private static let medium = CGSize(width: 364, height: 170)

        private var running: WidgetContent {
            var content = WidgetContent.sample
            content.workout = .active(
                name: "Back & Triceps", startedAt: .now.addingTimeInterval(-1_520), isPaused: false)
            content.energy = .low
            return content
        }

        private var restWithoutHealth: WidgetContent {
            var content = WidgetContent.sample
            content.workout = .rest(next: .now.addingTimeInterval(86_400))
            content.steps = nil
            content.energy = nil
            content.waterMl = 4_200
            return content
        }

        private var paused: WorkoutActivityState {
            var state = WorkoutActivityState.sample
            state.pausedElapsed = 1_520
            state.completedSets = 7
            state.currentExercise = "V Bar Triceps Pushdown"
            return state
        }

        var body: some View {
            VStack(alignment: .leading, spacing: Spacing.medium) {
                SectionHeader("Widgets")
                VStack(spacing: Spacing.medium) {
                    HStack(spacing: Spacing.medium) {
                        tile(Self.small) {
                            WaterWidgetView(content: .sample) { label in
                                Button {
                                } label: {
                                    label.frame(maxWidth: .infinity)
                                }
                            }
                        }
                        tile(Self.small) { StepsWidgetView(content: .sample) }
                    }
                    tile(Self.medium) { TodayWidgetView(content: .sample) }
                    tile(Self.medium) { TodayWidgetView(content: running) }
                    HStack(spacing: Spacing.medium) {
                        tile(Self.small) {
                            WaterWidgetView(content: restWithoutHealth) { label in
                                Button {
                                } label: {
                                    label.frame(maxWidth: .infinity)
                                }
                            }
                        }
                        tile(Self.small) { StepsWidgetView(content: restWithoutHealth) }
                    }
                    tile(Self.medium) { TodayWidgetView(content: restWithoutHealth) }
                    // The Live Activity's Lock Screen banner, running and paused.
                    ForEach([WorkoutActivityState.sample, paused], id: \.self) { state in
                        WorkoutActivityLockScreen(workoutName: "Back & Triceps", state: state) { label in
                            Button {
                            } label: {
                                label
                            }
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.circle)
                        }
                        .frame(width: Self.medium.width)
                        .background(.peakCanvas.opacity(0.85), in: .rect(cornerRadius: 22))
                    }
                }
                .padding(Spacing.medium)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.25, green: 0.22, blue: 0.45), Color(red: 0.05, green: 0.05, blue: 0.12)],
                        startPoint: .top, endPoint: .bottom),
                    in: .rect(cornerRadius: Radius.card))
            }
        }

        /// A widget as the Home Screen draws it: its size, the system's margins, the rounded background.
        private func tile(_ size: CGSize, @ViewBuilder content: () -> some View) -> some View {
            content()
                .padding(16)
                .frame(width: size.width, height: size.height)
                .background(.peakCanvas, in: .rect(cornerRadius: 22))
        }
    }
#endif
