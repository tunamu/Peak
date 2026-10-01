# 0021. Local reminders on workout days

- **Status:** Accepted
- **Date:** 2026-10-01

## Context

The author wants a nudge on workout days: in the morning, "today's workout, ready?", and, when a routine asks for
it, a second "time to train" at the hour they usually go. Peak has no server and collects nothing (V-03), and the
day's workout follows the routine's rotation, which moves with what was actually done.

## Decision

- **Local notifications only** (`UNUserNotificationCenter`). Nothing leaves the device and no push is involved.
- **Morning reminder:** on every day with a planned workout, at a time set in Settings › Reminders (09:00 by default),
  naming the day's workouts. On until turned off; nothing is sent before notifications are allowed. Onboarding has a
  Reminders step (Turn On asks for permission; Not Now turns it off), skipped once iOS has an answer.
- **Routine reminder:** a routine can add its own reminder at its own time (Set Routine › Reminder), on that
  routine's workout days, naming its workout.
- **No reminder** on a day whose planned workouts are done, or today while a workout is running.
- **Planning:** `ReminderPlanner` (PeakCore, pure, tested) turns the routines, the history and the reminder times into
  dated reminders for the next 14 days, at most 60 (iOS keeps 64 pending). The app replaces Peak's pending reminders
  with them at launch, on coming back, after every save (debounced) and when a reminder setting changes, since a
  finished or skipped workout moves the rotation.
- **Where the times live:** both the morning reminder and the routines' reminder times are settings of the device
  (`UserDefaults`), like iCloud Sync (D-18). Reminders are something this phone does, as alarms are. Keeping the
  routine's time out of the `Routine` model also leaves the stored schema unchanged: no `SchemaV2`, no migration of
  the author's data, no CloudKit schema change (D-29, revised from the plan's SchemaV2).
- A tap opens Home (`peak://home`), where today's workout waits; the "Start anyway?" check still applies there.

## Consequences

- If Peak is not opened for two weeks the reminders run out; opening it plans the next two weeks again.
- A reminder names the workout the rotation expects; if the day's workout changes later (a workout done early), the
  next launch or save corrects the pending ones.
- Routine reminder times are not in Peak JSON exports or iCloud; after a reinstall they are set again.
