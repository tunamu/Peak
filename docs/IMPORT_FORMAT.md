# Import Format

> Status: Peak JSON v1 is final (F7-01): DTOs, JSON Schema and examples. The importer, exporter and spreadsheet
> readers follow in F7-02…F7-08.

Peak imports JSON, XLSX and CSV/TSV through a single Import button ([ADR 0005](adr/0005-single-import-flow.md)).
Export always writes Peak JSON, and an exported file imported into an empty store recreates exactly the same data.

## Peak JSON v1

The same format is used for import and export. Schema:
[`schema/peak-workout-data.v1.schema.json`](schema/peak-workout-data.v1.schema.json). Examples:
[`full.json`](schema/examples/full.json) (every field) and [`minimal.json`](schema/examples/minimal.json) (the
smallest useful file). In code: `PeakExportV1`, read and written with `PeakJSON`.

A minimal file is a list of workouts:

```json
{
  "units": { "weight": "kg" },
  "sessions": [
    { "date": "2026-09-28", "title": "Chest & Biceps",
      "exercises": [
        { "exerciseName": "Dumbbell Chest Press",
          "sets": [ { "weight": 27.5, "reps": 9 }, { "weight": 22.5, "reps": 13 } ] }
      ] }
  ]
}
```

### Sections

| Key | Required | Content |
| --- | --- | --- |
| `schema`, `schemaVersion` | – | `"peak.workout-data"`, `1`. Written on export; checked when present |
| `exportedAt` | – | Timestamp |
| `units` | – | `{ "weight": "kg" \| "lb" }`, default kg |
| `exercises` | – | `id`, `name`\*, `muscleGroup`, `kind`, `equipment`, `incrementKg`, `archived`, `createdAt` |
| `workoutTemplates` | – | `id`, `name`\*, `kind`, `note`, `archived`, `createdAt`, `items` (`exerciseId` / `exerciseName`, `targetSets`) |
| `routines` | – | `id`, `name`\*, `note`, `active`, `schedule`, `templateIds` (the rotation), `createdAt` |
| `sessions` | ✔ | See below |
| `waterLogs` | – | `loggedAt`\*, `amountMl`\* (negative = removal), `source` |
| `settings` | – | `stepGoal`, `waterGoalMl`, `overload` (`thresholdReps`, `resetReps`), `unitSystem`, `quickWaterAmounts` |

\* required inside its object. Array order is the list order for templates and routines.

**Session:** `exercises`\* plus optional `id`, `date`, `startedAt`, `endedAt`, `pausedTotalSec`, `pausedAt`, `status`
(`active` / `paused` / `completed` / `discarded`, default completed), `title`, `templateId`, `routineId`, `note`,
`source`, `dateEstimated`, `healthKitWorkoutId`.
Each exercise needs `exerciseId` or `exerciseName`, and has `completed`, `sets` or `segments`:

- **Set:** `weight`\*, `reps`\* (integer), `targetWeight`, `targetReps`, `completed` (default true), `completedAt`
- **Segment:** `speedKmh`, `inclinePercent`, `durationMin` (missing = the rest of the session)

**Schedule:** `{ "type": "weekdays", "days": ["mon", "wed", "fri"] }` or
`{ "type": "interval", "everyDays": 2, "startDate": "2026-09-01" }`.

**Values:** dates are `yyyy-MM-dd`; timestamps are ISO 8601 with a zone (`2026-09-29T07:00:00Z`, fractions and offsets
allowed; export writes milliseconds in UTC). Enum values are the ones in the schema, in English.

### Rules

- `sessions` is the only required section. Unknown keys are rejected by the schema, so typos show up.
- Ids are free strings ("chest-biceps" or a UUID) that only link records inside one file.
- If an `exerciseId` is not found, the importer matches on `exerciseName`, ignoring case and diacritics
  ("İncline" = "Incline"). If nothing matches, the exercise is created and listed in the preview.
- `date` is optional. Undated sessions (no `date`, no `startedAt`) are placed one day apart, in array order, before the
  first dated session, and marked `dateEstimated`. The preview shows a warning for them.
- `weight` and `targetWeight` are read in `units.weight` and stored in kg; fields ending in `Kg` are always kilograms.
- Settings outside the app's ranges are clamped.
- A new schema version increases `schemaVersion`; the importer keeps reading older versions.

### Converting another log with an LLM

Give the model the schema file and your log, then ask:

> Convert this training log into JSON that validates against the attached JSON Schema. One session per workout day,
> sets as weight and reps, exercise names as written. Leave out any field you do not know. Output only the JSON.

## Spreadsheets (XLSX, CSV, TSV)

The layout is detected automatically. If confidence is low, a mapping screen asks for each column's role.

| Layout | Shape |
| --- | --- |
| Long | One row per set: Date · Exercise · Set · Weight · Reps (· Workout · Note) |
| Wide | One row per session × exercise; sets as `27.5 x 9` cells or Weight1/Reps1 column pairs |
| Block | A row with a single filled cell is an exercise header; the rows below are sessions with set cells |

- **Header synonyms (EN/TR):** date/tarih/gün · exercise/movement/hareket/egzersiz · weight/ağırlık/kg/lbs ·
  reps/tekrar/rep · set · workout/antrenman/program · note/not
- **Set cell pattern:** `^\s*(\d+(?:[.,]\d+)?)\s*(kg|lb|lbs)?\s*[x×*]\s*(\d+)(?::(\d+))?\s*$`. `27.5x8:9` means target 8,
  actual 9. `-` or an empty cell means no set.
- **CSV:** the delimiter (`,` `;` tab), decimal commas ("27,5") and the date format (dd.MM.yyyy, yyyy-MM-dd, M/d/yyyy)
  are detected. When unsure, the mapping screen asks.
- **Mapping roles:** Date, Exercise, Set #, Weight, Reps, Set cell, Workout, Note, Ignore; plus the date format and the
  weight unit. The first 5 rows are previewed live.
- **Templates:** [import-templates/](import-templates/README.md).

## Merge and replace

- **Merge** (default): a set whose date + exercise + set fingerprint already exists is skipped.
- **Replace all:** asks for confirmation and writes an automatic JSON backup first.

## Export

`peak-export-YYYY-MM-DD.json`, shared with the system file exporter or share sheet.
