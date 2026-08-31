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

### Phase B — launcher
- [ ] **App launcher** — scan `/Applications`, `~/Applications`, `/System/Applications`; icon grid with paginated sets. Click to `NSWorkspace.open`.
- [ ] Config: **extra folders to scan**, and **folder shortcuts** (open in Finder).
- [ ] Display modes: icon grid / list / paginated sets (setting).
- [ ] **Actions** row — run **Shortcuts** (`shortcuts run <name>` via `NSUserActivity` / `x-callback` or the Shortcuts CLI); icon or paginated sets. List available shortcuts via the Shortcuts app export or `shortcuts list`.

### Phase C — profiles + system
- [ ] **Profiles** — named sets of dashboard layout + settings. Manual switch from the panel.
- [ ] **Focus-based switching** — observe the current Focus (`INFocusStatusCenter` / the Focus filter API is limited; may need the DND defaults / `com.apple.donotdisturb` or a Focus filter extension) and switch profile.
- [ ] **Time-based switching** — schedule rules (e.g. Work 9–18 Mon–Fri).
- [ ] **Quick toggles** widget — Dark Mode, Do Not Disturb, True Tone, Night Shift, AirDrop, Bluetooth, Wi-Fi. Some need private APIs / `osascript` / `shortcuts`; scope to what's reliably scriptable.
- [ ] **Persist Never Sleep** toggle (wraps `caffeinate` / `IOPMAssertionCreateWithName`) with an option to **Launch at Login** (`SMAppService`).
- [ ] **Screen Time** widget — usage today. (Screen Time data is sandboxed / no public API — investigate `knowledgeC.db` read feasibility or drop.)

### Phase D — media cards + mirror + events
- [ ] Media **source cards** — beyond the current unified Now Playing: detect installed players (Spotify, Apple Music, **Plex**, **NetEase Cloud Music**, **VLC**) and show a per-app card when that app is the Now Playing source. Bundle-id detection for install state.
- [ ] **Mirror** widget — front-camera preview (`AVCaptureSession`), needs `NSCameraUsageDescription`. Also useful on hover (already noted in §7).
- [ ] **Shortcuts & events** widget — next calendar events (EventKit) + pinned shortcuts in one card.

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
