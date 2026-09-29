# 0012. Walking cardio: duration from start and finish, speed and incline per session

- **Status:** Accepted
- **Date:** 2026-09-29

## Context

Treadmill walks are logged differently from strength sets.

## Decision

Duration is the difference between start and finish. Speed and incline are entered during the session. An Apple Watch only contributes the step count.

## Consequences

- Cardio uses segments (speed, incline, duration) instead of sets.
- Distance is derived: Σ speed × duration.
