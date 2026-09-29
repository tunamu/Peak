# Design System

> Status: tokens (F1-01, `PeakDesign/Tokens/`), glass primitives (F1-02, `PeakDesign/Glass/`) and shared components
> (F1-03, `PeakDesign/Components/`) are done.

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
| `text.tertiary` | `.peakTextTertiary` | #67676A | #A8A8AD | #6C6C70 | #48484A | Non-essential text ("Weekly Average"); never tappable |
| `accent.steps` | `.peakSteps` | #FF0004 | #FF453A | #D70015 | | Step ring |
| `accent.water` | `.peakWater` | #00BBFF | | #0077CC | | Water drop, water slider |
| `energy.ready` | `.peakEnergyReady` | #0DFF00 | | #1E9E32 | | |
| `energy.low` | `.peakEnergyLow` | #FFAE00 | | #B86E00 | | |
| `energy.notReady` | `.peakEnergyNotReady` | #FF0000 | #FF453A | #D70015 | | |
| `tint.positive` | `.peakTintPositive` | #00FF1A @ 10% | | #1E9E32 @ 12% | | Add / Update / Finish glass tint |
| `tint.destructive` | `.peakTintDestructive` | #FF0000 @ 10% | | #D70015 @ 12% | | Remove / Reset / Cancel glass tint |
| `brand.flag` | `.peakBrandFlag` | #FE0000 | | #FE0000 | | Logo flag |

## Contrast

`ContrastTests` (in `PeakDesignTests`) enforces, in every appearance, on the canvas **and** on a glass card:

- Text: at least 4.5:1.
- Graphics (rings, icons, bars): at least 3:1.
- The exceptions are dark mode **without** Increase Contrast, where `text.secondary`, `text.tertiary`, `accent.steps`
  and `energy.notReady` keep the design's values.
- `text.secondary` stays stronger than `text.tertiary`.
- Logos are exempt (WCAG 1.4.11).

Worst ratio of each token over the canvas and a glass card (refresh with `swift test --filter contrastReport`):

| Token | Dark | Dark + HC | Light | Light + HC |
| --- | --- | --- | --- | --- |
| `text.primary` | 11.37 | 11.37 | 18.82 | 18.82 |
| `text.secondary` | 2.88 | 5.27 | 5.78 | 10.17 |
| `text.tertiary` | 2.02 | 4.80 | 4.69 | 8.18 |
| `accent.steps` | 2.85 | 3.34 | 4.83 | 4.83 |
| `accent.water` | 5.17 | 5.17 | 4.17 | 4.17 |
| `energy.ready` | 8.30 | 8.30 | 3.14 | 3.14 |
| `energy.low` | 6.12 | 6.12 | 3.57 | 3.57 |
| `energy.notReady` | 2.84 | 3.34 | 4.83 | 4.83 |

The glass card color was measured on the iOS 27 simulator (a `.glassEffect(.regular)` card over the canvas): #3A3A3A in
dark mode and #F8F8FD in light mode (`PeakPalette.glassSurface`). Re-measure if the design's background changes.

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

Glass is used widely, as in the design ([ADR 0013](adr/0013-widespread-glass.md)). Use the primitives in
`PeakDesign/Glass/` instead of calling `.glassEffect` directly:

| Primitive | Looks like | Use |
| --- | --- | --- |
| `.glassCard()` | 20 pt corners, padding 24 × 16 | Steps card, Energy and Water tiles |
| `.glassTable()` | 16 pt corners, padding 8 | Set table container (rows stay plain) |
| `.glassPill()` | Capsule, at least 44 pt tall | Short values ("200ml") |
| `.buttonStyle(.peakGlass)` | 16 pt corners, at least 44 pt tall, tint from the button's role | Start, Reset, Update, Finish Workout |
| `.buttonStyle(.peakGlass(.positive))` | Same, with an explicit tint | Actions whose role says nothing about color (Add) |
| `.buttonStyle(.peakGlassPill)` | Capsule button | "Start Today's Workout" |

Button tint follows `ButtonRole`: `.confirm` → `tint.positive` (green), `.destructive` and `.cancel` →
`tint.destructive` (red), anything else → neutral glass. The role also tells VoiceOver what the button does.

- **Neutral buttons** use the same 16 pt shape as the design, not the system `.glass` style (which draws a capsule).
- **Buttons are at least 44 pt tall.** The design's 30 pt Remove/Add buttons grow to meet the touch-target minimum.
- **Neighbouring glass elements** (Energy + Water, bottom bar, Remove/Add) sit in one `GlassEffectContainer(spacing:)`
  for performance and morphing.
- **Table rows are never glass individually;** only the table container is.
- Cards and tables set their `containerShape`, so a `ConcentricRectangle` inside them follows their corners.
- **Reduce Transparency:** system glass adapts itself; custom fills fall back to an opaque `bg.canvas` tone.
- Scrolling performance is measured with Instruments before release (F10).

## Components

Shared building blocks in `PeakDesign/Components/`. They take their text as `LocalizedStringKey`, so strings written at
the call site in the app are picked up by the app's String Catalog (strings inside the package would not be).

| Component | Design | Notes |
| --- | --- | --- |
| `SectionHeader("Goal Settings", action: .init("New") { … })` | C-07 | `.title2`, marked as a header for VoiceOver. The optional action ("+ New") uses `text.secondary`, not the design's tertiary, because it is tappable |
| `SettingsRow("Daily Step Goal", accessory: .value("10.000")) { … }` | C-08 | Whole row tappable, at least 44 pt (the design draws 20 pt). Accessories: `.value` (tertiary), `.action("Edit")` (secondary), `.icon`, `.none`. All rows use 15 pt `.subheadline`; the design's 13 pt first rows are an inconsistency. Dims when disabled. Use `SettingsRow(verbatim:)` for names the user typed, so they are never looked up as translation keys |
| `ProgressRing(progress: 0.76, tint: .peakSteps)` | C-04 ring | 8 pt stroke on a `fill.control` track; values above 1 draw a full ring. VoiceOver reads a percentage; add `.accessibilityLabel` at the call site |
| `ValuePickerSheet(titles:current:defaultValue:options:format:onSave:)` | S-02, S-03, S-04 | Current value, optional footnote, wheel picker, Reset (saves the default) and Update. Reset is disabled at the default, Update until the value changes |
| `SheetActionBar(cancel:confirm:isConfirmEnabled:…)` | S-05, S-07 | Cancel (red) and Update/Create (green) glass buttons for the bottom of an editing sheet, via `.safeAreaInset(edge: .bottom)` |
| `ResultSheet(.success, title: "Success", message: Text(…)) { buttons }` | S-09 | 52 pt checkmark or cross (scales with Dynamic Type), success or error haptic, context actions |
| `.fittedSheet()` | D-14 | Sizes a sheet to its content instead of a fixed detent, so it grows with Dynamic Type; very tall content scrolls. Shows the drag indicator |

Known limit: the system wheel picker does not scale its rows with Dynamic Type; the labels around it do.

## Showcase

`DesignShowcase` (debug builds only) shows every token, primitive and component with sample content from the design,
with previews in dark, light and Dynamic Type XXXL. In the app it is the Component Gallery: Settings › Developer ›
Component Gallery. Launch arguments for screenshots are listed in [DEVELOPMENT.md](DEVELOPMENT.md).

## Icons

SF Symbols; active states use `.fill`. Exception: the tab bar. iOS 26 draws every tab symbol filled and marks the
selected tab with its glass pill and tint (white in dark mode, black in light, like the design). Filling only the
selected symbol was tried; the tab bar ignores the override on the first render, so the system behavior is kept.

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

**App icon:** a mountain with a red flag on #2E2E2E, in `Peak/Resources/AppIcon.icon` (Icon Composer format). Two layers
(`mountain.svg` white, `flag.svg` #FE0000) so each gets its own Liquid Glass treatment; the system derives the Dark,
Clear and Tinted appearances from them. The artwork is the design's Hugeicons "mountain" (mirrored) and "flag-01"
(MIT, see THIRD_PARTY_NOTICES). SF Symbols are not allowed in app icons by their license.

Icon Composer ships inside Xcode and is the default app for `.icon` files: double-click `AppIcon.icon` in Finder, or
run `open Peak/Resources/AppIcon.icon`. To render a preview from the command line:

```bash
"/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool" \
  Peak/Resources/AppIcon.icon --export-image --output-file icon.png \
  --platform iOS --rendition Default --width 1024 --height 1024 --scale 1
```

Renditions: `Default`, `Dark`, `ClearLight`, `ClearDark`, `TintedLight`, `TintedDark` (tinted also takes
`--tint-color` and `--tint-strength`).
