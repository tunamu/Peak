import XCTest

/// F11-07: a reminder end to end. Onboarding's Turn On asks for notifications, the test reminder arrives while Peak
/// is in the background, and a tap on it opens Peak.
final class ReminderTests: XCTestCase {
    @MainActor
    func testReminderArrivesAndOpensPeak() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-PeakOnboarding", "YES", "-PeakOnboardingStep", "4", "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
        ]
        app.launch()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let turnOn = app.buttons["Turn On"]
        if turnOn.waitForExistence(timeout: 5) {
            turnOn.tap()
            // The system asks only once per install; afterwards the step is skipped.
            let allow = springboard.buttons["Allow"]
            if allow.waitForExistence(timeout: 5) { allow.tap() }
        }
        app.terminate()

        app.launchArguments = [
            "-PeakSkipOnboarding", "YES", "-PeakReminderNow", "YES", "-AppleLanguages", "(en)", "-AppleLocale",
            "en_US",
        ]
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5))
        XCUIDevice.shared.press(.home)

        let banner = springboard.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS[c] 'Workout Day'")
        ).firstMatch
        XCTAssertTrue(banner.waitForExistence(timeout: 15), "The reminder did not arrive")
        XCTAssertTrue(banner.label.contains("Ready?"), banner.label)
        banner.tap()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10), "A tap did not open Peak")
    }
}
