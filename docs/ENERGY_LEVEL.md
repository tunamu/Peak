# Energy Level

> Status: skeleton. Implemented as `EnergyEngine` in F3; thresholds live in `EnergyConfig` and this file is updated
> with the code.

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

## Levels

| Score | Level | Message |
| --- | --- | --- |
| ≥ 70 | Ready | You can workout now |
| 40–69 | Low | You can workout a bit |
| < 40 | Not Ready | You can't workout now. You should rest at least 1 day to workout again. |

## Output

`level`, `score`, `reasons` (shown in the detail sheet, e.g. "Last workout 18 hours ago") and `sources` (which data was
used).

Starting a workout while Not Ready shows a soft "Start anyway?" alert. It never blocks.
