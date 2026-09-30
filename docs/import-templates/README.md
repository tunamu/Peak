# Import Templates

Ready-to-fill files with two example workouts to replace: spreadsheets in the long layout (one row per set), and the
same workouts as Peak JSON. Filled in and picked in Settings › Import Workout Data, they import without questions.
The app shares them from Settings › Import Template, in the phone's language. Layout details: [IMPORT_FORMAT.md](../IMPORT_FORMAT.md#spreadsheets-xlsx-csv-tsv).

| File | Language | Content |
| --- | --- | --- |
| [`peak-template.xlsx`](peak-template.xlsx) | English | Excel: real dates and numbers, bold frozen header |
| [`peak-template.csv`](peak-template.csv) | English | `,` separated, `27.5`, `2026-09-28` |
| [`peak-sablon.xlsx`](peak-sablon.xlsx) | Turkish | Excel, Turkish column names |
| [`peak-sablon.csv`](peak-sablon.csv) | Turkish | As Turkish Excel writes it: `;` separated, `27,5`, `28.09.2026` |
| [`peak-template.json`](peak-template.json) | English | [Peak JSON](../IMPORT_FORMAT.md#peak-json-v1): exercises with muscle group and increment, sessions by day |
| [`peak-sablon.json`](peak-sablon.json) | Turkish | The same, with the note in Turkish |

Columns: Date · Workout · Exercise · Set · Weight (kg) · Reps · Note (Turkish: Tarih · Antrenman · Hareket · Set ·
Ağırlık (kg) · Tekrar · Not). Weight in pounds: write "Weight (lb)" in the header. Workout and Note may stay empty; a
set's row may leave Date, Workout and Exercise empty to repeat the row above.

The files are written by `ImportTemplate` (PeakCore) and must stay its exact bytes; `ImportTemplateTests` checks.
After changing the generator, rewrite them:

```bash
cd Packages/PeakKit && PEAK_WRITE_TEMPLATES=1 swift test --filter ImportTemplateTests
```

The JSON files validate against the [schema](../schema/peak-workout-data.v1.schema.json). Both CSV files start with a
UTF-8 byte order mark, so Excel opens them with the right characters. The .xlsx files were checked with openpyxl and
macOS Quick Look.
