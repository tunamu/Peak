import Foundation

/// A set as performed: weight and reps.
public struct SetPerformance: Hashable, Sendable, CustomStringConvertible {
    public var weightKg: Double
    public var reps: Int

    public init(weightKg: Double, reps: Int) {
        self.weightKg = weightKg
        self.reps = reps
    }

    public var description: String { "\(weightKg.formatted())x\(reps)" }
}

/// What a set should reach next time.
public typealias SetTarget = SetPerformance

/// The progressive overload rule (docs/PROGRESSIVE_OVERLOAD.md).
public struct ProgressionRule: Hashable, Sendable {
    /// A set must go above this many reps before its weight goes up (">12").
    public var thresholdReps: Int
    /// The rep target after a weight increase.
    public var resetReps: Int
    /// Reps added to the target while the weight stays: 1 in Peak (9 done → 10 next), 0 in the `/coach` skill the
    /// author's log was kept with (9 done → at least 9 again), which the statistics tests replay.
    public var repStep: Int

    public init(thresholdReps: Int = 12, resetReps: Int = 6, repStep: Int = 1) {
        self.thresholdReps = thresholdReps
        self.resetReps = resetReps
        self.repStep = repStep
    }

    /// The `/coach` skill's rule, for replaying the log it produced.
    public static let coach = ProgressionRule(repStep: 0)
}

/// Next targets from the last performance, set by set (docs/PROGRESSIVE_OVERLOAD.md): above the threshold the weight
/// goes up by the exercise's increment and reps reset; otherwise the weight stays and the target is one rep more than
/// just done (50×9 → 50×10, and 50×12 → 50×13, which passes the threshold). No forward projection: planned future
/// sessions show today's targets.
public enum ProgressionEngine {
    /// The target for one set after `set` was performed.
    public static func target(after set: SetPerformance, incrementKg: Double, rule: ProgressionRule = .init())
        -> SetTarget
    {
        if set.reps > rule.thresholdReps {
            return SetTarget(weightKg: set.weightKg + incrementKg, reps: rule.resetReps)
        }
        return SetTarget(weightKg: set.weightKg, reps: set.reps + rule.repStep)
    }

    /// Targets for the next session.
    ///
    /// - Parameters:
    ///   - lastSets: The sets of the exercise's last completed session, in order. Sets without reps (never done) are
    ///     ignored.
    ///   - setCount: How many sets the template asks for today. Extra sets copy the last target; fewer drop the rest.
    /// - Returns: One target per set, or an empty array when there is no history (the UI shows "—").
    public static func targets(
        after lastSets: [SetPerformance],
        setCount: Int,
        incrementKg: Double,
        rule: ProgressionRule = .init()
    ) -> [SetTarget] {
        let done = lastSets.filter { $0.reps > 0 }
        guard let last = done.last, setCount > 0 else { return [] }
        let targets = done.map { target(after: $0, incrementKg: incrementKg, rule: rule) }
        let lastTarget = target(after: last, incrementKg: incrementKg, rule: rule)
        return Array((targets + Array(repeating: lastTarget, count: max(0, setCount - targets.count))).prefix(setCount))
    }

    /// A set is successful when it reaches both the target weight and reps. A set without a target (no history yet)
    /// counts as successful: it sets the baseline.
    public static func isSuccessful(_ set: SetPerformance, target: SetTarget?) -> Bool {
        guard let target else { return true }
        return set.reps >= target.reps && set.weightKg >= target.weightKg - 0.000_1
    }
}
