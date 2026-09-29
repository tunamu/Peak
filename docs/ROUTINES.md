# Routines

> Status: implemented (F3) as `RoutineScheduler` in `Packages/PeakKit/Sources/PeakCore/Engines/`. It works on value
> types (`RoutineSnapshot`, `WorkoutRecord`), not on SwiftData models.

```swift
let plan = RoutineScheduler(calendar: .current).plan(
    routines: routines, history: completedSessions, days: scheduler.week(containing: .now), today: .now)
// [day: [PlannedWorkout(templateID:, routineID:, status: .completed | .planned)]]
```

## Schedule types

| Type | A day is a workout day when… |
| --- | --- |
| Weekdays | the day is in the routine's `weekdaysMask` (bit 0 = Monday … bit 6 = Sunday) |
| Interval | last session day + `intervalDays` ≤ day. With no sessions yet, `startDate` is the first workout day. N = 1 is every day, N = 2 every other day. An overdue workout lands on today, not on every missed day |

## Which template

- The next template is the entry after the template of this routine's last completed session. With no sessions, it is
  the first entry.
- **A missed day does not skip a workout.** The rotation only moves when a session is completed.
- The rotation cursor is derived from session history, never stored (no sync conflicts).
- Archived templates are skipped. If the last done template was archived, the rotation still moves on from its place.

## Several routines on one day

- Several routines can be active at once ([ADR 0015](adr/0015-multiple-active-routines.md)). All of them are listed,
  ordered by `sortIndex`.
- The main Start button targets the first unfinished workout.
- A workout completed today shows as "Completed", and that routine is not planned again today.

## Future days (week strip)

From today on, every planned day moves the rotation one step and is marked "planned". Days before today show only
what was done. The Home week strip shows pages of seven days starting the day before today, so today is always the
second day (V-06, as in the design); `RoutineScheduler.week(containing:)` still gives a calendar week for other uses.

## On the Home screen

`DayPlanner` (`PeakCore/Home/`) turns stored routines and sessions into `RoutineScheduler` input and back into cards:
completed sessions first, then the running one (today only), then planned workouts in routine order. A running session
replaces its routine's planned workout. With nothing on a day from today on, it looks four weeks ahead for the next
workout day. Several workouts on one day stack as separate cards, each labelled with its routine; only one session
runs at a time, so while one runs the others' Start is disabled.

## Tests

`RoutineSchedulerTests` covers: the six-template Monday/Wednesday/Friday rotation (from the real log on 29.09.2026 it
plans Wednesday Back & Triceps, Friday Shoulder & Biceps and Monday Chest & Triceps, the same as the `/coach` skill),
wrap-around, a missed day, a workout done today, archived templates, interval schedules (every other day, overdue),
several routines on one day, inactive routines and the week's first day. `DayPlannerTests` covers the Home side:
rotation on scheduled days, rest days with the next date, past days, a running session, completed today, two routines
on one day, week underlines, the energy input and template counts.
