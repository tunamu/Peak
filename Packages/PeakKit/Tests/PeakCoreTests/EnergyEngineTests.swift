import Foundation
import PeakCore
import Testing

@Suite struct EnergyEngineTests {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()

    static let engine = EnergyEngine(calendar: calendar)
    /// Tuesday 29.09.2026, 18:00.
    static let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 29, hour: 18)) ?? .now

    static func workout(hoursAgo: Double, _ muscles: Set<MuscleGroup> = [.chest]) -> EnergyInput.Workout {
        .init(endedAt: now.addingTimeInterval(-hoursAgo * 3_600), muscleGroups: muscles)
    }

    static func score(_ input: EnergyInput) -> Int { engine.evaluate(input).score }

    @Test func noDataIsFullyReady() {
        let result = Self.engine.evaluate(EnergyInput(now: Self.now))
        #expect(result.score == 100)
        #expect(result.level == .ready)
        #expect(result.reasons.isEmpty)
        #expect(result.sources == [.workouts])
    }

    // Level A

    @Test(arguments: [(10.0, 70), (23.9, 70), (24.0, 90), (47.9, 90), (48.0, 100), (100.0, 100)])
    func lastWorkout(_ hoursAgo: Double, _ expected: Int) {
        let input = EnergyInput(now: Self.now, workouts: [Self.workout(hoursAgo: hoursAgo, [.legs])])
        #expect(Self.score(input) == expected)
    }

    @Test func futureWorkoutsAreIgnored() {
        #expect(Self.score(EnergyInput(now: Self.now, workouts: [Self.workout(hoursAgo: -2)])) == 100)
    }

    @Test func sameMusclesWithin48Hours() {
        let input = EnergyInput(
            now: Self.now, workouts: [Self.workout(hoursAgo: 30, [.chest, .biceps])],
            plannedMuscleGroups: [.chest, .triceps])
        let result = Self.engine.evaluate(input)
        #expect(result.score == 100 - 10 - 25)
        #expect(result.reasons.map(\.reason).contains(.sameMuscles([.chest])))

        let older = EnergyInput(
            now: Self.now, workouts: [Self.workout(hoursAgo: 50, [.chest])], plannedMuscleGroups: [.chest])
        #expect(Self.score(older) == 100)
    }

    @Test func threeDaysInARow() {
        // Sunday, Monday and today (Tuesday): a 3-day streak, plus today's workout 2 hours ago.
        let input = EnergyInput(
            now: Self.now,
            workouts: [
                Self.workout(hoursAgo: 2, [.legs]), Self.workout(hoursAgo: 26, [.back]), Self.workout(hoursAgo: 50),
            ])
        let result = Self.engine.evaluate(input)
        #expect(result.reasons.map(\.reason).contains(.trainingStreak(days: 3)))
        #expect(result.score == 100 - 30 - 20)
    }

    @Test func streakEndingYesterdayCounts() {
        let input = EnergyInput(
            now: Self.now,
            workouts: [Self.workout(hoursAgo: 20), Self.workout(hoursAgo: 44), Self.workout(hoursAgo: 68)])
        #expect(Self.engine.evaluate(input).reasons.map(\.reason).contains(.trainingStreak(days: 3)))

        let broken = EnergyInput(now: Self.now, workouts: [Self.workout(hoursAgo: 20), Self.workout(hoursAgo: 68)])
        let hasStreak = Self.engine.evaluate(broken).reasons.contains {
            if case .trainingStreak = $0.reason { true } else { false }
        }
        #expect(!hasStreak)
    }

    // Level B

    @Test(arguments: [(4.5, 70), (4.99, 70), (5.0, 85), (6.49, 85), (6.5, 100), (8.0, 100)])
    func sleep(_ hours: Double, _ expected: Int) {
        let result = Self.engine.evaluate(EnergyInput(now: Self.now, sleepDuration: hours * 3_600))
        #expect(result.score == expected)
        #expect(result.sources.contains(.sleep))
    }

    // Level C

    static let steadyHRV = [50.0, 50, 50, 50, 50, 50, 50]

    @Test(arguments: [(40.0, 75), (42.4, 75), (42.5, 90), (47.4, 90), (47.5, 100), (60.0, 100)])
    func heartRateVariability(_ today: Double, _ expected: Int) {
        let input = EnergyInput(
            now: Self.now, heartRateVariability: today, heartRateVariabilityHistory: Self.steadyHRV)
        #expect(Self.score(input) == expected)
    }

    @Test func restingHeartRateRise() {
        let history = [58.0, 58, 58, 58, 58]
        #expect(Self.score(EnergyInput(now: Self.now, restingHeartRate: 64, restingHeartRateHistory: history)) == 85)
        #expect(Self.score(EnergyInput(now: Self.now, restingHeartRate: 63, restingHeartRateHistory: history)) == 100)
    }

    @Test func watchDataNeedsFiveDaysOfBaseline() {
        let input = EnergyInput(
            now: Self.now, heartRateVariability: 30, heartRateVariabilityHistory: [50, 50, 50, 50],
            restingHeartRate: 80, restingHeartRateHistory: [58, 58, 58, 58])
        let result = Self.engine.evaluate(input)
        #expect(result.score == 100)
        #expect(!result.sources.contains(.heart))
    }

    @Test func baselineUsesTheLastSevenDays() {
        // Old high values fall out of the window: the last seven average 50.
        let input = EnergyInput(
            now: Self.now, heartRateVariability: 50, heartRateVariabilityHistory: [90.0, 90, 90] + Self.steadyHRV)
        #expect(Self.score(input) == 100)
    }

    // Levels

    @Test(arguments: [
        (100, EnergyLevel.ready), (70, .ready), (69, .low), (40, .low), (39, .notReady), (0, .notReady),
    ])
    func levels(_ score: Int, _ level: EnergyLevel) {
        #expect(EnergyLevel(score: score) == level)
    }

    @Test func everythingBadBottomsOutAtZero() {
        let input = EnergyInput(
            now: Self.now,
            workouts: [Self.workout(hoursAgo: 2), Self.workout(hoursAgo: 26), Self.workout(hoursAgo: 50)],
            plannedMuscleGroups: [.chest], sleepDuration: 4 * 3_600,
            heartRateVariability: 30, heartRateVariabilityHistory: Self.steadyHRV,
            restingHeartRate: 70, restingHeartRateHistory: [58, 58, 58, 58, 58])
        let result = Self.engine.evaluate(input)
        #expect(result.score == 0)
        #expect(result.level == .notReady)
        #expect(result.sources == [.workouts, .sleep, .heart])
        #expect(result.reasons.count == 6)
    }
}
