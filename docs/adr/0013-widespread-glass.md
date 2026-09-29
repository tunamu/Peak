# 0013. Liquid Glass used widely, as in the design

- **Status:** Accepted
- **Date:** 2026-09-29

## Context

Apple's HIG recommends keeping glass off the content layer. The design uses glass on cards, tables, buttons and the day picker.

## Decision

Follow the design: glass on cards, table containers, buttons and the day picker. Buttons use a light tint (positive green, destructive red, about 10%). This deliberately relaxes the HIG recommendation.

## Consequences

- Performance and legibility risk. Mitigations: group neighbours in `GlassEffectContainer`, never make individual table rows glass, measure with Instruments before release.
- Fallback if scrolling stutters: move glass inside scroll content to a subtle solid fill.
- Rules: [DESIGN_SYSTEM.md](../DESIGN_SYSTEM.md).
