# 0006. Converting personal note formats is out of scope

- **Status:** Accepted
- **Date:** 2026-09-29

## Context

The maintainer's existing history lives in a Markdown training log.

## Decision

The app does not parse personal note formats. Because the JSON schema is documented, external tools can convert such notes into Peak JSON.

## Consequences

- The importer stays focused on JSON and spreadsheets.
- The JSON schema is a public contract and must stay documented and versioned.
