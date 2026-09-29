# Peak Roadmap

## Phase 1: MVP (v1.0) — App Store

Target: Q2 2027

### Core Features
- ✅ Minimal iOS 26.0+ app (SwiftUI)
- ✅ Home screen (week strip, today's workouts, metrics)
- ⬜ Workout session (strength + cardio logging)
- 🔶 Settings (goals and routines ✅, import/export F7)
- ✅ Progressive overload engine
- ✅ Routine scheduler
- 🔶 HealthKit integration (steps, water, sleep, heart ✅; workouts F6)
- ⬜ iCloud sync (SwiftData + CloudKit)
- ⬜ Widgets (small, medium)
- ⬜ Onboarding flow
- 🔶 Localization (EN, TR)

### Quality
- 🔶 Swift Testing suite (88 unit tests; UI tests later)
- ✅ SwiftLint + swift-format
- ⬜ Accessibility audit (WCAG AA)

## Phase 2: Post-Launch

- Analysis screen (volume trends, 1RM est.)
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
