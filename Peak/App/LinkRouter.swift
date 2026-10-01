import Observation
import PeakCore

/// Where shortcuts that open the app leave their `peak://` link (F9-04). They run in the app's process, so the app
/// opens the link the same way as one from a widget.
@MainActor
@Observable
final class LinkRouter {
    static let shared = LinkRouter()

    /// A link waiting for the app to open it.
    var pending: PeakLink?
    /// Onboarding's "Import My Data": Settings › Import Workout Data opens its file picker once it shows.
    var opensImportPicker = false
}
