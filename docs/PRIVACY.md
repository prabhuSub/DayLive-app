# Hyperday — Privacy

_Last updated: 2026-09-28 · applies to Hyperday v0.1 (pre-release)_

Hyperday is designed so that your day stays on your iPhone.

## What Hyperday accesses

| Data | Why | Where it goes |
|---|---|---|
| **Calendar events** (with your permission: Full Access) | To show your events in Today, Calendar, Stats and the Live Activity, and to apply your color/category rules | Read on-device only. Never uploaded, never modified. |
| **Blocks, steps, categories, rules, colors** you create | The app's core features | Stored in the app's private container on your iPhone |
| **Daily history** (which blocks happened, steps checked) | Stats and streaks | Stored in the app's private container on your iPhone |

## What Hyperday does not do

- No accounts or sign-in.
- No network requests, servers or cloud sync (yet).
- No analytics, crash reporting or tracking SDKs.
- No advertising.
- Hyperday never creates, edits or deletes events in your calendars.

## Live Activities and Siri

- The Lock Screen card is rendered by iOS from data the app provides on-device.
- "Add a block in Hyperday" runs through Siri/App Intents. Speech handling is done by Apple under Apple's privacy policy; Hyperday only receives the block's title, length and start time.

## Your control

- Revoke calendar access at any time: **Settings › Privacy & Security › Calendars › Hyperday**.
- Remove sample data: **Hyperday › Settings › Remove sample data**.
- Delete everything by deleting the app.

## Future changes

If a future version adds sync or push notifications (for example, on-time switching of the Live Activity), this document will be updated **before** that version ships, describing exactly what leaves the device and why.

Contact: open an issue on the GitHub repository.
