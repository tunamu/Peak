# Import Format

> Status: complete (F7). Peak JSON, Excel, CSV and TSV import with the mapping screen, export, and templates.

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
| `settings` | – | `stepGoal`, `waterGoalMl`, `overload` (`thresholdReps`, `resetReps`, `repStep`), `unitSystem`, `quickWaterAmounts` |

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
- `date` is optional. Undated sessions (no `date`, no `startedAt`) are placed one day apart, in array order, ending the
  day before the earliest dated session (or before today when none has a date), and marked `dateEstimated`. The preview
  lists each one as a warning.
- A `date` without `startedAt` starts the session at noon of that day; a finished session without `endedAt` lasts 0.
- `weight` and `targetWeight` are read in `units.weight` and stored in kg; fields ending in `Kg` are always kilograms.
- Settings outside the app's ranges are clamped.
- A new schema version increases `schemaVersion`; the importer keeps reading older versions.

### Converting another log with an LLM

Give the model the schema file and your log, then ask:

> Convert this training log into JSON that validates against the attached JSON Schema. One session per workout day,
> sets as weight and reps, exercise names as written. Leave out any field you do not know. Output only the JSON.

## Spreadsheets (XLSX, CSV, TSV)

The layout is detected automatically. If confidence is low, a mapping screen asks for each column's role.

**Reading the file** ([ADR 0018](adr/0018-spreadsheet-readers.md)):

- **XLSX:** every visible sheet, in the workbook's order (hidden sheets are left out). Cells are read as text: numbers
  as Excel stores them ("27.5" in every language), date cells as `2026-09-28` (with the time when the cell's format
  shows one), formulas as their last calculated value, booleans as `TRUE`/`FALSE`. Both the 1900 and 1904 date
  systems are read.
- **CSV / TSV:** the encoding (UTF-8 with or without BOM, UTF-16 with BOM, else Windows-1254 as Turkish Excel writes
  it), the delimiter (`,` `;` tab `|`) and the decimal separator are detected; .tsv files are read with tabs. Quoted
  fields may hold delimiters, `""` and line breaks.
- Cells are trimmed, short rows padded, empty rows and columns at the end dropped. Numbers are read with the file's
  decimal separator, grouping included ("1.002,5").

| Layout | Shape |
| --- | --- |
| Long | One row per set: Date · Exercise · Set · Weight · Reps (· Workout · Note) |
| Wide | One row per session × exercise; sets as `27.5 x 9` cells or Weight 1 / Reps 1 column pairs |
| Block | A name alone on a row is an exercise (a name above it, a section); rows below are sessions with set cells |

**Detection** (`SheetAnalyzer`): among the first 10 rows, the one naming the most roles is the header. With an
exercise column and either weight and reps or set-cell columns, the sheet is long (one weight and reps column) or wide
(set cells, or several pairs); unnamed columns whose cells are mostly sets become set cells. Otherwise, lone names
followed by session rows make a block sheet. Anything else gets a guessed mapping marked unsure, and the mapping
screen asks. It also asks when there are two exercise or date columns, or when dates fit both day and month first.

- **Header names (EN/TR),** compared ignoring case and accents, whole name first, then word by word in this order:
  date/day/tarih/tarihi/gün/seans/session · exercise/movement/lift/hareket/egzersiz ·
  weight/load/kg/lb/lbs/ağırlık/yük · reps/rep/repetitions/tekrar · set/set no/set #/# · workout/routine/program/
  template/antrenman/rutin · note/comment/not/notlar/açıklama. A number with "set" ("1. Set", "Set 2", "S3"), or
  weight and reps in one name ("Ağırlık x Tekrar"), is a set-cell column; "Weight 1" / "Reps 1" pair up in order.
  "lb" or "lbs" in a header, or in most set cells, means pounds.
- **Set cells:** `27.5 x 9`, `27,5x9`, `60 kg × 8`, `135lb*5`; `27.5x8:9` means target 8, done 9 (the `/coach`
  form). `-`, `–` or an empty cell is no set. A lone comma or point in a set cell is always a decimal.
- **Dates:** `2026-09-28`, `28.09.2026`, `9/28/26` and dates inside text ("3. Seans (07.09.2026)"). A first part
  above 12 means day first, a second part above 12 month first; without such a date, `.` and `-` mean day first and
  `/` month first (unsure). Two-digit years are 20xx.
- **Sessions:** long and wide rows with the same date and workout are one session, and an empty date, workout or
  exercise cell repeats the one above. In block sheets, rows of the same date are one session across exercises and
  sections ("Sırt (Back) & Biceps (Pazu)"); undated rows ("1. Seans") are one session per section and number, and the
  importer dates them. Sets follow the Set column when every set has one, else row order.
- **Unreadable cells** are skipped with a warning naming the cell ("Antrenman!C5").
- **Import screen (S-10):** the sheet (when there are several), the layout (table or blocks), the row with column
  names, each column's role (Date, Exercise, Set #, Weight, Reps, Set cell, Workout, Note, Ignore), the date order and
  the weight unit; for CSV also the separator and the decimal separator. The first 5 workouts are shown as they will
  be imported, and they follow every change.
- **Templates:** [import-templates/](import-templates/README.md), in English and Turkish, also saved from Settings ›
  Import Template.

## Files Peak cannot import

Each ends in a message that says what to do, and nothing is written:

| File | Message |
| --- | --- |
| Damaged Peak JSON | Where it breaks: "sessions[0].date: expected a date as yyyy-MM-dd" or "unexpected end of file" |
| JSON from another app | Not Peak data |
| Damaged .xlsx (cut short, missing parts, broken XML) | Open it in Excel or Numbers and save it again |
| Old Excel (.xls) | Save it as .xlsx |
| A photo or other binary file | Not a spreadsheet |
| No rows, or only hidden sheets | Nothing to import |
| Over 64 MB unpacked | Too large for a training log |

A CSV saved under an .xlsx name opens as CSV. A file that reads but gives no workouts opens the import screen,
where the mapping can be fixed.

## Merge and replace

The import first shows a preview (`PeakImporter.preview`): sessions in the file, new and duplicate, sets, the date
range, the exercises it creates, and the problems it found. Nothing is written until the import is confirmed
(`commit`), and then in one save.

- **Merge** (default): records already in the store win and are not changed.
  - An exercise, template or routine is the same record when its id is a UUID the store has, or, when it has no such
    id, when the store has one of that name (case and accent insensitive). Otherwise it is added.
  - A session is a duplicate when the store has its UUID, or has a session on the same day with the same movements
    and sets. Duplicates are skipped, so **importing the same file twice adds nothing the second time**. Sessions with
    an estimated date match on their movements and sets alone, since the estimate can differ between imports.
  - Water logs are skipped when the store has one at the same millisecond with the same amount and source.
- **Replace all:** asks first, then writes a backup of the store (`peak-backup-YYYY-MM-DD-HHmmss.json`, the export format) and then
  deletes everything before adding the file. If the backup cannot be written, nothing is deleted. Backups are in
  Files › On My iPhone › Peak › Backups.
- Settings in the file are applied only when "Apply the File's Settings" is on (off by default).

### Problems

| Problem | Blocks the import |
| --- | --- |
| Another `schema`, a newer `schemaVersion` | Yes |
| A blank name; a movement with neither `exerciseId` nor `exerciseName` | Yes |
| Negative weight, reps, speed or paused time; `incrementKg` ≤ 0; `targetSets`, `everyDays` < 1; `durationMin` ≤ 0 | Yes |
| A weekday schedule without days; `endedAt` before `startedAt` | Yes |
| An id that finds nothing (the link is left out; an exercise falls back to its name) | No, warning |
| An estimated date | No, warning |

Each problem names where it is, for example `sessions[2].exercises[0].sets[1].reps`.

## Export

Settings › Export Workout Data writes `peak-export-YYYY-MM-DD.json` and opens the system file exporter (`PeakExporter`).

- Everything is written: archived exercises and templates, running and paused workouts, water logs and settings.
- Ids are the stored UUIDs; weights are kg (`units.weight` is `kg`); timestamps are UTC with milliseconds.
- Records come in a fixed order (templates and routines by list order, sessions by start time, ties by id), so the same
  data always gives the same file.
- A routine keeps only its chosen schedule: the weekdays of an interval routine (or the reverse) are not written.
- **Round trip:** the file imported into an empty store (`PeakImporter`) and exported again gives the same bytes
  (`PeakRoundTripTests`).
