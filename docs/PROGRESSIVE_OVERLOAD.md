# Progressive Overload

> Status: implemented (F3) as `ProgressionEngine` and `SessionStatistics` in `Packages/PeakKit/Sources/PeakCore/Engines/`.
> The rule is the same as the `/coach` skill that produced the author's training log.

```swift
let targets = ProgressionEngine.targets(
    after: [SetPerformance(weightKg: 27.5, reps: 9), SetPerformance(weightKg: 22.5, reps: 13)],
    setCount: 2, incrementKg: 2.5, rule: ProgressionRule(thresholdReps: 12, resetReps: 6))
// [27.5×9, 25×6]
```

## Inputs

- The sets of the exercise's last completed session
- The exercise's `incrementKg`
- Threshold `T` (default 12) and reset reps `R` (default 6), both configurable in Settings

## Rules

Each set is evaluated on its own:

| Last result | Next target |
| --- | --- |
| `reps > T` | `(weight + increment) × R` |
| `reps ≤ T` | `weight × reps` (at least the same again) |

- **Set count:** if today's template asks for more sets, extra sets copy the last set's target; if fewer, the rest are
  dropped.
- **No forward projection:** future planned sessions show today's target.
- **No history:** the target is empty and the Reference column shows "—".
- **Unfinished sets** (0 reps) in the last session are ignored.
- **lb mode:** targets are computed in kg and shown rounded to 0.5 lb. An increment entered in lb is converted to kg.

## Success (for statistics)

- A set succeeds when `reps ≥ targetReps` and `weight ≥ targetWeight`.
- An exercise succeeds when all of its planned sets succeed; a missing set fails it.
- An exercise without targets (first time) succeeds when any set was done: it sets the baseline.
- A cardio exercise succeeds when it is marked done.
- Session success rate = successful exercises / all exercises.
- Completion = done sets / all sets; a cardio exercise is one unit. Volume = Σ weight × reps of strength sets.

## Test fixtures (real training data)

`ProgressionEngineTests` reproduces all 13 "next targets" of the `/coach` program after 28.09.2026, for example:

| Last session | Increment | Next target |
| --- | --- | --- |
| 50×17 | 5 | 55×6 |
| 27.5×9 | 2.5 | 27.5×9 |
| 45×12 | 5 | 45×12 |
| 65×14, 65×13, 60×15 | 5 | 70×6, 70×6, 65×6 |
| 27.5×9, 22.5×13 | 2.5 | 27.5×9, 25×6 |

`SessionStatisticsTests` replays the six logged sessions after the 12-rep rule started (14.09.2026), taking each
target from the exercise's previous session. Four match the log's success rate. Two do not, because the log miscounted
them against its own rule; the tests follow the rule:

| Session | Log | Rule | Why |
| --- | --- | --- | --- |
| 18.09 Shoulder & Biceps | 60% | 80% | Lateral Raise set 2: target 15×6 (12.5×14 went above 12), done 15×8 |
| 23.09 Back & Biceps | 60% | 80% | Goblet Curl set 2: target 22.5×6 (20×15 went above 12), done 22.5×8 |
