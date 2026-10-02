import SwiftUI

/// D-23: every haptic in Peak, by what it means. The system's own feedback, kept for moments that matter, as the HIG
/// asks: a choice, a set or water logged, a workout started, paused or finished, a warning and an error. Controls
/// that give their own (toggles, steppers, pickers, list reordering, the keyboard) get nothing more. iOS leaves them
/// out when System Haptics is off. The table is in docs/DESIGN_SYSTEM.md › Haptics.
public enum PeakHaptic: CaseIterable, Sendable {
    /// A day, page, period or measure picked.
    case selection
    /// A set became done.
    case setDone
    /// Water added.
    case waterAdded
    /// A workout began.
    case workoutStarted
    /// A running workout paused or resumed.
    case pauseToggled
    /// A workout finished, an import done.
    case success
    /// Something asks before going on: "Start anyway?", Delete All Data.
    case warning
    /// Something failed, such as an import.
    case error

    public var feedback: SensoryFeedback {
        switch self {
        case .selection: .selection
        case .setDone: .impact(weight: .light)
        case .waterAdded: .increase
        case .workoutStarted: .impact(weight: .medium)
        case .pauseToggled: .impact(weight: .light)
        case .success: .success
        case .warning: .warning
        case .error: .error
        }
    }
}

extension View {
    /// Plays `haptic` whenever `trigger` changes.
    public func peakHaptic(_ haptic: PeakHaptic, trigger: some Equatable) -> some View {
        sensoryFeedback(haptic.feedback, trigger: trigger)
    }

    /// Plays the haptic `haptic` picks from the old and new value of `trigger`, or none for `nil`.
    public func peakHaptic<Trigger: Equatable>(
        trigger: Trigger, _ haptic: @escaping (_ old: Trigger, _ new: Trigger) -> PeakHaptic?
    ) -> some View {
        sensoryFeedback(trigger: trigger) { old, new in haptic(old, new)?.feedback }
    }
}
