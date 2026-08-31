import SwiftUI

/// The expanded panel: a "home board" showing a now-playing strip plus every
/// widget at a glance. Tap the media strip or any widget tile to focus it
/// full-size; a back chevron returns home.
struct DashboardPage: View {
    @ObservedObject var viewModel: NotchViewModel
    @ObservedObject var nowPlaying: NowPlayingController
    @ObservedObject var battery: BatteryMonitor
    @StateObject private var store = DashboardStore()
    @StateObject private var weather = WeatherService()
    @StateObject private var launcherStore = LauncherStore()
    @StateObject private var appScanner = AppScanner()
    @StateObject private var shortcuts = ShortcutsService()
    @StateObject private var toggles = SystemToggles()
    @StateObject private var profiles = ProfileStore()
    @StateObject private var focus = FocusMonitor()
    @StateObject private var calendar = CalendarService()
    @StateObject private var camera = CameraMirrorController()

    private var mirrorInUse: Bool { store.slots.contains(.mirror) }

    private enum Focus: Equatable { case home, media, widget(DashboardWidgetKind) }
    @State private var nav: Focus = .home
    @State private var lastAutoMinute = -1

    private let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    var body: some View {
        VStack(spacing: 6) {
            switch nav {
            case .home:
                homeBoard
            case .media:
                detail("Now Playing") { MediaPlayerView(nowPlaying: nowPlaying) }
            case .widget(let kind):
                detail(kind.title) {
                    widget(for: kind)
                        .padding(10)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: nav)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: viewModel.isExpanded) { _, expanded in
            if !expanded { nav = .home }
        }
        .onAppear {
            weather.start()
            focus.start()
            appScanner.rescan(extraFolders: launcherStore.extraFolders)
            shortcuts.reload()
            calendar.start()
            profiles.applyLayout = { store.slots = $0 }
            if let active = profiles.active { store.slots = active.slots }
            camera.setActive(viewModel.isExpanded && mirrorInUse)
        }
        .onChange(of: viewModel.isExpanded) { _, expanded in
            camera.setActive(expanded && mirrorInUse)
        }
        .onChange(of: mirrorInUse) { _, inUse in
            camera.setActive(viewModel.isExpanded && inUse)
        }
        .onChange(of: launcherStore.extraFolders) { _, folders in
            appScanner.rescan(extraFolders: folders)
        }
        .onChange(of: viewModel.now) { _, now in
            let minute = Calendar.current.component(.minute, from: now)
            guard minute != lastAutoMinute else { return }
            lastAutoMinute = minute
            if let target = profiles.resolveAutomatic(now: now, focus: focus.current),
               target.id != profiles.activeID {
                profiles.activate(target)
            }
        }
        .onChange(of: focus.current) { _, f in
            if let target = profiles.resolveAutomatic(now: .now, focus: f),
               target.id != profiles.activeID {
                profiles.activate(target)
            }
        }
    }

    // MARK: Home board

    private var homeBoard: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                ProfileBar(profiles: profiles)
            }
            MediaStrip(nowPlaying: nowPlaying, now: viewModel.now) {
                nav = .media
            }
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(0..<DashboardStore.slotCount, id: \.self) { index in
                    DashboardSlot(
                        kind: store.slots[index],
                        onTap: { nav = .widget(store.slots[index]) },
                        onChange: { newKind in
                            store.setSlot(index, to: newKind)
                            profiles.captureLayout(store.slots)
                        },
                        content: { widget(for: store.slots[index]) }
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func detail<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Button {
                    nav = .home
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(4)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
            }
            content()
        }
        .transition(.opacity)
    }

    @ViewBuilder
    private func widget(for kind: DashboardWidgetKind) -> some View {
        switch kind {
        case .dayProgress: DayProgressWidget(now: viewModel.now)
        case .quote:       QuoteWidget(now: viewModel.now)
        case .weather:     WeatherWidget(weather: weather)
        case .shelf:       ShelfWidget(viewModel: viewModel)
        case .battery:     BatteryWidget(battery: battery)
        case .appLauncher: AppLauncherWidget(scanner: appScanner, store: launcherStore)
        case .shortcuts:   ShortcutsWidget(service: shortcuts)
        case .quickToggles: QuickTogglesWidget(toggles: toggles)
        case .events:      EventsWidget(calendar: calendar)
        case .mirror:      MirrorWidget(camera: camera)
        case .empty:       EmptyView()
        }
    }
}

// MARK: - Profile bar

private struct ProfileBar: View {
    @ObservedObject var profiles: ProfileStore

    var body: some View {
        HStack(spacing: 6) {
            Menu {
                ForEach(profiles.profiles) { profile in
                    Button {
                        profiles.activate(profile)
                    } label: {
                        Label(profile.name, systemImage: profile.id == profiles.activeID ? "checkmark" : "")
                    }
                }
                Divider()
                Toggle("Auto-switch (Focus / schedule)", isOn: $profiles.autoSwitch)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "person.crop.rectangle.stack")
                        .font(.system(size: 9))
                    Text(profiles.active?.name ?? "No profile")
                        .font(.system(size: 10, weight: .semibold))
                    if profiles.autoSwitch {
                        Image(systemName: "clock").font(.system(size: 8))
                    }
                }
                .foregroundStyle(.white.opacity(0.7))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()

            Spacer()
        }
        .padding(.horizontal, 2)
    }
}

// MARK: - Slot chrome

private struct DashboardSlot<Content: View>: View {
    let kind: DashboardWidgetKind
    let onTap: () -> Void
    let onChange: (DashboardWidgetKind) -> Void
    @ViewBuilder let content: () -> Content
    @State private var hovering = false

    var body: some View {
        content()
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(.white.opacity(hovering ? 0.1 : 0.06), in: RoundedRectangle(cornerRadius: 10))
            .overlay(alignment: .topTrailing) {
                if hovering {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 8))
                        .foregroundStyle(.white.opacity(0.4))
                        .padding(5)
                }
            }
            .contentShape(Rectangle())
            .onHover { hovering = $0 }
            .onTapGesture(perform: onTap)
            .contextMenu {
                ForEach(DashboardWidgetKind.allCases) { option in
                    Button {
                        onChange(option)
                    } label: {
                        Label(option.title, systemImage: option.symbol)
                    }
                }
            }
    }
}

// MARK: - Media strip

private struct MediaStrip: View {
    @ObservedObject var nowPlaying: NowPlayingController
    let now: Date
    let onTap: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 10) {
            if let track = nowPlaying.track {
                ArtworkView(image: track.artwork, size: 34, corner: 7)
                VStack(alignment: .leading, spacing: 1) {
                    Text(track.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(track.artist)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                EqualizerBars(playing: track.isPlaying,
                              tint: MediaSource.match(bundleID: track.bundleID)?.tint ?? .white)
                HStack(spacing: 10) {
                    Button { nowPlaying.previous() } label: {
                        Image(systemName: "backward.fill").font(.system(size: 11))
                    }.buttonStyle(.plain)
                    Button { nowPlaying.togglePlayPause() } label: {
                        Image(systemName: track.isPlaying ? "pause.fill" : "play.fill").font(.system(size: 14))
                    }.buttonStyle(.plain)
                    Button { nowPlaying.next() } label: {
                        Image(systemName: "forward.fill").font(.system(size: 11))
                    }.buttonStyle(.plain)
                }
                .foregroundStyle(.white.opacity(0.85))
            } else {
                Image(systemName: "music.note").font(.system(size: 13)).foregroundStyle(.white.opacity(0.4))
                Text("Nothing playing")
                    .font(.system(size: 11)).foregroundStyle(.white.opacity(0.4))
                Spacer()
                Text(now, format: .dateTime.hour().minute())
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 44)
        .background(.white.opacity(hovering ? 0.1 : 0.06), in: RoundedRectangle(cornerRadius: 10))
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture { if nowPlaying.track != nil { onTap() } }
    }
}

// MARK: - Widgets

private struct DayProgressWidget: View {
    let now: Date

    private var fraction: Double {
        let cal = Calendar.current
        let start = cal.startOfDay(for: now)
        let end = cal.date(byAdding: .day, value: 1, to: start)!
        return now.timeIntervalSince(start) / end.timeIntervalSince(start)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Day", systemImage: "clock.arrow.circlepath")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
            Spacer(minLength: 0)
            Text("\(Int(fraction * 100))%")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
            ProgressView(value: fraction)
                .tint(.white.opacity(0.85))
        }
    }
}

private struct QuoteWidget: View {
    let now: Date

    var body: some View {
        let quote = Quotes.current(for: now)
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: "quote.opening")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.4))
            Text(quote.text)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(3)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
            Text("— \(quote.author)")
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.45))
                .lineLimit(1)
        }
    }
}

private struct WeatherWidget: View {
    @ObservedObject var weather: WeatherService

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let c = weather.conditions {
                HStack(spacing: 6) {
                    Image(systemName: c.symbol)
                        .font(.system(size: 18))
                        .foregroundStyle(.white)
                    Text("\(Int(c.temperature.rounded()))°")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                Text(c.summary)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer(minLength: 0)
                HStack(spacing: 8) {
                    Text("H \(Int(c.high.rounded()))°")
                    Text("L \(Int(c.low.rounded()))°")
                }
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.45))
                if !c.place.isEmpty {
                    Text(c.place).font(.system(size: 9)).foregroundStyle(.white.opacity(0.35)).lineLimit(1)
                }
            } else {
                Label("Weather", systemImage: "cloud.sun")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                Spacer(minLength: 0)
                Text(weather.lastError ?? "Loading…")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ShelfWidget: View {
    @ObservedObject var viewModel: NotchViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Shelf", systemImage: "tray.full")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
            if viewModel.shelfItems.isEmpty {
                Spacer(minLength: 0)
                Text("Drop files onto the notch")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.35))
                Spacer(minLength: 0)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.shelfItems, id: \.self) { url in
                            ShelfChip(url: url) { viewModel.removeFromShelf(url) }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct BatteryWidget: View {
    @ObservedObject var battery: BatteryMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Battery", systemImage: "battery.100")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
            Spacer(minLength: 0)
            if let s = battery.state {
                HStack(spacing: 6) {
                    Image(systemName: s.symbolName).font(.system(size: 16))
                    Text("\(s.percent)%")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
                .foregroundStyle(s.isCharging ? .green : (s.percent <= 20 ? .red : .white))
            } else {
                Text("No battery").font(.system(size: 10)).foregroundStyle(.white.opacity(0.4))
            }
        }
    }
}

// MARK: - Launcher widgets

private struct AppLauncherWidget: View {
    @ObservedObject var scanner: AppScanner
    @ObservedObject var store: LauncherStore
    @State private var page = 0

    private let perPage = 8   // 4 cols × 2 rows
    private let cols = [GridItem(.adaptive(minimum: 34), spacing: 8)]

    private var pages: [[LaunchItem]] {
        stride(from: 0, to: scanner.items.count, by: perPage).map {
            Array(scanner.items[$0..<min($0 + perPage, scanner.items.count)])
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label("Apps", systemImage: "square.grid.3x3.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
                if pages.count > 1 {
                    Text("\(page + 1)/\(pages.count)")
                        .font(.system(size: 9, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }

            if scanner.items.isEmpty {
                Spacer(minLength: 0)
                Text("Scanning…").font(.system(size: 10)).foregroundStyle(.white.opacity(0.4))
                Spacer(minLength: 0)
            } else {
                let safePage = min(page, max(pages.count - 1, 0))
                LazyVGrid(columns: cols, spacing: 8) {
                    ForEach(pages.isEmpty ? [] : pages[safePage]) { item in
                        Button { Launcher.open(item) } label: {
                            Image(nsImage: item.icon)
                                .resizable()
                                .frame(width: 30, height: 30)
                        }
                        .buttonStyle(.plain)
                        .help(item.name)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 16).onEnded { v in
                guard pages.count > 1 else { return }
                if v.translation.width < -20 { page = min(page + 1, pages.count - 1) }
                else if v.translation.width > 20 { page = max(page - 1, 0) }
            }
        )
        .contextMenu {
            Button("Add Folder to Scan…") {
                if let url = Launcher.chooseFolder() { store.addFolder(url) }
            }
            if !store.extraFolders.isEmpty {
                Menu("Remove Scanned Folder") {
                    ForEach(store.extraFolders, id: \.self) { url in
                        Button(url.lastPathComponent) { store.removeFolder(url) }
                    }
                }
            }
        }
    }
}

private struct QuickTogglesWidget: View {
    @ObservedObject var toggles: SystemToggles

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Toggles", systemImage: "switch.2")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))

            HStack(spacing: 8) {
                ToggleButton(system: "moon.fill", label: "Dark",
                             on: toggles.isDarkMode) { toggles.toggleDarkMode() }
                ToggleButton(system: "cup.and.saucer.fill", label: "Awake",
                             on: toggles.keepAwake) { toggles.toggleKeepAwake() }
                ToggleButton(system: "power", label: "Login",
                             on: toggles.launchAtLogin) { toggles.toggleLaunchAtLogin() }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private struct ToggleButton: View {
        let system: String
        let label: String
        let on: Bool
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                VStack(spacing: 3) {
                    Image(systemName: system)
                        .font(.system(size: 14))
                        .frame(width: 30, height: 30)
                        .background(on ? Color.accentColor : Color.white.opacity(0.1),
                                    in: RoundedRectangle(cornerRadius: 8))
                    Text(label)
                        .font(.system(size: 8))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .foregroundStyle(on ? .white : .white.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
    }
}

private struct EventsWidget: View {
    @ObservedObject var calendar: CalendarService

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Next", systemImage: "calendar")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))

            if calendar.access == .denied {
                Spacer(minLength: 0)
                Text("Calendar access off").font(.system(size: 10)).foregroundStyle(.white.opacity(0.4))
                Spacer(minLength: 0)
            } else if calendar.events.isEmpty {
                Spacer(minLength: 0)
                Text("Nothing scheduled").font(.system(size: 10)).foregroundStyle(.white.opacity(0.4))
                Spacer(minLength: 0)
            } else {
                ForEach(calendar.events) { event in
                    HStack(spacing: 5) {
                        Circle().fill(event.color).frame(width: 5, height: 5)
                        Text(event.title)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text(event.isAllDay ? "all day"
                             : event.start.formatted(date: .omitted, time: .shortened))
                            .font(.system(size: 9, design: .rounded))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct MirrorWidget: View {
    @ObservedObject var camera: CameraMirrorController

    var body: some View {
        ZStack {
            switch camera.state {
            case .running:
                CameraPreview(session: camera.session)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            case .denied:
                VStack(spacing: 4) {
                    Image(systemName: "video.slash").font(.system(size: 16))
                    Text("Camera access off").font(.system(size: 9))
                }
                .foregroundStyle(.white.opacity(0.4))
            case .idle:
                Image(systemName: "camera.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ShortcutsWidget: View {
    @ObservedObject var service: ShortcutsService

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Shortcuts", systemImage: "bolt.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))

            if service.names.isEmpty {
                Spacer(minLength: 0)
                Text("No shortcuts found").font(.system(size: 10)).foregroundStyle(.white.opacity(0.4))
                Spacer(minLength: 0)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(service.names, id: \.self) { name in
                            Button { service.run(name) } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.white.opacity(0.5))
                                    Text(name)
                                        .font(.system(size: 10))
                                        .foregroundStyle(.white.opacity(0.85))
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
