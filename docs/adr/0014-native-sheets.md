# 0014. Large cards in the design are native sheets

- **Status:** Accepted
- **Date:** 2026-09-29

## Context

The design shows large modal cards.

## Decision

Implement them as native sheets with `presentationDetents` sized to their content.

## Consequences

- Gets the iOS 26 inset Liquid Glass sheet for free.
- The system glass background of sheets is never overridden.
