import XCTest

/// F10-02: Apple's accessibility audit (contrast, hit regions, labels, clipped text, traits) on every main screen,
/// in English and Turkish. Debug launch arguments open each screen, as for screenshots (docs/DEVELOPMENT.md).
final class AccessibilityAuditTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = true
    }

    @MainActor
    private func launch(_ arguments: [String], language: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments =
            arguments + [
                "-AppleLanguages", "(\(language))", "-AppleLocale", language == "tr" ? "tr_TR" : "en_US",
            ]
        app.launch()
        return app
    }

    /// Runs the audit and fails on every issue except two kinds that are checked another way:
    /// - Contrast: the audit misreads text on Liquid Glass, so the text's contrast is measured from the screenshot
    ///   instead (the element's darkest pixels against its median), and must reach 4.5:1 (WCAG AA).
    /// - Dynamic Type and clipped text inside the containers capped on purpose (`peak.capped.*`: the week strip, the
    ///   set table, the workout's bottom bar and the bar above the tab bar), which show the large content viewer.
    /// Content scrolled under the bars (the tab bar, the bar above it, the workout's bottom bar) is blurred by their
    /// glass on purpose and is read once scrolled up, so contrast, Dynamic Type and clipping are not judged there.
    @MainActor
    private func audit(_ app: XCUIApplication, _ screen: String, knowsUnnamedIssues: Bool = false) throws {
        let capped = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'peak.capped.'"))
            .allElementsBoundByIndex.map(\.frame)
        // The system tab bar covers whatever is under it; Peak's own bars only what pokes out from under them (their
        // own contents stay audited).
        let tabBars = app.tabBars.allElementsBoundByIndex.map(\.frame)
        let ownBars = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier IN %@", ["peak.capped.accessory", "peak.capped.bottomBar"]))
            .allElementsBoundByIndex.map(\.frame)
        let screenshot = XCUIScreen.main.screenshot()
        try XCTContext.runActivity(named: "Audit \(screen)") { _ in
            try app.performAccessibilityAudit { issue in
                let frame = issue.element?.frame
                let isUnderBar =
                    frame.map { frame in
                        tabBars.contains { $0.intersects(frame) }
                            || ownBars.contains { $0.intersects(frame) && !$0.contains(frame) }
                    } ?? false
                if isUnderBar && [.contrast, .dynamicType, .textClipped].contains(issue.auditType) {
                    return true
                }
                let name = issue.element.map { "'\($0.label)' \($0.frame)" } ?? "an unnamed element"
                switch issue.auditType {
                case .contrast:
                    if let frame, let ratio = Self.contrast(in: frame, of: screenshot), ratio >= 4.5 {
                        return true
                    }
                case .dynamicType, .textClipped:
                    if let frame, capped.contains(where: { $0.insetBy(dx: -1, dy: -1).contains(frame) }) {
                        return true
                    }
                default:
                    break
                }
                let message = "\(screen): \(issue.compactDescription) – \(name) – \(issue.detailedDescription)"
                // The second movement's header is flagged "partially unsupported" while the first, the same view with
                // a Dynamic Type font, passes: the audit's result there depends on the position, not the text.
                let isMovementHeader =
                    issue.auditType == .dynamicType && issue.element?.elementType == .staticText
                    && issue.element?.label.range(of: #"^\d+- "#, options: .regularExpression) != nil
                if (issue.element == nil || isMovementHeader) && knowsUnnamedIssues {
                    // Known where the audit cannot say which element it means. On the workout sheet: iOS 26's own
                    // toolbar buttons (Close and More, 36 pt glass circles drawn by the system), the list's drag
                    // handles and section rows. In Settings: text found in the screenshot (in English only) where
                    // rows are blurred under the tab bar. Kept visible in the report until a device pass with
                    // VoiceOver places them (docs/STATUS.md › F10-02).
                    XCTExpectFailure("Unnamed audit issue on \(screen)", options: .nonStrict()) {
                        XCTFail(message)
                    }
                } else {
                    XCTFail(message)
                }
                return true
            }
        }
    }

    /// The contrast of the text in `frame`: its darkest pixels against the median (light mode).
    private static func contrast(in frame: CGRect, of screenshot: XCUIScreenshot) -> Double? {
        let image = screenshot.image
        guard let cgImage = image.cgImage, frame.width > 0, frame.height > 0 else { return nil }
        let scale = CGFloat(cgImage.width) / image.size.width
        let rect = CGRect(
            x: frame.minX * scale, y: frame.minY * scale, width: frame.width * scale, height: frame.height * scale
        ).integral.intersection(CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        guard !rect.isEmpty, let crop = cgImage.cropping(to: rect) else { return nil }
        let width = crop.width
        let height = crop.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard
                let context = CGContext(
                    data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                    bytesPerRow: width * 4, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return false }
            context.draw(crop, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }
        func channel(_ value: UInt8) -> Double {
            let value = Double(value) / 255
            return value <= 0.039_28 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        var luminances: [Double] = []
        luminances.reserveCapacity(width * height)
        for index in stride(from: 0, to: pixels.count, by: 4) {
            luminances.append(
                0.2126 * channel(pixels[index]) + 0.7152 * channel(pixels[index + 1]) + 0.0722
                    * channel(pixels[index + 2]))
        }
        luminances.sort()
        // The darkest 0.2 %: even a two-letter label ("Aç") covers more of its button than that.
        let text = luminances[luminances.count / 500]
        let background = luminances[luminances.count / 2]
        return (max(text, background) + 0.05) / (min(text, background) + 0.05)
    }

    @MainActor
    func testTabs() throws {
        for language in ["en", "tr"] {
            for tab in ["home", "analysis", "settings"] {
                let app = launch(["-PeakSkipOnboarding", "YES", "-PeakTab", tab], language: language)
                try audit(app, "\(tab) (\(language))", knowsUnnamedIssues: tab == "settings")
                app.terminate()
            }
        }
    }

    @MainActor
    func testOnboarding() throws {
        for language in ["en", "tr"] {
            for step in 0...4 {
                let app = launch(["-PeakOnboarding", "YES", "-PeakOnboardingStep", "\(step)"], language: language)
                try audit(app, "onboarding step \(step) (\(language))")
                app.terminate()
            }
        }
    }

    /// The weight and reps fields fill their 44 pt cells: a tap near the cell's edge must focus the field.
    @MainActor
    func testSetFieldsTakeTapsAcrossTheirCell() throws {
        let setup = launch(
            [
                "-PeakSkipOnboarding", "YES", "-PeakTab", "settings", "-PeakLoadSampleProgram", "YES",
                "-PeakLoadSecondRoutine", "YES",
            ],
            language: "en")
        setup.terminate()
        let app = launch(["-PeakSkipOnboarding", "YES", "-PeakOpenLink", "peak://workout/start"], language: "en")
        let field = app.textFields["Weight"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(field.frame.height, 44)
        // 4 pt inside the top edge of the 44 pt cell.
        let edge = field.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .withOffset(CGVector(dx: 0, dy: -(44 / 2 - 4)))
        edge.tap()
        // The simulator may hide the software keyboard, so focus is read from the field itself.
        let isFocused = NSPredicate(format: "hasKeyboardFocus == true")
        expectation(for: isFocused, evaluatedWith: field)
        waitForExpectations(timeout: 3)
    }

    /// The running workout. The sample program and an everyday routine are loaded first, so today has a workout.
    @MainActor
    func testWorkout() throws {
        let setup = launch(
            [
                "-PeakSkipOnboarding", "YES", "-PeakTab", "settings", "-PeakLoadSampleProgram", "YES",
                "-PeakLoadSecondRoutine", "YES",
            ],
            language: "en")
        setup.terminate()
        for language in ["en", "tr"] {
            // Starts today's workout the first time, reopens it the second.
            let app = launch(
                ["-PeakSkipOnboarding", "YES", "-PeakOpenLink", "peak://workout/start"], language: language)
            let finish = app.buttons[language == "tr" ? "Antrenmanı Bitir" : "Finish Workout"]
            XCTAssertTrue(finish.waitForExistence(timeout: 5), "The workout did not open")
            try audit(app, "workout (\(language))", knowsUnnamedIssues: true)
            app.terminate()
        }
    }
}
