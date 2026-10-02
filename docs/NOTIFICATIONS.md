# Notifications

> Status: F11-07, F11-08. Decision record: [ADR 0021](adr/0021-local-reminders.md).

Peak only sends local notifications, scheduled on the device. Nothing goes to a server.

## Reminders

| Reminder | When | Text (English / Turkish) | Set in |
| --- | --- | --- | --- |
| Morning | Every day with a planned workout, at the morning time (09:00 by default) | Workout Day · "Today: Chest & Biceps. Ready?" / Antrenman Günü · "Bugün: Göğüs & Biceps. Hazır mısın?" | Settings › Reminders (on by default) |
| Routine | The routine's workout days, at its own time | Time to Train · "Chest & Biceps is waiting for you." / Spor Zamanı · "Göğüs & Biceps seni bekliyor." | Set Routine › Reminder (off by default) |

No reminder is sent for a day whose planned workouts are done, or today while a workout runs. A tap opens Home.

## Planning

`ReminderPlanner` (PeakCore) takes the routines, the completed sessions and the reminder times, asks
`RoutineScheduler` for the next 14 days, and returns dated reminders with stable identifiers
(`peak.reminder.morning.2026-10-02`, `peak.reminder.routine.<routine>.2026-10-02`), sorted, at most 60.

`Reminders` (the app) removes every pending `peak.reminder.*` request and adds the planned ones:

- at launch and whenever the app becomes active;
- after every save to the store, a second after the last one (a workout's sets save often);
- when the morning reminder is turned on or off, its time changes, or a routine's reminder changes.

The reminder times are device settings in `UserDefaults` (`reminders.morningOn`, `reminders.morningMinutes`,
`reminders.routineMinutes`), not part of the store, exports or iCloud.

## Permission

Onboarding's Reminders step asks (Turn On) or turns the morning reminder off (Not Now); it is skipped once iOS has an
answer. Turning on a reminder in Settings or in a routine asks if iOS has not been asked yet. When notifications are
off in the Settings app, Settings › Reminders says so and links there.

## Testing

- `ReminderPlannerTests`: workout days and their names, today before and after its time, a running workout, a day
  already done, routine times, the 60 limit, inactive routines.
- `ReminderTests` (UI): allows notifications through onboarding, sends a test reminder with `-PeakReminderNow YES`
  (five seconds later, under an identifier planning does not remove), checks the banner's text, and taps it open.
