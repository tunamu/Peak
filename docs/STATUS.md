# Peak Development Status

**Last Updated**: 2026-09-29  
**Current Phase**: F0 — Repository and infrastructure

## F0 — Repository and infrastructure

| ID | Task | Status |
| --- | --- | --- |
| F0-01 | Public GitHub repo (MIT LICENSE, Xcode .gitignore, README skeleton) | ✅ |
| F0-02 | Xcode 27 project: `Peak` app target (iOS 26.0, iPhone only), synchronized folders, `Packages/PeakKit` | ✅ Launches on iOS 26.3 and 27.0 simulators |
| F0-03 | Capabilities and entitlements, App Group, CloudKit container | ⏸️ Blocked: needs an Apple ID in Xcode and a physical iPhone |
| F0-04 | SwiftLint + swift-format + EditorConfig | ✅ `swiftlint` and `swift-format lint` clean |
| F0-05 | GitHub Actions (`xcodebuild build test`), PR and issue templates | ⬜ |
| F0-06 | Docs skeleton, CONTRIBUTING, CODE_OF_CONDUCT, SECURITY, CHANGELOG, THIRD_PARTY_NOTICES | ⬜ |
| F0-07 | `Localizable.xcstrings` (EN base + TR) | ⬜ |

## Upcoming phases (⬜)

- F1: Design system and app skeleton
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

- `Peak/Peak.entitlements` is not wired to the build yet and contains placeholder keys; F0-03 replaces it.
- Design tokens from `figma-spec.md` pending import (F1-01).
