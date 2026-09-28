# Changelog

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
