# 0015. Multiple routines can be active at the same time

- **Status:** Accepted
- **Date:** 2026-09-29

## Context

A typical week mixes strength, core and walking routines.

## Decision

Any number of routines can be active. Each keeps its own rotation.

## Consequences

- Home can list several workouts for one day; the main Start button targets the first unfinished one.
- Rotation state is derived, not stored (see [ROUTINES.md](../ROUTINES.md)).
