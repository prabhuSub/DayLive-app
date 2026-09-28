# DayLive — v1

Your day as a Live Activity: the current block, "also:" for overlaps, what's next, a segmented day bar, and a Done / Start next button. Blocks come from iOS Calendar plus the ones you add in the app or by Siri.

## Run it on your iPhone (free Apple ID works)

1. Install **Xcode** from the Mac App Store and open it once.
2. Install XcodeGen: `brew install xcodegen`.
3. In Terminal:
   ```
   cd DayLive
   xcodegen generate
   open DayLive.xcodeproj
   ```
4. Click the **DayLive** project → target **DayLive** → *Signing & Capabilities* → Team: your Apple ID ("Personal Team"). Do the same for target **DayLiveWidget**.
   - If Xcode says the bundle ID is taken, change `com.prabhu` in `project.yml` (e.g. `com.prabhus165`) and run `xcodegen generate` again.
5. Plug in your iPhone. On the phone, turn on *Settings › Privacy & Security › Developer Mode* and restart.
6. Pick your iPhone as the run destination and press ▶︎.
7. First time only: on the iPhone, go to *Settings › General › VPN & Device Management* and trust your developer certificate.
8. When the app opens, allow **Full Access** to calendars. The Live Activity starts on its own. Lock the phone to see it.

A free account's install stops working after **7 days**. Press ▶︎ again to reinstall; your data stays.

## What to test first

- [ ] The card fits on the Lock Screen with the "also:" line showing. Create two overlapping events to check.
- [ ] Tesla calendar events appear. If they don't, check that the calendar is turned on in the iOS Calendar app.
- [ ] Tap **Done** on the Lock Screen: the bar fills and the card moves on.
- [ ] Say "Hey Siri, add a block in DayLive".
- [ ] Long-press the Dynamic Island to see the expanded view.

## Known v1 limits (on purpose)

- **Switching at a block's start time is best-effort.** Without push, the card updates when you open the app, tap Done, add a block, or when iOS runs a background refresh (which can come late). If it's out of date, the card says "Out of date · tap to refresh". **v1.1 fixes this** with the $99 account plus pushes from the Raspberry Pi.
- About every 7.5 hours the Live Activity restarts, but only while the app is open. iOS ends it at about 8 hours.
- Only today's blocks. You can't edit a block yet (delete it and add it again). Events marked "Free" and all-day events are skipped.
- No drag-to-draw timeline yet (planned for v1.1).

## Files

| Folder | What |
|---|---|
| `Shared/` | The Live Activity data (`DayActivityAttributes`), the Done button intent, and the card views. Used by both targets. |
| `Widget/` | The Lock Screen and Dynamic Island layouts. |
| `App/Model/` | `DayEngine` (overlaps, what's next, bar segments), `BlockStore` (your blocks, saved as JSON), `CalendarService` (EventKit). |
| `App/LiveActivity/` | Start, update and restart the activity, plus background refresh. |
| `App/Views/`, `App/Intents/` | The Today list, the quick-add sheet, and the Siri "Add Block" command. |
