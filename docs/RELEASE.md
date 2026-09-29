# Release

> Status: skeleton. Completed during F11.

## Prerequisites

- Apple Developer Program membership (CloudKit, push notifications and TestFlight require it).
- App Store name checked early: "Peak" may be taken; fallback "Peak: Workout Log".

## Checklist

- [ ] App Store Connect record and name reserved
- [ ] Privacy nutrition label: **Data Not Collected**
- [ ] Privacy policy ([privacy.md](privacy.md)) published on GitHub Pages
- [ ] HealthKit review: usage descriptions, Guideline 5.1.3 compliance, "not medical advice" note on Energy Level
- [ ] `PrivacyInfo.xcprivacy`: no tracking, no collected data, required-reason API `UserDefaults` (`CA92.1`)
- [ ] `ITSAppUsesNonExemptEncryption = NO`
- [ ] Screenshots (6.9", English and Turkish), description and keywords
- [ ] TestFlight: internal, then external testers; no critical crashes in Xcode Organizer
- [ ] `vX.Y.Z` tag, GitHub Release notes, `CHANGELOG.md` section moved out of "Unreleased"
- [ ] README links to the App Store page

## Versioning

[Semantic Versioning](https://semver.org). `MARKETING_VERSION` is the user-facing version; `CURRENT_PROJECT_VERSION` is
the build number and increases with every upload.
