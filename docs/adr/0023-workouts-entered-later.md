# 0023. Workouts entered after the fact

- **Status:** Accepted
- **Date:** 2026-10-02

## Context

A workout done without starting it in Peak (the phone left in the locker, a forgotten start) had no way in: past days
on Home and in History could only be looked at, and a finished workout could not be removed. The author asked for both
past days and today, with the same set tables as a live workout.

## Decision

- **Where:** Home on a past day and History on a picked day up to today show **Log Workout**. On today Home's
  "Start Another Workout" becomes **Add Workout** with **Start Now** and **Log Finished**; a planned card's long press
  adds **Log as Finished**. Never on future days.
- **What it offers:** each active routine's next workout as the rotation stood before that day, saved with its routine
  so the rotation moves on ("Push Day · Main Routine"); then every workout on its own, which leaves the rotation alone
  (as F6-07's Start Another Workout).
- **The sheet:** the workout sheet with its tables, notes and Complete Movement, without the timer, pausing, the Live
  Activity or "Start anyway?". The bottom bar shows the start time (tap: start and length, `LogTimeSheet`) and Save
  Workout; Cancel throws it away, asking first when anything was entered. Saving shows the summary and writes the
  workout to Apple Health, like finishing a live one.
- **Time:** the workout's last start time and length, else 18:00 for an hour (`ManualLogPlan`, rounded to 5 minutes).
  It may not end after now; on today it ends now by default.
- **Data:** a new `SessionStatus.logging` while it is entered; no schema change (`statusRaw` is a string). It is not
  running (`current()` asks for active or paused only), not in the history, and not exported. `endedAt` holds the
  planned end; saving makes it `completed` and dates its sets at the end. Left half entered, it opens again on the next
  launch, as a running workout survives being killed.
- **Targets:** come from the performance before the workout's own date, so a past entry follows what was done before
  it; live workouts are unchanged (their date is now).
- **Deleting:** a finished workout's sheet has **Delete Workout** (asked first). Its Health workout is deleted too,
  best effort; Peak deletes it either way.
- Editing a finished workout is left for later (v1.1).

## Consequences

- One sheet serves both, so the tables and their tests stay single.
- With iCloud Sync on, a workout half entered on one device opens on the other's next launch too, like a running one.
- Health's Exercise minutes count an entered workout at the time given, which is approximate.
