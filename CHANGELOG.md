# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Xcode project with the `Peak` app target (iOS 26.0+, iPhone) and the local `PeakKit` package (`PeakCore`,
  `PeakDesign`).
- SwiftLint, swift-format and EditorConfig; SwiftLint runs on every Xcode build.
- GitHub Actions CI: lint, app build and `PeakKit` tests on the Xcode 27 runner.
- Pull request and issue templates.
- String Catalog with English and Turkish.
- Documentation: architecture, decision records, data model, import format, engines, design system, HealthKit,
  testing, release and privacy policy draft.
- Code of Conduct (Contributor Covenant 3.0), security policy and third-party notices.
- Automatic signing; HealthKit (with background delivery) and App Group entitlements.
- Apple Health usage descriptions in English and Turkish, and a privacy manifest.
- Design tokens in `PeakDesign`: colors for dark, light and Increase Contrast, typography, spacing and radius, with
  WCAG AA contrast tests.
- Liquid Glass primitives: glass card, table and pill modifiers, and a glass button style tinted by the button's role.
- Shared components: section header, settings row, progress ring, value picker sheet, result sheet and content-sized
  sheets.
- Tab bar with Home, Analysis (coming soon) and Settings, in English and Turkish.
- Component Gallery in debug builds (Settings › Developer).
- App icon (Liquid Glass, Icon Composer format) with Default, Dark, Clear and Tinted appearances.
- Data layer: SwiftData schema v1 with a migration plan, stored in the App Group; repositories for exercises,
  templates, routines, sessions and water; settings store; optional sample program.
- Engines: progressive overload targets, routine scheduling, energy score and session statistics.
- Settings screen: step, water and progressive overload goals; creating, editing and archiving workouts and movements;
  routines on weekdays or every N days; units, Apple Health status and About. English and Turkish.
- Home screen: week strip in a glass capsule like the tab bar, with today always second and workout days underlined
  (tap a day or drag the selected pill, swipe for seven days back or ahead, double-tap the title for today), the day's workout
  cards (planned, running, completed, rest day, no routine, several routines), daily steps with the weekly average,
  energy level with its reasons and data sources, and water intake with add and remove. Past days show what was done,
  future days what is planned.
- Apple Health service: steps, sleep, heart rate variability and resting heart rate for the energy level, a step
  observer with background delivery, and one water sample per day. Works without Health access.
- "Start Today's Workout" bar above the tab bar (iOS 26.1+), showing the running workout and its time.
- Starting a workout from Home; the workout sheet can be closed or discarded until the Workout Session screen arrives.
