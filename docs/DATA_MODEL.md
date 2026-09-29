# Data Model

> Status: schema v1 written (F2) in `Packages/PeakKit/Sources/PeakCore/`. Not frozen yet; it freezes before the first
> release.

## CloudKit rules (apply from day one)

- Every property has a default value or is optional.
- No `@Attribute(.unique)`. Uniqueness is enforced in code (dedupe).
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
| `Models/SchemaV1.swift` | The `@Model` classes, nested in `SchemaV1: VersionedSchema` |
| `Models/Models.swift` | Short names (`Exercise` = `SchemaV1.Exercise`), typed enum accessors, ordered relationship arrays |
| `Models/ModelEnums.swift` | Enums stored as raw strings; `Weekday` and its bit mask |
| `Persistence/PeakStore.swift` | `PeakStore.makeContainer(_:syncsWithCloudKit:)` and `PeakMigrationPlan` |
| `Repositories/` | Reads and writes per area; the rules below live here |
| `Settings/SettingsStore.swift` | Settings, see below |
| `Seed/SampleProgram.swift` | The optional sample program |

Stored enum properties end in `Raw` (`muscleGroupRaw`); use the typed accessor (`muscleGroup`) in code and the raw
field only in `#Predicate`, which cannot see computed properties.

## Entities

| Entity | Purpose | Key fields |
| --- | --- | --- |
| `Exercise` | Movement library | `name`, `muscleGroup`, `kind` (strength/cardio), `equipment`, `incrementKg` (default 2.5), `isArchived` |
| `WorkoutTemplate` | A named workout, e.g. "Chest & Biceps" | `name`, `kind`, `note`, `sortIndex`, `isArchived`, `items` |
| `TemplateItem` | Exercise inside a template | `order`, `targetSets` (default 2), `exercise`, `template` |
| `Routine` | A schedule of templates | `isActive`, `scheduleType` (weekdays/interval), `weekdaysMask`, `intervalDays`, `startDate`, `entries` |
| `RoutineEntry` | Template position in a routine's rotation | `order`, `template`, `routine` |
| `WorkoutSession` | A performed workout | `status`, `startedAt`, `endedAt`, `pausedTotal`, `pausedAt`, `title` (snapshot), `source`, `isDateEstimated`, `healthKitWorkoutID`, `exercises` |
| `SessionExercise` | Exercise inside a session | `order`, `exerciseName` (snapshot), `isCompleted`, `sets`, `segments` |
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
- iCloud sync is **off** until F8. `ModelConfiguration` would otherwise sync automatically as soon as the app has an
  iCloud entitlement, so `PeakStore` always passes the CloudKit setting explicitly.
- Keep the `ModelContainer` alive for as long as its contexts are used (the app holds it in `PeakApp`). A
  `ModelContext` does not retain its container; tests keep theirs alive for the whole run.

## Settings (App Group `UserDefaults`, not SwiftData)

`stepGoal` (10000) · `waterGoalMl` (4000) · `overloadThresholdReps` (12) · `overloadResetReps` (6) · `unitSystem`
(metric) · `quickWaterAmounts` ([200, 330, 500, 1000]) · `hasCompletedOnboarding`

`SettingsStore` (`@Observable`) writes every change to the App Group's `UserDefaults`, where the widget can read it,
and clamps values to the ranges the pickers offer (steps 1,000–50,000, water 1,000–6,000 ml, reps 6–20, up to four
quick water amounts of 50–2,000 ml). A `SettingsMirror` can copy settings to iCloud's key-value store; that mirror
arrives with iCloud sync in F8, because the key-value store needs the paid developer membership.

## Sample program

`SampleProgram.install(into:)` adds 13 exercises, the design's six templates ("Chest & Biceps" … "Shoulder &
Triceps") and a Monday/Wednesday/Friday routine ("Main Routine") that rotates through them. Running it twice adds
nothing. It is offered in onboarding (F10-05); until then debug builds have Settings › Developer › Load Sample Program.

## Computed, never stored

Step count (live from HealthKit) · energy score ([ENERGY_LEVEL.md](ENERGY_LEVEL.md)) · next targets
([PROGRESSIVE_OVERLOAD.md](PROGRESSIVE_OVERLOAD.md)).

## Migrations

`SchemaV1` and `PeakMigrationPlan` exist from the first release. The v1 schema is frozen before release; after that
a change means a new `SchemaV2` (a copy of the models with the change), a `MigrationStage` from v1 to v2, and moving
the short type names in `Models.swift` to the new schema. Only lightweight migrations are allowed once iCloud sync is
on.
