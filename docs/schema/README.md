# JSON Schema

[`peak-workout-data.v1.schema.json`](peak-workout-data.v1.schema.json) is the machine-readable form of
[Peak JSON v1](../IMPORT_FORMAT.md#peak-json-v1) (JSON Schema draft 2020-12). It can be given to an LLM as a prompt to
convert other training logs into Peak JSON.

| File | Content |
| --- | --- |
| [`examples/full.json`](examples/full.json) | Every field in the schema at least once |
| [`examples/minimal.json`](examples/minimal.json) | Sessions only, matched by exercise name, one undated |

`PeakJSONSchemaTests` validates both examples against the schema, checks that the DTOs (`PeakExportV1`) keep every
field of `full.json` and that `full.json` uses every property the schema declares, and feeds broken files that must be
rejected. The tests use a small built-in validator for the keywords the schema uses; it fails on any other keyword.
Check a change with a full validator too, for example Ajv:

```bash
npm install ajv ajv-formats
node -e '
const Ajv = require("ajv/dist/2020"), fs = require("fs"); const ajv = new Ajv({ strict: true, strictRequired: false }); require("ajv-formats")(ajv);
const v = ajv.compile(JSON.parse(fs.readFileSync("peak-workout-data.v1.schema.json")));
for (const f of ["full", "minimal"]) console.log(f, v(JSON.parse(fs.readFileSync(`examples/${f}.json`))) || v.errors);'
```
