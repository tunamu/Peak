# Data Model

> Status: schema v1 written (F2) in `Packages/PeakKit/Sources/PeakCore/`. Not frozen yet; it freezes before the first
> release.

## CloudKit rules (apply from day one)

- Every property has a default value or is optional.
- No `@Attribute(.unique)`. Uniqueness is enforced in code (see [Duplicates from sync](#duplicates-from-sync)).
- All relationships are optional and have an inverse.
- Enums are stored as `String` raw values.
- Order is always an explicit `order: Int` field, because CloudKit does not keep relationship array order.
- Records are archived (`isArchived`), not deleted, so history stays intact. Sessions keep a snapshot of names.
- **Data read from HealthKit is never stored here.** It is read live and, if needed, cached locally in the App Group only.

`SchemaRulesTests` checks the first four rules on the real schema (no unique constraints, defaults or optionals,
optional relationships with inverses, only `String`/`Int`/`Double`/`Bool`/`Date`/`UUID` attributes), so a new
property that would break sync fails CI.

## Code layout

| Path | What |
| --- | --- |
| `Models/SchemaV2.swift` | The current `@Model` classes, nested in `SchemaV2: VersionedSchema` (F11) |
| `Models/SchemaV1.swift` | The first schema, kept for the migration from devices that have it |
| `Models/Models.swift` | Short names (`Exercise` = `SchemaV2.Exercise`), typed enum accessors, ordered relationship arrays |
| `Models/ModelEnums.swift` | Enums stored as raw strings; `Weekday` and its bit mask |
| `Persistence/PeakStore.swift` | `PeakStore.makeContainer(_:syncsWithCloudKit:)` and `PeakMigrationPlan` |
| `Repositories/` | Reads and writes per area; the rules below live here |
| `Settings/SettingsStore.swift` | Settings, see below |
| `Seed/SampleProgram.swift` | The optional sample program |
| `Sync/Deduplicator.swift` | Merging records two devices created separately |
| `Sync/SyncMonitor.swift`, `Sync/SyncState.swift` | Sync status for Settings (per event kind: setup, import, export); runs the deduplicator after iCloud imports |

Stored enum properties end in `Raw` (`muscleGroupRaw`); use the typed accessor (`muscleGroup`) in code and the raw
field only in `#Predicate`, which cannot see computed properties.

## Entities

| Entity | Purpose | Key fields |
| --- | --- | --- |
| `Exercise` | Movement library | `name`, `muscleGroup`, `kind` (strength/cardio), `equipment`, `incrementKg` (default 2.5), `note` (setup), `overloadThresholdReps` / `overloadResetReps` / `overloadRepStep` (own rule, `nil` = follow), `isArchived` |
| `WorkoutTemplate` | A named workout, e.g. "Chest & Biceps" | `name`, `kind`, `note`, the same three `overload…` values, `sortIndex`, `isArchived`, `items` |
| `TemplateItem` | Exercise inside a template | `order`, `targetSets` (default 2), `exercise`, `template` |
| `Routine` | A schedule of templates | `isActive`, `scheduleType` (weekdays/interval), `weekdaysMask`, `intervalDays`, `startDate`, `entries` |
| `RoutineEntry` | Template position in a routine's rotation | `order`, `template`, `routine` |
| `WorkoutSession` | A performed workout | `status`, `startedAt`, `endedAt`, `pausedTotal`, `pausedAt`, `title` (snapshot), `source`, `isDateEstimated`, `healthKitWorkoutID`, `exercises` |
| `SessionExercise` | Exercise inside a session | `order`, `exerciseName` (snapshot), `note` (this session), `isCompleted`, `sets`, `segments` |
| `SetEntry` | One strength set | `order`, `weightKg`, `reps`, `targetWeightKg`, `targetReps`, `isCompleted`, `completedAt` |
| `CardioSegment` | One cardio segment | `order`, `speedKmh`, `inclinePercent`, `durationSec` |
| `WaterLog` | Water intake change | `date`, `amountMl` (negative = removal), `source` (app/widget/intent) |

The routine rotation cursor is **derived, not stored**: the next template is the entry after the one used in the
routine's last completed session. This avoids sync conflicts between devices.

`weekdaysMask`: bit 0 = Monday … bit 6 = Sunday. Monday, Wednesday and Friday is `0b10101` (21).

## Delete and archive rules

| Action | Effect |
| --- | --- |
| Archive an exercise or template | Hidden from lists; sessions, template items and routines keep pointing at it |
| Rename an exercise or template | Past sessions keep the old name (snapshot); history still finds them through the link |
| Discard a session | The session and its exercises, sets and segments are deleted; exercises stay |
| Delete a routine | Its rotation entries go; its sessions stay, with the link cleared and the title kept |
| Delete a template (not offered in the UI) | Its items go; exercises stay |
| Remove water | Never below zero: a removal larger than the day's total only removes what is there |

Exercises are matched by name ignoring case, accents and extra spaces (`String.matchingKey`): "İncline Walk" is
"incline walk". Creating an exercise that already exists (even archived) returns the existing one.

## Store and container

- The store lives in the App Group container (`group.com.tunamu.peak`, `Library/Application Support/Peak.store`), so
  the widget opens the same data.
- iCloud sync is opt-in and per device (Settings › General › iCloud Sync, off by default; `AppData` keeps the choice
  in the app's own defaults). SwiftData decides about CloudKit when a container opens, so turning it on or off opens
  the store again with the new setting and the screens rebuild on it; no relaunch.
- With sync on, the app syncs the store with the CloudKit private database `iCloud.com.tunamu.peak` (F8). The widget opens the same
  store without sync; SwiftData records persistent history either way, so the app uploads the widget's writes the next
  time it runs. `ModelConfiguration` would sync automatically as soon as a target has an iCloud entitlement, so
  `PeakStore` always passes the CloudKit setting explicitly.
- `PeakStore.initializeCloudKitSchema()` (debug builds, Settings › Developer › Initialize CloudKit Schema) creates every
  record type in the development environment, including models with no data yet, before the schema is deployed to
  production. It uses a throwaway store.
- Keep the `ModelContainer` alive for as long as its contexts are used (the app holds it in `PeakApp`). A
  `ModelContext` does not retain its container; tests keep theirs alive for the whole run.

## Settings (App Group `UserDefaults`, not SwiftData)

`stepGoal` (10000) · `waterGoalMl` (4000) · `overloadThresholdReps` (12) · `overloadResetReps` (6) ·
`overloadRepStep` (1, 0–5) · `unitSystem` (metric) · `quickWaterAmounts` ([200, 330, 500, 1000]) ·
`hasCompletedOnboarding`

`SettingsStore` (`@Observable`) writes every change to the App Group's `UserDefaults`, where the widget can read it,
and clamps values to the ranges the pickers offer (steps 1,000–50,000, water 1,000–6,000 ml, reps 6–20, up to four
quick water amounts of 50–2,000 ml). In the app, `UbiquitousSettingsMirror` copies every change to iCloud's key-value
store too. At start-up the mirror's values win and are written to the App Group copy; settings only this device has go
up to the mirror; keys neither side has stay unset, so a new device does not push defaults over values still
downloading. Changes from another device arrive through the store's notification.

## Duplicates from sync

Two devices can each create the same record before iCloud brings them together: the sample program loaded on both,
or "Row" added on each while offline. `Deduplicator` merges them; `SyncMonitor` runs it at launch and after every
finished iCloud import (`NSPersistentCloudKitContainer.eventChangedNotification`), once per burst.

| Model | Same record when | The duplicate's links move to the survivor |
| --- | --- | --- |
| `Exercise` | Same name (`matchingKey`) | Template items, session exercises; archived only if both were |
| `WorkoutTemplate` | Same name, kind and exercise list (exercise and set count, in order) | Routine entries, sessions; archived only if both were |
| `Routine` | Same name, schedule type, weekdays, interval and rotation (start date ignored) | Sessions; active if either was |

- The survivor is the oldest record, so a movement's own settings win over a copy just made on another device.
  Every device must pick the same survivor on its own (if each picked a different one, each would delete the other's
  and both would be lost), so age is `createdAt` in whole seconds: CloudKit keeps milliseconds, and the same record
  can carry a slightly different date on each device. Within the same second the smallest `id` wins (ids sync
  unchanged).
- Copies with the **same** `id` (one export imported on two devices) are left alone, for the same reason: nothing
  tells them apart identically everywhere.
- Exercises go first, then templates, then routines, so templates that differed only in which copy of an exercise they
  used are recognized as the same.
- The duplicate's own children (a template's items, a routine's entries) are deleted with it.
- Sessions and water logs are never merged: each is an event, and two identical ones on a day can be real. Importing
  the same file on two devices before they sync can therefore double sessions (F8-03 scenario); importing after sync
  finds them as duplicates.

## Sample program

`SampleProgram.install(into:)` adds 13 exercises, the design's six templates ("Chest & Biceps" … "Shoulder &
Triceps") and a Monday/Wednesday/Friday routine ("Main Routine") that rotates through them. Running it twice adds
nothing. It is offered in onboarding (F10-05); until then debug builds have Settings › Developer › Load Sample Program.
It is never installed on its own, so a second device does not seed what iCloud is about to bring; if both devices
load it before syncing, `Deduplicator` leaves one copy.

## Computed, never stored

Step count (live from HealthKit) · energy score ([ENERGY_LEVEL.md](ENERGY_LEVEL.md)) · next targets
([PROGRESSIVE_OVERLOAD.md](PROGRESSIVE_OVERLOAD.md)).

## Migrations

A change to the stored models means a new schema version (a copy of the models with the change), a `MigrationStage`
to it, and moving the short type names in `Models.swift` to it. Only lightweight migrations: iCloud sync needs them.

| Version | Since | Change | Stage |
| --- | --- | --- | --- |
| `SchemaV1` | F2 | The first schema | — |
| `SchemaV2` | F11 | `Exercise.note`, `SessionExercise.note` (F11-12); `overloadThresholdReps`, `overloadResetReps`, `overloadRepStep` on `Exercise` and `WorkoutTemplate` (F11-10). All optional or defaulted | Lightweight ([ADR 0022](adr/0022-schema-v2.md)) |

`MigrationTests` writes a v1 store file with data and opens it with the app's plan: every record is in place and the
new properties are empty. With iCloud Sync on, the CloudKit development schema needs the new fields
(`PeakStore.initializeCloudKitSchema()`, debug builds) before production is deployed (F12).
