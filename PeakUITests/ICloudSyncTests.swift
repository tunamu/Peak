import XCTest

/// ADR 0024: 1.0 does not offer iCloud Sync, so Settings › General has no switch; `-PeakICloudSync YES` brings it back.
final class ICloudSyncTests: XCTestCase {
    @MainActor
    func testHiddenUnlessOffered() throws {
        let hidden = settingsGeneral(offered: false)
        XCTAssertFalse(hidden.switches["iCloud Sync"].exists)

        let offered = settingsGeneral(offered: true)
        XCTAssertTrue(offered.switches["iCloud Sync"].exists)
    }

    /// Opens Settings and scrolls to General, where the Version row is.
    @MainActor
    private func settingsGeneral(offered: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-PeakSkipOnboarding", "YES", "-PeakTab", "settings", "-PeakICloudSync", offered ? "YES" : "NO",
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
        ]
        app.launch()
        let version = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Version'")).firstMatch
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 5))
        for _ in 0..<10 where !version.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(version.isHittable)
        return app
    }
}
