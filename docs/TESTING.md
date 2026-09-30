# Testing

> Status: 152 package tests (F2–F7), green on the Mac host and the iOS simulator. No UI test target yet: taps and
> drags are checked by hand, screenshots come from debug launch arguments (see DEVELOPMENT.md).

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
`make_fixtures.py` there (Turkish Excel CSV, UTF-8 CSV, TSV, .xlsx workbooks, and one sheet per layout: long, wide, block, unsure). Change the script, not the files.

## Running

```bash
# Package tests on the host (fastest)
cd Packages/PeakKit && swift test

# Package tests on the iOS simulator (what CI runs)
cd Packages/PeakKit && xcodebuild test -scheme PeakKit-Package \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'
```

CI runs lint, the app build and the package tests on every pull request (`.github/workflows/ci.yml`).
