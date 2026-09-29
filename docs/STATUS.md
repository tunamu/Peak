# Peak Development Status

**Last Updated**: 2026-09-29  
**Current Phase**: F1 — Design system and app skeleton

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
| F1-06 | App icon (Icon Composer, 4 variants) | ⬜ |

## Upcoming phases (⬜)

- F2: Data layer
- F3: Engines (progression, routine, energy)
- F4: Settings screen
- F5: Home screen
- F6: Workout Session
- F7: Import / Export
- F8: iCloud sync
- F9: Widgets and Live Activity
- F10: Polish, accessibility, localization
- F11: App Store release

## Notes

- The project is signed with a free Personal Team for now. Personal Teams cannot use iCloud (CloudKit, key-value store)
  or Push Notifications, so those capabilities are added once the paid Apple Developer Program membership is active,
  before F8 (iCloud sync). Until then, settings live in App Group `UserDefaults` only.
