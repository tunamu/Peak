# Data Model

> Status: skeleton. The `@Model` types are written in F2; this file follows them.

## CloudKit rules (apply from day one)

- Every property has a default value or is optional.
- No `@Attribute(.unique)`. Uniqueness is enforced in code (dedupe).
- All relationships are optional and have an inverse.
- Enums are stored as `String` raw values.
- Order is always an explicit `order: Int` field, because CloudKit does not keep relationship array order.
- Records are archived (`isArchived`), not deleted, so history stays intact. Sessions keep a snapshot of names.
- **Data read from HealthKit is never stored here.** It is read live and, if needed, cached locally in the App Group only.

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

## Settings (key-value store, not SwiftData)

`stepGoal` (10000) · `waterGoalMl` (4000) · `overloadThresholdReps` (12) · `overloadResetReps` (6) · `unitSystem`
(metric) · `quickWaterAmounts` ([200, 330, 500, 1000]) · `hasCompletedOnboarding`

## Computed, never stored

Step count (live from HealthKit) · energy score ([ENERGY_LEVEL.md](ENERGY_LEVEL.md)) · next targets
([PROGRESSIVE_OVERLOAD.md](PROGRESSIVE_OVERLOAD.md)).

## Migrations

`VersionedSchema` and `SchemaMigrationPlan` exist from the first release. The v1 schema is frozen before release;
after that only lightweight migrations are allowed.
