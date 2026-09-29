# Progressive Overload

> Status: skeleton. Implemented as `ProgressionEngine` in F3; this file is updated with the code.

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
- **lb mode:** targets are computed in kg and shown rounded to 0.5 lb. An increment entered in lb is converted to kg.

## Success (for statistics)

- A set succeeds when `reps ≥ targetReps` and `weight ≥ targetWeight`.
- An exercise succeeds when all of its sets succeed.
- Session success rate = successful exercises / all exercises.

## Test fixtures (real training data)

| Last session | Increment | Next target |
| --- | --- | --- |
| 50×17 | 5 | 55×6 |
| 27.5×9 | — (not used) | 27.5×9 |
| 45×12 | — (not used) | 45×12 |
| 65×14, 65×13, 60×15 | 5 | 70×6, 70×6, 65×6 |
| 27.5×9, 22.5×13 | 2.5 | 27.5×9, 25×6 |
