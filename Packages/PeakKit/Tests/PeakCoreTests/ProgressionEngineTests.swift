import Foundation
import PeakCore
import Testing

/// "27.5x9, 22.5x13" → sets.
func sets(_ text: String) -> [SetPerformance] {
    text.split(separator: ",").map { part in
        let pieces = part.trimmingCharacters(in: .whitespaces).split(separator: "x")
        return SetPerformance(weightKg: Double(pieces[0]) ?? 0, reps: Int(pieces[1]) ?? 0)
    }
}

@Suite struct ProgressionEngineTests {
    @Test(arguments: [
        ("50x17", 5.0, "55x6"),  // above 12: +increment, reps reset to 6
        ("27.5x9", 2.5, "27.5x9"),  // at or below 12: same weight, reps as done
        ("45x12", 5.0, "45x12"),  // exactly 12 is not enough
        ("45x13", 5.0, "50x6"),
    ])
    func singleSet(_ done: String, _ increment: Double, _ expected: String) {
        let target = ProgressionEngine.target(after: sets(done)[0], incrementKg: increment)
        #expect(target == sets(expected)[0])
    }

    /// The `/coach` skill's next targets after the 28.09.2026 state (Program.md › "Bir Sonraki Hedef"),
    /// from each exercise's last session and increment.
    @Test(arguments: [
        ("Dumbbell Chest Press", 2.5, "27.5x9, 22.5x13", "27.5x9, 25x6"),
        ("Incline Smith Machine Press", 5.0, "55x6, 45x9", "55x6, 45x9"),
        ("Fly", 5.0, "50x7, 45x8", "50x7, 45x8"),
        ("Lat Pulldown", 5.0, "60x8, 55x9", "60x8, 55x9"),
        ("Close Grip Pulldown", 5.0, "50x11, 50x8", "50x11, 50x8"),
        ("Row", 5.0, "65x14, 65x13, 60x15", "70x6, 70x6, 65x6"),
        ("Smith Machine Shoulder Press", 5.0, "50x9, 45x11", "50x9, 45x11"),
        ("Lateral Raise", 2.5, "15x12, 15x10", "15x12, 15x10"),
        ("Rear Delt Fly", 5.0, "40x10, 35x11", "40x10, 35x11"),
        ("Incline Dumbbell Curl", 2.5, "15x9, 12.5x9", "15x9, 12.5x9"),
        ("Dumbbell Curl Goblet", 2.5, "22.5x12, 22.5x9", "22.5x12, 22.5x9"),
        ("V Bar Triceps Pushdown", 5.0, "65x12, 65x9", "65x12, 65x9"),
        ("Triceps Barbell Curl", 5.0, "30x10, 30x9", "30x10, 30x9"),
    ])
    func matchesCoachProgram(_ name: String, _ increment: Double, _ last: String, _ expected: String) {
        let done = sets(last)
        let targets = ProgressionEngine.targets(after: done, setCount: done.count, incrementKg: increment)
        #expect(targets == sets(expected), "\(name)")
    }

    @Test func extraSetsCopyTheLastTargetAndFewerDropTheRest() {
        let done = sets("60x8, 55x13")
        #expect(ProgressionEngine.targets(after: done, setCount: 3, incrementKg: 5) == sets("60x8, 60x6, 60x6"))
        #expect(ProgressionEngine.targets(after: done, setCount: 1, incrementKg: 5) == sets("60x8"))
    }

    @Test func noHistoryMeansNoTargets() {
        #expect(ProgressionEngine.targets(after: [], setCount: 2, incrementKg: 5).isEmpty)
        #expect(ProgressionEngine.targets(after: sets("0x0, 0x0"), setCount: 2, incrementKg: 5).isEmpty)
    }

    @Test func unfinishedSetsAreIgnored() {
        #expect(ProgressionEngine.targets(after: sets("60x8, 0x0"), setCount: 2, incrementKg: 5) == sets("60x8, 60x8"))
    }

    @Test func customRule() {
        let rule = ProgressionRule(thresholdReps: 10, resetReps: 8)
        #expect(ProgressionEngine.target(after: sets("40x11")[0], incrementKg: 2.5, rule: rule) == sets("42.5x8")[0])
        #expect(ProgressionEngine.target(after: sets("40x10")[0], incrementKg: 2.5, rule: rule) == sets("40x10")[0])
    }

    @Test func poundsRoundToHalf() {
        #expect(WeightUnits.displayValue(kg: 22.5, in: .imperial) == 49.5)
        #expect(WeightUnits.displayValue(kg: 22.5, in: .metric) == 22.5)
        #expect(abs(WeightUnits.kilograms(fromDisplayValue: 49.604_009, in: .imperial) - 22.5) < 0.001)
    }
}

/// F3-04 against the real training log (Antrenman-Logu.md), for the sessions after the 12-rep rule started on
/// 14.09.2026. Targets come from each exercise's previous session, as the app will compute them.
@Suite struct SessionStatisticsTests {
    struct Exercise {
        let name: String
        let increment: Double
        let previous: String?
        let done: String
    }

    static func result(_ exercise: Exercise) -> ExerciseResult {
        let done = sets(exercise.done)
        let targets = exercise.previous.map {
            ProgressionEngine.targets(after: sets($0), setCount: done.count, incrementKg: exercise.increment)
        }
        return ExerciseResult(name: exercise.name, sets: done, targets: targets ?? [])
    }

    struct LoggedSession {
        let date: String
        /// The success rate written in the log.
        let logRate: Double
        /// The success rate by the rule.
        let ruleRate: Double
        let exercises: [Exercise]

        init(_ date: String, _ logRate: Double, _ ruleRate: Double, _ exercises: [Exercise]) {
            self.date = date
            self.logRate = logRate
            self.ruleRate = ruleRate
            self.exercises = exercises
        }
    }

    static let sessions: [LoggedSession] = [
        LoggedSession(
            "16.09 Back & Triceps", 1.0, 1.0,
            [
                Exercise(name: "Lat Pulldown", increment: 5, previous: "60x8, 55x9", done: "60x8, 55x9"),
                Exercise(name: "Close Grip Pulldown", increment: 5, previous: "50x9, 45x12", done: "50x10, 45x13"),
                Exercise(name: "Row", increment: 5, previous: "60x8, 55x12, 50x17", done: "60x13, 55x15, 55x16"),
                Exercise(name: "V Bar", increment: 5, previous: "65x10, 60x12", done: "65x11, 60x13"),
                Exercise(name: "Triceps Barbell", increment: 5, previous: "25x11, 25x20", done: "25x16, 30x6"),
            ]
        ),
        // The log says 60%: it counted Lateral Raise as partial, but its second set (15x8) beat the rule's
        // target 15x6 (12.5x14 went above 12). By the rule this session is 4/5.
        LoggedSession(
            "18.09 Shoulder & Biceps", 0.6, 0.8,
            [
                Exercise(name: "Smith Shoulder Press", increment: 5, previous: nil, done: "50x6, 45x9"),
                Exercise(name: "Lateral Raise", increment: 2.5, previous: "15x12, 12.5x14", done: "15x12, 15x8"),
                Exercise(name: "Rear Delt Fly", increment: 5, previous: "40x11, 35x11", done: "40x10, 35x10"),
                Exercise(name: "Incline Curl", increment: 2.5, previous: "12.5x13, 12.5x9", done: "15x6, 12.5x10"),
                Exercise(name: "Goblet Curl", increment: 2.5, previous: "22.5x9, 20x12", done: "22.5x10, 20x15"),
            ]
        ),
        LoggedSession(
            "21.09 Chest & Triceps", 1.0, 1.0,
            [
                Exercise(name: "Chest Press", increment: 2.5, previous: "27.5x7, 22.5x11", done: "27.5x8, 22.5x12"),
                Exercise(name: "Incline Smith", increment: 5, previous: "55x5, 45x7", done: "55x5, 45x8"),
                Exercise(name: "Fly", increment: 5, previous: "50x6, 45x7", done: "50x7, 45x8"),
                Exercise(name: "V Bar", increment: 5, previous: "65x11, 60x13", done: "65x11, 65x6"),
                Exercise(name: "Triceps Barbell", increment: 5, previous: "25x16, 30x6", done: "30x9, 30x8"),
            ]
        ),
        // The log says 60% but its own note says Goblet Curl "tuttu": its second set (22.5x8) beat the rule's
        // target 22.5x6 (20x15 went above 12). By the rule this session is 4/5.
        LoggedSession(
            "23.09 Back & Biceps", 0.6, 0.8,
            [
                Exercise(name: "Lat Pulldown", increment: 5, previous: "60x8, 55x9", done: "60x8, 55x9"),
                Exercise(name: "Close Grip Pulldown", increment: 5, previous: "50x10, 45x13", done: "50x11, 50x8"),
                Exercise(name: "Row", increment: 5, previous: "60x13, 55x15, 55x16", done: "65x14, 65x13, 60x15"),
                Exercise(name: "Incline Curl", increment: 2.5, previous: "15x6, 12.5x10", done: "15x5, 12.5x9"),
                Exercise(name: "Goblet Curl", increment: 2.5, previous: "22.5x10, 20x15", done: "22.5x10, 22.5x8"),
            ]
        ),
        LoggedSession(
            "25.09 Shoulder & Triceps", 1.0, 1.0,
            [
                Exercise(name: "Smith Shoulder Press", increment: 5, previous: "50x6, 45x9", done: "50x9, 45x11"),
                Exercise(name: "Lateral Raise", increment: 2.5, previous: "15x12, 15x8", done: "15x12, 15x10"),
                Exercise(name: "Rear Delt Fly", increment: 5, previous: "40x10, 35x10", done: "40x10, 35x11"),
                Exercise(name: "V Bar", increment: 5, previous: "65x11, 65x6", done: "65x12, 65x9"),
                Exercise(name: "Triceps Barbell", increment: 5, previous: "30x9, 30x8", done: "30x10, 30x9"),
            ]
        ),
        LoggedSession(
            "28.09 Chest & Biceps", 1.0, 1.0,
            [
                Exercise(name: "Chest Press", increment: 2.5, previous: "27.5x8, 22.5x12", done: "27.5x9, 22.5x13"),
                Exercise(name: "Incline Smith", increment: 5, previous: "55x5, 45x8", done: "55x6, 45x9"),
                Exercise(name: "Fly", increment: 5, previous: "50x7, 45x8", done: "50x7, 45x8"),
                Exercise(name: "Incline Curl", increment: 2.5, previous: "15x5, 12.5x9", done: "15x9, 12.5x9"),
                Exercise(name: "Goblet Curl", increment: 2.5, previous: "22.5x10, 22.5x8", done: "22.5x12, 22.5x9"),
            ]
        ),
    ]

    @Test func successRateFollowsTheRule() {
        for session in Self.sessions {
            let rate = SessionStatistics.successRate(session.exercises.map(Self.result))
            #expect(abs(rate - session.ruleRate) < 0.001, "\(session.date): \(rate)")
        }
    }

    @Test func matchesTheLogWhereTheLogFollowsTheRule() {
        let agreeing = Self.sessions.filter { $0.logRate == $0.ruleRate }
        #expect(agreeing.count == 4)
        for session in agreeing {
            #expect(SessionStatistics.successRate(session.exercises.map(Self.result)) == session.logRate)
        }
    }

    @Test func firstTimeExerciseCountsAsBaseline() {
        let first = ExerciseResult(name: "New", sets: sets("50x6, 45x9"), targets: [])
        #expect(first.isSuccessful)
        #expect(!ExerciseResult(name: "Skipped", sets: sets("0x0, 0x0")).isSuccessful)
    }

    @Test func missingSetFails() {
        let result = ExerciseResult(name: "Row", sets: sets("60x8"), targets: sets("60x8, 55x9"))
        #expect(!result.isSuccessful)
    }

    @Test func volumeAndCompletion() {
        let exercises = [
            ExerciseResult(name: "Row", sets: sets("60x10, 50x0"), targets: sets("60x8, 50x8")),
            ExerciseResult(name: "Walk", isCardio: true, isCompleted: true),
            ExerciseResult(name: "Bike", isCardio: true, isCompleted: false),
        ]
        #expect(SessionStatistics.volumeKg(exercises) == 600)
        #expect(SessionStatistics.completion(exercises) == 0.5)
        #expect(SessionStatistics.completion([]) == 0)
    }
}
