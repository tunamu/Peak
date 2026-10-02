import XCTest

/// The Analysis page picker moves like the week strip: dragging its pill changes the page, and so does a tap.
final class AnalysisPageTests: XCTestCase {
    @MainActor
    func testDraggingThePillChangesThePage() throws {
        let language = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        let setup = XCUIApplication()
        setup.launchArguments =
            ["-PeakSkipOnboarding", "YES", "-PeakTab", "settings", "-PeakLoadSampleHistory", "YES"]
            + language
        setup.launch()
        setup.terminate()

        let app = XCUIApplication()
        app.launchArguments = ["-PeakSkipOnboarding", "YES", "-PeakTab", "analysis"] + language
        app.launch()
        let performance = app.buttons["Performance"]
        let history = app.buttons["History"]
        XCTAssertTrue(performance.waitForExistence(timeout: 10))
        XCTAssertTrue(performance.isSelected)

        // Grab the pill on Performance and drag it onto History.
        performance.press(forDuration: 0.1, thenDragTo: history)
        XCTAssertTrue(app.buttons["Previous Month"].waitForExistence(timeout: 5), "Dragging did not open History")
        XCTAssertTrue(history.isSelected)

        performance.tap()
        let muscles = app.staticTexts["Muscle Balance"]
        XCTAssertTrue(muscles.waitForExistence(timeout: 5), "Tapping did not open Performance")
        XCTAssertTrue(performance.isSelected)
    }
}
