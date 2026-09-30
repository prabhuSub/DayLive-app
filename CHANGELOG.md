# Changelog

## Unreleased

### Added
- **Widgets:** Home Screen small / medium / large and StandBy (small).
- **Lock Screen widgets:** Now (rectangular), Day strip (rectangular), and a configurable Circle (time left / steps / next start / blocks left).
- **Apple Watch:** a Smart Stack card for the Live Activity with the time left, next, the bar and the Step / Done button.
- **Siri & Shortcuts:** "What's next", "Start my day", "I'm done" and "Start Deep Work" (90 min).
- **Focus filter:** show everything, only work, only personal, or nothing while a Focus is on.
- **Week view drag:** long-press to move a planned block (15-minute snap, across days), pull the bottom handle to resize.
- **Weekly recap:** a Sunday 7 PM notification that opens a full-screen card you can share or save to Photos.

- **Start timer:** tap Start (swipe right on a block, the editor, or "Start now" on the Lock Screen in free time) and the countdown runs from that moment for the block's length, then shows **+overtime** until Done.
- **Free time:** one bar that fills up until your next block, with "1:40:05 until Standup".
- **Date before time** when adding or editing (Today / Tomorrow / Pick date), and **Move to tomorrow** (editor or swipe left).
- **Multiple categories per block.** The first one sets the color; Stats split the time evenly.

### Changed
- Done and Step buttons are always yellow.
- Only one Hyperday Live Activity at a time; older cards are cleared.
- Minimum iOS is now **18**.
- `deploy.sh` signs with an App Group and falls back without it on a free Apple ID.

## 0.1.0 — 2026-09-28 (pre-release)

### Added
- **Live Activity** for the day on the Lock Screen and in the Dynamic Island. It shows:
  - the current block, a live countdown and what's next
  - an "also:" line for overlaps
  - a segmented bar
  - Step / Done / Start next buttons
- **Checklist steps** per block. They drive the bar, and a yellow **Step n/N** button checks the next one.
- **Today** tab: heading, Focused / Steps / Meetings left, Add block, Go Live, timeline, and a LIVE NOW pill that opens the live block.
- **Calendar** tab: every calendar on the device plus your tasks, in Agenda / Week / Month views. Tap a date to jump to it; tap it again to go back to today.
- **Stats** tab: Week / Month / Year, focused hours, steps, streak, hours by category, meeting load, and blocks done / ended early / missed.
- **Categories**: auto rules (first match wins), manual override, editable colors. **Calendar colors**, with Tesla calendars defaulting to red.
- **Sample data** for previewing (8 weeks + a planned day).
- **Light / Dark / System** appearance and a native Liquid Glass tab bar (iOS 26+).
- **Siri / Shortcuts**: "Add a block in Hyperday".
- App icon (default, dark, tinted).
- `deploy.sh`: one command to build and install. It auto-detects the signing team.
