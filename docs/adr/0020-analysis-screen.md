# 0020. The Analysis screen: Performance and History pages

- **Status:** Accepted
- **Date:** 2026-10-01

## Context

The Analysis tab has been a placeholder since F1-04. The author decided to build it before the App Store release
(F11) rather than after it, so v1 does not ship an empty tab. It should answer two questions: am I getting stronger,
and what did I do. The design file has no Analysis screen, so its layout follows the screens already built.

## Decision

- **Two pages**, Performance and History, under a segmented control at the top. The pages also swipe left and right
  (a paging horizontal scroll view kept in step with the control). Nothing inside a page scrolls sideways, so the two
  gestures never compete: charts take a period picker instead of a horizontal scroll.
- **Performance** looks at a period (4 weeks, 3 months, 6 months, 1 year, all time):
  - totals with their change against the period before: sessions, volume, done sets, target success;
  - weekly volume and sessions, and the run of weeks in a row with a workout;
  - muscle group balance, counted in **done sets** rather than volume, since a leg day's kilograms cannot be weighed
    against a biceps day's;
  - every movement with a **trend arrow** beside its name, and every workout template, each opening a detail chart.
- **Trend arrow:** a movement follows its best set's estimated one-rep max (Epley, w × (1 + r / 30); the reps for a
  bodyweight movement; the distance, or else the minutes, for a walk). The last session is compared with the average
  of up to three sessions before it: more than 2% higher is a green arrow up, more than 2% lower a red arrow down,
  anything between a grey dash. Under two sessions there is no arrow. The arrow is a shape as well as a color, and
  VoiceOver reads it as words.
- **History** lists every completed session, newest first, under a **month calendar** whose days with a workout carry
  a dot. Tapping a day narrows the list to it. The month changes with arrow buttons, not by swiping, to leave the
  swipe to the pages. A session opens in the read-only workout view Home already uses.
- **Muscle groups from names:** spreadsheet imports leave every exercise's group as Other, so the analysis guesses
  one from the name ("Lat Pulldown" → back) when the stored group is Other. A group set in Settings always wins.
- The numbers come from `PerformanceAnalysis` in PeakCore: pure functions over `AnalysisSession` values, tested with
  the author's real history. Nothing is stored; every figure is computed from the completed sessions when the screen
  opens.

## Consequences

- No schema change and no migration: the screen reads what is already stored.
- An estimated one-rep max is only an estimate; it rewards both heavier sets and more reps, which is what the
  progression rule asks for, but it is labeled as an estimate.
- A movement that changes from bodyweight to weighted switches what its chart follows.
- Computing on open is fine for years of sessions (the author's 22 sessions take well under a millisecond); if it ever
  is not, the per-movement series can be cached without changing the screen.
