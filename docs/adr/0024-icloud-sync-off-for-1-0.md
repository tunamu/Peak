# 0024. iCloud Sync not offered in 1.0

- **Status:** Accepted
- **Date:** 2026-10-02

## Context

iCloud Sync (F8, opt-in since D-18) is built and its status row works, but the two-device check never ran: the
maintainer's iCloud storage is full, so every upload fails with a quota error, and no other account was at hand.
Shipping it also means deploying the CloudKit schema to production, which cannot be taken back (record types and
fields can only be added afterwards). Untested sync that can duplicate or lose workouts is worse than none.

## Decision

- 1.0 ships without iCloud Sync. One flag, `AppData.isSyncAvailable`, is `false`: Settings › General hides the switch
  and status rows, onboarding skips its iCloud step, and the store never opens with CloudKit, whatever an earlier
  build saved as the preference.
- Everything stays in place: the CloudKit and key-value entitlements, `SyncMonitor`, `Deduplicator`, the settings
  mirror, the strings and their tests. The schema stays CloudKit-compatible (DATA_MODEL rules).
- Debug builds can turn it on with `-PeakICloudSync YES`, so the two-device check (F8-03) needs no code change.

## Turning it on later (1.1)

1. Run the two-device scenarios in TESTING.md with an iCloud account that has room (debug build, `-PeakICloudSync YES`).
2. Settings › Developer › Initialize CloudKit Schema, then deploy the schema to production in CloudKit Console.
3. Make `isSyncAvailable` return `true`; update the privacy policy, README and CHANGELOG.

## Consequences

- Data stays on the device; backups are the Export file. The privacy policy says so.
- The entitlements remain in 1.0. They grant access, not use; nothing reaches iCloud while the flag is off.
