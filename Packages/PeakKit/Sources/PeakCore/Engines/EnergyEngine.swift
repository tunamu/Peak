import Foundation

/// The thresholds of the energy score (docs/ENERGY_LEVEL.md). Not medical advice.
public enum EnergyConfig {
    public static let readyMinimum = 70
    public static let lowMinimum = 40

    // Level A: training load (everyone).
    public static let recentWorkoutPenalty = 30  // last strength workout under 24 h ago
    public static let yesterdayWorkoutPenalty = 10  // 24–48 h ago
    public static let sameMusclesPenalty = 25  // today's muscles trained in the last 48 h
    public static let streakDays = 3
    public static let streakPenalty = 20  // 3 or more training days in a row

    // Level B: sleep.
    public static let shortSleep: TimeInterval = 5 * 3_600
    public static let shortSleepPenalty = 30
    public static let lightSleep: TimeInterval = 6.5 * 3_600
    public static let lightSleepPenalty = 15

    // Level C: Apple Watch, against the 7-day average; needs this many days of baseline.
    public static let baselineDays = 5
    public static let hrvLargeDrop = -0.15
    public static let hrvLargeDropPenalty = 25
    public static let hrvSmallDrop = -0.05
    public static let hrvSmallDropPenalty = 10
    public static let restingHeartRateRise = 5.0
    public static let restingHeartRatePenalty = 15
}

public enum EnergyLevel: String, Codable, Sendable {
    /// ≥ 70: "You can workout now".
    case ready
    /// 40–69: "You can workout a bit".
    case low
    /// < 40: "You can't workout now. You should rest at least 1 day to workout again."
    case notReady

    public init(score: Int) {
        self =
            score >= EnergyConfig.readyMinimum ? .ready : score >= EnergyConfig.lowMinimum ? .low : .notReady
    }
}

/// Where the score's inputs came from, for the detail sheet.
public enum EnergySource: String, Hashable, Sendable {
    case workouts, sleep, heart
}

/// Why points were taken off. The UI turns these into sentences ("Last workout 18 hours ago").
public enum EnergyReason: Hashable, Sendable {
    case lastWorkout(hoursAgo: Int)
    case sameMuscles([MuscleGroup])
    case trainingStreak(days: Int)
    case sleep(duration: TimeInterval)
    case heartRateVariability(changePercent: Int)
    case restingHeartRate(changeBpm: Int)
}

public struct EnergyInput: Sendable {
    /// A strength workout: when it ended and what it trained.
    public struct Workout: Sendable {
        public var endedAt: Date
        public var muscleGroups: Set<MuscleGroup>

        public init(endedAt: Date, muscleGroups: Set<MuscleGroup>) {
            self.endedAt = endedAt
            self.muscleGroups = muscleGroups
        }
    }

    public var now: Date
    /// Recent strength workouts (a week is plenty).
    public var workouts: [Workout]
    /// Muscles of today's planned workout; empty when nothing is planned.
    public var plannedMuscleGroups: Set<MuscleGroup>
    /// Last night's sleep; `nil` without sleep data.
    public var sleepDuration: TimeInterval?
    /// Today's HRV (SDNN, ms) and the previous days' values.
    public var heartRateVariability: Double?
    public var heartRateVariabilityHistory: [Double]
    /// Today's resting heart rate (bpm) and the previous days' values.
    public var restingHeartRate: Double?
    public var restingHeartRateHistory: [Double]

    public init(
        now: Date,
        workouts: [Workout] = [],
        plannedMuscleGroups: Set<MuscleGroup> = [],
        sleepDuration: TimeInterval? = nil,
        heartRateVariability: Double? = nil,
        heartRateVariabilityHistory: [Double] = [],
        restingHeartRate: Double? = nil,
        restingHeartRateHistory: [Double] = []
    ) {
        self.now = now
        self.workouts = workouts
        self.plannedMuscleGroups = plannedMuscleGroups
        self.sleepDuration = sleepDuration
        self.heartRateVariability = heartRateVariability
        self.heartRateVariabilityHistory = heartRateVariabilityHistory
        self.restingHeartRate = restingHeartRate
        self.restingHeartRateHistory = restingHeartRateHistory
    }
}

public struct EnergyResult: Sendable {
    public var score: Int
    public var level: EnergyLevel
    /// Each deduction and its points, in rule order.
    public var reasons: [(reason: EnergyReason, points: Int)]
    public var sources: Set<EnergySource>
}

/// The hybrid energy score (D-03): starts at 100, and each rule with data takes points off.
public struct EnergyEngine: Sendable {
    public var calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public func evaluate(_ input: EnergyInput) -> EnergyResult {
        var reasons: [(reason: EnergyReason, points: Int)] = []
        var sources: Set<EnergySource> = [.workouts]
        let past = input.workouts.filter { $0.endedAt <= input.now }

        if let last = past.map(\.endedAt).max() {
            let hours = input.now.timeIntervalSince(last) / 3_600
            if hours < 24 {
                reasons.append((.lastWorkout(hoursAgo: Int(hours)), EnergyConfig.recentWorkoutPenalty))
            } else if hours < 48 {
                reasons.append((.lastWorkout(hoursAgo: Int(hours)), EnergyConfig.yesterdayWorkoutPenalty))
            }
        }

        let recentMuscles =
            past
            .filter { input.now.timeIntervalSince($0.endedAt) < 48 * 3_600 }
            .reduce(into: Set<MuscleGroup>()) { $0.formUnion($1.muscleGroups) }
        let overlap = input.plannedMuscleGroups.intersection(recentMuscles).subtracting([.other, .cardio])
        if !overlap.isEmpty {
            reasons.append(
                (.sameMuscles(overlap.sorted { $0.rawValue < $1.rawValue }), EnergyConfig.sameMusclesPenalty))
        }

        let streak = trainingStreak(past.map(\.endedAt), now: input.now)
        if streak >= EnergyConfig.streakDays {
            reasons.append((.trainingStreak(days: streak), EnergyConfig.streakPenalty))
        }

        if let sleep = input.sleepDuration {
            sources.insert(.sleep)
            if sleep < EnergyConfig.shortSleep {
                reasons.append((.sleep(duration: sleep), EnergyConfig.shortSleepPenalty))
            } else if sleep < EnergyConfig.lightSleep {
                reasons.append((.sleep(duration: sleep), EnergyConfig.lightSleepPenalty))
            }
        }

        reasons += heartReasons(input, sources: &sources)

        let score = max(0, 100 - reasons.reduce(0) { $0 + $1.points })
        return EnergyResult(score: score, level: EnergyLevel(score: score), reasons: reasons, sources: sources)
    }

    // MARK: Private

    private func heartReasons(_ input: EnergyInput, sources: inout Set<EnergySource>)
        -> [(reason: EnergyReason, points: Int)]
    {
        var reasons: [(reason: EnergyReason, points: Int)] = []
        if let today = input.heartRateVariability,
            let average = baseline(input.heartRateVariabilityHistory), average > 0
        {
            sources.insert(.heart)
            let change = (today - average) / average
            let percent = Int((change * 100).rounded())
            if change < EnergyConfig.hrvLargeDrop {
                reasons.append((.heartRateVariability(changePercent: percent), EnergyConfig.hrvLargeDropPenalty))
            } else if change < EnergyConfig.hrvSmallDrop {
                reasons.append((.heartRateVariability(changePercent: percent), EnergyConfig.hrvSmallDropPenalty))
            }
        }
        if let today = input.restingHeartRate, let average = baseline(input.restingHeartRateHistory) {
            sources.insert(.heart)
            let rise = today - average
            if rise > EnergyConfig.restingHeartRateRise {
                reasons.append(
                    (.restingHeartRate(changeBpm: Int(rise.rounded())), EnergyConfig.restingHeartRatePenalty))
            }
        }
        return reasons
    }

    /// The average of the last seven values, once there are enough days to trust it.
    private func baseline(_ values: [Double]) -> Double? {
        let week = values.suffix(7)
        guard week.count >= EnergyConfig.baselineDays else { return nil }
        return week.reduce(0, +) / Double(week.count)
    }

    /// Consecutive calendar days with a workout, ending today (or yesterday when today has none yet).
    private func trainingStreak(_ dates: [Date], now: Date) -> Int {
        let days = Set(dates.map { calendar.startOfDay(for: $0) })
        var day = calendar.startOfDay(for: now)
        if !days.contains(day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        var streak = 0
        while days.contains(day) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }
}
