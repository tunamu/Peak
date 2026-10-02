import XCTest

/// F11-13: a workout entered after the fact from Home and from History, and a finished workout deleted.
final class ManualLogTests: XCTestCase {
    private let language = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]

    override func setUp() {
        continueAfterFailure = false
    }

    /// The sample program with three finished sessions before today.
    @MainActor
    private func loadSampleHistory() {
        let setup = XCUIApplication()
        setup.launchArguments =
            ["-PeakSkipOnboarding", "YES", "-PeakTab", "settings", "-PeakLoadSampleHistory", "YES"] + language
        setup.launch()
        setup.terminate()
    }

    @MainActor
    private func launch(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-PeakSkipOnboarding", "YES"] + arguments + language
        app.launch()
        return app
    }

    /// Cards of finished "Chest & Biceps" workouts on screen.
    @MainActor
    private func finishedCards(_ app: XCUIApplication) -> Int {
        app.buttons.matching(NSPredicate(format: "label CONTAINS 'Chest & Biceps' AND label CONTAINS 'min'")).count
    }

    /// Picks Chest & Biceps from the open Log Workout menu, changes nothing but the time, and saves.
    @MainActor
    private func logChestAndBiceps(_ app: XCUIApplication) {
        let template = app.buttons["Chest & Biceps"]
        XCTAssertTrue(template.waitForExistence(timeout: 5), "The menu has no workouts")
        template.tap()

        let time = app.buttons["Workout Time"]
        XCTAssertTrue(time.waitForExistence(timeout: 5), "The workout did not open to be entered")
        XCTAssertFalse(app.buttons["Finish Workout"].exists, "Entered after the fact, but shown as running")
        time.tap()
        let update = app.buttons["Update"]
        XCTAssertTrue(update.waitForExistence(timeout: 5), "The time sheet did not open")
        update.tap()

        app.buttons["Save Workout"].firstMatch.tap()
        let confirm = app.alerts.buttons["Save Workout"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        let done = app.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5), "No summary after saving")
        done.tap()
    }

    @MainActor
    func testLoggingYesterdayFromHome() throws {
        loadSampleHistory()
        let app = launch(["-PeakTab", "home", "-PeakHomeDay", "yesterday"])
        let log = app.buttons["Log Workout"]
        XCTAssertTrue(log.waitForExistence(timeout: 10), "A past day has no Log Workout")
        let before = finishedCards(app)

        log.tap()
        logChestAndBiceps(app)
        XCTAssertTrue(log.waitForExistence(timeout: 5))
        XCTAssertEqual(finishedCards(app), before + 1, "Yesterday does not show the entered workout")
    }

    @MainActor
    func testLoggingTodayFromHistoryAndDeletingIt() throws {
        loadSampleHistory()
        let app = launch(["-PeakTab", "analysis", "-PeakAnalysisPage", "history"])
        let today = Date.now.formatted(
            Date.FormatStyle(locale: Locale(identifier: "en_US")).weekday(.wide).day().month(.wide))
        let day = app.buttons[today]
        // History opens on the month of the last workout, which can be the month before.
        XCTAssertTrue(app.buttons["Next Month"].waitForExistence(timeout: 10))
        if !day.waitForExistence(timeout: 2) {
            app.buttons["Next Month"].tap()
        }
        XCTAssertTrue(day.waitForExistence(timeout: 5), "Today is not on the calendar")
        day.tap()

        let log = app.buttons["Log Workout"]
        XCTAssertTrue(log.waitForExistence(timeout: 5), "A picked day has no Log Workout")
        let before = finishedCards(app)
        log.tap()
        logChestAndBiceps(app)
        XCTAssertTrue(log.waitForExistence(timeout: 5))
        XCTAssertEqual(finishedCards(app), before + 1, "Today's list does not show the entered workout")

        // Delete it again from its read-only sheet.
        // Today's card, not the Performance page's workout rows beside it.
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS 'Chest & Biceps'", today))
            .firstMatch.tap()
        let more = app.buttons["More"]
        XCTAssertTrue(more.waitForExistence(timeout: 5))
        more.tap()
        app.buttons["Delete Workout"].firstMatch.tap()
        let confirm =
            app.sheets.buttons["Delete Workout"].exists
            ? app.sheets.buttons["Delete Workout"] : app.buttons["Delete Workout"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        XCTAssertTrue(log.waitForExistence(timeout: 5))
        XCTAssertEqual(finishedCards(app), before, "The deleted workout is still listed")
    }
}
