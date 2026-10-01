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
- 🔶 iCloud sync, opt-in (SwiftData + CloudKit; two-device check pending)
- 🔶 Widgets (small, medium: water with a button, steps, today's workout) and the workout's Live Activity
- ✅ Onboarding flow
- ✅ Localization (EN, TR)
- ⬜ Analysis screen: progress per movement (best set, estimated 1RM), weekly volume, frequency and streak (F11)
- ⬜ Progressive overload per workout and per movement: the threshold, reset reps and rep increase set for one
  workout template or one movement, over the app-wide values in Settings (F11, after the Analysis screen)

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
