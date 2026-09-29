# 0017. Color tokens in code, design grays with an Increase Contrast fallback

- **Status:** Accepted
- **Date:** 2026-09-29

## Context

Measured against WCAG 2.x, the design's dark grays fall short of 4.5:1 for small text: `text.secondary` (#808080) is
4.13:1 on the canvas and about 3:1 on a glass card; `text.tertiary` (#67676A) is 2.89:1 and about 2.1:1. Raising them
to pass on cards (about #9E9E9E) makes the app look brighter than the design and nearly erases the difference between
secondary and tertiary text. Apple's own `tertiaryLabel` is also below 4.5:1.

The plan put colors in an Asset Catalog. Contrast would then have to be checked against values copied out of the
catalog's JSON files.

## Decision

- Colors are defined in code (`PeakPalette`, `ColorToken`, `RGBA`) and exposed as `Color` through a dynamic `UIColor`
  that follows light/dark mode and Increase Contrast. Tests check the same values the app draws with.
- Dark mode keeps the design's grays by default. With Settings › Accessibility › Increase Contrast on, both themes switch
  to grays that pass 4.5:1 on the canvas and on glass cards.
- Light mode passes AA with or without Increase Contrast.
- Anything tappable uses `text.secondary` or stronger, never `text.tertiary`.
- Logos (`brand.flag`) are exempt, as WCAG 1.4.11 allows.

## Consequences

- `ContrastTests` fails CI if a token change breaks these rules. The contrast table in
  [DESIGN_SYSTEM.md](../DESIGN_SYSTEM.md) is printed by `swift test --filter contrastReport`.
- Colors are not visible as swatches in Xcode's asset editor; previews show them instead.
- The glass card background is an estimate until it is measured on a simulator (F1-02). Two graphic tokens sit at
  3.01:1 on that estimate, so the measurement may force a small change.
