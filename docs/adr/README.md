# Architecture Decision Records

Each file records one decision: the context, what was decided and what follows from it. A decision is never
edited away. If it changes, a new ADR supersedes it and the old one is marked **Superseded by NNNN**.

| ADR | Decision |
| --- | --- |
| [0001](0001-swiftui-ios26-xcode27.md) | SwiftUI native app, iOS 26.0 deployment target, Xcode 27 |
| [0002](0002-swiftdata-cloudkit.md) | SwiftData with CloudKit private database for sync |
| [0003](0003-hybrid-energy-level.md) | Hybrid Energy Level: rule-based recovery plus HealthKit signals |
| [0004](0004-tabs-home-settings-analysis.md) | Tabs: Home and Settings active, Analysis as a placeholder |
| [0005](0005-single-import-flow.md) | Single import flow for JSON, XLSX and CSV/TSV |
| [0006](0006-note-format-conversion-out-of-scope.md) | Converting personal note formats is out of scope |
| [0007](0007-v1-scope.md) | v1 includes widgets, Live Activity, HealthKit workouts and iCloud sync |
| [0008](0008-dark-and-light-theme.md) | Dark and light themes that follow the system |
| [0009](0009-mit-license.md) | MIT license |
| [0010](0010-english-docs-en-tr-ui.md) | English repository docs, English and Turkish UI |
| [0011](0011-drag-to-reorder-sets.md) | Drag handle on set rows reorders sets |
| [0012](0012-walking-cardio-model.md) | Walking cardio: duration from start and finish, speed and incline per session |
| [0013](0013-widespread-glass.md) | Liquid Glass used widely, as in the design |
| [0014](0014-native-sheets.md) | Large cards in the design are native sheets |
| [0015](0015-multiple-active-routines.md) | Multiple routines can be active at the same time |
| [0016](0016-week-strip-selected-day.md) | The week strip shows the selected day |
| [0017](0017-color-tokens-and-contrast.md) | Color tokens in code, design grays with an Increase Contrast fallback |

## Open assumptions

Working assumptions that have not been confirmed yet. Each becomes an ADR once confirmed.

| ID | Assumption |
| --- | --- |
| V-01 | Icons are SF Symbols; active states use the `.fill` variant (except the tab bar, where iOS fills every symbol; see DESIGN_SYSTEM › Icons) |
| V-02 | Weight defaults to kg with an lb option; data is always stored in kg. Water is stored in ml |
| V-03 | The app is free, with no ads, no analytics and no third-party SDKs |
| V-04 | Design hex values are the dark variants; light variants are derived to pass WCAG AA |
| V-05 | iPhone only in v1 (no iPad layout) |
| V-06 | The week strip follows the locale's first weekday, opens on today, and swipes to the previous or next week |
