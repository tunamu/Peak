import Foundation

/// Which way a movement or a number is heading (D-26): the arrow beside a movement's name.
public enum Trend: String, Hashable, Sendable {
    case rising, steady, falling
}

/// The last value against the average of the ones before it.
public struct TrendChange: Hashable, Sendable {
    public var trend: Trend
    /// Relative change, e.g. 0.06 for 6% up.
    public var change: Double

    public init(trend: Trend, change: Double) {
        self.trend = trend
        self.change = change
    }
}

/// One session of one movement: a point on its chart.
public struct MovementPoint: Hashable, Sendable {
    public var sessionID: UUID
    public var date: Date
    public var isDateEstimated: Bool
    /// The set with the highest estimated one-rep max; `nil` for a walk or when no set has reps.
    public var bestSet: SetPerformance?
    /// What the chart and the trend follow: the best set's estimated one-rep max in kg, its reps for a bodyweight
    /// movement, and for a walk its distance in km (or its minutes when the distance is unknown).
    public var value: Double
    public var volumeKg: Double
    public var doneSets: Int
    public var distanceKm: Double?
    public var durationSec: Int?
    /// Above every earlier session of the movement (never the first one).
    public var isRecord: Bool
    /// The session's note on the movement (F11-12).
    public var note: String = ""
}

/// A movement across the sessions it appears in.
public struct MovementSummary: Hashable, Sendable, Identifiable {
    public var id: String { key }
    public var key: String
    /// The name it was last logged under.
    public var name: String
    public var muscleGroup: MuscleGroup
    public var isCardio: Bool
    /// Its reps are what counts: every set without weight.
    public var isBodyweight: Bool
    /// Oldest first.
    public var points: [MovementPoint]
    public var trend: TrendChange?
    /// How the movement is set up, as last saved (F11-12).
    public var setupNote: String = ""

    public var latest: MovementPoint? { points.last }
    /// Sessions with a note on the movement, newest first.
    public var notes: [MovementPoint] { points.filter { !$0.note.isEmpty }.reversed() }
    /// The best value so far.
    public var record: MovementPoint? { points.max { $0.value < $1.value } }
}

/// One session of a workout template.
public struct WorkoutPoint: Hashable, Sendable {
    public var sessionID: UUID
    public var date: Date
    public var volumeKg: Double
    /// Done sets / planned sets (0…1).
    public var completion: Double
    /// Movements that hit every target (0…1); `nil` when none had targets.
    public var successRate: Double?
    public var duration: TimeInterval
}

/// A workout template across its sessions; imported sessions without a template are grouped by title.
public struct WorkoutSeries: Hashable, Sendable, Identifiable {
    public var id: String
    public var templateID: UUID?
    public var title: String
    /// Oldest first.
    public var points: [WorkoutPoint]
    /// Follows the volume.
    public var trend: TrendChange?

    public var latest: WorkoutPoint? { points.last }
}

/// A calendar week of training.
public struct WeekTotals: Hashable, Sendable, Identifiable {
    public var id: Date { start }
    public var start: Date
    public var sessions: Int
    public var volumeKg: Double
    public var doneSets: Int
}

/// Done strength sets of a muscle group (D-27: sets, since volume cannot compare legs with biceps).
public struct MuscleShare: Hashable, Sendable, Identifiable {
    public var id: MuscleGroup { group }
    public var group: MuscleGroup
    public var sets: Int
    /// Of all done strength sets in the period (0…1).
    public var share: Double
}

/// The numbers on top of the Performance page for a period.
public struct PeriodTotals: Hashable, Sendable {
    public var sessions: Int
    public var volumeKg: Double
    public var doneSets: Int
    public var duration: TimeInterval
    /// Movements that hit every target / movements that had targets (0…1); `nil` when none had any.
    public var successRate: Double?
}

/// The period the Performance page looks at.
public enum AnalysisPeriod: String, CaseIterable, Hashable, Sendable {
    case fourWeeks, threeMonths, sixMonths, year, all

    /// From the start of the period's first day to the end of today; `nil` for all time.
    public func range(now: Date, calendar: Calendar = .current) -> Range<Date>? {
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        let start: Date? =
            switch self {
            case .fourWeeks: calendar.date(byAdding: .day, value: -28, to: end)
            case .threeMonths: calendar.date(byAdding: .month, value: -3, to: end)
            case .sixMonths: calendar.date(byAdding: .month, value: -6, to: end)
            case .year: calendar.date(byAdding: .year, value: -1, to: end)
            case .all: nil
            }
        return start.map { $0..<end }
    }

    /// The same length just before `range(now:)`, for the change arrows; `nil` for all time.
    public func previousRange(now: Date, calendar: Calendar = .current) -> Range<Date>? {
        guard let range = range(now: now, calendar: calendar) else { return nil }
        let start: Date? =
            switch self {
            case .fourWeeks: calendar.date(byAdding: .day, value: -28, to: range.lowerBound)
            case .threeMonths: calendar.date(byAdding: .month, value: -3, to: range.lowerBound)
            case .sixMonths: calendar.date(byAdding: .month, value: -6, to: range.lowerBound)
            case .year: calendar.date(byAdding: .year, value: -1, to: range.lowerBound)
            case .all: nil
            }
        return start.map { $0..<range.lowerBound }
    }
}

/// F11-02: the Analysis screen's numbers, from completed sessions (docs/ANALYSIS.md). Pure; sessions come in any
/// order.
public enum PerformanceAnalysis {
    /// Changes within ±2% read as flat (D-26).
    public static let flatBand = 0.02
    /// The last value is compared with the average of up to this many before it.
    public static let trendWindow = 3

    // MARK: Sets

    /// Epley's estimate of the weight one rep could move: w × (1 + r / 30); the weight itself for a single rep.
    public static func estimatedOneRepMax(_ set: SetPerformance) -> Double {
        guard set.reps > 0, set.weightKg > 0 else { return 0 }
        return set.reps == 1 ? set.weightKg : set.weightKg * (1 + Double(set.reps) / 30)
    }

    /// The set with the highest estimated one-rep max, then the most reps (bodyweight sets); `nil` without reps.
    public static func bestSet(_ sets: [SetPerformance]) -> SetPerformance? {
        sets.filter { $0.reps > 0 }.max { lhs, rhs in
            let left = estimatedOneRepMax(lhs)
            let right = estimatedOneRepMax(rhs)
            return left == right ? lhs.reps < rhs.reps : left < right
        }
    }

    // MARK: Trend

    /// The last value against the average of up to `trendWindow` values before it; `nil` under two values or when
    /// there is nothing to compare with.
    public static func trend(_ values: [Double]) -> TrendChange? {
        guard values.count >= 2, let last = values.last else { return nil }
        let before = values.dropLast().suffix(trendWindow)
        return change(from: before.reduce(0, +) / Double(before.count), to: last)
    }

    // MARK: Movements

    /// Every movement in the sessions, with its points oldest first; ordered by the latest session, then name.
    public static func movements(in sessions: [AnalysisSession]) -> [MovementSummary] {
        var byKey: [String: [(AnalysisSession, AnalysisMovement)]] = [:]
        for session in sessions.sorted(by: chronological) {
            for movement in session.movements where !movement.key.isEmpty {
                byKey[movement.key, default: []].append((session, movement))
            }
        }
        return byKey.map { key, entries in summary(key: key, entries: entries) }
            .filter { !$0.points.isEmpty }
            .sorted { lhs, rhs in
                let left = lhs.latest?.date ?? .distantPast
                let right = rhs.latest?.date ?? .distantPast
                return left == right ? lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending : left > right
            }
    }

    private static func summary(key: String, entries: [(AnalysisSession, AnalysisMovement)]) -> MovementSummary {
        let isCardio = entries.contains { $0.1.result.isCardio }
        let strengthSets = entries.flatMap { $0.1.result.sets.filter { $0.reps > 0 } }
        let isBodyweight = !isCardio && !strengthSets.isEmpty && strengthSets.allSatisfy { $0.weightKg <= 0 }
        var points: [MovementPoint] = []
        for (session, movement) in entries {
            let done = movement.result.sets.filter { $0.reps > 0 }
            let best = isCardio ? nil : bestSet(done)
            let value: Double? =
                if isCardio {
                    movement.distanceKm ?? movement.durationSec.map { Double($0) / 60 }
                } else if let best, isBodyweight {
                    Double(best.reps)
                } else {
                    best.map(estimatedOneRepMax)
                }
            // A movement that was skipped this time is not a point at zero.
            guard let value, value > 0 else { continue }
            let earlierBest = points.map(\.value).max()
            points.append(
                MovementPoint(
                    sessionID: session.id,
                    date: session.date,
                    isDateEstimated: session.isDateEstimated,
                    bestSet: best,
                    value: value,
                    volumeKg: isCardio ? 0 : SessionStatistics.volumeKg([movement.result]),
                    doneSets: isCardio ? 0 : done.count,
                    distanceKm: movement.distanceKm,
                    durationSec: movement.durationSec,
                    isRecord: earlierBest.map { value > $0 + 0.000_1 } ?? false,
                    note: movement.note
                ))
        }
        let last = entries.last?.1
        return MovementSummary(
            key: key,
            name: last?.name ?? key,
            muscleGroup: last?.muscleGroup ?? .other,
            isCardio: isCardio,
            isBodyweight: isBodyweight,
            points: points,
            trend: trend(points.map(\.value)),
            setupNote: last?.setupNote ?? ""
        )
    }

    // MARK: Workouts

    /// Every workout template in the sessions, by its template, or by title for sessions without one; ordered by the
    /// latest session.
    public static func workouts(in sessions: [AnalysisSession]) -> [WorkoutSeries] {
        var byID: [String: [AnalysisSession]] = [:]
        for session in sessions.sorted(by: chronological) {
            let id = session.templateID?.uuidString ?? "title:" + session.title.matchingKey
            byID[id, default: []].append(session)
        }
        return byID.map { id, sessions in
            let points = sessions.map { session in
                WorkoutPoint(
                    sessionID: session.id,
                    date: session.date,
                    volumeKg: session.volumeKg,
                    completion: SessionStatistics.completion(session.results),
                    successRate: targetSuccess(session.results),
                    duration: session.duration
                )
            }
            return WorkoutSeries(
                id: id,
                templateID: sessions.last?.templateID,
                title: sessions.last?.title ?? "",
                points: points,
                trend: trend(points.map(\.volumeKg))
            )
        }
        .sorted { ($0.latest?.date ?? .distantPast) > ($1.latest?.date ?? .distantPast) }
    }

    // MARK: Weeks

    /// Totals per calendar week from the first session's week (or `range`'s start) to the week of `now`, empty
    /// weeks included, oldest first.
    public static func weeks(
        of sessions: [AnalysisSession],
        in range: Range<Date>? = nil,
        now: Date,
        calendar: Calendar = .current
    ) -> [WeekTotals] {
        let inRange = sessions.filter { range?.contains($0.date) ?? true }
        guard let first = range?.lowerBound ?? inRange.map(\.date).min(),
            var week = calendar.dateInterval(of: .weekOfYear, for: first)?.start,
            let last = calendar.dateInterval(of: .weekOfYear, for: now)?.start
        else { return [] }
        var totals: [Date: WeekTotals] = [:]
        for session in inRange {
            guard let start = calendar.dateInterval(of: .weekOfYear, for: session.date)?.start else { continue }
            var total = totals[start] ?? WeekTotals(start: start, sessions: 0, volumeKg: 0, doneSets: 0)
            total.sessions += 1
            total.volumeKg += session.volumeKg
            total.doneSets += session.doneSetCount
            totals[start] = total
        }
        var result: [WeekTotals] = []
        while week <= last {
            result.append(totals[week] ?? WeekTotals(start: week, sessions: 0, volumeKg: 0, doneSets: 0))
            guard let next = calendar.date(byAdding: .weekOfYear, value: 1, to: week) else { break }
            week = next
        }
        return result
    }

    /// Weeks in a row with at least one session, up to this week. This week does not break the run before it is
    /// over: with no session yet, the count ends last week.
    public static func streakWeeks(of sessions: [AnalysisSession], now: Date, calendar: Calendar = .current) -> Int {
        let trained = Set(sessions.compactMap { calendar.dateInterval(of: .weekOfYear, for: $0.date)?.start })
        guard var week = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return 0 }
        if !trained.contains(week) {
            guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: week) else { return 0 }
            week = previous
        }
        var count = 0
        while trained.contains(week) {
            count += 1
            guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: week) else { break }
            week = previous
        }
        return count
    }

    // MARK: Muscle groups

    /// Done strength sets per muscle group, most first; groups without sets are left out.
    public static func muscleShares(of sessions: [AnalysisSession]) -> [MuscleShare] {
        var sets: [MuscleGroup: Int] = [:]
        for movement in sessions.flatMap(\.movements) where !movement.result.isCardio {
            let done = movement.result.sets.count { $0.reps > 0 }
            if done > 0 { sets[movement.muscleGroup, default: 0] += done }
        }
        let total = sets.values.reduce(0, +)
        return sets.map { MuscleShare(group: $0, sets: $1, share: Double($1) / Double(total)) }
            .sorted { $0.sets == $1.sets ? $0.group.sortIndex < $1.group.sortIndex : $0.sets > $1.sets }
    }

    // MARK: Periods

    public static func totals(of sessions: [AnalysisSession], in range: Range<Date>? = nil) -> PeriodTotals {
        let inRange = sessions.filter { range?.contains($0.date) ?? true }
        return PeriodTotals(
            sessions: inRange.count,
            volumeKg: inRange.reduce(0) { $0 + $1.volumeKg },
            doneSets: inRange.reduce(0) { $0 + $1.doneSetCount },
            duration: inRange.reduce(0) { $0 + $1.duration },
            successRate: targetSuccess(inRange.flatMap(\.results))
        )
    }

    /// Movements that hit every target, counting only those that had targets (and walks): an imported session has
    /// none, and would otherwise count as all hit. `nil` when nothing had a target.
    public static func targetSuccess(_ results: [ExerciseResult]) -> Double? {
        let judged = results.filter { $0.isCardio || !$0.targets.isEmpty }
        return judged.isEmpty ? nil : SessionStatistics.successRate(judged)
    }

    /// The relative change from `previous` to `current`, as a trend; `nil` when there was nothing before.
    public static func change(from previous: Double, to current: Double) -> TrendChange? {
        guard previous > 0 else { return nil }
        let change = current / previous - 1
        // The tolerance keeps exactly 2% flat: 102 / 100 − 1 is a hair above 0.02 in floating point.
        let band = flatBand + 1e-9
        let trend: Trend = change > band ? .rising : change < -band ? .falling : .steady
        return TrendChange(trend: trend, change: change)
    }

    private static func chronological(_ lhs: AnalysisSession, _ rhs: AnalysisSession) -> Bool {
        lhs.date < rhs.date
    }
}

extension MuscleGroup {
    /// The order groups are listed in when their counts tie.
    public var sortIndex: Int { Self.allCases.firstIndex(of: self) ?? 0 }
}
