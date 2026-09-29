# Design System

> Status: skeleton. Tokens and components are built in F1 (`PeakDesign`); this file is updated with them.

## Color tokens

Dark values come from the design. Light values are derived and must pass WCAG AA (text ≥ 4.5:1, graphics ≥ 3:1).

| Token | Dark | Light | Use |
| --- | --- | --- | --- |
| `bg.canvas` | #202020 | #F2F2F7 | Screen and sheet background |
| `text.primary` | #FFFFFF | #000000 | Main text |
| `text.secondary` | #808080 | #6C6C70 | Card labels ("Energy Level") |
| `text.tertiary` | #67676A | #8E8E93 | Supporting text ("Weekly Average", "Edit") |
| `fill.control` | #FFFFFF @ 10% | #000000 @ 6% | Button and selected-day fill |
| `accent.steps` | #FF0004 | #D70015 | Step ring |
| `accent.water` | #00BBFF | #0077CC | Water drop, water slider |
| `energy.ready` | #0DFF00 | #1E9E32 | |
| `energy.low` | #FFAE00 | #B86E00 | |
| `energy.notReady` | #FF0000 | #D70015 | |
| `tint.positive` | #00FF1A @ 10% | #1E9E32 @ 12% | Add / Update / Finish glass tint |
| `tint.destructive` | #FF0000 @ 10% | #D70015 @ 12% | Remove / Reset / Cancel glass tint |
| `brand.flag` | #FE0000 | #FE0000 | Logo flag |

## Typography

System text styles only, so Dynamic Type works everywhere.

| Design | Where | SwiftUI |
| --- | --- | --- |
| SF 28 Regular | "Welcome Back", "Settings" | `.title` |
| SF 22 Regular | "Dashboard", section titles, exercise name | `.title2` |
| SF 20 Semibold | "Chest & Biceps", "02:16" | `.title3.weight(.semibold)` |
| SF 17 Regular / Semibold | Card labels / values | `.body` / `.headline` |
| SF 15 Regular | Settings rows | `.subheadline` |
| SF 13 Regular | Table cells, supporting text | `.footnote` |
| SF 11 Regular | "5 Movements - 13 Sets", "75%" | `.caption2` |

Numbers (durations, tables, steps) use `.monospacedDigit()`.

## Spacing and shape

- **Spacing scale:** 4 · 8 · 12 · 16 · 24 · 32. Screen margin 16, card padding 24 horizontal / 16 vertical, 24 between
  sections.
- **Radius:** card 20 · table and button 16 · pill = `Capsule` · day chip 46 pt circle. Nested corners use
  `ConcentricRectangle`.
- **Touch targets:** at least 44 × 44 pt; smaller rows grow their hit area with `contentShape`.

## Liquid Glass

Glass is used widely, as in the design ([ADR 0013](adr/0013-widespread-glass.md)).

- **Card:** `.glassEffect(.regular, in: .rect(cornerRadius: 20))`
- **Tinted button:** `.glassEffect(.regular.tint(.positive).interactive(), in: .rect(cornerRadius: 16))`; destructive
  actions use the destructive tint.
- **Neutral button** (Start, Complete Movement): `.buttonStyle(.glass)`
- **Neighbouring glass elements** (Energy + Water, bottom bar, Remove/Add) are grouped in `GlassEffectContainer` for
  performance and morphing.
- **Table rows are never glass individually;** only the table container is.
- **Reduce Transparency:** system glass adapts itself; custom fills fall back to an opaque `bg.canvas` tone.
- Scrolling performance is measured with Instruments before release (F10).

## Icons

SF Symbols; active states use `.fill`.

| Design | SF Symbol |
| --- | --- |
| home | `house` / `house.fill` |
| chart | `chart.line.uptrend.xyaxis` |
| settings | `gearshape` / `gearshape.fill` |
| add | `plus.circle` / `plus` |
| play · pause | `play.fill` · `pause.fill` |
| ok · cross | `checkmark` · `xmark` |
| reorder | `line.3.horizontal` |
| export · import | `square.and.arrow.up` · `square.and.arrow.down` |
| back · forward | `chevron.left` · `chevron.right` |
| energy · water | `bolt.fill` · `drop.fill` |
| log out | `rectangle.portrait.and.arrow.right` |

**App icon:** a mountain with a red flag, built in Icon Composer with Default, Dark, Clear and Tinted variants.
