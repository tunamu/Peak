# Peak Development Status

**Last Updated**: 2026-09-29  
**Current Phase**: F7 — Import / Export (F7-01…F7-05 done)

## F0 — Repository and infrastructure

| ID | Task | Status |
| --- | --- | --- |
| F0-01 | Public GitHub repo (MIT LICENSE, Xcode .gitignore, README skeleton) | ✅ |
| F0-02 | Xcode 27 project: `Peak` app target (iOS 26.0, iPhone only), synchronized folders, `Packages/PeakKit` | ✅ Launches on iOS 26.3 and 27.0 simulators |
| F0-03 | Capabilities and entitlements, App Group, CloudKit container | ✅ Signed build runs on iPhone; HealthKit and App Group enabled. iCloud and Push wait for the paid membership (see Notes) |
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
Apple Health workout), start another workout outside the plan. Device checks pending: Health write, touch flows.

## F7: Import / Export 🔶

| ID | Task | Status |
| --- | --- | --- |
| F7-01 | JSON v1 DTOs + JSON Schema + IMPORT_FORMAT | ✅ `PeakExportV1` + `PeakJSON`; both examples validate against the schema (tests and Ajv), DTOs keep every field |
| F7-02 | Exporter + round-trip test | ✅ `PeakExporter` + plain `PeakImporter`; export → import into an empty store → export gives the same bytes. Settings › Export Workout Data opens the file exporter |
| F7-03 | JSON importer: validation, merge/dedupe, undated sessions | ✅ Preview + commit; the same file imported twice adds nothing (both examples and an export); replace all writes a backup first |
| F7-04 | RawTable readers: XLSX, CSV/TSV (delimiter and decimal detection) | ✅ Turkish Excel CSV (Windows-1254, `;`, "27,5") reads right; XLSX with ZIPFoundation, checked on Excel, Numbers and Google Sheets files ([ADR 0018](adr/0018-spreadsheet-readers.md)) |
| F7-05 | Layout detection (long/wide/block) + header names + set cell parser | ✅ All 11 fixture sheets classified right; `SheetConverter` turns them into Peak JSON. The real `/coach` history (153 rows) reads as its 22 sessions and 165 sets |

## Upcoming phases (⬜)

- F8: iCloud sync
- F9: Widgets and Live Activity
- F10: Polish, accessibility, localization
- F11: App Store release

## Notes

- The project is signed with a free Personal Team for now. Personal Teams cannot use iCloud (CloudKit, key-value store)
  or Push Notifications, so those capabilities are added once the paid Apple Developer Program membership is active,
  before F8 (iCloud sync). Until then, settings live in App Group `UserDefaults` only.
