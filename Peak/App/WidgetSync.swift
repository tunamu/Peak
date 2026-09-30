import PeakCore
import SwiftData
import SwiftUI
import WidgetKit

/// Keeps the widgets (C-16), the workout's Live Activity (C-17) and Apple Health in step with the app:
/// - every save to the store (water, a workout, an import) reloads the widgets, and so does leaving the app;
/// - every save, the launch and coming back bring the Live Activity in line with the running workout;
/// - coming back copies today's water total to Health, so water added from the widget reaches it too.
struct WidgetSync: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @Environment(HealthConnection.self) private var health

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { _ in
                WidgetCenter.shared.reloadAllTimelines()
                Task { await WorkoutActivity.sync(context: modelContext) }
            }
            .task { await WorkoutActivity.sync(context: modelContext) }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .active:
                    Task {
                        await copyWaterToHealth()
                        await WorkoutActivity.sync(context: modelContext)
                    }
                case .background: WidgetCenter.shared.reloadAllTimelines()
                default: break
                }
            }
    }

    private func copyWaterToHealth() async {
        guard health.status == .connected, let total = try? WaterRepository(context: modelContext).total(on: .now)
        else { return }
        try? await health.service.setWaterTotal(total, on: .now)
    }
}

extension WidgetSnapshot {
    /// Leaves today's Health values for the widgets and reloads them.
    static func save(steps: Int?, energy: EnergyLevel?) {
        try? WidgetSnapshot(day: LocalDate(.now), steps: steps, energy: energy).write()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
