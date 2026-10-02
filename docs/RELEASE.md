# Release

> Status: skeleton. Completed during F12.

## Prerequisites

- Apple Developer Program membership (CloudKit, push notifications and TestFlight require it).
- App Store name checked early: "Peak" may be taken; fallback "Peak: Workout Log".

## Checklist

- [ ] App Store Connect record and name reserved
- [ ] Privacy nutrition label: **Data Not Collected**
- [ ] Privacy policy ([privacy.md](privacy.md)) published on GitHub Pages
- [x] HealthKit review: usage descriptions name every type asked for (read: steps, sleep, HRV, resting heart rate,
  water; write: water, workouts, walking distance), nothing read from Health is stored or synced (5.1.3), "Not medical
  advice." on Energy Level. The App Store description must mention Apple Health (2.5.1)
- [x] Privacy manifests in the app **and** the widget extension (`PeakWidgets/PrivacyInfo.xcprivacy`; each bundle is
  checked on upload): no tracking, no collected data, required-reason API `UserDefaults` (`CA92.1` app-only, `1C8F.1`
  App Group). ZIPFoundation brings its own
- [x] `ITSAppUsesNonExemptEncryption = NO`
- [x] iCloud Sync hidden for 1.0 ([ADR 0024](adr/0024-icloud-sync-off-for-1-0.md)); no CloudKit production deploy needed
- [ ] Screenshots (6.9", English and Turkish), description and keywords
- [ ] TestFlight: internal, then external testers; no critical crashes in Xcode Organizer
- [ ] `vX.Y.Z` tag, GitHub Release notes, `CHANGELOG.md` section moved out of "Unreleased"
- [ ] README links to the App Store page

## Versioning

[Semantic Versioning](https://semver.org). `MARKETING_VERSION` is the user-facing version; `CURRENT_PROJECT_VERSION` is
the build number and increases with every upload.
