# Energy Level

> Status: implemented (F3) as `EnergyEngine` in `Packages/PeakKit/Sources/PeakCore/Engines/`; the thresholds live in
> `EnergyConfig`.

Energy Level is an estimate to help plan training. **It is not medical advice**, and the detail sheet says so.

## Score

The score runs from 0 to 100 and starts at 100. Each component applies only when its data exists
([ADR 0003](adr/0003-hybrid-energy-level.md)).

| Data level | Component | Rule |
| --- | --- | --- |
| A (everyone) | Time since last strength workout | < 24 h: −30 · 24–48 h: −10 |
| A | Today's planned muscle group trained in the last 48 h | yes: −25 |
| A | Consecutive training days | ≥ 3: −20 |
| B (sleep data) | Last night's sleep | < 5 h: −30 · 5–6.5 h: −15 |
| C (Apple Watch, ≥ 5-day baseline) | HRV (SDNN) vs. 7-day average | below −15%: −25 · −5% to −15%: −10 |
| C | Resting heart rate vs. 7-day average | more than +5 bpm: −15 |

Exact boundaries (each has a test):

- Last workout: under 24 h → −30; from 24 h up to (not including) 48 h → −10.
- Same muscles: any of today's planned muscle groups (not "other" or "cardio") in a workout that ended under 48 h ago.
- Streak: consecutive calendar days with a workout, counted back from today, or from yesterday when today has none.
- Sleep: under 5 h → −30; from 5 h up to (not including) 6.5 h → −15.
- HRV: change = (today − average) / average; below −15% → −25; from −15% up to (not including) −5% → −10.
- Baseline: the average of the last seven values, used only when there are at least five.
- The score never goes below 0.

Example: last workout 30 h ago on chest, chest planned today, 5 h 40 min of sleep → 100 − 10 − 25 − 15 = **50, Low**.

## Levels

| Score | Level | Message |
| --- | --- | --- |
| ≥ 70 | Ready | You can workout now |
| 40–69 | Low | You can workout a bit |
| < 40 | Not Ready | You can't workout now. You should rest at least 1 day to workout again. |

## Output

`level`, `score`, `reasons` and `sources` (which data was used). Reasons are values, not sentences
(`.lastWorkout(hoursAgo: 18)`, `.sleep(duration:)`, …) with their points; the detail sheet turns them into localized
text such as "Last workout 18 hours ago".

Starting a workout while Not Ready shows a soft "Start anyway?" alert. It never blocks.
