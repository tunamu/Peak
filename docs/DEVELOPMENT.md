# Development Guide

## Build Environment

- **Xcode**: 27.0+ (iOS 27 SDK)
- **Swift**: 6.4+
- **Deployment Target**: iOS 26.0+
- **Minimum Device**: iPhone 11

## Project Structure

```
Peak.xcodeproj          # Xcode project (app target, synchronized folders)
Peak/                   # App target sources (SwiftUI)
  ├── App/              # PeakApp (@main entry point), RootTabView
  ├── Features/         # Home, Analysis, Settings (one folder per feature)
  ├── Resources/        # Assets.xcassets, strings, icons
  └── Peak.entitlements # iCloud + HealthKit permissions

Packages/PeakKit/       # Local Swift Package, linked to the app target
  ├── Package.swift
  ├── Sources/PeakCore/     # Models, engines, services
  ├── Sources/PeakDesign/   # Tokens, glass primitives, components, showcase (debug)
  ├── Tests/PeakCoreTests/  # Swift Testing tests
  └── Tests/PeakDesignTests/ # Contrast and component tests

PeakWidgets/            # Widget extension (later)
```

The app itself lives only in `Peak.xcodeproj`. `PeakKit` holds libraries only: a Swift Package
executable cannot produce an iOS `.app` bundle.

## Build & Run

```bash
# Xcode
open Peak.xcodeproj
# Select Peak scheme > iPhone simulator > Run (Cmd+R)

# Command line: app
xcodebuild -project Peak.xcodeproj -scheme Peak \
  -destination 'platform=iOS Simulator,name=iPhone 17' build

# Command line: package tests
cd Packages/PeakKit && swift test
```

## Running on a device

1. Connect the iPhone with a cable and tap **Trust** on the device.
2. In Xcode, open the run destination menu and choose **Manage Devices…** (Device Hub). Select the iPhone and click
   **Pair** if it appears.
3. On the iPhone: **Settings > Privacy & Security > Developer Mode**, turn it on and restart. The switch only appears
   after pairing has started.
4. Choose the iPhone as the run destination and press Run (⌘R).

Signing is automatic. The project uses the maintainer's team (`DEVELOPMENT_TEAM`). Contributors pick their own team in
the `Peak` target's **Signing & Capabilities** tab and use their own bundle identifier and App Group, because
`com.tunamu.peak` is registered to the maintainer's team.

With a free Personal Team (contributors without a paid membership):

- The first launch is blocked until you trust the developer: **Settings > General > VPN & Device Management >
  Developer App > Trust**.
- The provisioning profile is valid for 7 days. Run from Xcode again to renew it.
- iCloud and Push Notifications are not available: remove the iCloud and `aps-environment` keys from your local copy
  of `Peak/Peak.entitlements`. HealthKit and App Groups work, and the app runs without sync.

From the command line:

```bash
xcodebuild build -project Peak.xcodeproj -scheme Peak \
  -destination 'platform=iOS,id=<UDID>' -allowProvisioningUpdates
xcrun devicectl list devices
xcrun devicectl device install app --device <UDID> <path/to/Peak.app>
xcrun devicectl device process launch --device <UDID> com.tunamu.peak
```

## Component Gallery and launch arguments

Debug builds have **Settings › Developer**: the **Component Gallery**, which shows every design token, glass primitive
and component with sample content, and **Load Sample Program**, which fills the store with the sample templates and
routine. The section is compiled out of Release builds.

Debug builds also read a few launch arguments, handy for screenshots from the command line (`simctl` cannot tap). In
Xcode, add them under Product › Scheme › Edit Scheme › Run › Arguments; `-key value` pairs land in `UserDefaults`.

| Argument | Effect |
| --- | --- |
| `-PeakTab home\|analysis\|settings` | Opens that tab |
| `-PeakOpenGallery YES` | With `-PeakTab settings`, opens the Component Gallery |
| `-PeakShowcaseSection dashboard\|buttons\|settings\|widgets` | Scrolls the gallery to a section |
| `-PeakShowcaseSheet stepGoal\|success\|failure` | Presents a sample sheet |
| `-PeakLoadSampleProgram YES` | With `-PeakTab settings`, loads the sample program (same as Settings › Developer › Load Sample Program) |
| `-PeakSettingsSheet stepGoal\|waterGoal\|overload\|newWorkout\|editWorkout\|newRoutine\|editRoutine` | With `-PeakTab settings`, opens that Settings sheet (edit opens the first workout or routine) |
| `-PeakImportFile /path/file.json` | With `-PeakTab settings`, reads that Peak JSON file as if picked in Import Workout Data (simulator: a path on the Mac) |
| `-PeakImportConfirm YES` | With `-PeakImportFile`, also confirms the import (merge) and shows the result |
| `-PeakImportScroll preview\|summary\|problems\|mode` | With `-PeakImportFile`, scrolls the import screen to that section |
| `-PeakTemplate xlsx\|csv\|json` | With `-PeakTab settings`, chooses that import template (the file exporter opens) |
| `-PeakExport YES` | With `-PeakTab settings`, taps Export Workout Data (the system file exporter opens) |
| `-PeakICloudSync YES` | Offers iCloud Sync (Settings row and onboarding step), which 1.0 hides ([ADR 0024](adr/0024-icloud-sync-off-for-1-0.md)); the two rows below need it |
| `-PeakShowICloud YES` | With `-PeakTab settings`, taps the iCloud row once sync reports a problem, or after 30 s |
| `-PeakToggleSync YES` | With `-PeakTab settings`, flips iCloud Sync once after launch, without the question |
| `-PeakOpenLink peak://workout/start` | Opens a `peak://` link at launch, as a widget tap does (`simctl openurl` asks first) |
| `-PeakOnboarding YES` | Shows onboarding even when there is data; add `-PeakOnboardingStep 0…5` to open on a step, or `-PeakOnboardingFinish import\|sample\|empty` to pick a start |
| `-PeakDeleteAll YES` | With `-PeakTab settings`, opens Delete All Data (nothing is deleted without typing the word) |
| `-PeakRequestHealth YES` | With `-PeakTab settings`, taps the Apple Health row |
| `-PeakLoadSampleHistory YES` | With `-PeakTab settings`, loads the sample program and three finished sessions before today (Settings › Developer › Load Sample History) |
| `-PeakLoadSecondRoutine YES` | With `-PeakTab settings`, adds an everyday second routine, so days have two workouts |
| `-PeakMockHealth YES` | Uses sample Health data (7,598 steps, a rested night, steady heart data) instead of HealthKit |
| `-PeakHomeDay yesterday\|tomorrow\|nextWeek` | Selects that day on Home (a bare `-1` would be read as another argument) |
| `-PeakLogWorkout yesterday\|today` | Opens the first workout to be entered after the fact for that day (ADR 0023) |
| `-PeakStartWorkout YES` | Starts the first workout from Home, to see the running state |
| `-PeakEnergy notReady` | Forces the energy level the "Start anyway?" alert checks (with `-PeakStartWorkout`, shows the alert) |
| `-PeakAnalysisPage performance\|history` | With `-PeakTab analysis`, opens that page |
| `-PeakAnalysisMovement "Lat Pulldown"` | With `-PeakTab analysis`, opens that movement's chart (by name, case and accents ignored) |
| `-PeakAnalysisScroll muscles\|movements\|workouts` | With `-PeakTab analysis`, scrolls the Performance page to that section |
| `-PeakStartWalk YES` | Discards the running workout and starts a walk (creates a Walking template if missing) |
| `-PeakPauseWorkout YES` | Pauses the running workout, to see the paused state |
| `-PeakOpenCompleted YES` | Opens the latest finished workout read-only, as tapping its card does |
| `-PeakOpenWorkout YES` | Opens the running workout's sheet |
| `-PeakCompleteMovement YES` | Completes the running workout's first movement |
| `-PeakFinishWorkout YES` | With `-PeakOpenWorkout`, logs every set three reps over its target and finishes, to show the summary |
| `-AppleLanguages "(tr)"` | Runs in Turkish (system argument); add `-AppleLocale tr_TR` for Turkish number formats |

```bash
xcrun simctl launch booted com.tunamu.peak -PeakTab settings -PeakOpenGallery YES -PeakShowcaseSheet success
```

## Formatting & Linting

Two tools with separate jobs, like Prettier and ESLint:

| Tool | Job | Config | How it runs |
| --- | --- | --- | --- |
| swift-format (ships with Xcode) | Layout: indentation, line breaks, import order | `.swift-format` | Xcode: Editor > Structure > Format File (⌃⇧I) |
| SwiftLint (`brew install swiftlint`) | Likely bugs and non-idiomatic code | `.swiftlint.yml` | Automatically on every Xcode build (SwiftLint build phase) |

SwiftLint rules that conflict with swift-format are disabled or relaxed in `.swiftlint.yml`.
The SwiftLint build phase needs `ENABLE_USER_SCRIPT_SANDBOXING = NO` on the app target, because it
reads the whole repo and writes a cache outside the build folder.

```bash
# Format everything in place
xcrun swift-format format -i --recursive \
  Peak Packages/PeakKit/Package.swift Packages/PeakKit/Sources Packages/PeakKit/Tests

# Check (same commands CI will run)
swiftlint lint --strict
xcrun swift-format lint --strict --recursive \
  Peak Packages/PeakKit/Package.swift Packages/PeakKit/Sources Packages/PeakKit/Tests
```

## Localization

The UI ships in English (base) and Turkish, from one String Catalog: `Peak/Resources/Localizable.xcstrings`.

- String literals in SwiftUI (`Text("Welcome Back")`) are localizable keys. Building in Xcode adds new keys to the
  catalog automatically; add the Turkish value in the catalog editor.
- Names that must not be translated (such as "Peak") are marked "Don't Translate" in the catalog.
- Try another language without changing the simulator: Product > Scheme > Edit Scheme > Run > Options > App Language.

## Apple Health and iCloud

Capabilities are configured in F0-03 and F8-01. Rules and data types: [HEALTHKIT.md](HEALTHKIT.md) and
[DATA_MODEL.md](DATA_MODEL.md).

Debug builds sync with the CloudKit **development** environment. Before a TestFlight or App Store build, run Settings ›
Developer › Initialize CloudKit Schema on a device signed in to iCloud, then deploy the schema to production in
CloudKit Console. A simulator syncs only when it is signed in to an iCloud account; without one, the app works
locally.

- Use a simulator with no Peak data from earlier runs as a second device (or delete the app first): records made
  before sign-in are uploaded too, and imported test history would double the real one.
- "Quota Exceeded" (`CKError` 25) in the log means the iCloud account's storage is full: the private database counts
  against it. Nothing uploads until there is room; the app keeps working locally and retries.
