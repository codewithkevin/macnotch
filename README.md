# MacNotch

An open-source macOS utility that turns the notch (or a simulated notch on
non-notch Macs) into an interactive panel — a clock and a drag-and-drop file
shelf today, with media controls, battery, and more planned.

Inspired by [macnotch.io](https://macnotch.io), NotchNook, and
[The Boring Notch](https://github.com/TheBoredTeam/boring.notch).

## Status

Early scaffold / MVP. Working:

- Borderless floating `NSPanel` anchored under the notch, above full-screen apps
- Hover to expand / collapse with a spring animation
- Live clock
- **System-wide media player** — artwork, title/artist, play/pause, next/previous,
  and a draggable scrubber for *any* app that reports to macOS Now Playing:
  Music, Spotify, podcasts, and browser media in Safari / Chrome / Arc / Firefox.
  Works on macOS 15.4+ / 26 via [`MediaRemoteAdapter`](https://github.com/ejbills/mediaremote-adapter).
  Shuffle, repeat and like are wired up too.
- **Battery widget** — glyph in the collapsed bar when charging / plugged in /
  low, a battery card in the expanded panel, and a pulse when a charger connects.
- Drag-and-drop file shelf — drag files in, drag them back out, remove with the
  hover ✕. Contents **persist across launches** via security-scoped bookmarks.
- Status-bar menu to reposition or quit

## Requirements

- macOS 14+
- Xcode 16+
- [XcodeGen](https://github.com/yonyz/XcodeGen) (`brew install xcodegen`)

## Build & run

```sh
xcodegen generate
open MacNotch.xcodeproj
```

Then run the `MacNotch` scheme. The `.xcodeproj` is generated and git-ignored —
edit `project.yml` to change build settings.

CLI build:

```sh
xcodebuild -project MacNotch.xcodeproj -scheme MacNotch -configuration Debug \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

## Architecture

| File | Role |
|------|------|
| `MacNotchApp.swift` | `@main` app + `AppDelegate` (status item, screen-change observers) |
| `NotchWindowController.swift` | Owns the `NotchPanel` (non-activating, `.statusBar` level, all-spaces) |
| `NotchMetrics.swift` | Resolves real notch geometry via `safeAreaInsets` / `auxiliaryTopLeftArea`; falls back to a simulated notch |
| `NotchViewModel.swift` | Observable state: expansion, clock, shelf items (persisted) |
| `ShelfStore.swift` | Security-scoped bookmark persistence for the shelf |
| `System/BatteryMonitor.swift` | IOKit power-source state + charger-connect events |
| `Media/NowPlayingController.swift` | Wraps `MediaRemoteAdapter`; publishes track + interpolated position + shuffle/repeat, exposes transport |
| `Views/NotchView.swift` | SwiftUI panel — `NotchShape`, collapsed/expanded content, media player, shelf, drop handling |

### Media backend

Apple locked the private `MediaRemote` framework behind an entitlement in
macOS 15.4. `MediaRemoteAdapter` works around this by loading a helper framework
inside `/usr/bin/perl` (an Apple-signed binary that *is* entitled) and streaming
now-playing JSON over stdout. The `MediaRemoteAdapter.framework` is embedded &
signed into the app bundle automatically by SPM.

## Roadmap

See [TODO.md](TODO.md) for the full working backlog.

- [x] Shuffle / repeat / like controls
- [x] Persist shelf across launches
- [x] Battery / charging widget
- [ ] Multi-display / per-notch support
- [ ] Settings window (hover delay, which widgets, launch at login)
- [ ] App icon + notarized release, Sparkle auto-update

## License

MIT — see [LICENSE](LICENSE).
