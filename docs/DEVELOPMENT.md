# Hyperday — Development

Everything you need to build Hyperday from source. For how the code fits together, see [ARCHITECTURE.md](ARCHITECTURE.md).

## Requirements

| | |
|---|---|
| Device | iPhone with iOS 17 or later (Dynamic Island on iPhone 14 Pro and later; Liquid Glass on iOS 26+) |
| Mac | macOS with **Xcode 26 or later** (the Liquid Glass APIs need the iOS 26 SDK) |
| Tools | [Homebrew](https://brew.sh), [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) |
| Apple account | A free Apple ID works for personal installs (they expire after 7 days). Push updates, TestFlight and the App Store need the [Apple Developer Program](https://developer.apple.com/programs/). |

## Build and run

### One command
```bash
git clone https://github.com/prabhuSub/DayLive-app.git
cd DayLive-app
./deploy.sh
```
`deploy.sh` does the following:
1. Finds your signing team from your Apple Development certificate and saves it in `.team`, which is not committed.
2. Generates the Xcode project from `project.yml`.
3. Builds the app for iOS.
4. Installs and launches it on your connected iPhone (cable, or the same Wi-Fi after one cabled run).

If it can't find your team, run `DEVELOPMENT_TEAM=ABCDE12345 ./deploy.sh`.

### With Xcode
```bash
DEVELOPMENT_TEAM=ABCDE12345 xcodegen generate
open DayLive.xcodeproj
```
Select your iPhone and press ▶︎. The first time, trust the developer profile on the phone: **Settings › General › VPN & Device Management**, and turn on **Developer Mode**.

> The `.xcodeproj` is generated and git-ignored. Edit `project.yml`, not the project file.

### First launch
1. Allow **Full Access** to calendars.
2. Tap **Add block**, or go to **Settings › Load sample data** to explore.
3. Tap **Go Live**, then lock the phone.

## Project structure

```
DayLive/
├── project.yml                  # XcodeGen spec (targets, Info.plist keys, signing)
├── deploy.sh                    # build + install on iPhone
├── App/                         # iOS app target
│   ├── DayLiveApp.swift         # entry point, environment, background refresh
│   ├── Assets.xcassets          # app icon (default/dark/tinted), HyperdayMark
│   ├── Model/
│   │   ├── Block.swift          # Block, Step, BlockOverride
│   │   ├── BlockStore.swift     # planned blocks, steps, overrides, category overrides
│   │   ├── CalendarService.swift# EventKit reads, calendar list
│   │   ├── Category.swift       # categories, rules, calendar colors
│   │   ├── DayEngine.swift      # pure day logic -> Live Activity state
│   │   └── HistoryStore.swift   # daily history, stats, sample data
│   ├── LiveActivity/
│   │   └── LiveActivityManager.swift  # start/update/restart, background refresh
│   ├── Intents/
│   │   └── AddBlockIntent.swift # Siri / Shortcuts
│   └── Views/                   # Today, Calendar, Stats, Settings, sheets, components
├── Shared/                      # compiled into both targets
│   ├── DayActivityAttributes.swift   # Live Activity data contract
│   ├── BlockActionIntent.swift       # Step / Done / Start next button
│   └── LiveActivityViews.swift       # Lock Screen card + pieces
├── Widget/                      # Widget extension (Live Activity UI)
│   ├── DayLiveWidget.swift
│   └── Assets.xcassets          # HyperdayMark icon for the card
└── docs/                        # privacy, architecture, images
```

> Code, targets and bundle IDs still use the original working name **DayLive**; the product name is **Hyperday**.

## Architecture

See [ARCHITECTURE.md](ARCHITECTURE.md). In short:
- **SwiftUI + ObservableObject stores** (`BlockStore`, `CategoryStore`, `HistoryStore`, `LiveActivityManager`), all on the main actor, persisted as JSON.
- **No App Group needed.** The widget only renders `ContentState`, and `LiveActivityIntent`s run in the app process.
- **`DayEngine` is pure**, so it can be unit tested without a device.

## Configuration and data

| File (app Documents) | Contents |
|---|---|
| `daylive-store.json` | planned blocks, steps, Done/Start-next overrides, category overrides |
| `daylive-categories.json` | categories, rules, fallback, calendar colors |
| `daylive-history.json` | one record per day, used by Stats |

Settings stored in `UserDefaults`: `appearance`, `autoStartActivity`, `activityStartedAt`.

## Known limitations

- **Switching at block times is best-effort.** Without push notifications, the card updates when you open the app, tap a button, or when iOS runs a background refresh (which can come late). If it's behind, it shows "Out of date · tap to refresh". This will be fixed by on-time pushes (see the roadmap).
- Live Activities last about 8 hours. Hyperday restarts the activity only while the app is open.
- All-day events are not shown yet.
- Stats count what you tap (Done, steps). Hyperday can't know whether you attended a meeting. "Ran over" isn't measurable, so it isn't shown.
- Personal installs with a free Apple ID expire after 7 days.

## Contribution notes

Hyperday is not accepting outside contributions yet. Bug reports and ideas are welcome as GitHub issues. Please include your iOS version, device, and steps to reproduce.

Development notes:
- Keep `DayEngine` free of UI and iOS APIs.
- Anything the widget renders must go through `DayActivityAttributes.ContentState`, which is limited to 4 KB.
- UI changes start as mockups before code.

