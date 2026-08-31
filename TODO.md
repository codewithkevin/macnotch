# MacNotch — Backlog

Status legend: **next** = pick up now · **soon** = after the "next" batch · **later** = nice to have

The README Roadmap is the short version; this file is the working breakdown.

---

## done

### 1. Media: shuffle / repeat / like controls ✅
`NowPlayingController` publishes `shuffle` / `repeatMode` and exposes
`toggleShuffle()` / `cycleRepeat()` (off → all → one) / `like()`. Secondary
button row under the transport controls; active state tinted with the accent
colour. `Sources/Media/NowPlayingController.swift`, `Sources/Views/NotchView.swift`

### 2. Persist the shelf across launches ✅
`ShelfStore` stores minimal bookmarks in `UserDefaults`, refreshes stale ones,
and drops entries whose file is gone. `NotchViewModel` loads on init and saves
on every mutation; added `removeFromShelf` + a hover ✕ on each chip.
`Sources/ShelfStore.swift`, `Sources/NotchViewModel.swift`

### 3. Battery / charging widget ✅
`BatteryMonitor` reads IOKit power sources and refreshes via
`IOPSNotificationCreateRunLoopSource`; publishes percent, charging/plugged/
charged, and time-to-full/empty. Collapsed shows a glyph when charging,
plugged, or ≤ 20% (red when low). Expanded shows a battery card beside the
clock. `justPluggedIn` drives a 2.5s pulse when a charger connects.
`Sources/System/BatteryMonitor.swift`, `Sources/Views/NotchView.swift`

---

## next

### 4. Multi-display / per-notch support
- `NotchMetrics.current()` currently picks the first screen with a notch. Support a panel per screen, or a setting to pick which display.
- Rebuild panels on `NSApplication.didChangeScreenParametersNotification` (observer already exists in `AppDelegate`).
- Handle the external-non-notch-display case (simulated notch there too, or none).

### 5. Settings window
- Real `Settings` scene (currently `EmptyView`). Options:
  - Hover-to-open delay + close delay
  - Which widgets are enabled (media / clock / battery / shelf)
  - Which display(s) to show on
  - Launch at login (`SMAppService.mainApp`)
- Persist via `@AppStorage`.

### 6. Notch interaction polish
- ~~Small open/close delay so a mouse passing over the notch doesn't trigger it.~~ ✅ (dwell + confirm)
- Optional "click to pin open".
- Haptic feedback on expand (`NSHapticFeedbackManager`).
- Match the hardware notch corner radius more precisely; blur/vibrancy behind the panel.

---

## Dashboard epic (replaces / absorbs the "Shelf" page)

The third pager page becomes a configurable **Dashboard** — a grid of widget
slots the user arranges, plus a launcher. Big feature; ship in phases. Target
layout: **4 widget slots** + a launcher strip + a top status row.

### Phase A — frame + first widgets ✅
- [x] `DashboardPage` — 2×2 `LazyVGrid`; layout persisted by `DashboardStore` (JSON in UserDefaults). Right-click a slot → context menu to change its widget.
- [x] `DashboardWidgetKind` enum registry (title + SF Symbol per kind).
- [x] **Day Progress** widget — % of day elapsed + progress bar (pure date math).
- [x] **Quote** widget — rotates hourly from a bundled in-source list (`Quotes`).
- [x] **Shelf** widget — compact wrapper over the existing shelf items/chips.
- [x] **Weather** widget — `WeatherService`: IP location via ipwho.is + Open-Meteo current/daily (no key, no CoreLocation permission). WMO code → SF Symbol.
- [x] **Battery** also available as a dashboard widget.
- follow-ups: `Widget` protocol + Settings-driven registry; CoreLocation for accurate weather; drag-to-reorder slots; 1×1 / 2×1 spans.

### Phase B — launcher ✅
- [x] **App launcher** widget — `AppScanner` scans `/Applications`(+Utilities), `/System/Applications`(+Utilities), `~/Applications` + extra folders; de-duped, sorted. Paginated icon grid (8/page, swipe), click → `NSWorkspace.open`.
- [x] **Extra folders to scan** — `LauncherStore` persists them; widget context menu adds (via `NSOpenPanel`) / removes.
- [x] **Shortcuts** widget — `ShortcutsService` runs `/usr/bin/shortcuts list` / `run <name>` via `Process`; scrollable list, click to run.
- follow-ups: list display mode for apps (LauncherStore.mode exists, not surfaced); pinned/favourite apps + ordering; folder-shortcut chips (open in Finder — `Launcher.reveal` exists); Actions as icon sets; first-run `shortcuts` permission handling.

### Phase C — profiles + system ✅ (partial, by design)
- [x] **Profiles** — `ProfileStore`: named layouts (`Profile` = name + slots + optional focusName + schedule), persisted. Switch from the `ProfileBar` menu on the dashboard. Editing a slot writes back to the active profile. Seeds "Default" + a scheduled "Work" profile.
- [x] **Time-based switching** — `Profile.Schedule` (weekday set + start/end minute, wraps midnight); checked once a minute when auto-switch is on.
- [x] **Focus-based switching** — `FocusMonitor` polls `~/Library/DoNotDisturb/DB/Assertions.json` (best effort; no public API). Focus match beats schedule match.
- [x] **Quick Toggles** widget — Dark Mode (`osascript`), Keep Awake (`IOPMAssertionCreateWithName`), Launch at Login (`SMAppService`). Reliable, no private APIs.
- ❌ Night Shift / True Tone / AirDrop / Bluetooth / DND toggles — dropped: all need private frameworks or extra binaries. Revisit if we ship a helper.
- ❌ **Screen Time** widget — dropped: no public API; `knowledgeC.db` is TCC-protected and unstable.
- follow-ups: profile editor UI (create/rename/delete, set schedule + Focus mapping — currently only editable in code/JSON); status-bar menu profile switcher; Wi-Fi toggle via `networksetup` (best effort).

### Phase D — media cards + mirror + events ✅
- [x] Media **source badge** — `MediaSource` maps known bundle IDs (Spotify, Apple Music, Plex, NetEase, VLC, Safari/Chrome/Arc/Firefox) to a name + accent + icon. Now Playing panel shows a tinted source chip; `Track` carries `bundleID`. `MediaSource.installed` lists which players are present.
- [x] **Mirror** widget — `CameraMirrorController` (`AVCaptureSession`, front camera, mirrored preview). Runs only while the panel is open *and* a slot uses it; `NSCameraUsageDescription` added.
- [x] **Events** widget — `CalendarService` (EventKit, full-access request); next 4 events over 48h with per-calendar colour. `NSCalendars*UsageDescription` added.
- follow-ups: dedicated media *cards* per source (bigger than the chip); pinned shortcuts alongside events; mirror flip / zoom controls.

### Open questions
- Widget slot sizing: fixed 2×2, or allow 1×1 / 2×1 / 2×2 spans? (macnotch.io uses spans.)
- How much of this is worth doing vs. deferring — a lot of the system toggles fight the sandbox / private APIs.

---

## later

### 7. More widgets
- Calendar: next event (EventKit, needs usage string + permission prompt).
- Timers / stopwatch.
- Now-playing lyrics (stretch).
- AirDrop-style quick-share from the shelf.
- Camera mirror (front camera preview) on hover.

### 8. Release engineering
- App icon + menu-bar template icon asset catalog.
- Hardened-runtime entitlements review; notarize a `.app` / `.dmg`.
- Sparkle auto-update feed.
- GitHub Actions: build + test on PR, draft release on tag.
- Basic unit tests: `NotchMetrics` geometry math, `NowPlayingController` position interpolation, shelf bookmark round-trip.

### 9. Licensing / distribution model
- Decide: fully free/OSS, or freemium like macnotch.io. Affects whether we add a licensing layer at all.

---

## known issues / cleanups
- `project.yml` pins the media package by commit revision — revisit when the fork tags releases.
- `DEVELOPMENT_TEAM` is empty in `project.yml`; each dev sets it locally. Consider an `.xcconfig` that's git-ignored.
- No error surface if the perl media helper fails to start — add a fallback state / log.
