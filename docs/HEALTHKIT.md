# HealthKit

> Status: skeleton. Capabilities are set up (F0-03); `HealthService` is built in F2–F5 and this file is updated with it.

## Read

| Type | Used for |
| --- | --- |
| `stepCount` | Today's total and 7-day daily average (`HKStatisticsCollectionQuery`; iPhone and Watch samples are deduplicated by the system) |
| `sleepAnalysis` | Energy Level |
| `heartRateVariabilitySDNN` | Energy Level (Apple Watch) |
| `restingHeartRate` | Energy Level (Apple Watch) |
| `dietaryWater` | Water tile |

## Write

| Type | How |
| --- | --- |
| `dietaryWater` | **One total sample per day.** When the total changes, the old sample is deleted and a new one is written, so "Remove" stays consistent |
| Workouts | `HKWorkoutBuilder`: `.traditionalStrengthTraining` for strength, `.walking` with distance for walks |

## Rules

- **Data read from HealthKit is never stored in SwiftData or iCloud** (App Store Review Guideline 5.1.3). It is read
  live and, when needed, cached locally in the App Group only. Water logs and workouts are the app's own data.
- **Permissions are requested in context** (onboarding or first use). Without permission the app still works; the
  affected card shows "Connect Apple Health".
- Step changes use an observer query with background delivery to refresh the widget.
- `HealthService` is a protocol. `MockHealthService` serves previews, tests and the simulator; DEBUG builds have a
  "Seed health data" menu because the simulator has no health data.

## Setup

| Item | Where | State |
| --- | --- | --- |
| HealthKit + background delivery | `Peak/Peak.entitlements` | ✅ |
| App Group `group.com.tunamu.peak` | `Peak/Peak.entitlements` | ✅ |
| Usage descriptions (`NSHealthShareUsageDescription`, `NSHealthUpdateUsageDescription`) | Build settings (`INFOPLIST_KEY_*`); Turkish in `Peak/Resources/InfoPlist.xcstrings` | ✅ |
| iCloud (CloudKit container `iCloud.com.tunamu.peak`, key-value store), Push, background remote notifications | — | Needs the paid Apple Developer Program; added before F8 |

The app does not list `healthkit` in `UIRequiredDeviceCapabilities`: it works without Health access.
