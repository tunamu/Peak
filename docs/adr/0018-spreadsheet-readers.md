# 0018. Spreadsheet readers: ZIPFoundation for .xlsx, our own CSV reader

- **Status:** Accepted
- **Date:** 2026-09-30

## Context

Import reads .xlsx, .csv and .tsv files (ADR 0005). The plan named CoreXLSX for .xlsx and Apple's TabularData for CSV,
with a check of CoreXLSX before use.

- **CoreXLSX** (Apache-2.0): last release 0.14.2 in March 2023, last commit March 2024. It pins XMLCoder with
  `upToNextMinor(from: "0.14.0")` while XMLCoder is at 0.18, so it would hold us on a 2022 release of a second
  dependency, plus ZIPFoundation as a third.
- **ZIPFoundation** (MIT): maintained (release 0.9.20 in September 2025, commits in 2026), no C code on Apple platforms
  (it uses the Compression framework). iOS has no public API that opens ZIP files.
- An .xlsx file is a ZIP of XML parts. The parts an import needs (workbook, relationships, shared strings, styles for
  dates, sheets) are small and Foundation's `XMLParser` reads them.
- **TabularData** needs the delimiter and parses types itself. Peak must guess the delimiter, the decimal separator and
  the encoding (Turkish Excel writes Windows-1254 with `;` and "27,5"), and keep cells as text for the mapping step.

## Decision

- .xlsx: ZIPFoundation to unpack, our `XLSXReader` with `XMLParser` for the XML. The only third-party package in the
  app, pinned `upToNextMinor(from: "0.9.20")`.
- .csv and .tsv: our `CSVReader` (RFC 4180), with encoding, delimiter and decimal separator detection.
- Both produce `RawTable`, text cells, for layout detection (F7-05).

## Consequences

- One dependency instead of three, and none unmaintained. It is listed in THIRD_PARTY_NOTICES.
- The XLSX reader covers what training logs use: shared and inline strings, rich text, date formats (1900 and 1904
  systems), cached formula values, sparse cells, hidden sheets (left out). It does not read charts, merged-cell
  layout or pivot tables.
- Checked against fixtures written for each case and against real files from Excel, Numbers and Google Sheets.
