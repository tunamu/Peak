import Foundation
import PeakCore
import Testing

/// F11-02: the Analysis screen's numbers (docs/ANALYSIS.md).
@Suite struct PerformanceAnalysisTests {
    /// Mondays start the week, in UTC, so the week tests do not depend on the machine.
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        calendar.timeZone = .gmt
        return calendar
    }()

    static func day(_ text: String) -> Date {
        let parts = text.split(separator: "-").compactMap { Int($0) }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 18)) ?? .now
    }

    static func session(
        _ date: String,
        title: String = "Push",
        _ movements: [(String, String)]
    ) -> AnalysisSession {
        AnalysisSession(
            date: day(date),
            duration: 3_600,
            title: title,
            movements: movements.map { name, done in
                AnalysisMovement(name: name, result: ExerciseResult(name: name, sets: sets(done)))
            }
        )
    }

    // MARK: Sets and trend

    @Test(arguments: [
        ("27.5x9", 35.75),
        ("100x1", 100.0),
        ("60x10", 80.0),
        ("50x0", 0.0),
        ("0x12", 0.0),
    ])
    func epleyOneRepMax(_ set: String, _ expected: Double) {
        #expect(abs(PerformanceAnalysis.estimatedOneRepMax(sets(set)[0]) - expected) < 0.000_1)
    }

    @Test func bestSetIsTheHighestEstimateThenTheMostReps() {
        // 27.5 × 9 → 35.75 beats 22.5 × 13 → 32.25.
        #expect(PerformanceAnalysis.bestSet(sets("27.5x9, 22.5x13")) == sets("27.5x9")[0])
        #expect(PerformanceAnalysis.bestSet(sets("0x8, 0x12, 0x10")) == sets("0x12")[0])
        #expect(PerformanceAnalysis.bestSet(sets("50x0")) == nil)
    }

    @Test(arguments: [
        ([100.0, 102, 101, 106], Trend.rising),  // 106 against 101: +5%
        ([100.0, 101], .steady),
        ([100.0, 102], .steady),  // exactly 2% is still flat
        ([100.0, 103], .rising),
        ([100.0, 97], .falling),
        ([50.0, 100, 100, 100, 101], .steady),  // only the last three before count
    ])
    func trend(_ values: [Double], _ expected: Trend) {
        #expect(PerformanceAnalysis.trend(values)?.trend == expected)
    }

    @Test func noTrendWithoutSomethingToCompare() {
        #expect(PerformanceAnalysis.trend([]) == nil)
        #expect(PerformanceAnalysis.trend([80]) == nil)
        #expect(PerformanceAnalysis.trend([0, 80]) == nil)
        #expect(PerformanceAnalysis.change(from: 0, to: 5) == nil)
    }

    // MARK: Muscle groups

    /// Every movement in the author's real log lands in the section it is listed under there.
    @Test(arguments: [
        ("Dumbell Chest Press", MuscleGroup.chest), ("İncline Smith Machine Press", .chest), ("Fly", .chest),
        ("Lat Pulldown", .back), ("Close Grip Pulldown", .back), ("Row", .back), ("Pullup Machine", .back),
        ("Shoulder Press", .shoulders), ("Smith Machine Shoulder Press", .shoulders), ("Lateral Raise", .shoulders),
        ("Reardelt Fly", .shoulders), ("Rear Delt Fly", .shoulders),
        ("Biceps Curl", .biceps), ("İncline Dumbell Curl", .biceps), ("Dumbell Curl Goblet", .biceps),
        ("V Bar Triceps Pushdown", .triceps), ("Triceps Barbell Curl", .triceps),
        ("Leg Press", .legs), ("Göğüs Press", .chest), ("Sırt Çekiş", .back), ("Karın Mekiği", .core),
        ("Incline Walk", .cardio), ("Smith Machine Press", .other),
    ])
    func muscleGroupFromName(_ name: String, _ expected: MuscleGroup) {
        #expect(MuscleGroup.inferred(from: name) == expected)
    }

    @Test func aSetGroupWinsOverTheName() {
        let movement = AnalysisMovement(name: "Fly", muscleGroup: .shoulders, result: ExerciseResult(name: "Fly"))
        #expect(movement.muscleGroup == .shoulders)
        let walk = AnalysisMovement(name: "Treadmill", result: ExerciseResult(name: "Treadmill", isCardio: true))
        #expect(walk.muscleGroup == .cardio)
    }

    @Test func muscleSharesCountDoneStrengthSets() {
        let shares = PerformanceAnalysis.muscleShares(of: [
            Self.session("2026-09-07", [("Fly", "40x10, 40x9, 40x0"), ("Row", "60x10")]),
            Self.session("2026-09-09", [("Row", "60x11, 60x10")]),
        ])
        #expect(shares.map(\.group) == [.back, .chest])
        #expect(shares.map(\.sets) == [3, 2])
        #expect(abs(shares[0].share - 0.6) < 0.000_1)
    }

    // MARK: Movements

    @Test func movementPointsRecordsAndSkippedSessions() throws {
        let movements = PerformanceAnalysis.movements(in: [
            Self.session("2026-09-14", [("Row", "60x10")]),
            Self.session("2026-09-07", [("Row", "55x10")]),
            Self.session("2026-09-21", [("Row", "60x0")]),  // skipped: not a point
            Self.session("2026-09-28", [("row ", "60x9")]),  // same movement by its key
        ])
        let row = try #require(movements.first)
        #expect(movements.count == 1)
        #expect(row.points.map(\.bestSet) == sets("55x10, 60x10, 60x9"))
        #expect(row.points.map(\.isRecord) == [false, true, false])
        #expect(row.record?.bestSet == sets("60x10")[0])
        #expect(row.name == "row ")
        #expect(row.muscleGroup == .back)
    }

    @Test func bodyweightFollowsRepsAndWalksTheirDistance() throws {
        let walk = AnalysisMovement(
            name: "Incline Walk", result: ExerciseResult(name: "Incline Walk", isCardio: true, isCompleted: true),
            distanceKm: 2.5, durationSec: 1_800)
        let movements = PerformanceAnalysis.movements(in: [
            Self.session("2026-09-07", [("Pull Up", "0x6, 0x5")]),
            Self.session("2026-09-14", [("Pull Up", "0x8")]),
            AnalysisSession(date: Self.day("2026-09-15"), movements: [walk]),
        ])
        let pullUp = try #require(movements.first { $0.name == "Pull Up" })
        #expect(pullUp.isBodyweight && pullUp.points.map(\.value) == [6, 8] && pullUp.trend?.trend == .rising)
        let walking = try #require(movements.first { $0.isCardio })
        #expect(walking.points.map(\.value) == [2.5] && walking.points[0].volumeKg == 0)
    }

    @Test func workoutsGroupByTemplateThenTitle() {
        let template = UUID()
        var first = Self.session("2026-09-07", title: "Push", [("Fly", "40x10")])
        first.templateID = template
        var second = Self.session("2026-09-14", title: "Push (renamed)", [("Fly", "40x12")])
        second.templateID = template
        let imported = Self.session("2026-09-01", title: "Göğüs", [("Fly", "35x10")])
        let workouts = PerformanceAnalysis.workouts(in: [imported, second, first])
        #expect(workouts.map(\.title) == ["Push (renamed)", "Göğüs"])
        #expect(workouts[0].points.map(\.volumeKg) == [400, 480])
        #expect(workouts[0].trend?.trend == .rising)
    }

    // MARK: Weeks and periods

    @Test func weeksIncludeEmptyOnesAndAddUp() {
        let sessions = [
            Self.session("2026-09-07", [("Row", "60x10")]),
            Self.session("2026-09-09", [("Row", "60x10, 60x8")]),
            Self.session("2026-09-21", [("Fly", "40x10")]),
        ]
        let weeks = PerformanceAnalysis.weeks(of: sessions, now: Self.day("2026-09-30"), calendar: Self.calendar)
        #expect(weeks.map(\.sessions) == [2, 0, 1, 0])
        #expect(weeks.map(\.doneSets) == [3, 0, 1, 0])
        #expect(weeks.reduce(0) { $0 + $1.volumeKg } == sessions.reduce(0) { $0 + $1.volumeKg })
        #expect(weeks.first?.start == Self.calendar.startOfDay(for: Self.day("2026-09-07")))
    }

    @Test func streakCountsWeeksInARowAndThisWeekIsNotOverYet() {
        let sessions = [
            Self.session("2026-08-31", [("Row", "60x10")]),
            // the week of 09-07 is missed
            Self.session("2026-09-15", [("Row", "60x10")]),
            Self.session("2026-09-24", [("Row", "60x10")]),
        ]
        let now = Self.day("2026-09-30")
        #expect(PerformanceAnalysis.streakWeeks(of: sessions, now: now, calendar: Self.calendar) == 2)
        let thisWeek = sessions + [Self.session("2026-09-29", [("Row", "60x10")])]
        #expect(PerformanceAnalysis.streakWeeks(of: thisWeek, now: now, calendar: Self.calendar) == 3)
        let later = Self.day("2026-10-08")
        #expect(PerformanceAnalysis.streakWeeks(of: sessions, now: later, calendar: Self.calendar) == 0)
    }

    @Test func periodsAndTheirTotals() throws {
        let now = Self.day("2026-09-30")
        let range = try #require(AnalysisPeriod.fourWeeks.range(now: now, calendar: Self.calendar))
        let previous = try #require(AnalysisPeriod.fourWeeks.previousRange(now: now, calendar: Self.calendar))
        #expect(range.upperBound == Self.calendar.startOfDay(for: Self.day("2026-10-01")))
        #expect(previous.upperBound == range.lowerBound)
        #expect(AnalysisPeriod.all.range(now: now) == nil)

        let sessions = [
            Self.session("2026-08-20", [("Row", "50x10")]),
            Self.session("2026-09-07", [("Row", "60x10")]),
            Self.session("2026-09-30", [("Row", "60x12")]),
        ]
        let current = PerformanceAnalysis.totals(of: sessions, in: range)
        let before = PerformanceAnalysis.totals(of: sessions, in: previous)
        #expect(current.sessions == 2 && current.volumeKg == 1_320 && current.doneSets == 2)
        // Without targets (as imported) nothing is judged.
        #expect(current.duration == 7_200 && current.successRate == nil)
        #expect(before.sessions == 1)
        #expect(PerformanceAnalysis.change(from: before.volumeKg, to: current.volumeKg)?.trend == .rising)
        #expect(PerformanceAnalysis.totals(of: [], in: range).successRate == nil)
    }

    @Test func targetSuccessJudgesOnlyMovementsWithTargets() {
        let hit = ExerciseResult(name: "Row", sets: sets("60x10"), targets: sets("60x10"))
        let missed = ExerciseResult(name: "Fly", sets: sets("40x8"), targets: sets("40x10"))
        let imported = ExerciseResult(name: "Curl", sets: sets("15x10"))
        #expect(PerformanceAnalysis.targetSuccess([hit, missed, imported]) == 0.5)
        #expect(PerformanceAnalysis.targetSuccess([imported]) == nil)
    }
}

/// The author's real `/coach` history, imported as in F7-08.
@MainActor
@Suite struct PerformanceAnalysisHistoryTests {
    static func importedHistory() throws -> [AnalysisSession] {
        let context = try makeContext()
        try PeakImporter(context: context).commit(ImportFixtureTests.load("antrenman-gecmisi.xlsx").converted().data)
        return try SessionRepository(context: context).completed().map(\.analysisSession)
    }

    @Test func dumbbellChestPressClimbsEverySession() throws {
        let movements = PerformanceAnalysis.movements(in: try Self.importedHistory())
        #expect(movements.count == 16)
        let press = try #require(movements.first { $0.name == "Dumbell Chest Press" })
        #expect(press.muscleGroup == .chest)
        #expect(press.points.compactMap(\.bestSet) == sets("22.5x9, 25x7, 25x9, 27.5x7, 27.5x8, 27.5x9"))
        #expect(press.points.dropFirst().allSatisfy { $0.isRecord })
        // 35.75 against the average of 32.5, 33.92 and 34.83: about +6%.
        let trend = try #require(press.trend)
        #expect(trend.trend == .rising && abs(trend.change - 0.059) < 0.001)
    }

    @Test func everyMovementFindsItsMuscleGroup() throws {
        let sessions = try Self.importedHistory()
        #expect(PerformanceAnalysis.movements(in: sessions).allSatisfy { $0.muscleGroup != .other })
        let shares = PerformanceAnalysis.muscleShares(of: sessions)
        #expect(Set(shares.map(\.group)) == [.chest, .back, .shoulders, .biceps, .triceps])
        #expect(shares.reduce(0) { $0 + $1.sets } == 165)
        #expect(abs(shares.reduce(0) { $0 + $1.share } - 1) < 0.000_1)
    }

    @Test func volumeMatchesTheSessionStatistics() throws {
        let sessions = try Self.importedHistory()
        let totals = PerformanceAnalysis.totals(of: sessions)
        #expect(totals.sessions == 22 && totals.doneSets == 165)
        #expect(abs(totals.volumeKg - sessions.reduce(0) { $0 + SessionStatistics.volumeKg($1.results) }) < 0.001)
        let workouts = PerformanceAnalysis.workouts(in: sessions)
        #expect(workouts.reduce(0) { $0 + $1.points.count } == 22)
    }
}
