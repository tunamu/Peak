# 0019. One more rep while the weight stays, and Previous in the set table

- **Status:** Accepted
- **Date:** 2026-09-30

## Context

Peak took its progression rule from the author's `/coach` skill: above 12 reps the weight goes up and reps reset to 6;
at 12 or fewer the weight stays and the target is the reps just done ("at least the same again"). Using the app, the
author found that a target equal to last time is no push: after 50 kg × 9 the next target was 50 kg × 9. The set table's
Reference column showed that target, which read as "last time", so there was no way to see both.

## Decision

- At or below the threshold the target is the same weight and **one rep more**: 50 × 9 → 50 × 10, and 50 × 12 →
  50 × 13, which passes the threshold and brings the weight increase. Above it nothing changes.
- The step is `ProgressionRule.repStep` (1). `ProgressionRule.coach` (0) keeps the old rule, so the tests that replay
  the author's `/coach` log still check it.
- The set table's first column is **Previous**: the same set the last time the movement was done before this workout.
  The target stays where it was: the weight field starts at the target weight, the reps field shows the target reps.
  The read-only view of a finished workout shows Previous the same way.
- The `/coach` skill keeps its rule; Peak is the author's record from now on.

## Consequences

- Targets are one rep higher than before; success rates (reps ≥ target) are harder to reach.
- Previous is computed from the history (no stored field), so no schema change on devices with data.
- Workouts started before this change keep the targets they were started with.
