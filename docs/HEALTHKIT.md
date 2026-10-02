# HealthKit

> Status: implemented (F5). `HealthService` (protocol), `HealthConnection` (shared status) and `MockHealthService` live
> in `PeakCore/Health/`; `HealthKitService` lives in the app (`Peak/Services/`).

## Read

| Type | Used for |
| --- | --- |
| `stepCount` | Today's total and 7-day daily average (`HKStatisticsCollectionQuery`; iPhone and Watch samples are deduplicated by the system) |
| `sleepAnalysis` | Energy Level |
| `heartRateVariabilitySDNN` | Energy Level (Apple Watch) |
| `restingHeartRate` | Energy Level (Apple Watch) |
| `dietaryWater` | Finding the day's own sample to replace or delete it |

Workouts are written and deleted, never read: both need only share access.

## Write

| Type | How |
| --- | --- |
| `dietaryWater` | **One total sample per day.** When the total changes, the old sample is deleted and a new one is written, so "Remove" stays consistent |
| Workouts | `HKWorkoutBuilder`: `.traditionalStrengthTraining` for strength, `.walking` (indoor) with `distanceWalkingRunning` for walks when every segment has a duration. Only the total pause is known, so it is written as one pause right before the end |

## How the numbers are read

| Value | Query |
| --- | --- |
| Day's steps | `HKStatisticsCollectionQueryDescriptor`, cumulative sum per calendar day |
| Weekly average | The seven days before the selected day; days without steps are left out |
| Sleep | Asleep samples (core, deep, REM, unspecified) from 18:00 the evening before to noon; overlapping iPhone and Watch samples are merged |
| HRV, resting heart rate | Daily averages; the day's value against the previous days (the engine needs five) |
| Water | Written, not read: the app's own log is the source. Sync identifier `peak.water.<yyyy-MM-dd>` with a millisecond version, so each write replaces the day's sample; a total of zero deletes it |

HealthKit never tells whether *read* access was granted. The status comes from `statusForAuthorizationRequest` and
write access to water; a denied read just returns no data.

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
| iCloud (CloudKit container `iCloud.com.tunamu.peak`, key-value store), Push | `Peak/Peak.entitlements` | ✅ F8-01 |
| Background remote notifications (CloudKit pushes) | `Peak/Info.plist` (`UIBackgroundModes`) | ✅ F8-01 |

The app does not list `healthkit` in `UIRequiredDeviceCapabilities`: it works without Health access.
