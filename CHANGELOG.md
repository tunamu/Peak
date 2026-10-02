# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Workouts done without starting them in Peak can be entered afterwards: Log Workout on a past day (Home, or a day
  picked in History), and Add Workout › Log Finished or a planned card's Log as Finished on today. The same tables as
  a live workout, with the start time and length instead of the timer (the last time's by default); the routine's
  workout moves the rotation on, and it is saved to Apple Health. A finished workout can be deleted, also from Health.
- Notes on movements: how a movement is set up (seat, grip), pinned above its sets every time, and a note for each
  session from the note button beside the movement, with last time's note at hand. Analysis lists a movement's notes
  over time.
- Progressive overload for one workout or one movement: its own threshold, reps after a weight increase and rep
  increase, over Settings (Set Workout › Progressive Overload, and the ⓘ beside each movement).
- More widgets. On the Lock Screen: water, steps and Energy Level rings, and today's workout in a line or a few. On
  the Home Screen: Energy Level (small), a Dashboard with steps, water (and its button) and energy (medium), and This
  Week (large): which days were done and which are planned, today's workout, and the week's workouts, volume and weeks
  in a row. In Control Center: Log Water and Start Workout.
- Reminders: on days with a planned workout, a morning notification naming the workout ("Today: Chest & Biceps.
  Ready?"), at 09:00 or the time set in Settings › Reminders; a routine can add its own "time to train" reminder at
  its own time. None once the day's workout is done. Onboarding asks for notifications in a new Reminders step.
- Haptics for a workout starting, pausing and resuming, and a warning before "Start anyway?" and Delete All Data.
- The Analysis tab, in two pages that swipe or switch with the control on top. **Performance**: for the last 4 weeks,
  3 or 6 months, a year or all time, the workouts, volume, sets and targets hit against the period before; weekly
  volume and the weeks in a row; sets per muscle group; every movement with an arrow beside its name (green up, red
  down, grey when steady) and a chart of its estimated one-rep max, weight, reps or volume with its records; every
  workout with its volume, completion, targets hit and duration. **History**: a month calendar with a dot on every
  workout day, and the month's workouts (or the day's) as the same cards Home shows, opening read-only. Muscle groups left as Other, as imports
  leave them, are told from the movement's name.
- iCloud Sync, off until you turn it on in Settings › General: workouts, templates, routines and water sync through
  your private iCloud database, and settings through iCloud's key-value store. Turning it on or off takes effect at
  once. Without an iCloud account Peak keeps working on the device. Water logged from the widget is uploaded the next
  time the app runs.
- A light tap when a set is done.
- Set fields take a tap anywhere in their 44 pt cell, and VoiceOver reads them as Weight and Reps.
- Empty lists say what they are for and offer the one thing to do (Create Workout, Create Routine).
- Larger text: Today's Workout, the Energy and Water tiles and the workout header stack instead of breaking words;
  fixed-column controls cap their size and show the large content viewer.
- Onboarding on the first launch: Apple Health, your step and water goals, iCloud Sync, and a start with your own
  data, the sample program or nothing. People who already have data skip it.
- Shortcuts and Siri: "Log water in Peak" adds water without opening the app (your quick amount, or the amount
  you give) and "Start today's workout in Peak" opens it on today's workout; in English and Turkish. Tapping a
  widget or the Live Activity now goes straight to the workout or Home.
- Settings › Rep Increase, under Progressive Overload: how many reps the next target adds while the weight stays the
  same (+1 by default, +0 to +5). Exports and imports carry it.
- Settings › Delete All Data, for starting over: it shows what will be deleted, asks you to type DELETE, and saves a
  backup first that can be imported again.
- Exercises, workouts and routines created on two devices before they synced are merged into one, keeping every past
  session.
- Settings › General › iCloud shows whether your data syncs: synced, not signed in, iCloud storage full, uploads
  turned down, offline and more, each explained in a sentence with a way to the Settings app when the fix is there.
- A running workout shows as a Live Activity: on the Lock Screen with the current movement, set progress, the clock
  and Pause/Resume, and in the Dynamic Island. It follows every change, keeps the right time after the app was
  killed, and ends when the workout is finished or discarded.
- Home Screen widgets: Water (small, with a button that logs the quick amount), Steps (small, a ring against the
  goal) and Today's Workout (medium, with Energy Level). They read the shared store; the app leaves today's Health
  values for them and refreshes them whenever data changes. Water logged from the widget reaches Apple Health the next
  time the app opens.
- Clear messages for files that cannot be imported: damaged Peak JSON says where ("sessions[0].date"), damaged Excel
  files, old .xls files, photos and other binary files, empty files and oversized workbooks each get their own. A CSV
  saved with an .xlsx name opens as CSV.
- Import templates: Settings › Import Template saves an Excel, CSV or Peak JSON file with two example
  workouts, in English or Turkish (Turkish CSV with `;` and decimal commas, as Turkish Excel expects). The same files
  are in `docs/import-templates/`.
- The import screen: Settings › Import Workout Data opens Peak JSON, Excel (.xlsx), CSV and TSV files, shows how the
  file will be read (sheet, layout, column roles, date order, unit, CSV separator and decimal) with the first
  workouts as they will be imported, the summary and any problems, then merges or replaces everything (after a
  backup) and reports the result. Peak's Documents folder appears in Files for the backups.
- Tapping a finished workout's card on Home (today or any past day) opens it read-only: the header with date,
  duration and % completed, and every movement's sets as logged, without the timer or editing.
- Settings › Import Workout Data imports Peak JSON files: it shows how many workouts are new and how many are
  already in Peak, then merges on confirmation. Importing the same file again adds nothing.
- Spreadsheet layouts for import: long (a row per set), wide (set cells or weight/reps pairs) and block (the `/coach`
  history) are recognized from English and Turkish column names and cell contents, including `27.5x8:9` set cells and
  day-first or month-first dates, and turned into Peak JSON for the importer.
- Spreadsheet readers for import: .xlsx (with ZIPFoundation, the first third-party package), .csv and .tsv with the
  encoding, delimiter and decimal comma detected, so Turkish Excel's `;` files with "27,5" read right.
- JSON import in PeakCore: a preview of what is new, duplicate or wrong (with the field's place in the file), merge
  that skips what the store already has so a file imported twice adds nothing, undated sessions placed before the
  first dated one, and replace all with an automatic backup. The import screen arrives with F7-06.
- Settings › Export Workout Data saves everything as `peak-export-YYYY-MM-DD.json` (Peak JSON v1). Exporting,
  importing into an empty store and exporting again gives the same file.
- Peak JSON v1, the import and export format: `PeakExportV1` DTOs, a JSON Schema
  (`docs/schema/peak-workout-data.v1.schema.json`) with full and minimal examples, and the format documented in
  `docs/IMPORT_FORMAT.md`.
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

### Changed

- Adding water closes the water sheet once the new total has shown; removing keeps it open.
- A finished workout without a recorded time (imported) shows only its movements done, not "0 min".
- Onboarding's start choices are taller cards with a symbol and a chevron.
- Targets aim one rep higher while the weight stays: after 50 kg × 9 the next target is 50 kg × 10 (ADR 0019). The
  set table shows **Previous** (the same set last time) instead of Reference; the target weight fills the weight field
  and the target reps show in the reps field.
- Finish Workout always asks first ("Finish workout?"), not only when sets are empty, so a stray tap cannot end a
  workout.

### Fixed

- English counts read right when one: "1 Movement · 1 Set", "1 of 1 set", "1 set is empty".
- A finished workout's time no longer keeps counting when shown again.

- SwiftLint and swift-format are clean again (nine violations from F6 had turned the Lint job red on `main`);
  the workout sheet's rows moved to `WorkoutSessionRows.swift`.
