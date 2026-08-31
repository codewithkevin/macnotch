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
- Drag-and-drop file shelf (drag files in, drag them back out)
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
| `NotchViewModel.swift` | Observable state: expansion, clock, shelf items |
| `Views/NotchView.swift` | SwiftUI panel — `NotchShape`, collapsed/expanded content, shelf, drop handling |

## Roadmap

- [ ] Now-playing media controls (MediaRemote)
- [ ] Battery / charging indicator
- [ ] Persist shelf across launches
- [ ] Per-display notch support / multi-monitor
- [ ] Settings window (hover delay, which widgets)
- [ ] App icon + notarized release, Sparkle auto-update

## License

MIT — see [LICENSE](LICENSE).
