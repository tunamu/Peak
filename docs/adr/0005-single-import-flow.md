# 0005. Single import flow for JSON, XLSX and CSV/TSV

- **Status:** Accepted
- **Date:** 2026-09-29

## Context

People keep training history in very different spreadsheet layouts.

## Decision

One Import button accepts Peak JSON, XLSX and CSV/TSV. The layout is detected automatically, columns can be mapped by hand, and a preview is shown before anything is written.

## Consequences

- A mapping screen and a preview step are required.
- XLSX reading needs a third-party package (listed in [THIRD_PARTY_NOTICES.md](../../THIRD_PARTY_NOTICES.md) once added).
- Details: [IMPORT_FORMAT.md](../IMPORT_FORMAT.md).
