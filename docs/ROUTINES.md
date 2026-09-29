# Routines

> Status: skeleton. Implemented as `RoutineScheduler` in F3; this file is updated with the code.

## Schedule types

| Type | A day is a workout day when… |
| --- | --- |
| Weekdays | the day is in the routine's `weekdaysMask` (bit 0 = Monday … bit 6 = Sunday) |
| Interval | last session date + `intervalDays` ≤ day. With no sessions yet, `startDate` is the reference. N = 1 is every day, N = 2 every other day |

## Which template

- The next template is the entry after the template of this routine's last completed session. With no sessions, it is
  the first entry.
- **A missed day does not skip a workout.** The rotation only moves when a session is completed.
- The rotation cursor is derived from session history, never stored (no sync conflicts).

## Several routines on one day

- Several routines can be active at once ([ADR 0015](adr/0015-multiple-active-routines.md)). All of them are listed,
  ordered by `sortIndex`.
- The main Start button targets the first unfinished workout.
- A workout completed today shows as "Completed".

## Future days (week strip)

From today on, every planned day moves the rotation one step and is marked "planned".

## Tests

Six-template Monday/Wednesday/Friday rotation · missed day · interval schedule · multiple routines · a template archived
in the middle of a rotation.
