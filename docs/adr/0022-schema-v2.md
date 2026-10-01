# 0022. SchemaV2: movement notes and per-movement progressive overload

- **Status:** Accepted
- **Date:** 2026-10-01

## Context

Two F11 features need stored data the first schema does not have: notes on a movement (how it is set up, and how it
went each session; F11-12) and progressive overload values for one workout or one movement (F11-10). Devices already
hold real data in `SchemaV1`, including the author's phone, and iCloud Sync only accepts lightweight migrations.

## Decision

- One new version, `SchemaV2`, for both features, so devices migrate once:
  - `Exercise.note` (setup, `""`), `SessionExercise.note` (this session, `""`);
  - `overloadThresholdReps`, `overloadResetReps`, `overloadRepStep` (`Int?`, `nil` = follow the level below) on
    `Exercise` and `WorkoutTemplate`.
- Every new property is optional or defaulted: the migration is `MigrationStage.lightweight(SchemaV1 → SchemaV2)`.
- The rule for a movement: its own values, else its workout's, else Settings (`ProgressionRule.applying(_:)`).
- Peak JSON v1 carries them as optional fields (`note`, `overload`), so older files still import and older builds
  ignore nothing they need.
- `MigrationTests` opens a store file written with `SchemaV1` and checks every record and the new defaults.
- The routine's reminder time stays out of the schema (D-29, ADR 0021): it is a device setting.

## Consequences

- `SchemaV1.swift` stays in the code for the migration; new changes go into a `SchemaV3` the same way.
- Before installing a V2 build on a device with data, an export (Settings › Export Workout Data) is the backup if
  anything goes wrong.
- The CloudKit development schema needs the new fields before the production deploy (F12).
