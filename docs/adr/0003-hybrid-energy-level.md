# 0003. Hybrid Energy Level: rule-based recovery plus HealthKit signals

- **Status:** Accepted
- **Date:** 2026-09-29

## Context

HRV and resting heart rate are only available with an Apple Watch, but every user should get an energy estimate.

## Decision

Compute the score from training-based recovery rules for everyone, and add sleep, HRV and resting heart rate only when that data exists.

## Consequences

- Works without a Watch; becomes more precise with one.
- The detail sheet lists which sources were used.
- Rules and thresholds are documented in [ENERGY_LEVEL.md](../ENERGY_LEVEL.md).
