import Foundation
import PeakCore
import SwiftData
import WidgetKit

/// One moment of the widgets' timeline.
struct PeakEntry: TimelineEntry {
    let date: Date
    let content: WidgetContent
}

/// Reads the shared store (App Group), the settings and the Health snapshot the app left, for all three widgets.
///
/// The timeline is one entry, refreshed every 30 minutes and just after midnight; the app also reloads it whenever
/// water, a workout or Health data changes. A running workout's clock ticks on its own (`Text(timerInterval:)`).
struct PeakTimeline: TimelineProvider {
    func placeholder(in context: Context) -> PeakEntry {
        PeakEntry(date: .now, content: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (PeakEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        Task { @MainActor in
            completion(PeakEntry(date: .now, content: Self.content()))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PeakEntry>) -> Void) {
        Task { @MainActor in
            let now = Date.now
            let entry = PeakEntry(date: now, content: Self.content(now: now))
            let midnight = Calendar.current.startOfDay(for: now).addingTimeInterval(86_400 + 60)
            let next = min(now.addingTimeInterval(30 * 60), midnight)
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }

    /// Today's content, or the sample if the store cannot be opened (an unsigned build without the App Group).
    @MainActor
    static func content(now: Date = .now) -> WidgetContent {
        guard let container = SharedStore.container else { return .sample }
        let settings = SettingsStore(defaults: SettingsStore.appGroupDefaults())
        let content = try? WidgetContent.make(
            context: container.mainContext, settings: settings, snapshot: WidgetSnapshot.read(), now: now)
        return content ?? .sample
    }
}

/// The widget process's one container: `ModelContext` does not keep its container alive.
@MainActor
enum SharedStore {
    static let container: ModelContainer? = try? PeakStore.makeContainer(.appGroup)
}
