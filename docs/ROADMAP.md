# Peak Roadmap

## Phase 1: MVP (v1.0) — App Store

Target: Q2 2027

### Core Features
- ✅ Minimal iOS 26.0+ app (SwiftUI)
- ✅ Home screen (week strip, today's workouts, metrics)
- ✅ Workout session (strength + cardio logging, summary, read-only history)
- ✅ Settings (goals, routines, import from JSON/Excel/CSV, templates, export)
- ✅ Progressive overload engine
- ✅ Routine scheduler
- 🔶 HealthKit integration (steps, water, sleep, heart ✅; workout saving built, check on a device pending)
- 🔶 iCloud sync, opt-in (SwiftData + CloudKit): built, hidden in 1.0 until the two-device check ([ADR 0024](adr/0024-icloud-sync-off-for-1-0.md))
- 🔶 Widgets (small, medium: water with a button, steps, today's workout) and the workout's Live Activity
- ✅ Onboarding flow
- ✅ Localization (EN, TR)
- ✅ Analysis screen (F11, [ANALYSIS.md](ANALYSIS.md)): Performance (period totals, weekly volume and sessions, streak,
  muscle balance, every movement with a trend arrow and its chart) and History (month calendar and every session)
- ✅ Reminders: a morning reminder on workout days and an optional reminder per routine (F11)
- ✅ Haptics: one catalog of system feedback for meaningful moments (F11)
- ✅ More widgets: Lock Screen rings and today's workout, Energy, Dashboard, This Week, Control Center buttons (F11)
- ✅ Progressive overload per workout and per movement: the threshold, reset reps and rep increase set for one
  workout template or one movement, over the app-wide values in Settings (F11)
- ✅ Movement notes: setup and per-session notes (F11)

### Quality
- ✅ Swift Testing suite (package tests on the Mac host and the iOS simulator)
- 🔶 UI tests: `performAccessibilityAudit` on every tab, onboarding and a running workout
- ✅ SwiftLint + swift-format
- 🔶 Accessibility audit (WCAG AA): Dynamic Type and automated audits done, VoiceOver pass on a device pending
- 🔶 Performance: launch and idle measured ([PERFORMANCE.md](PERFORMANCE.md)); scrolling hitches still to check on a
  device

## Phase 2: Post-Launch

- Apple Watch app
- CSV export
- Rest timer
- iPad layout
- iPad Lock screen widgets

## Known Risks

- App name "Peak" may be taken on App Store → reserve ASAP
- Glass effect performance on older iPhone models
- iCloud sync edge cases with offline-first strategy
- HealthKit permissions on iOS 26+

See `plan.md` in vault for full technical details.
