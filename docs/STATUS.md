# Peak Development Status

**Last Updated**: 2026-10-01  
**Current Phase**: F11 — Analysis and v1 improvements (F11-01…F11-13 done) · next: device checks, then F12 (App Store) · F10-02 and F10-04 wait for a device pass · F8 two-device check waits for an iCloud account with room

## F0 — Repository and infrastructure

| ID | Task | Status |
| --- | --- | --- |
| F0-01 | Public GitHub repo (MIT LICENSE, Xcode .gitignore, README skeleton) | ✅ |
| F0-02 | Xcode 27 project: `Peak` app target (iOS 26.0, iPhone only), synchronized folders, `Packages/PeakKit` | ✅ Launches on iOS 26.3 and 27.0 simulators |
| F0-03 | Capabilities and entitlements, App Group, CloudKit container | ✅ Signed build runs on iPhone; HealthKit and App Group enabled. iCloud (CloudKit, key-value store), Push and remote-notification background mode added in F8-01 |
| F0-04 | SwiftLint + swift-format + EditorConfig | ✅ `swiftlint` and `swift-format lint` clean |
| F0-05 | GitHub Actions (`xcodebuild build test`), PR and issue templates | ✅ Green on PR #2 and on `main` |
| F0-06 | Docs skeleton, CONTRIBUTING, CODE_OF_CONDUCT, SECURITY, CHANGELOG, THIRD_PARTY_NOTICES | ✅ |
| F0-07 | `Localizable.xcstrings` (EN base + TR) | ✅ "Welcome Back" shows in English and Turkish |

## F1 — Design system and app skeleton

| ID | Task | Status |
| --- | --- | --- |
| F1-01 | Color tokens (dark/light/Increase Contrast), typography, spacing and radius | ✅ In code, not an Asset Catalog ([ADR 0017](adr/0017-color-tokens-and-contrast.md)); `ContrastTests` enforce AA, report in DESIGN_SYSTEM |
| F1-02 | Glass primitives: card, table, pill, glass button style, container use | ✅ `.glassCard()`, `.glassTable()`, `.glassPill()`, `.buttonStyle(.peakGlass)` (tint from role); showcase previews dark + light; glass color measured for the contrast tests |
| F1-03 | Shared components: SectionHeader, SettingsRow, ProgressRing, ValuePickerSheet, ResultSheet | ✅ Plus `.fittedSheet()`; previews in dark, light and Dynamic Type XXXL; checked on the simulator at accessibility sizes |
| F1-04 | TabView skeleton + Analysis placeholder | ✅ Home / Analysis / Settings with native glass tab bar, design tint (white/black), minimize on scroll; EN + TR |
| F1-05 | DEBUG-only Component Gallery | ✅ Settings › Developer › Component Gallery; debug launch arguments for screenshots |
| F1-06 | App icon (Icon Composer, 4 variants) | ✅ `AppIcon.icon` from the design's vectors; Default, Dark, Clear and Tinted rendered with `ictool`; home screen checked in dark and light |

## F2 — Data layer

| ID | Task | Status |
| --- | --- | --- |
| F2-01 | SwiftData models (CloudKit rules) + `SchemaV1` + migration plan | ✅ 10 models; `SchemaRulesTests` checks the CloudKit rules on the real schema |
| F2-02 | ModelContainer in the App Group; CloudKit flag ready but off until F8 | ✅ Store created in the App Group container on the simulator (signed build); widget arrives in F9 |
| F2-03 | Repositories (Exercise, Template, Routine, Session, Water) | ✅ In-memory tests green |
| F2-04 | SettingsStore (App Group defaults + sync mirror) | ✅ Written to App Group `UserDefaults`; iCloud key-value mirror plugs in with F8 |
| F2-05 | Sample program seed (six templates + routine, only when chosen) | ✅ `SampleProgram.install`; onboarding (F10-05) will offer it, debug builds have Settings › Developer › Load Sample Program |
| F2-06 | Archive and cascade tests | ✅ Archived and renamed exercises show in history by name |

## F3 — Engines

| ID | Task | Status |
| --- | --- | --- |
| F3-01 | ProgressionEngine + tests | ✅ Reproduces all 13 next targets of the `/coach` program after 28.09.2026 |
| F3-02 | RoutineScheduler + tests | ✅ Six-template rotation matches the `/coach` upcoming list; missed day, interval, several routines, archived templates |
| F3-03 | EnergyEngine + tests (levels A/B/C) | ✅ A test per rule and boundary; boundary mutations are caught |
| F3-04 | Statistics (volume, completion, target success) | ✅ Matches 4 of 6 logged success rates; the other 2 were miscounted in the log (see PROGRESSIVE_OVERLOAD.md) |
| F3-05 | PROGRESSIVE_OVERLOAD, ROUTINES, ENERGY_LEVEL docs | ✅ Formulas, exact boundaries and examples |

## F4 — Settings screen

| ID | Task | Status |
| --- | --- | --- |
| F4-01 | Settings layout: Goal / Workout / Recorded Workouts / Routines / General | ✅ Import and export rows are shown disabled until F7 |
| F4-02 | Step, water and progressive overload sheets | ✅ Saved to `SettingsStore`; Home reads them in F5 |
| F4-03 | Set Workout + New Movement (create, edit, archive) | ✅ Choose, order and size movements; delete archives. Taps and drags still need a manual pass on a device (no UI tests yet) |
| F4-04 | Set Routine (weekdays / interval, several active) | ✅ Weekday chips in the locale's week order; interval with start date |
| F4-05 | General: units, Apple Health status, About | ✅ kg/lb switch (weights appear from F5 on); Health status from HealthKit's request status; version, source, license, privacy |

## F5 — Home screen

| ID | Task | Status |
| --- | --- | --- |
| F5-01 | Title + WeekStrip | ✅ One glass capsule like the tab bar; pages of seven days start yesterday, so today is always second (as in the design); the selected day's pill can be dragged, swipes page seven days, workout days are underlined, double-tap the title for today |
| F5-02 | TodayWorkoutCard, all states | ✅ Planned, running, completed, rest day (with the next date), no workout, no routine, several (stacked, labelled with their routine; while one runs the others' Start waits); `DayPlanner` turns stored routines and sessions into cards (tests) |
| F5-03 | HealthService: real + mock, access, observer and background delivery | ✅ `HealthService` protocol and `MockHealthService` in PeakCore, `HealthKitService` in the app; without access every card still works. Access and real numbers still need a check on a device |
| F5-04 | StepsCard | ✅ Day total from a statistics collection query (same method as the Health app); needs the side-by-side check with Health on a device |
| F5-05 | WaterTile + water sheet + one Health sample per day | ✅ Sync identifier + version replaces the day's sample; a zero total deletes it |
| F5-06 | EnergyTile + detail sheet | ✅ Reasons as sentences, data sources, "not medical advice"; score only for today |
| F5-07 | Bottom accessory + conditional visibility | ✅ Start / running workout / hidden with `tabViewBottomAccessory(isEnabled:)` (iOS 26.1+); left out on iOS 26.0 |
| F5-08 | Past and future days | ✅ Past: completed sessions and that day's steps and water; future: planned workouts, no Start |

## F6: Workout Session ✅

State machine with persistence (a workout survives the app being killed), set tables with targets from the last
performance, Complete Movement, bottom bar with pause and finish check, walking segments, finish pipeline (summary +
Apple Health workout), start another workout outside the plan. After first use (2026-09-30): Finish always asks,
and a finished workout opens read-only from its card. Device checks pending: Health write, touch flows.

## F7: Import / Export ✅

| ID | Task | Status |
| --- | --- | --- |
| F7-01 | JSON v1 DTOs + JSON Schema + IMPORT_FORMAT | ✅ `PeakExportV1` + `PeakJSON`; both examples validate against the schema (tests and Ajv), DTOs keep every field |
| F7-02 | Exporter + round-trip test | ✅ `PeakExporter` + plain `PeakImporter`; export → import into an empty store → export gives the same bytes. Settings › Export Workout Data opens the file exporter |
| F7-03 | JSON importer: validation, merge/dedupe, undated sessions | ✅ Preview + commit; the same file imported twice adds nothing (both examples and an export); replace all writes a backup first |
| F7-04 | RawTable readers: XLSX, CSV/TSV (delimiter and decimal detection) | ✅ Turkish Excel CSV (Windows-1254, `;`, "27,5") reads right; XLSX with ZIPFoundation, checked on Excel, Numbers and Google Sheets files ([ADR 0018](adr/0018-spreadsheet-readers.md)) |
| F7-05 | Layout detection (long/wide/block) + header names + set cell parser | ✅ All 11 fixture sheets classified right; `SheetConverter` turns them into Peak JSON. The real `/coach` history (153 rows) reads as its 22 sessions and 165 sets |

| F7-06 | Mapping screen + preview (S-10) + commit + S-09 | ✅ Settings › Import Workout Data takes Peak JSON, .xlsx, .csv and .tsv: S-10 shows the sheet, layout, header row, column roles, date order, unit (and CSV separator and decimal), the first five workouts as imported, the summary and problems, and merge or replace all (with a backup in Files › Peak › Backups); S-09 reports the result. End to end on the simulator with Turkish CSV, block and wide files |
| F7-07 | Template files (xlsx/csv) + sharing in the app | ✅ English and Turkish templates (docs/import-templates), written by `ImportTemplate`; each reads back as a confident long layout and imports without problems; the .xlsx files open in openpyxl and Quick Look. Settings › Import Template saves one in the phone's language |
| F7-08 | Fixtures: the real `/coach` history as Excel (block), synthetic long/wide, broken files | ✅ The real history reads as its 22 sessions and 165 sets; 12 weeks of sets preview in well under a second; every broken file (cut or damaged workbook, bad XML, hidden sheets only, damaged or foreign JSON, a photo, an old .xls, an empty file, a ZIP bomb) ends in its own readable message |

## F8: iCloud sync 🔶

| ID | Task | Status |
| --- | --- | --- |
| F8-01 | Turn on CloudKit; deploy the schema to production in CloudKit Dashboard | 🔶 The app syncs its store with the private database (`iCloud.com.tunamu.peak`); the widget opens the same store without sync, and its writes reach iCloud through persistent history when the app runs. Settings mirror to iCloud's key-value store (`UbiquitousSettingsMirror`). Signed with the paid team: the profile carries CloudKit, key-value store and Push. Without an iCloud account the app works locally (checked on the simulator). Still to do: data flowing between two devices, Settings › Developer › Initialize CloudKit Schema, then deploy to production |
| F8-02 | Dedupe routine + seed only by the user's choice | 🔶 `Deduplicator` merges exercises, templates and routines that two devices created separately (the sample program loaded on both becomes one; links move to the survivor, the oldest by whole seconds and then the smallest id, so every device agrees); `SyncMonitor` runs it at launch and after each iCloud import. Sessions and water are never merged ([DATA_MODEL.md](DATA_MODEL.md#duplicates-from-sync)). The sample program is only installed when chosen. Still to see on two devices (iPhone + simulator) |
| F8-03 | Two-device tests: offline edits and merging | ⬜ |
| F8-04 | iCloud status row + no account / signed out | ✅ Settings › General › iCloud: Synced (with the time), On, Checking, Not signed in, Restricted, Not available, Storage full, Not uploaded, Offline, Not synced. A tap explains in one sentence and, for an account or storage problem, offers Open Settings. `SyncState` keeps the last outcome of setup, import and export apart, so a download that works cannot hide uploads that fail. With a full iCloud account the app only gets "partial failure" without the per-record reasons (Core Data rebuilds the event's error from its domain and code), so that reads as Not uploaded, "most often because iCloud storage is full"; an explicit quota error reads as Storage full. Seen on the simulator with a full account, in English and Turkish. The app works on the device in every state |
| F8-05 | iCloud Sync opt-in + Delete All Data (D-18, D-19) | ✅ iCloud Sync is off until the user turns it on (Settings › General); the choice is per device and turning it on or off reopens the store with or without CloudKit, no relaunch (checked on the simulator both ways: the status row appears and syncing starts; turned off, CloudKit goes quiet). The settings mirror follows the switch. Settings › Delete All Data shows what will go, needs the word DELETE (SİL in Turkish) typed, writes a backup first (nothing is deleted if it cannot) and is unavailable while a workout runs; with sync on it warns that iCloud and other devices lose the data too. Replace-all imports use the same eraser |
| F8-06 | Settings: Rep Increase, Delete button | ✅ Settings › Goal Settings › Rep Increase (+0…+5, default +1) under Progressive Overload sets how many reps the target grows while the weight stays; it feeds every new target, syncs with the other settings and travels in Peak JSON (`overload.repStep`, optional, schema updated). Delete All Data's button reads Delete |

## F9: Widgets and Live Activity 🔶

| ID | Task | Status |
| --- | --- | --- |
| F9-01 | Widget extension + App Group data + snapshot provider | ✅ `PeakWidgetsExtension` reads the shared store and settings; the app leaves today's steps and Energy Level in an App Group file (Health data stays out of the store) and reloads the widgets on every save; `WidgetContent` builds what they show (tests) |
| F9-02 | W-01 (interactive water), W-02, W-03; rendering modes | 🔶 Water with a +quick-amount button (`AddWaterIntent`), steps ring, today's workout with Energy Level; English and Turkish; shown in the Component Gallery at real sizes. Tinted and clear Home Screen styles still to be checked on a device |
| F9-03 | Live Activity + Dynamic Island + Pause/Resume intent | ✅ One activity per running workout, kept in line with the store after every save, at launch and on return (so a relaunch after the app was killed shows the right clock, anchored to the start); Lock Screen with movement, set progress, clock and Pause/Resume (`TogglePauseIntent`, runs in the app); Dynamic Island compact, minimal and expanded. On the simulator the system rendered it on start and removed it on finish; the Lock Screen and island still to be seen on a device |
| F9-04 | Deep links (`peak://`) + App Intents | ✅ `peak://home`, `peak://settings`, `peak://workout/start` (today's next workout, or the running one) and `peak://workout/open` (`PeakLink`, tests); the widgets and the Live Activity use them. Shortcuts: Log Water (runs without opening Peak; optional amount, else the quick amount; says the day's total) and Start Today's Workout (opens Peak and starts like the Start button), with Siri phrases in English and Turkish. The widget's own water button stays out of the Shortcuts list. On the simulator a link started today's planned workout from another tab and reopened the running one. A start from a link at a cold launch does not ask "Start anyway?": the Energy Level is not known yet |

## F10: Polish, accessibility, localization 🔶

| ID | Task | Status |
| --- | --- | --- |
| F10-01 | Every Turkish string + plural forms | ✅ No app, widget, Info.plist or Siri phrase string lacks Turkish (checked against what the compiler extracts, including the package's widget views). English plurals fixed where a count could be 1: "1 Movement · 1 Set", "1 of 1 set", "1 set is empty" (checked by formatting the compiled catalog); Turkish keeps the noun singular after a number |
| F10-02 | Accessibility: VoiceOver, Dynamic Type, Reduce Motion, Reduce Transparency, Increase Contrast, 44 pt | 🔶 Dynamic Type checked at the largest accessibility size on the simulator: Today's Workout card, the Energy and Water tiles and the workout header now stack instead of breaking words; the week strip, the set table and the workout's bottom bar (fixed columns) are capped at the largest standard size with the large content viewer, and Finish Workout shortens to Finish when it would not fit. Onboarding and Settings wrap by word. Onboarding respects Reduce Motion. `PeakUITests` runs `performAccessibilityAudit` on the three tabs, onboarding and a running workout in English and Turkish: green; issues the audit cannot attach to an element (iOS's own toolbar buttons on the workout sheet, rows blurred under the tab bar in Settings) are kept as expected failures. Increase Contrast and Reduce Transparency checked on the simulator (2026-10-02, every tab, a finished workout): readable; it found a done set's number drawn in the glass tint, now `text.positive` (8.30:1 dark, 5.21:1 light). The audit leaves disabled controls out of contrast (WCAG 1.4.3), which had failed Start while another workout runs. Still to do: a VoiceOver pass on a device |
| F10-03 | Haptics: set completed, water added, workout finished | ✅ A light tap when a set becomes done (entering its reps; not on every digit or on reopening); water and the finish summary already had theirs. To feel on a device |
| F10-04 | Performance (Instruments) | 🔶 Measured on an iPhone 13 Pro Max with real data ([PERFORMANCE.md](PERFORMANCE.md)): cold launch 930 ms to the first frame, of which Peak's own code about 90 ms (opening the store 22 ms); with a workout running the main thread is busy 3 ms in 9.5 s. Home's 11 glass surfaces sit in `GlassEffectContainer`s. Scrolling hitches still to check on a device with the Animation Hitches template |
| F10-05 | Onboarding (C-15) | ✅ First launch: welcome, Apple Health (what is read and saved; Connect / Not Now; skipped when already decided or unavailable), step and water goals, iCloud Sync (Turn On / Not Now, applied at the end so the store reopens once), and how to start: Import My Data (onboarding closes, Settings opens on the file picker), the sample program, or empty. Anyone with data already (an update, or data from iCloud) skips it. Each step and the import path seen on the simulator in Turkish |
| F10-06 | Empty and error states | ✅ Each empty list has one sentence and one action: Settings › Recorded Workouts (Create Workout), Routines (Create Routine, or Create Workout first when there are none), Home without a routine (Set Up), without Health (Connect Apple Health); an import with nothing to add says to try another header row or layout. Seen on a clean simulator in Turkish |

## F11: Analysis and v1 improvements 🔶

| ID | Task | Status |
| --- | --- | --- |
| F11-01 | Decisions: Analysis (ADR 0020), reminders, haptics | ✅ [ADR 0020](adr/0020-analysis-screen.md), [ADR 0021](adr/0021-local-reminders.md), DESIGN_SYSTEM › Haptics |
| F11-02 | `PerformanceAnalysis` engine | ✅ Estimated one-rep max (Epley), best set, per-movement points with records and a trend (±2% band against the last three), per-template series, weeks with empty ones, streak, muscle balance in done sets, period totals and change. Muscle groups guessed from names when stored as Other. Checked with the author's real history: Dumbbell Chest Press rises every session (+6% at the end), every movement lands in its log section's group, volume equals `SessionStatistics` |
| F11-03 | Analysis tab: Performance and History pages | ✅ `AnalysisView` replaces the placeholder: a page picker (`GlassSegmentedPicker`, the week strip's look and draggable pill) and a paging horizontal scroll view kept in step; nothing inside a page scrolls sideways. One sentence and Import Workout Data when there is nothing yet |
| F11-04 | Performance page | ✅ Period menu (4 weeks … all time); Workouts, Volume, Sets, Targets Hit with the change against the period before (targets hit only counts movements that had targets, so imports are not judged); weekly volume chart (Swift Charts) with the run of weeks; muscle balance in sets; Movements and Workouts lists with trend arrows |
| F11-05 | Movement and workout detail, trend arrows | ✅ Movement: Est. 1RM, Weight, Reps, Volume (bodyweight: Reps, Sets; walk: Distance, Duration), records in green, best set, the trend in words, every session opening the workout. Workout: Volume, Completed, Targets Hit, Duration. Charts plot the user's unit. Seen on the simulator with the author's history in English and Turkish, dark and light |
| F11-06 | History page with month calendar | ✅ `MonthCalendar` (locale's first weekday, dots on workout days, arrow buttons, future days disabled, capped at the largest standard size); the month's or the day's workouts as Home's finished-workout cards (date, name, time, movements done), each opening `CompletedWorkoutSheet`. Opens on the month of the latest workout |
| F11-07 | Reminders: planner, scheduling, permission | ✅ `ReminderPlanner` (14 days, at most 60; none on a day already done or while a workout runs) and `Reminders` (replaces `peak.reminder.*` at launch, on return, after saves, on setting changes). Settings › Reminders: Workout Day Reminder (on, 09:00), time, a note and a link when notifications are off. Onboarding's Reminders step. A tap opens Home. [ADR 0021](adr/0021-local-reminders.md), [NOTIFICATIONS.md](NOTIFICATIONS.md). `ReminderTests` on the simulator: allowed through onboarding, the banner arrived with "Today: … Ready?", a tap opened Peak |
| F11-08 | Reminder per routine | ✅ Set Routine › Reminder: Remind Me and its time; kept on the device with the morning reminder (D-29 revised: no schema change) |
| F11-10 | Progressive overload per workout and per movement | ✅ Set Workout › Progressive Overload › Own Rule, and each movement's ⓘ settings (also from Analysis): threshold, reps after weight up, rep increase; unset values follow the workout, then Settings (`ProgressionRule.applying`, tested). Targets at start and the summary's Next Time use it. SchemaV2 ([ADR 0022](adr/0022-schema-v2.md)) |
| F11-12 | Movement notes | ✅ A setup note on the movement (pinned above its sets every time) and a note per session (the note button by each movement while logging, with last time's note). Shown in the read-only workout and as the movement's notes over time in Analysis. Peak JSON carries them. SchemaV2 with a lightweight migration, checked on a v1 store file (`MigrationTests`) |
| F11-11 | More widgets | ✅ Lock Screen: Water, Steps and Energy rings (`accessoryCircular`), Today's Workout (`accessoryRectangular`, `accessoryInline`). Home Screen: Energy (small), Dashboard (medium: steps, water with its button, energy), This Week (large: the week's done and planned days, today's workout and Energy Level, the week's workouts and volume in the user's unit, weeks in a row; `WeekGlance`, tested). Control Center: Log Water (runs in place) and Start Workout (opens today's workout). All in the Component Gallery at real sizes (`-PeakShowcaseSection glance\|lockScreen`); English and Turkish. To add and check on a device |
| F11-13 | Workouts entered after the fact | ✅ [ADR 0023](adr/0023-workouts-entered-later.md): Log Workout on past days (Home, History), Add Workout › Start Now / Log Finished and a planned card's Log as Finished today. The workout sheet without the timer (time pill → `LogTimeSheet`, Save Workout); `SessionStatus.logging`, no schema change; `current()` asks for active or paused only; targets from before the day; `ManualLogPlan` defaults (last time's start and length, else 18:00 for an hour, never past now); `DayPlanner.logSuggestions`. Delete Workout on a finished workout, also from Health. `ManualLogTests` (unit and UI) |
| F11-09 | Haptics catalog | ✅ `PeakHaptic` in PeakDesign; every haptic goes through it. New: workout started, pause and resume, warning before "Start anyway?" and Delete All Data, selection on the Analysis pickers and calendar. Table in DESIGN_SYSTEM › Haptics. To feel on a device |

## Upcoming phases (⬜)

- F12: App Store release

## Notes

- The project is signed with the maintainer's paid Apple Developer Program team (since 2026-10-01); development
  profiles last a year. Builds run from Xcode use the CloudKit **development** environment; TestFlight and App Store
  builds use production, which only has the schema once it is deployed (F8-01).
