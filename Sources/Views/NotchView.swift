import SwiftUI
import UniformTypeIdentifiers

struct NotchView: View {
    @ObservedObject var viewModel: NotchViewModel
    @ObservedObject var nowPlaying: NowPlayingController
    @ObservedObject var battery: BatteryMonitor

    private var collapsedWidth: CGFloat { max(viewModel.metrics.notchWidth, 180) }
    private var collapsedHeight: CGFloat { max(viewModel.metrics.notchHeight, 28) }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                NotchShape(cornerRadius: viewModel.isExpanded ? 22 : 10)
                    .fill(.black)
                    .shadow(color: .black.opacity(viewModel.isExpanded ? 0.35 : 0),
                            radius: 18, y: 8)

                if viewModel.isExpanded {
                    ExpandedContent(viewModel: viewModel, nowPlaying: nowPlaying, battery: battery)
                        .padding(.horizontal, 22)
                        .padding(.top, collapsedHeight)
                        .padding(.bottom, 16)
                        .transition(.opacity)
                } else {
                    CollapsedContent(viewModel: viewModel, nowPlaying: nowPlaying, battery: battery)
                        .frame(height: collapsedHeight)
                }
            }
            .frame(width: viewModel.isExpanded ? viewModel.metrics.expandedSize.width : collapsedWidth,
                   height: viewModel.isExpanded ? viewModel.metrics.expandedSize.height : collapsedHeight)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.isExpanded)
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                handleDrop(providers)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(viewModel.isExpanded)
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                Task { @MainActor in
                    viewModel.addToShelf([url])
                    viewModel.setExpanded(true)
                }
            }
        }
        return true
    }
}

// MARK: - Collapsed

private struct CollapsedContent: View {
    @ObservedObject var viewModel: NotchViewModel
    @ObservedObject var nowPlaying: NowPlayingController
    @ObservedObject var battery: BatteryMonitor

    var body: some View {
        HStack(spacing: 6) {
            if let track = nowPlaying.track {
                ArtworkView(image: track.artwork, size: 18, corner: 4)
                Image(systemName: track.isPlaying ? "waveform" : "pause.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.75))
                    .symbolEffect(.variableColor.iterative, isActive: track.isPlaying)
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
            }
            Spacer(minLength: 4)
            Text(viewModel.now, format: .dateTime.hour().minute())
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
                .monospacedDigit()
            if let s = battery.state {
                HStack(spacing: 3) {
                    Text("\(s.percent)%")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .monospacedDigit()
                    Image(systemName: s.symbolName)
                        .font(.system(size: 11))
                }
                .foregroundStyle(s.percent <= 20 && !s.isPluggedIn ? .red : .white.opacity(0.7))
                .symbolEffect(.pulse, isActive: battery.justPluggedIn)
            }
        }
        .padding(.horizontal, 14)
    }
}

// MARK: - Expanded

private struct ExpandedContent: View {
    @ObservedObject var viewModel: NotchViewModel
    @ObservedObject var nowPlaying: NowPlayingController
    @ObservedObject var battery: BatteryMonitor

    @State private var page = 0
    @GestureState private var drag: CGFloat = 0

    private var pageCount: Int { battery.state != nil ? 3 : 2 }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width

            HStack(spacing: 0) {
                mediaOrClock.frame(width: w)
                if battery.state != nil {
                    BatteryCard(battery: battery).frame(width: w)
                }
                DashboardPage(viewModel: viewModel, battery: battery).frame(width: w)
            }
            .offset(x: -CGFloat(page) * w + drag)
            .frame(width: w, alignment: .leading)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 12)
                    .updating($drag) { value, state, _ in state = value.translation.width }
                    .onEnded { value in
                        let threshold = w / 4
                        var next = page
                        if value.translation.width < -threshold { next += 1 }
                        else if value.translation.width > threshold { next -= 1 }
                        page = min(max(next, 0), pageCount - 1)
                    }
            )
            .overlay(alignment: .bottom) {
                if pageCount > 1 {
                    HStack(spacing: 5) {
                        ForEach(0..<pageCount, id: \.self) { i in
                            Circle()
                                .fill(.white.opacity(i == page ? 0.9 : 0.28))
                                .frame(width: 5, height: 5)
                                .onTapGesture { withAnimation(.spring(response: 0.3)) { page = i } }
                        }
                    }
                }
            }
            .animation(.spring(response: 0.32, dampingFraction: 0.85), value: page)
            .animation(.interactiveSpring(), value: drag)
        }
        .onChange(of: viewModel.isExpanded) { _, expanded in
            if !expanded { page = 0 }
        }
    }

    @ViewBuilder private var mediaOrClock: some View {
        if nowPlaying.hasMedia {
            MediaPlayerView(nowPlaying: nowPlaying)
        } else {
            ClockView(now: viewModel.now)
        }
    }
}

private struct BatteryCard: View {
    @ObservedObject var battery: BatteryMonitor

    var body: some View {
        if let s = battery.state {
            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: s.symbolName)
                    .font(.system(size: 24))
                    .foregroundStyle(s.isCharging ? .green
                                     : (s.percent <= 20 ? .red : .white.opacity(0.85)))
                    .symbolEffect(.pulse, isActive: battery.justPluggedIn)
                Text("\(s.percent)%")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                Text(statusLine(s))
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.45))
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
    }

    private func statusLine(_ s: BatteryMonitor.State) -> String {
        if s.isCharged && s.isPluggedIn { return "Charged" }
        if s.isCharging {
            return s.timeRemainingString.map { "\($0) to full" } ?? "Charging"
        }
        return s.timeRemainingString.map { "\($0) left" } ?? "On battery"
    }
}

private struct ClockView: View {
    let now: Date
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(now, format: .dateTime.weekday(.wide).month().day())
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
            Text(now, format: .dateTime.hour().minute().second())
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
        .frame(maxHeight: .infinity, alignment: .center)
    }
}

// MARK: - Media player

private struct MediaPlayerView: View {
    @ObservedObject var nowPlaying: NowPlayingController

    var body: some View {
        let track = nowPlaying.track

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ArtworkView(image: track?.artwork, size: 56, corner: 10)

                VStack(alignment: .leading, spacing: 2) {
                    Text(track?.title ?? "Nothing playing")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(track?.artist ?? "")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                    if let app = track?.appName, !app.isEmpty {
                        Text(app)
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.35))
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                VStack(spacing: 6) {
                    HStack(spacing: 14) {
                        TransportButton(system: "backward.fill", size: 15) { nowPlaying.previous() }
                        TransportButton(system: (track?.isPlaying ?? false) ? "pause.fill" : "play.fill",
                                        size: 20) { nowPlaying.togglePlayPause() }
                        TransportButton(system: "forward.fill", size: 15) { nowPlaying.next() }
                    }
                    HStack(spacing: 16) {
                        TransportButton(system: "shuffle", size: 11,
                                        active: nowPlaying.isShuffling) { nowPlaying.toggleShuffle() }
                        TransportButton(system: nowPlaying.repeatSymbol, size: 11,
                                        active: nowPlaying.isRepeating) { nowPlaying.cycleRepeat() }
                        TransportButton(system: "heart", size: 11) { nowPlaying.like() }
                    }
                }
            }

            ScrubBar(progress: nowPlaying.progress,
                     elapsed: nowPlaying.elapsed,
                     duration: track?.duration ?? 0) { fraction in
                nowPlaying.seek(toFraction: fraction)
            }
        }
        .frame(maxHeight: .infinity, alignment: .center)
    }
}

private struct TransportButton: View {
    let system: String
    let size: CGFloat
    var active: Bool = false
    let action: () -> Void
    @State private var hovering = false

    private var opacity: Double {
        if active { return 1 }
        return hovering ? 1 : 0.8
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(active ? Color.accentColor : .white.opacity(opacity))
                .frame(width: size + 12, height: size + 12)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

private struct ScrubBar: View {
    let progress: Double
    let elapsed: TimeInterval
    let duration: TimeInterval
    let onSeek: (Double) -> Void

    var body: some View {
        VStack(spacing: 3) {
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.15))
                    Capsule().fill(.white.opacity(0.8))
                        .frame(width: max(0, min(w, w * progress)))
                }
                .frame(height: 4)
                .frame(maxHeight: .infinity, alignment: .center)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { value in
                            onSeek(min(max(value.location.x / w, 0), 1))
                        }
                )
            }
            .frame(height: 12)

            HStack {
                Text(elapsed.clockString)
                Spacer()
                Text(duration > 0 ? duration.clockString : "--:--")
            }
            .font(.system(size: 10, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.45))
            .monospacedDigit()
        }
    }
}

private struct ArtworkView: View {
    let image: NSImage?
    let size: CGFloat
    let corner: CGFloat

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
            } else {
                RoundedRectangle(cornerRadius: corner)
                    .fill(.white.opacity(0.1))
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: size * 0.4))
                            .foregroundStyle(.white.opacity(0.4))
                    )
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: corner))
    }
}

// MARK: - Shelf

struct ShelfView: View {
    @ObservedObject var viewModel: NotchViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Shelf").font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                if !viewModel.shelfItems.isEmpty {
                    Button("Clear") { viewModel.clearShelf() }
                        .buttonStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            if viewModel.shelfItems.isEmpty {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                    .foregroundStyle(.white.opacity(0.2))
                    .overlay(
                        Text("Drop files here")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.4))
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(viewModel.shelfItems, id: \.self) { url in
                            ShelfChip(url: url) { viewModel.removeFromShelf(url) }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ShelfChip: View {
    let url: URL
    let onRemove: () -> Void
    @State private var hovering = false

    var body: some View {
        VStack(spacing: 4) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .frame(width: 34, height: 34)
            Text(url.lastPathComponent)
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(1)
                .frame(maxWidth: 60)
        }
        .overlay(alignment: .topTrailing) {
            if hovering {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.white, .black.opacity(0.6))
                }
                .buttonStyle(.plain)
                .offset(x: 4, y: -4)
            }
        }
        .onHover { hovering = $0 }
        .onDrag { NSItemProvider(contentsOf: url) ?? NSItemProvider() }
    }
}

// MARK: - Shape

/// A rounded-bottom shape that visually merges with the top edge of the screen.
struct NotchShape: Shape {
    var cornerRadius: CGFloat

    var animatableData: CGFloat {
        get { cornerRadius }
        set { cornerRadius = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let r = min(cornerRadius, rect.height / 2)
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY),
                          control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - r),
                          control: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
