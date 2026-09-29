# 0008. Dark and light themes that follow the system

- **Status:** Accepted
- **Date:** 2026-09-29

## Context

The design is only drawn in dark mode.

## Decision

Support both themes and follow the system setting. Dark values come from the design; light values are derived.

## Consequences

- Light variants must pass WCAG AA: text ≥ 4.5:1, graphics ≥ 3:1.
- Every `#Preview` is checked in both themes.
