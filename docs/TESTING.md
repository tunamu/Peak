# Testing

> Status: 236 package tests, green on the Mac host and the iOS simulator. The `PeakUITests` target runs
> `performAccessibilityAudit` on every tab, onboarding, a running workout and the Analysis pages with the author's
> real history, in English and Turkish (F10-02, F11), and sends a reminder end to end (`ReminderTests`). Other taps
> and drags are checked by hand; screenshots come from debug launch arguments (see DEVELOPMENT.md).

## Layers

| Layer | Tool | Covers |
| --- | --- | --- |
| Unit | Swift Testing (`Packages/PeakKit/Tests`) | Engines, import parsing and mapping, JSON round-trip |
| UI | XCUITest | Main flows (start, log, finish a workout; import) and `performAccessibilityAudit` |
| Previews | `#Preview` | Every view in dark and light mode, and at Dynamic Type XXL |
| Sync | Manual, two devices | iCloud scenarios, written in F8 |

Engines are pure and take value types, so they are tested without SwiftData or HealthKit. HealthKit is replaced with
`MockHealthService`.

## Fixtures

Real training data is used as fixtures, for example the progressive overload cases in
[PROGRESSIVE_OVERLOAD.md](PROGRESSIVE_OVERLOAD.md#test-fixtures-real-training-data).

Import reader fixtures live in `Packages/PeakKit/Tests/PeakCoreTests/Fixtures/Import/` and are written by
`make_fixtures.py` there (Turkish Excel CSV, UTF-8 CSV, TSV, .xlsx workbooks, one sheet per layout, the real `/coach` history, twelve synthetic weeks, and `broken/`). Change the script, not the files; it writes the same bytes on every run.

## Running

```bash
# Package tests on the host (fastest)
cd Packages/PeakKit && swift test

# Package tests on the iOS simulator (what CI runs)
cd Packages/PeakKit && xcodebuild test -scheme PeakKit-Package \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'
```

```bash
# UI tests (accessibility audits and a reminder; about seven minutes)
xcodebuild test -project Peak.xcodeproj -scheme PeakUITests \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest'
```

If a UI test run stops at "Timed out while preparing execution worker", shut the simulator down
(`xcrun simctl shutdown <UDID>`) and run again.

CI runs lint, the app build and the package tests on every pull request (`.github/workflows/ci.yml`). The UI tests
run locally only, for now.
