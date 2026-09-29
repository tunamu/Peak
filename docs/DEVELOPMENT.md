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

With a free Personal Team:

- The first launch is blocked until you trust the developer: **Settings > General > VPN & Device Management >
  Developer App > Trust**.
- The provisioning profile is valid for 7 days. Run from Xcode again to renew it.
- iCloud and Push Notifications are not available. HealthKit and App Groups work.

From the command line:

```bash
xcodebuild build -project Peak.xcodeproj -scheme Peak \
  -destination 'platform=iOS,id=<UDID>' -allowProvisioningUpdates
xcrun devicectl list devices
xcrun devicectl device install app --device <UDID> <path/to/Peak.app>
xcrun devicectl device process launch --device <UDID> com.tunamu.peak
```

## Component Gallery and launch arguments

Debug builds have **Settings › Developer › Component Gallery**, which shows every design token, glass primitive and
component with sample content. It is compiled out of Release builds.

Debug builds also read a few launch arguments, handy for screenshots from the command line (`simctl` cannot tap). In
Xcode, add them under Product › Scheme › Edit Scheme › Run › Arguments; `-key value` pairs land in `UserDefaults`.

| Argument | Effect |
| --- | --- |
| `-PeakTab home\|analysis\|settings` | Opens that tab |
| `-PeakOpenGallery YES` | With `-PeakTab settings`, opens the Component Gallery |
| `-PeakShowcaseSection dashboard\|buttons\|settings` | Scrolls the gallery to a section |
| `-PeakShowcaseSheet stepGoal\|success\|failure` | Presents a sample sheet |
| `-AppleLanguages "(tr)"` | Runs in Turkish (system argument) |

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

Capabilities are configured in F0-03. Rules and data types: [HEALTHKIT.md](HEALTHKIT.md) and
[DATA_MODEL.md](DATA_MODEL.md).
