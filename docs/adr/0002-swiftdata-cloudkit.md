# 0002. SwiftData with CloudKit private database for sync

- **Status:** Accepted
- **Date:** 2026-09-29

## Context

Peak has no accounts and no servers. Data still needs to follow the user across devices.

## Decision

Store data locally with SwiftData and sync it through the user's CloudKit private database.

## Consequences

- No backend cost, strong privacy: data lives on device and in the user's own iCloud.
- The model must follow CloudKit rules from day one (see [DATA_MODEL.md](../DATA_MODEL.md)): defaults or optionals everywhere, no unique constraints, optional relationships with inverses, explicit `order` fields, archive instead of delete.
- Data read from HealthKit is never written to SwiftData or CloudKit (App Review Guideline 5.1.3).
