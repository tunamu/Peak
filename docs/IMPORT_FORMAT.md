# Import Format

> Status: skeleton. The importer and the JSON Schema file are built in F7; this file is updated with them.

Peak imports JSON, XLSX and CSV/TSV through a single Import button ([ADR 0005](adr/0005-single-import-flow.md)).
Export always writes Peak JSON, and an exported file imported into an empty store recreates exactly the same data.

## Peak JSON v1

The same format is used for import and export.

```json
{
  "schema": "peak.workout-data",
  "schemaVersion": 1,
  "exportedAt": "2026-09-29T10:00:00Z",
  "units": { "weight": "kg", "speed": "km/h" },
  "exercises": [
    { "id": "dumbbell-chest-press", "name": "Dumbbell Chest Press", "muscleGroup": "chest",
      "kind": "strength", "equipment": "dumbbell", "incrementKg": 2.5 }
  ],
  "workoutTemplates": [
    { "id": "chest-biceps", "name": "Chest & Biceps", "kind": "strength",
      "items": [ { "exerciseId": "dumbbell-chest-press", "targetSets": 2 } ] }
  ],
  "routines": [
    { "id": "main", "name": "Workout routine 1", "active": true,
      "schedule": { "type": "weekdays", "days": ["mon", "wed", "fri"] },
      "templateIds": ["chest-biceps"] }
  ],
  "sessions": [
    { "id": "2026-09-28-chest-biceps", "date": "2026-09-28", "startedAt": null, "endedAt": null,
      "templateId": "chest-biceps", "routineId": "main", "note": "",
      "exercises": [
        { "exerciseId": "dumbbell-chest-press",
          "sets": [ { "weight": 27.5, "reps": 9 }, { "weight": 22.5, "reps": 13 } ] }
      ] },
    { "id": "walk-1", "date": "2026-09-29",
      "startedAt": "2026-09-29T07:00:00Z", "endedAt": "2026-09-29T07:40:00Z",
      "templateId": "walking",
      "exercises": [
        { "exerciseName": "Incline Walk",
          "segments": [ { "speedKmh": 5.5, "inclinePercent": 10, "durationMin": 40 } ] }
      ] }
  ],
  "settings": { "stepGoal": 10000, "waterGoalMl": 4000, "overload": { "thresholdReps": 12, "resetReps": 6 } }
}
```

### Rules

- `sessions` is the only required section.
- If an `exerciseId` is not found, the importer matches on `exerciseName`, ignoring case and diacritics
  ("İncline" = "Incline"). If nothing matches, the exercise is created and listed in the preview.
- `date` is optional. Undated sessions are placed one day apart, in array order, before the first dated session, and
  marked `isDateEstimated`. The preview shows a warning for them.
- Weights are read in `units.weight` and stored in kg.
- A new schema version increases `schemaVersion`; the importer keeps reading older versions.
- Machine-readable schema: [schema/](schema/README.md).

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
