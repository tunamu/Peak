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
  ├── App/              # PeakApp (@main entry point), root views
  ├── Features/         # Feature modules (Home, Settings, etc)
  ├── Resources/        # Assets.xcassets, strings, icons
  └── Peak.entitlements # iCloud + HealthKit permissions

Packages/PeakKit/       # Local Swift Package, linked to the app target
  ├── Package.swift
  ├── Sources/PeakCore/     # Models, engines, services
  ├── Sources/PeakDesign/   # UI tokens, glass components
  └── Tests/PeakCoreTests/  # Swift Testing tests

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

## HealthKit Permissions

Add to `Peak/Peak.entitlements`:
```xml
<key>com.apple.developer.healthkit</key>
<array>
  <string>HKQuantityTypeIdentifierStepCount</string>
  <string>HKQuantityTypeIdentifierWaterConsumed</string>
  <!-- See PERMISSIONS.md for full list -->
</array>
```

## iCloud Sync

`SwiftData` + `CloudKit` are wired via:
- `.entitlements` file (iCloud containers)
- Model @Query/@Environment bindings in Views
- CloudKit schema auto-sync (first app launch)

## Next Steps

- [ ] Create Home screen scaffold
- [ ] Implement HealthKit mock for testing
