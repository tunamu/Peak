import XCTest

/// Adding water closes the water sheet once the new total has shown; removing keeps it open.
final class WaterTests: XCTestCase {
    @MainActor
    func testAddingWaterClosesTheSheet() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-PeakSkipOnboarding", "YES", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        let tile = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Water Intake'")).firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 5))
        tile.tap()
        let add = app.buttons["Add"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        let gone = NSPredicate(format: "exists == false")
        expectation(for: gone, evaluatedWith: add)
        waitForExpectations(timeout: 3)
    }
}
