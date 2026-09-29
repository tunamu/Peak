# Design System

> Status: tokens done (F1-01) in `Packages/PeakKit/Sources/PeakDesign/Tokens/`. Glass primitives and components follow in
> F1-02 and F1-03.

## Color tokens

Values live in code (`PeakPalette`), not in an Asset Catalog, so the contrast tests check exactly what the app draws
([ADR 0017](adr/0017-color-tokens-and-contrast.md)). Views use the shortcuts: `.foregroundStyle(.peakTextSecondary)`,
`.background(.peakCanvas)`. Each color follows light/dark mode and **Increase Contrast** by itself.

Dark values come from the design. Light values are derived for WCAG AA. The high-contrast (HC) columns apply when
Settings › Accessibility › Increase Contrast is on; an empty cell keeps the normal value.

| Token | Swift | Dark | Dark HC | Light | Light HC | Use |
| --- | --- | --- | --- | --- | --- | --- |
| `bg.canvas` | `.peakCanvas` | #202020 | | #F2F2F7 | | Screen and sheet background |
| `fill.control` | `.peakFillControl` | #FFFFFF @ 10% | | #000000 @ 6% | | Button and selected-day fill |
| `text.primary` | `.peakTextPrimary` | #FFFFFF | | #000000 | | Main text |
| `text.secondary` | `.peakTextSecondary` | #808080 | #B0B0B5 | #5E5E63 | #3A3A3C | Card labels ("Energy Level"), tappable supporting text ("Edit") |
| `text.tertiary` | `.peakTextTertiary` | #67676A | #A1A1A6 | #6C6C70 | #48484A | Non-essential text ("Weekly Average"); never tappable |
| `accent.steps` | `.peakSteps` | #FF0004 | | #D70015 | | Step ring |
| `accent.water` | `.peakWater` | #00BBFF | | #0077CC | | Water drop, water slider |
| `energy.ready` | `.peakEnergyReady` | #0DFF00 | | #1E9E32 | | |
| `energy.low` | `.peakEnergyLow` | #FFAE00 | | #B86E00 | | |
| `energy.notReady` | `.peakEnergyNotReady` | #FF0000 | | #D70015 | | |
| `tint.positive` | `.peakTintPositive` | #00FF1A @ 10% | | #1E9E32 @ 12% | | Add / Update / Finish glass tint |
| `tint.destructive` | `.peakTintDestructive` | #FF0000 @ 10% | | #D70015 @ 12% | | Remove / Reset / Cancel glass tint |
| `brand.flag` | `.peakBrandFlag` | #FE0000 | | #FE0000 | | Logo flag |

## Contrast

`ContrastTests` (in `PeakDesignTests`) enforces, in every appearance, on the canvas **and** on a glass card:

- Text: at least 4.5:1. The one exception is dark mode without Increase Contrast, where `text.secondary` and
  `text.tertiary` keep the design's grays.
- Graphics (rings, icons, bars): at least 3:1.
- `text.secondary` stays stronger than `text.tertiary`.
- Logos are exempt (WCAG 1.4.11).

Worst ratio of each token over the canvas and a glass card (refresh with `swift test --filter contrastReport`):

| Token | Dark | Dark + HC | Light | Light + HC |
| --- | --- | --- | --- | --- |
| `text.primary` | 12.03 | 12.03 | 18.82 | 18.82 |
| `text.secondary` | 3.05 | 5.57 | 5.78 | 10.17 |
| `text.tertiary` | 2.13 | 4.68 | 4.69 | 8.18 |
| `accent.steps` | 3.01 | 3.01 | 4.83 | 4.83 |
| `accent.water` | 5.47 | 5.47 | 4.17 | 4.17 |
| `energy.ready` | 8.78 | 8.78 | 3.14 | 3.14 |
| `energy.low` | 6.48 | 6.48 | 3.57 | 3.57 |
| `energy.notReady` | 3.01 | 3.01 | 4.83 | 4.83 |

The glass card is estimated as 10% white over the canvas in dark mode and white in light mode until it is measured on
a simulator (F1-02).

## Typography

System text styles only, so Dynamic Type works everywhere. Use the semantic names in code.

| Design | Where | Swift | Text style |
| --- | --- | --- | --- |
| SF 28 Regular | "Welcome Back", "Settings" | `.peakScreenTitle` | `.title` |
| SF 22 Regular | "Dashboard", section titles, exercise name | `.peakSectionTitle` | `.title2` |
| SF 20 Semibold | "Chest & Biceps", "02:16" | `.peakEmphasis` | `.title3.weight(.semibold)` |
| SF 17 Regular | Card labels | `.peakCardLabel` | `.body` |
| SF 17 Semibold | Card values | `.peakCardValue` | `.headline` |
| SF 15 Regular | Settings rows | `.peakRow` | `.subheadline` |
| SF 13 Regular | Table cells, supporting text | `.peakDetail` | `.footnote` |
| SF 11 Regular | "5 Movements - 13 Sets", "75%" | `.peakMeta` | `.caption2` |

Numbers (durations, tables, steps) use `.monospacedDigit()`.

## Spacing and shape

- **Spacing scale** (`Spacing`): `xxSmall` 4 · `xSmall` 8 · `small` 12 · `medium` 16 · `large` 24 · `xLarge` 32.
  Named uses: `screenMargin` 16, `cardHorizontal` 24, `cardVertical` 16, `section` 24.
- **Radius** (`Radius`): `card` 20 · `control` 16 (tables and buttons) · pill = `Capsule`. Nested corners use
  `ConcentricRectangle`.
- **Sizes** (`Metrics`): `dayChip` 46 pt circle · `minTouchTarget` 44 pt; smaller rows grow their hit area with
  `contentShape`.

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
