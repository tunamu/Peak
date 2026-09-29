# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Starting a workout while energy is Not Ready asks "Start anyway?" first (Home card, bottom accessory and Start
  Another Workout alike); it never blocks.
- "Start Another Workout" under today's cards starts any template outside the plan; it is saved without a
  routine, so the rotation is untouched. Hidden while a workout runs.
- Finishing a workout shows its summary (duration, volume, targets hit or walk distance, weights going up next
  time) and writes it to Apple Health as strength training or an indoor walk with distance; paused time is left out.
- Walking in a workout: segments with speed (km/h), incline (%) and an optional duration (min), Add Segment,
  swipe to delete; the distance is only computed when every segment has a duration.
- Workout bottom bar: 00:02:16 clock with Pause/Resume and Finish Workout, which asks first when sets are empty.
  Close and Discard moved to the toolbar; the sheet no longer closes by swiping.
- Home card and bottom accessory pause and resume a running workout directly; tapping the card opens it.
- Complete Movement: fills empty sets with their targets, folds the movement into a summary row (tap to reopen)
  and scrolls to the next open movement; the header's % Completed follows.
- Workout session screen: header with date, size, time and % completed; one set table per movement with
  Reference (targets from the last performance), editable weight and reps, Add Set, drag to reorder and swipe to
  delete. Weights are prefilled with the target; entering reps completes a set.
- Workout session state machine (`WorkoutSessionController`): pause, resume, finish and discard, saved on every
  change so a workout survives the app being killed. Paused timers freeze on Home, the accessory and the sheet.
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
