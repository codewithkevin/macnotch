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
- Small open/close delay so a mouse passing over the notch doesn't trigger it.
- Optional "click to pin open".
- Haptic feedback on expand (`NSHapticFeedbackManager`).
- Match the hardware notch corner radius more precisely; blur/vibrancy behind the panel.

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
